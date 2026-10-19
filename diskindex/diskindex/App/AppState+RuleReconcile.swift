//
//  AppState+RuleReconcile.swift
//  diskindex
//
//  Regel-Warteschlange: Status-Flags statt Swift-Namensfilter (234).
//

import Foundation
import SwiftUI

extension AppState {
    func enqueueRuleReconcile() {
        guard featureAccess.canWriteIndex else {
            ruleReconcileDeferredWhileLocked = true
            return
        }
        ruleReconcileNeedsRerun = true
        guard ruleReconcileTask == nil else { return }
        startRuleReconcileWorker()
    }

    func waitForRuleReconcileIdle() async {
        if !isRuleReconcileQueueActive { return }
        await withCheckedContinuation { continuation in
            ruleReconcileIdleWaiters.append(continuation)
        }
    }

    func cancelRuleReconcileForTermination() {
        ruleReconcileTask?.cancel()
        ruleReconcileTask = nil
        isRuleReconcileQueueActive = false
        ruleReconcileNeedsRerun = false
        indexRepository.blocksLoadsForRuleReconcile = false
        indexRepository.hidesLoadsByScope = false
        resumeRuleReconcileIdleWaiters()
    }

    /// Versions-Sperre: laufenden oder anstehenden Abgleich zum Unlock merken (c.0.3.3.002 e/f).
    func cancelRuleReconcileForVersionLock() {
        if isRuleReconcileQueueActive || ruleReconcileNeedsRerun {
            ruleReconcileDeferredWhileLocked = true
        }
        cancelRuleReconcileForTermination()
    }

    private func startRuleReconcileWorker() {
        guard featureAccess.canWriteIndex else {
            ruleReconcileDeferredWhileLocked = true
            return
        }
        isRuleReconcileQueueActive = true
        indexRepository.hidesLoadsByScope = true
        // bug.0.4.088: Spalten nicht leeren und Laden nicht sperren. Ausgeblendet hat schon `IndexRepository.scope`
        // (an Ort und Stelle); neu gelesen wird erst nach der Warteschlange (`resumeAfterRuleReconcile`).
        guard let store = indexStore else {
            finishRuleReconcileWorker(emitIdle: true)
            return
        }
        let own = WorkerTaskHandle()
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    // bug.0.4.062 (REPORT 132): abgebrochen und schon ersetzt → den Handle des neuen nicht anfassen.
                    guard own.isCurrent(self.ruleReconcileTask) else { return }
                    self.finishRuleReconcileWorker(emitIdle: true)
                }
            }
            repeat {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.ruleReconcileNeedsRerun = false }
                let scope = await MainActor.run { IndexScope.from(self.appSettings) }
                do {
                    _ = try await store.reconcileScopeToStatus(scope)
                } catch {
                    if DiskIndexLog.isOperationalFailure(error) {
                        DiskIndexLog.shared.record(.index, .error, "rule reconcile \(error)")
                    }
                    break
                }
            } while await MainActor.run(body: { self.ruleReconcileNeedsRerun }) && !Task.isCancelled
        }
        own.task = task
        ruleReconcileTask = task
    }

    private func finishRuleReconcileWorker(emitIdle: Bool) {
        ruleReconcileTask = nil
        if ruleReconcileNeedsRerun, indexStore != nil {
            if featureAccess.canWriteIndex {
                startRuleReconcileWorker()
            } else {
                ruleReconcileDeferredWhileLocked = true
            }
            return
        }
        isRuleReconcileQueueActive = false
        indexRepository.blocksLoadsForRuleReconcile = false
        indexRepository.hidesLoadsByScope = false
        resumeRuleReconcileIdleWaiters()
        if emitIdle, let indexStore {
            Task { await indexStore.emit(.ruleReconcileIdle) }
        }
        scheduleDatabaseMaintenance()
    }

    private func resumeRuleReconcileIdleWaiters() {
        let waiters = ruleReconcileIdleWaiters
        ruleReconcileIdleWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    /// bug.0.4.088: Suchtreffer und Favoriten, die die neue Regel ausschließt, verschwinden sofort an Ort und Stelle
    /// (gleiche Prüfung wie die Warteschlange: eigener Name und Tiefe); neu gesucht wird nach der Warteschlange.
    func hideResultsInPlace(by scope: IndexScope) {
        // Offener Ordner, den die Regel jetzt ausschließt: seine Spalte (und alle rechts davon) schließen, die Auswahl
        // darin verwerfen – der Ordner selbst ist in der Spalte links schon ausgeblendet.
        var state = columnBrowserState
        if let cut = state.pathStack.indices.first(where: { scope.shouldHide(name: state.pathStack[$0], depth: $0 + 1) }) {
            state.pathStack = Array(state.pathStack.prefix(cut))
            if let focus = state.selection.focusColumnIndex, focus >= cut {
                state.selection = ColumnSelection()
                state.selectedUncapturedFolderID = nil
            }
            columnBrowserState = state
        }
        let hides = { (item: IndexedItem) in scope.shouldHide(name: item.name, depth: item.parentPath.count + 1) }
        let hiddenHits = searchMatch.items.filter { hides($0.item) }.count
        let hiddenFavorites = favoriteObjects.filter { hides($0.item) }.count
        guard hiddenHits > 0 || hiddenFavorites > 0 else { return }
        withAnimation(IndexRepository.rowChangeAnimation) {
            if hiddenHits > 0 {
                searchMatch.items.removeAll { hides($0.item) }
                searchMatch.itemCount = searchMatch.itemCount.map { max(0, $0 - hiddenHits) }
            }
            if hiddenFavorites > 0 {
                favoriteObjects.removeAll { hides($0.item) }
                favoriteItemCount = favoriteItemCount.map { max(0, $0 - hiddenFavorites) }
            }
        }
    }

    func resumeAfterRuleReconcile() async {
        // bug.0.4.088/090: veraltet statt leer – kein Ladezustand, wieder freigegebene Einträge erscheinen an ihrem Platz.
        indexRepository.markAllStale()
        await loadStoredMedia()
        await reloadFavoritesIfVisible()
        if pendingSearchAfterRuleReconcile || mainWindowDestination == .search {
            pendingSearchAfterRuleReconcile = false
            await runSearch()
        }
    }
}

/// Eigener Handle eines Worker-Tasks (bug.0.4.062, REPORT 132): Das `defer` des alten Tasks läuft erst nach dem
/// Abbruch, oft nachdem schon ein neuer gestartet ist. Nur wer noch der aktuelle Task ist, räumt auf.
final class WorkerTaskHandle {
    var task: Task<Void, Never>?

    func isCurrent(_ current: Task<Void, Never>?) -> Bool {
        guard let task, let current else { return false }
        return task == current
    }
}

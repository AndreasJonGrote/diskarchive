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
        // bug.0.4.105: nicht nach Voreinstellungen abgleichen, solange die gespeicherten Einstellungen nicht lesbar sind.
        guard !settingsUnreadable else { return }
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
                        DiskIndexLog.shared.record(.index, .error, "rule reconcile \(DiskIndexLog.errorSummary(error))")
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

    /// Ob die (noch nicht von der Warteschlange angewendete) Regel einen Treffer bzw. Favoriten ausblendet – eine Quelle
    /// für `hideResultsInPlace` und das Nachladen während der Warteschlange (bug.0.4.096).
    /// bug.0.4.097: auch jede Ebene von `parentPath` (Treffer und Favoriten unterhalb eines ignorierten Ordners).
    nonisolated static func ruleHidesResult(_ item: IndexedItem, by scope: IndexScope) -> Bool {
        if scope.shouldHide(name: item.name, depth: item.parentPath.count + 1) { return true }
        return item.parentPath.indices.contains { scope.shouldHide(name: item.parentPath[$0], depth: $0 + 1) }
    }

    /// bug.0.4.088: Suchtreffer und Favoriten, die die neue Regel ausschließt, verschwinden sofort an Ort und Stelle
    /// (eigener Name und Tiefe sowie jede Ebene des Pfads, bug.0.4.097); neu gesucht wird nach der Warteschlange.
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
        let hides = { (item: IndexedItem) in Self.ruleHidesResult(item, by: scope) }
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

    /// bug.0.4.131: Eine neu gelesene Spalte enthält den dort offenen Ordner nicht mehr. Umbenannt (gleiche Zeile, neuer
    /// Name) → Pfad folgt dem neuen Namen, Auswahl bleibt; gelöscht → Pfad ab dieser Ebene gekürzt, Auswahl auf den
    /// Elternordner. Die Unterpfade unter dem alten Namen werden ungültig.
    func followOpenPathAfterReload(mediumID: UUID, path: [String], previous: [IndexedItem]?, items: [IndexedItem]) {
        let shownMedium = columnBrowserState.selectedMediumID ?? columnBrowserMedia.first?.id
        guard shownMedium == mediumID else { return }
        var state = columnBrowserState
        let level = path.count
        guard level < state.pathStack.count, Array(state.pathStack.prefix(level)) == path else { return }
        let open = state.pathStack[level]
        if items.contains(where: { $0.isFolder && $0.name == open }) { return }
        let oldStack = state.pathStack
        let renamed: IndexedItem? = {
            if let old = previous?.first(where: { $0.isFolder && $0.name == open }), let rowID = old.rowID {
                return items.first { $0.isFolder && $0.rowID == rowID }
            }
            // Ohne alten Stand (Cache verworfen): die gemerkte Zeilenkennung des offenen Ordners (bug.0.4.147), auch
            // wenn die Auswahl schon tiefer liegt …
            if level < state.openFolderRowIDs.count {
                let known = state.openFolderRowIDs[level]
                if let hit = items.first(where: { $0.isFolder && $0.rowID == known }) { return hit }
            }
            // … sonst der gewählte Ordner dieser Spalte.
            guard state.selection.focusColumnIndex == level else { return nil }
            return items.first { $0.isFolder && state.selection.contains($0.id) }
        }()
        if let renamed {
            state.pathStack[level] = renamed.name
        } else {
            state.pathStack = Array(state.pathStack.prefix(level))
            state.selectedUncapturedFolderID = nil
            if level > 0, let parent = indexRepository.children(mediumID: mediumID, path: Array(path.dropLast()))
                .first(where: { $0.isFolder && $0.name == path[level - 1] }) {
                state.selection = ColumnSelection(
                    ids: [parent.id], anchorID: parent.id, focusColumnIndex: level - 1, lastClickedID: parent.id
                )
            } else {
                state.selection = ColumnSelection()
            }
        }
        DiskIndexLog.shared.ui("open path changed level=\(level)")
        columnBrowserState = state
        for depth in (level + 1)...oldStack.count {
            indexRepository.invalidate(mediumID: mediumID, path: Array(oldStack.prefix(depth)))
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

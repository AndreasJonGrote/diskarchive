//
//  AppState+RuleReconcile.swift
//  diskindex
//
//  Regel-Warteschlange: Status-Flags statt Swift-Namensfilter (234).
//

import Foundation

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
        indexRepository.blocksLoadsForRuleReconcile = true
        indexRepository.invalidateAll()
        guard let store = indexStore else {
            finishRuleReconcileWorker(emitIdle: true)
            return
        }
        ruleReconcileTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
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

    func resumeAfterRuleReconcile() async {
        indexRepository.invalidateAll()
        await loadStoredMedia()
        await reloadFavoritesIfVisible()
        if pendingSearchAfterRuleReconcile || mainWindowDestination == .search {
            pendingSearchAfterRuleReconcile = false
            await runSearch()
        }
    }
}

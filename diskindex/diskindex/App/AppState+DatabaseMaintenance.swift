//
//  AppState+DatabaseMaintenance.swift
//  diskindex
//
//  Leerlauf: incremental_vacuum + WAL wenn Wartungs-Schuld hoch genug (236).
//

import Foundation

extension AppState {
    func scheduleDatabaseMaintenance() {
        guard indexStore != nil else { return }
        guard databaseMaintenanceTask == nil else { return }
        startDatabaseMaintenanceWorker()
    }

    func cancelDatabaseMaintenanceForTermination() {
        databaseMaintenanceTask?.cancel()
        databaseMaintenanceTask = nil
    }

    private func startDatabaseMaintenanceWorker() {
        databaseMaintenanceTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.databaseMaintenanceTask = nil
                }
            }
            for _ in 0..<2 {
                guard !Task.isCancelled else { return }
                let ready = await MainActor.run { self.canRunDatabaseMaintenance() }
                guard ready else {
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                guard let store = await MainActor.run(body: { self.indexStore }) else { return }
                if await store.hasAnyActiveIndexingToken() {
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                await store.runCompactionIfNeeded()
                return
            }
        }
    }

    func canRunDatabaseMaintenance() -> Bool {
        guard storeReady, indexStore != nil else { return false }
        if isRuleReconcileQueueActive { return false }
        if !mediumLiveSyncIDs.isEmpty { return false }
        if !menuBarIndexingSpinnerIDs.isEmpty { return false }
        return true
    }
}

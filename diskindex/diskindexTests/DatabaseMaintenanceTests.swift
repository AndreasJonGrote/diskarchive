//
//  DatabaseMaintenanceTests.swift
//  diskindexTests
//
//  Wartungs-Schuld, Compaction, Sabotage (236).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite struct DatabaseMaintenanceTests {
    @Test func maintenanceDebtAccumulatesAndCompactionClearsIt() async throws {
        let harness = try StoreHarness.make()
        let store = harness.store
        await store.recordMaintenanceDebt(6_000)
        await store.recordMaintenanceDebt(4_500)
        #expect(await store.maintenanceDebt() == 10_500)
        await store.runCompactionIfNeeded()
        #expect(await store.maintenanceDebt() == 0)
    }

    @Test func incrementalVacuumSabotageLeavesFreelistUntouched() async throws {
        let previous = DatabaseMaintenance.incrementalVacuumEnabled
        defer { DatabaseMaintenance.incrementalVacuumEnabled = previous }

        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Bulk", fsType: "apfs", bytes: 1_000_000)
        _ = try await harness.addRoot(
            medium: medium,
            entries: (0..<2_000).map { ScannedEntry(name: "f-\($0).txt", isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        )
        let ids = try await harness.store.pool.read { db in
            try Int64.fetchAll(
                db,
                sql: "SELECT id FROM items WHERE storageID = (SELECT id FROM storages WHERE uuid = ?)",
                arguments: [MediumCodecV3.data(medium.uuid)]
            )
        }
        try await harness.store.pool.write { db in
            let marks = Array(repeating: "?", count: ids.count).joined(separator: ",")
            try db.execute(sql: "DELETE FROM items WHERE id IN (\(marks))", arguments: StatementArguments(ids))
        }
        let freeBefore = try await harness.store.pool.read { db in try DatabaseMaintenance.freelistCount(db) }
        #expect(freeBefore > 0)

        DatabaseMaintenance.incrementalVacuumEnabled = false
        await harness.store.recordMaintenanceDebt(MaintenancePolicy.changeThreshold)
        await harness.store.runCompactionIfNeeded()

        let freeAfter = try await harness.store.pool.read { db in try DatabaseMaintenance.freelistCount(db) }
        #expect(freeAfter == freeBefore)
        #expect(await harness.store.maintenanceDebt() == 0)

        DatabaseMaintenance.incrementalVacuumEnabled = true
        await harness.store.recordMaintenanceDebt(MaintenancePolicy.changeThreshold)
        await harness.store.runCompactionIfNeeded()
        let freeCompacted = try await harness.store.pool.read { db in try DatabaseMaintenance.freelistCount(db) }
        #expect(freeCompacted < freeBefore)
    }

    @MainActor
    @Test func maintenanceRunsAfterLiveSyncEnds() async throws {
        let harness = try StoreHarness.make()
        let appState = AppState()
        appState.attach(store: harness.store)
        await harness.store.recordMaintenanceDebt(MaintenancePolicy.changeThreshold)
        let mediumID = UUID()
        appState.beginMediumLiveSync(mediumID)
        appState.scheduleDatabaseMaintenance()
        try await Task.sleep(for: .milliseconds(300))
        #expect(await harness.store.maintenanceDebt() == MaintenancePolicy.changeThreshold)
        appState.endMediumLiveSync(mediumID)
        let cleared = await waitUntil(timeout: 5) {
            await harness.store.maintenanceDebt() == 0
        }
        #expect(cleared)
    }

    @MainActor
    @Test func maintenanceWorkerRunsWhenIdle() async throws {
        let harness = try StoreHarness.make()
        let appState = AppState()
        appState.attach(store: harness.store)
        await harness.store.recordMaintenanceDebt(MaintenancePolicy.changeThreshold)
        appState.scheduleDatabaseMaintenance()
        try await Task.sleep(for: .milliseconds(500))
        #expect(await harness.store.maintenanceDebt() == 0)
    }
}

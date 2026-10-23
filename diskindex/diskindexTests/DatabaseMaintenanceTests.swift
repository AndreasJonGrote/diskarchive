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

@Suite(.serialized) struct DatabaseMaintenanceTests {
    @Test func maintenanceDebtAccumulatesAndCompactionClearsIt() async throws {
        let harness = try StoreHarness.make()
        let store = harness.store
        await store.recordMaintenanceDebt(6_000)
        await store.recordMaintenanceDebt(4_500)
        #expect(await store.maintenanceDebt() == 10_500)
        await store.runCompactionIfNeeded()
        #expect(await store.maintenanceDebt() == 0)
    }

    /// Nach vielen gelöschten Zeilen senkt die Wartung die freelist (incremental_vacuum in `runCompactionIfNeeded`).
    /// bug.0.3.9.001: ohne prozessweiten Sabotage-Schalter; die Gegenprobe ist eine Handprobe (Vakuum-Aufruf in
    /// `IndexStoreV3.runCompactionIfNeeded` auskommentieren → rot).
    @Test func compactionShrinksFreelist() async throws {
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

        await harness.store.recordMaintenanceDebt(MaintenancePolicy.changeThreshold)
        await harness.store.runCompactionIfNeeded()
        #expect(await harness.store.maintenanceDebt() == 0)
        let freeCompacted = try await harness.store.pool.read { db in try DatabaseMaintenance.freelistCount(db) }
        #expect(freeCompacted < freeBefore)
    }

    /// bug.0.4.108: „Vergessen“ eines großen Mediums erhöht die Wartungsschuld, danach gibt die Wartung Seiten zurück.
    @Test func forgettingALargeMediumAddsMaintenanceDebt() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Gross", fsType: "apfs", bytes: 1_000_000)
        _ = try await harness.addRoot(
            medium: medium,
            entries: (0..<20_000).map { ScannedEntry(name: "f-\($0).txt", isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        )
        #expect(await harness.store.maintenanceDebt() < 20_000)
        try await harness.store.deleteMedium(uuid: medium.uuid)
        #expect(await harness.store.maintenanceDebt() >= 20_000, "Wartungsschuld nach Vergessen nicht erhöht")
        let freeBefore = try await harness.store.pool.read { db in try DatabaseMaintenance.freelistCount(db) }
        #expect(freeBefore > 0)
        await harness.store.runCompactionIfNeeded()
        let freeAfter = try await harness.store.pool.read { db in try DatabaseMaintenance.freelistCount(db) }
        #expect(freeAfter < freeBefore, "Datei wird nach Vergessen nicht kleiner")
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
        let cleared = await waitUntil(timeout: 5) {
            await harness.store.maintenanceDebt() == 0
        }
        #expect(cleared)
    }
}

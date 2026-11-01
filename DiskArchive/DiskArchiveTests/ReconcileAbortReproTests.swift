//
//  ReconcileAbortReproTests.swift
//  DiskArchiveTests
//
//  bug.0.4.014 — Repro aus Werkzeuge/audit-repro/ReproAuditTests.swift (Nr. 58, 59, 67).
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct ReconcileAbortReproTests {

    private struct RawRow {
        var id: Int64
        var parentID: Int64?
        var name: String
        var status: Int
        var depth: Int
    }

    private func rawRows(_ store: IndexStoreV3) async throws -> [RawRow] {
        try await store.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT id, parentID, name, status, depth FROM items ORDER BY id").map {
                RawRow(id: $0["id"], parentID: $0["parentID"], name: $0["name"], status: $0["status"], depth: $0["depth"])
            }
        }
    }

    private func favoriteCount(_ store: IndexStoreV3) async throws -> Int {
        try await store.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM favorites") ?? 0 }
    }

    private func child(_ store: IndexStoreV3, _ medium: UUID, _ parent: Int64?, _ name: String) async throws -> StoredItem? {
        try await store.children(mediumUUID: medium, parentID: parent).first { $0.name == name }
    }

    @Test func nr58_pendingFinishKeepsGoneRowsAndFavorites() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "X", isFolder: true, fileID: "10")],
            seenAt: Date()
        )
        let x = try #require(try await child(harness.store, medium.uuid, nil, "X"))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: x.id,
            entries: [ScannedEntry(name: "f.txt", isFolder: false, sizeBytes: 3, fileID: "11")],
            seenAt: Date()
        )
        let f = try #require(try await child(harness.store, medium.uuid, x.id, "f.txt"))
        try await harness.store.setFavorite(itemID: f.id, true)

        let token = UUID()
        #expect(try await harness.store.beginIndexing(mediumUUID: medium.uuid, token: token))
        try await harness.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: [], seenAt: Date())
        let goneBefore = try await rawRows(harness.store).filter { $0.status == 2 }.map(\.name).sorted()
        #expect(goneBefore == ["X", "f.txt"], "Vorbedingung: X und f.txt sind gone, ist \(goneBefore)")
        _ = try await harness.store.finishIndexing(mediumUUID: medium.uuid, token: token, status: .pending, firstIndexedAt: nil)

        let stillThere = try await rawRows(harness.store).contains { $0.id == f.id }
        let favorites = try await favoriteCount(harness.store)
        #expect(stillThere, "Nr. 58: Zeile f.txt (gone) wurde bei finishIndexing(.pending) gelöscht")
        #expect(favorites == 1, "Nr. 58: Favorit verloren nach finishIndexing(.pending), favorites=\(favorites)")
    }

    @Test func nr67_failedBeginIndexingLeavesNoToken() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.deleteMedium(uuid: medium.uuid)
        var threw = false
        do {
            _ = try await harness.store.beginIndexing(mediumUUID: medium.uuid, token: UUID())
        } catch {
            threw = true
        }
        #expect(threw, "Vorbedingung: beginIndexing für gelöschtes Medium wirft")
        let hasToken = await harness.store.hasAnyActiveIndexingToken()
        let hasMediumToken = await harness.store.hasActiveIndexingToken(mediumUUID: medium.uuid)
        #expect(!hasToken, "Nr. 67: hasAnyActiveIndexingToken()==true nach geworfenem beginIndexing")
        #expect(!hasMediumToken, "Nr. 67: hasActiveIndexingToken(medium)==true nach geworfenem beginIndexing")
    }

    @Test func nr59_pausedReconcileDoesNotSkipLayersOnNextRun() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("l1/l2/l3/f.txt")
        let first = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        #expect(first.status == .indexed)
        let indexed = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(indexed.indexStatus == .indexed && indexed.completedDepth >= 3)

        access.clearListed()
        let paused = try await harness.run(access: access, maxDepth: nil, fromScratch: false, shouldHalt: {
            access.listed.isEmpty ? .none : .pause
        })
        let afterPause = try #require(try await harness.store.medium(uuid: harness.mediumID))

        access.file("l1/l2/spaet.txt")
        access.clearListed()
        let next = try await harness.run(access: access, maxDepth: nil, fromScratch: false)
        let names = try await harness.names()
        #expect(names.contains("spaet.txt"),
                "Nr. 59: Folgelauf findet l1/l2/spaet.txt nicht. pausiert=\(paused.status) DB-Status nach Pause=\(afterPause.indexStatus) completedDepth=\(afterPause.completedDepth); Folgelauf status=\(next.status) gelesen=\(access.listed)")
    }
}

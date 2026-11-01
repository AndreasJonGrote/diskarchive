//
//  FileIdentityWriterReproTests.swift
//  DiskArchiveTests
//
//  bug.0.4.016 — Repro aus Werkzeuge/audit-repro (Regel 25): Nr. 57, 69.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct FileIdentityWriterReproTests {
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

    private func child(_ store: IndexStoreV3, _ medium: UUID, _ parent: Int64?, _ name: String) async throws -> StoredItem? {
        try await store.children(mediumUUID: medium, parentID: parent).first { $0.name == name }
    }

    @Test func nr57_moveIntoFolderWithSameNamedFileNeverFails() async throws {
        var failures: [String] = []
        for run in 0..<30 {
            let harness = try StoreHarness.make()
            let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: nil,
                entries: [
                    ScannedEntry(name: "P", isFolder: true, fileID: "100"),
                    ScannedEntry(name: "Q", isFolder: true, fileID: "200"),
                ],
                seenAt: Date()
            )
            let p = try #require(try await child(harness.store, medium.uuid, nil, "P"))
            let q = try #require(try await child(harness.store, medium.uuid, nil, "Q"))
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: p.id,
                entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, fileID: "1001")],
                seenAt: Date()
            )
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: q.id,
                entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 2, fileID: "1002")],
                seenAt: Date()
            )
            do {
                try await harness.store.applyDirectory(
                    mediumUUID: medium.uuid, parentID: p.id,
                    entries: [
                        ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, fileID: "1001"),
                        ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 2, fileID: "1002"),
                    ],
                    seenAt: Date()
                )
            } catch {
                failures.append("Lauf \(run): \(error)")
            }
        }
        #expect(failures.isEmpty, "Nr. 57: \(failures.count)/30 Läufe scheitern. Erster: \(failures.first ?? "-")")
    }

    @Test func nr57_deletedTargetNameBecomesGone() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [
                ScannedEntry(name: "P", isFolder: true, fileID: "100"),
                ScannedEntry(name: "Q", isFolder: true, fileID: "200"),
            ],
            seenAt: Date()
        )
        let p = try #require(try await child(harness.store, medium.uuid, nil, "P"))
        let q = try #require(try await child(harness.store, medium.uuid, nil, "Q"))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: p.id,
            entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, fileID: "1001")],
            seenAt: Date()
        )
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: q.id,
            entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 2, fileID: "1002")],
            seenAt: Date()
        )
        let r1 = try #require(try await child(harness.store, medium.uuid, p.id, "a.txt"))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: p.id,
            entries: [ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 2, fileID: "1002")],
            seenAt: Date()
        )
        let row = try #require(try await rawRows(harness.store).first { $0.id == r1.id })
        let visible = try await harness.store.children(mediumUUID: medium.uuid, parentID: p.id).map(\.name).sorted()
        #expect(row.status == 2, "Nr. 57: R1 (P/a.txt) hat status=\(row.status) statt 2; sichtbar in P: \(visible)")
    }

    @Test func nr69_folderMovedByFileIDShiftsDescendantDepths() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let store = harness.store
        let id = medium.uuid
        let a = ScannedEntry(name: "A", isFolder: true, fileID: "1")
        let b = ScannedEntry(name: "B", isFolder: true, fileID: "2")
        let m = ScannedEntry(name: "M", isFolder: true, fileID: "3")
        let x = ScannedEntry(name: "x", isFolder: true, fileID: "4")
        let y = ScannedEntry(name: "y.txt", isFolder: false, sizeBytes: 9, fileID: "5")
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [a], seenAt: Date())
        let aRow = try #require(try await child(store, id, nil, "A"))
        try await store.applyDirectory(mediumUUID: id, parentID: aRow.id, entries: [b], seenAt: Date())
        let bRow = try #require(try await child(store, id, aRow.id, "B"))
        try await store.applyDirectory(mediumUUID: id, parentID: bRow.id, entries: [m], seenAt: Date())
        let mRow = try #require(try await child(store, id, bRow.id, "M"))
        try await store.applyDirectory(mediumUUID: id, parentID: mRow.id, entries: [x], seenAt: Date())
        let xRow = try #require(try await child(store, id, mRow.id, "x"))
        try await store.applyDirectory(mediumUUID: id, parentID: xRow.id, entries: [y], seenAt: Date())
        let yRow = try #require(try await child(store, id, xRow.id, "y.txt"))
        #expect(xRow.depth == 4 && yRow.depth == 5, "Vorbedingung: x Tiefe 4, y Tiefe 5")

        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [a, m], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: aRow.id, entries: [b], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: bRow.id, entries: [], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: mRow.id, entries: [x], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: xRow.id, entries: [y], seenAt: Date())

        let rows = try await rawRows(store)
        let mAfter = try #require(rows.first { $0.id == mRow.id })
        let xAfter = try #require(rows.first { $0.id == xRow.id })
        let yAfter = try #require(rows.first { $0.id == yRow.id })
        #expect(mAfter.parentID == nil && mAfter.depth == 1, "Vorbedingung: M liegt in der Wurzel, Tiefe 1 (ist \(mAfter.depth))")
        #expect(xAfter.depth == 2, "Nr. 69: x hat Tiefe \(xAfter.depth) statt 2")
        #expect(yAfter.depth == 3, "Nr. 69: y.txt hat Tiefe \(yAfter.depth) statt 3")
    }

    @Test func fileIDRenameWithNewFileAtOldNameKeepsFavorite30x() async throws {
        for _ in 0..<30 {
            let harness = try StoreHarness.make()
            let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: nil,
                entries: [ScannedEntry(name: "old.txt", isFolder: false, sizeBytes: 3, fileID: "9001")],
                seenAt: Date()
            )
            let before = try #require(try await child(harness.store, medium.uuid, nil, "old.txt"))
            try await harness.store.setFavorite(itemID: before.id, true)
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: nil,
                entries: [
                    ScannedEntry(name: "new.txt", isFolder: false, sizeBytes: 3, fileID: "9001"),
                    ScannedEntry(name: "old.txt", isFolder: false, sizeBytes: 9, fileID: "9002"),
                ],
                seenAt: Date()
            )
            let renamed = try #require(try await child(harness.store, medium.uuid, nil, "new.txt"))
            #expect(renamed.id == before.id)
            #expect(renamed.isFavorite)
        }
    }
}

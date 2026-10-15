//
//  LiveRenameReproTests.swift
//  diskindexTests
//
//  bug.0.4.017 — Repro Nr. 56, 70 (Regel 25).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct LiveRenameReproTests {
    private struct RawRow {
        var id: Int64
        var parentID: Int64?
        var name: String
        var status: Int
        var depth: Int
    }

    private func child(_ store: IndexStoreV3, _ medium: UUID, _ parent: Int64?, _ name: String) async throws -> StoredItem? {
        try await store.children(mediumUUID: medium, parentID: parent).first { $0.name == name }
    }

    @Test func nr56_liveRenameWithUnknownParentLeavesRootAlone() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 5, fileID: "77")],
            seenAt: Date()
        )
        let before = try #require(try await child(harness.store, medium.uuid, nil, "readme.txt"))
        let applied = try await harness.store.applyLiveRename(
            mediumUUID: medium.uuid,
            mountPath: "/Volumes/T",
            fromPath: "/Volumes/T/A/B/C/readme.txt",
            toPath: "/Volumes/T/A/B/C/readme2.txt"
        )
        let fetched = try await harness.store.pool.read { db -> Row? in
            try Row.fetchOne(db, sql: "SELECT id, parentID, name, status, depth FROM items WHERE id = ?", arguments: [before.id])
        }
        let afterRow = try #require(fetched)
        let name: String = afterRow["name"]
        let parentID: Int64? = afterRow["parentID"]
        let depth: Int = afterRow["depth"]
        #expect(!applied, "Nr. 56: applyLiveRename meldet Erfolg, obwohl /A/B/C nicht im Index ist")
        #expect(name == "readme.txt" && parentID == nil && depth == 1,
                "Nr. 56: Wurzelzeile verändert → name=\(name) parent=\(String(describing: parentID)) depth=\(depth)")
    }

    @Test func nr70_deleteAndCreateOtherFileDoesNotMoveFavorite() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-nr70-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "alt.jpg", isFolder: false, sizeBytes: 10, fileID: "900000001")],
            seenAt: Date()
        )
        let old = try #require(try await child(harness.store, medium.uuid, nil, "alt.jpg"))
        try await harness.store.setFavorite(itemID: old.id, true)
        let neuURL = mount.appendingPathComponent("neu.jpg")
        try Data(repeating: 1, count: 20).write(to: neuURL)
        var st = stat()
        #expect(stat(neuURL.path, &st) == 0)
        let neuInode = String(st.st_ino)
        let altPath = mount.appendingPathComponent("alt.jpg").path
        let pairs = LiveRenamePairs.pair(
            events: [
                ItemPathEvent(path: altPath, itemCreated: false, itemRemoved: true, itemRenamed: false),
                ItemPathEvent(path: neuURL.path, itemCreated: true, itemRemoved: false, itemRenamed: false),
            ],
            fileExists: { FileManager.default.fileExists(atPath: $0) }
        )
        for pair in pairs {
            _ = try await harness.store.applyLiveRename(
                mediumUUID: medium.uuid, mountPath: mount.path, fromPath: pair.fromPath, toPath: pair.toPath
            )
        }
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "neu.jpg", isFolder: false, sizeBytes: 20, fileID: neuInode)],
            seenAt: Date()
        )
        let neu = try #require(try await child(harness.store, medium.uuid, nil, "neu.jpg"))
        #expect(!neu.isFavorite && neu.id != old.id,
                "Nr. 70: neu.jpg erbt Zeile/Favorit von alt.jpg (gleiche id=\(neu.id == old.id), favorit=\(neu.isFavorite))")
    }
}

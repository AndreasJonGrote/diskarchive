//
//  IndexStoreV3Tests.swift
//  DiskArchiveTests
//
//  Aufgabe 231 f (2)–(6): Meldungen und Zähler, Darstellung im Schema, verschwundene Einträge, Journal-Datei.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

struct IndexStoreV3Tests {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    // (2) Umbenennen, Löschen und ein neuer Ordner: Meldungen, Zähler und Namen je Ordner
    @Test func renameDeleteAndNewFolderGiveTheExpectedChangesCountsAndNames() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Gleich")
        let changes = try await store.collectChanges {
            let writer = store.writer
            let uuid = medium.uuid
            try await writer.applyDirectories(mediumUUID: uuid, batches: [(nil, "/", 1, [
                ScannedEntry(name: "Docs", isFolder: true, modifiedAt: day),
                ScannedEntry(name: "Fotos", isFolder: true, modifiedAt: day),
                ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 5, modifiedAt: day),
            ], true)], seenAt: day)
            try await writer.completeLayer(mediumUUID: uuid, depth: 1)
            let docs = try #require(try await writer.folderID(mediumUUID: uuid, path: ["Docs"]))
            try await writer.applyDirectories(mediumUUID: uuid, batches: [(docs, "/Docs/", 2, [
                ScannedEntry(name: "x.pdf", isFolder: false, sizeBytes: 9, modifiedAt: day),
                ScannedEntry(name: "Sub", isFolder: true, modifiedAt: day),
            ], true)], seenAt: day)
            let sub = try #require(try await writer.folderID(mediumUUID: uuid, path: ["Docs", "Sub"]))
            try await writer.applyDirectories(mediumUUID: uuid, batches: [(sub, "/Docs/Sub/", 3, [
                ScannedEntry(name: "tief.txt", isFolder: false, sizeBytes: 1, modifiedAt: day),
            ], true)], seenAt: day)
            try await writer.completeLayer(mediumUUID: uuid, depth: 3)
            let later = day.addingTimeInterval(3_600)
            try await writer.applyDirectories(mediumUUID: uuid, batches: [(nil, "/", 1, [
                ScannedEntry(name: "Papiere", isFolder: true, modifiedAt: later),
                ScannedEntry(name: "Fotos", isFolder: true, modifiedAt: day),
                ScannedEntry(name: "Neu", isFolder: true, modifiedAt: later),
            ], true)], seenAt: later)
            try await writer.flushMediumMeta(mediumUUID: uuid, force: true)
        }
        #expect(changes.map(Self.describe) == [
            "items [[]]", "counts", "layer 1", "counts", "items [[\"Docs\"]]", "counts", "items [[\"Docs\", \"Sub\"]]", "counts",
            "layer 3", "counts", "items [[]]", "counts", "counts",
        ])
        let stored = try #require(try await store.writer.medium(uuid: medium.uuid))
        let truth = try await store.counts(medium: medium)
        #expect(stored.fileCount == truth.files && stored.folderCount == truth.folders)
        #expect(truth.files == 0 && truth.folders == 3)
        #expect(stored.completedDepth == 3)
        #expect(try await Self.names(store, medium, path: []) == ["Fotos", "Neu", "Papiere"])
        #expect(try await Self.names(store, medium, path: ["Papiere"]).isEmpty)
    }

    private static func describe(_ change: IndexChange) -> String {
        switch change {
        case .medium: "medium"
        case .items(_, let paths): "items \(paths)"
        case .layer(_, let depth): "layer \(depth)"
        case .counts: "counts"
        case .removed: "removed"
        case .ruleReconcileIdle: "ruleReconcileIdle"
        }
    }

    private static func names(_ store: TestStore, _ medium: StoredMedium, path: [String]) async throws -> [String] {
        let parent: Int64? = path.isEmpty ? nil : try await store.writer.folderID(mediumUUID: medium.uuid, path: path)
        return try await store.children(medium: medium, parentID: parent).map(\.name).sorted()
    }

    // (3) Darstellung: slug, kind, extID, item_details, modifiedAt als Sekunden
    @Test func entriesAreStoredAsNumbersAndSearchNames() async throws {
        let store = try TestStore.make()
        let v3 = store.store
        let medium = try await store.insert(name: "Zahlen")
        let token = UUID()
        _ = try await v3.beginIndexing(mediumUUID: medium.uuid, token: token)
        let modified = Date(timeIntervalSince1970: 1_700_000_000.9)
        _ = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Ärger.JPG", isFolder: false, sizeBytes: 42, modifiedAt: modified, fileID: "77"),
            ScannedEntry(name: "Ordner", isFolder: true),
            ScannedEntry(name: "Prog.app", isFolder: true, isPackage: true),
        ])
        let rows = try v3.pool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT i.name, i.slug, i.kind, i.isFolder, i.depth, i.status, i.modifiedAt, i.fileID, e.ext,
                           d.sizeBytes, d.isPackage
                    FROM items i LEFT JOIN extensions e ON e.id = i.extID LEFT JOIN item_details d ON d.itemID = i.id
                    ORDER BY i.name
                    """
            )
        }
        let photo = try #require(rows.first { ($0["name"] as String) == "Ärger.JPG" })
        #expect(photo["slug"] as String == "arger.jpg")
        #expect(photo["ext"] as String? == "jpg")
        #expect(photo["kind"] as Int == ItemKind.image.rawValue)
        #expect(photo["sizeBytes"] as Int64? == 42)
        #expect(photo["modifiedAt"] as Int64? == 1_700_000_000)
        #expect(photo["fileID"] as Int64? == 77)
        #expect(photo["status"] as Int == 0)
        #expect(photo["depth"] as Int == 1)
        let folder = try #require(rows.first { ($0["name"] as String) == "Ordner" })
        #expect(folder["isFolder"] as Bool)
        #expect(folder["ext"] as String? == nil)
        #expect(folder["kind"] as Int == ItemKind.other.rawValue)
        let package = try #require(rows.first { ($0["name"] as String) == "Prog.app" })
        #expect(package["kind"] as Int == ItemKind.programs.rawValue)
        #expect(package["isPackage"] as Bool)
        let types = try await v3.pool.read { db in try String.fetchAll(db, sql: "SELECT typeof(modifiedAt) FROM items WHERE name = 'Ärger.JPG'") }
        #expect(types == ["integer"])
    }

    // (4) verschwundener Eintrag
    @Test func goneItemsAreMarkedFirstAndDeletedAtTheEndOfTheRun() async throws {
        let store = try TestStore.make()
        let v3 = store.store
        let medium = try await store.insert(name: "Weg")
        let token = UUID()
        _ = try await v3.beginIndexing(mediumUUID: medium.uuid, token: token)
        let created = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "bleibt.txt", isFolder: false),
            ScannedEntry(name: "geht.txt", isFolder: false, sizeBytes: 3),
        ])
        let gone = try #require(created.first { $0.name == "geht.txt" })
        try await v3.setFavorite(itemID: gone.id, true)

        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "bleibt.txt", isFolder: false)])
        let status = try await v3.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT status FROM items WHERE id = ?", arguments: [gone.id])
        }
        #expect(status == ItemStatus.gone.rawValue)
        #expect(try await Self.count(v3, "favorites") == 1)
        #expect(try await Self.count(v3, "item_details") == 2)

        #expect(try await v3.finishIndexing(mediumUUID: medium.uuid, token: token, status: .indexed, firstIndexedAt: day))
        #expect(try await Self.count(v3, "items WHERE id = \(gone.id)") == 0)
        #expect(try await Self.count(v3, "favorites") == 0)
        #expect(try await Self.count(v3, "item_details") == 1)
        #expect(try await Self.count(v3, "items") == 1)
    }

    // (5) Journal-Datei nach dem Lauf
    @Test func journalFileIsTruncatedAfterTheRun() async throws {
        let store = try TestStore.make()
        let v3 = store.store
        let medium = try await store.insert(name: "Viel")
        let token = UUID()
        _ = try await v3.beginIndexing(mediumUUID: medium.uuid, token: token)
        for block in 0..<4 {
            let entries = (0..<5_000).map { ScannedEntry(name: "datei-\(block)-\($0).txt", isFolder: false, sizeBytes: 1, modifiedAt: day) }
            try await v3.applyDirectories(mediumUUID: medium.uuid, batches: [(nil, "/", 1, entries, false)], seenAt: day)
        }
        let walPath = v3.pool.path + "-wal"
        let before = Self.fileSize(walPath)
        #expect(before > 100_000, "ohne Lauf-Ende wächst die Journal-Datei: \(before)")
        _ = try await v3.finishIndexing(mediumUUID: medium.uuid, token: token, status: .indexed, firstIndexedAt: day)
        let after = Self.fileSize(walPath)
        #expect(after <= 16_384, "Journal-Datei nach dem Lauf: \(after) Byte")
    }

    private static func count(_ store: IndexStoreV3, _ table: String) async throws -> Int {
        try await store.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? -1 }
    }

    private static func fileSize(_ path: String) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.intValue ?? 0
    }
}

//
//  StoreSwitchTests.swift
//  diskindexTests
//
//  Aufgabe 233: Umschalten auf `IndexStoreV3` (`archive.sqlite`, erste GRDB-Migration, Bereinigen, nicht lesbare Ordner,
//  Programme, veraltete Zusatzdaten, „Zuletzt gesehen“).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite struct StoreSwitchTests {
    // (1) frischer Ordner → archive.sqlite, genau eine Migration, V3-Schema; eine daneben liegende index.sqlite bleibt unberührt
    @Test func freshFolderGetsArchiveWithOneMigrationAndLeavesTheOldFileAlone() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-switch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = directory.appendingPathComponent("index.sqlite")
        let oldBytes = Data("alte Datenbank, die nie geöffnet wird".utf8)
        try oldBytes.write(to: old)
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: old.path)

        let fileURL = directory.appendingPathComponent("archive.sqlite")
        let store = try IndexStoreV3.open(at: fileURL)
        let pool = store.pool
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let applied = try await pool.read { db in
            try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
        }
        #expect(applied == [SchemaV3.firstMigration, SchemaV3.itemsGoneMigration])
        #expect(SchemaV3.firstMigration == "0.3.0-schema")
        let tables = try await pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> 'grdb_migrations'"))
        }
        #expect(tables == Set(SchemaV3.tableNames))
        let columns = try await pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(items)").map { $0["name"] as String }
        }
        #expect(Set(columns) == [
            "id", "storageID", "parentID", "extID", "kind", "isFolder", "depth", "status", "modifiedAt",
            "fileID", "contentStamp", "listedAt", "unreadable", "name", "slug",
        ])
        let indexes = try await pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'"))
        }
        #expect(!indexes.contains("items_lastseen"))
        try pool.close()

        // Zweites Öffnen führt keine Migration mehr aus.
        let again = try IndexStoreV3.open(at: fileURL)
        let count = try await again.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations") }
        #expect(count == 2)
        try again.pool.close()

        #expect(try Data(contentsOf: old) == oldBytes)
        let attributes = try FileManager.default.attributesOfItem(atPath: old.path)
        #expect(attributes[.modificationDate] as? Date == oldDate)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(names.contains("index.sqlite"))
        #expect(try IndexStoreV3.storeFileURL().lastPathComponent == "archive.sqlite")
    }

    // 233 d): Größe oder Datum geändert → gelesene Zusatzdaten und Prüfsumme weg, Nutzerwerte bleiben; unverändert → alles bleibt
    @Test func changedSizeOrDateDropsReadExtrasButKeepsUserValues() async throws {
        let harness = try TestStore.make()
        let medium = try await harness.insert(name: "Platte")
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        let file = ScannedEntry(name: "foto.jpg", isFolder: false, sizeBytes: 10, modifiedAt: seen)
        let created = try await harness.addRoot(medium: medium, entries: [file], seenAt: seen)
        let id = try #require(created.first?.id)
        let pool = harness.store.pool
        func plant() async throws {
            try await pool.write { db in
                try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES ('width')")
                try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES ('note')")
                let key = try #require(try Int64.fetchOne(db, sql: "SELECT id FROM meta_keys WHERE key = 'width'"))
                let note = try #require(try Int64.fetchOne(db, sql: "SELECT id FROM meta_keys WHERE key = 'note'"))
                try db.execute(sql: "DELETE FROM item_meta WHERE itemID = ?", arguments: [id])
                try db.execute(sql: "INSERT INTO item_meta (itemID, keyID, value, source) VALUES (?, ?, '640', 0)", arguments: [id, key])
                try db.execute(sql: "INSERT INTO item_meta (itemID, keyID, value, source) VALUES (?, ?, 'meins', 1)", arguments: [id, note])
                try db.execute(sql: "INSERT OR REPLACE INTO item_checksum (itemID, partial) VALUES (?, x'0102')", arguments: [id])
            }
        }
        func state() async throws -> (read: Int, user: Int, checksum: Int) {
            try await pool.read { db in
                (
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item_meta WHERE itemID = ? AND source = 0", arguments: [id]) ?? -1,
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item_meta WHERE itemID = ? AND source = 1", arguments: [id]) ?? -1,
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item_checksum WHERE itemID = ?", arguments: [id]) ?? -1
                )
            }
        }
        try await plant()
        let planted = try await state()
        #expect(planted.read == 1 && planted.user == 1 && planted.checksum == 1)

        // unverändert: nichts geht verloren
        _ = try await harness.addRoot(medium: medium, entries: [file], seenAt: seen.addingTimeInterval(10))
        let unchanged = try await state()
        #expect(unchanged.read == 1 && unchanged.user == 1 && unchanged.checksum == 1)

        // Größe geändert
        var bigger = file
        bigger.sizeBytes = 11
        _ = try await harness.addRoot(medium: medium, entries: [bigger], seenAt: seen.addingTimeInterval(20))
        let bySize = try await state()
        #expect(bySize.read == 0 && bySize.user == 1 && bySize.checksum == 0)

        // Datum geändert
        try await plant()
        var newer = bigger
        newer.modifiedAt = seen.addingTimeInterval(500)
        _ = try await harness.addRoot(medium: medium, entries: [newer], seenAt: seen.addingTimeInterval(30))
        let byDate = try await state()
        #expect(byDate.read == 0 && byDate.user == 1 && byDate.checksum == 0)
    }

    // (3) Bereinigen nach geringerer Tiefe: 100.000 Einträge in unter 10 s (F25)
    @Test func pruningAfterLowerDepthRemovesAHundredThousandEntriesQuickly() async throws {
        let harness = try TestStore.make()
        let medium = try await harness.insert(name: "Last", bytes: 1_000_000_000)
        let pool = harness.store.pool
        let folders = 1_000
        let perFolder = 100
        try await pool.write { db in
            let storage = try #require(try Int64.fetchOne(db, sql: "SELECT id FROM storages"))
            let folder = try db.makeStatement(sql: "INSERT INTO items (storageID, parentID, name, slug, isFolder, depth) VALUES (?, NULL, ?, ?, 1, 1)")
            let file = try db.makeStatement(sql: "INSERT INTO items (storageID, parentID, name, slug, isFolder, depth) VALUES (?, ?, ?, ?, 0, 2)")
            let detail = try db.makeStatement(sql: "INSERT INTO item_details (itemID, sizeBytes) VALUES (?, 1)")
            for index in 0..<folders {
                let name = "ordner-\(index)"
                try folder.execute(arguments: [storage, name, name])
                let parent = db.lastInsertedRowID
                for child in 0..<perFolder {
                    let childName = "datei-\(index)-\(child).bin"
                    try file.execute(arguments: [storage, parent, childName, childName])
                    try detail.execute(arguments: [db.lastInsertedRowID])
                }
            }
        }
        let before = try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") }
        #expect(before == folders + folders * perFolder)

        let started = ContinuousClock.now
        let removed = try await harness.store.pruneToMatch(SampleScope.depth(1))
        let elapsed = started.duration(to: .now)
        let parts = elapsed.components
        let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        let report = "Bereinigen nach Tiefe 2 → 1: \(removed) Einträge in \(String(format: "%.2f", seconds)) s"
        print(report)
        Attachment.record(report, named: "prune-100k.txt")

        #expect(removed == folders * perFolder)
        #expect(elapsed < .seconds(10))
        let left = try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") }
        #expect(left == folders)
        let details = try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item_details") }
        #expect(details == 0)
        #expect(try await harness.store.orphanCount() == 0)
        _ = medium
    }

    // (4) Ordner unlesbar → später lesbar → unreadable = 0
    @Test func unreadableFolderBecomesReadableAgain() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("bad/keep.txt")
        access.file("fine/other.txt")
        _ = try await harness.run(access: access, maxDepth: nil)
        access.markUnreadable("bad")
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        let bad = try #require(try await harness.item(named: "bad"))
        #expect(bad.unreadable)
        let fine = try #require(try await harness.item(named: "fine"))
        #expect(!fine.unreadable)

        access.markReadable("bad")
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        let readable = try #require(try await harness.item(named: "bad"))
        #expect(!readable.unreadable)
        let flag = try await harness.store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT unreadable FROM items WHERE id = ?", arguments: [bad.id])
        }
        #expect(flag == 0)
    }

    // (5) .key-Paket ist kein Programm, .app schon (und .dmg/.pkg)
    @Test func onlyAppPackagesDmgAndPkgCountAsPrograms() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.package("Vortrag.key", child: "index.apxl")
        access.package("Werkzeug.app", child: "Contents")
        access.file("Installer.dmg")
        access.file("Paket.pkg")
        access.file("foto.jpg")
        access.file("Ordner/inside.txt")
        _ = try await harness.run(access: access, maxDepth: nil)

        func kind(_ name: String) async throws -> ItemKind? {
            let item = try #require(try await harness.item(named: name))
            let raw = try await harness.store.pool.read { db in
                try Int.fetchOne(db, sql: "SELECT kind FROM items WHERE id = ?", arguments: [item.id])
            }
            return raw.flatMap(ItemKind.init(rawValue:))
        }
        #expect(try await kind("Werkzeug.app") == .programs)
        #expect(try await kind("Installer.dmg") == .programs)
        #expect(try await kind("Paket.pkg") == .programs)
        #expect(try await kind("Vortrag.key") != .programs)
        #expect(try await kind("Ordner") != .programs)

        var filters = SearchFilters()
        filters.fileTypes = [.programs]
        let hits = try await harness.store.search(query: "", filters: filters, limit: 50)
        #expect(Set(hits.map(\.name)) == ["Werkzeug.app", "Installer.dmg", "Paket.pkg"])
    }
}

@Suite @MainActor struct DetailLastSeenTests {
    // (6) Detailspalte: „Zuletzt gesehen“ mit dem Datum des Mediums
    @Test func detailColumnShowsTheLastSeenDateOfTheMedium() async throws {
        guard let first = PreviewData.media.first else {
            Issue.record("PreviewData.media empty")
            return
        }
        var medium = first
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        medium.lastSeenAt = seen
        let formatted = seen.formatted(date: .abbreviated, time: .omitted)
        for language in [AppDisplayLanguage.german, .english] {
            L10n.$languageOverride.withValue(language) {
                let text = ColumnDetailText.lastSeen(medium: medium)
                let prefix = language == .german ? "Zuletzt gesehen: " : "Last seen: "
                #expect(text == prefix + formatted)
            }
        }
        medium.lastSeenAt = nil
        #expect(ColumnDetailText.lastSeen(medium: medium) == nil)
        let later = seen.addingTimeInterval(86_400 * 40)
        medium.lastSeenAt = later
        #expect(ColumnDetailText.lastSeen(medium: medium)?.contains(later.formatted(date: .abbreviated, time: .omitted)) == true)
    }
}

private enum SampleScope {
    static func depth(_ maxDepth: Int) -> IndexScope {
        // Nur der Tiefenweg (reines SQL), ohne Namensprüfung in Swift.
        var scope = IndexScope(
            maxDepth: maxDepth,
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
        )
        scope.checksNames = false
        return scope
    }
}

//
//  SchemaV3Tests.swift
//  diskindexTests
//
//  Schema V3 und Grundbausteine (Slug, natürliche Sortierung, ItemKind, Zeit); Aufgaben 230 und 233.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

private func makeV3() throws -> (pool: DatabasePool, directory: URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-v3-\(UUID().uuidString)", isDirectory: true)
    let pool = try SchemaV3.openPool(at: directory.appendingPathComponent("v3.sqlite"))
    return (pool, directory)
}

private func insertStorage(_ db: Database, name: String) throws -> Int64 {
    try db.execute(
        sql: "INSERT INTO storages (uuid, name, slug) VALUES (?, ?, ?)",
        arguments: [UUID().uuidString.data(using: .utf8), name, Slug.make(name)]
    )
    return db.lastInsertedRowID
}

private func insertItem(_ db: Database, storage: Int64, parent: Int64? = nil, name: String, isFolder: Bool = false) throws -> Int64 {
    try db.execute(
        sql: "INSERT INTO items (storageID, parentID, name, slug, isFolder) VALUES (?, ?, ?, ?, ?)",
        arguments: [storage, parent, name, Slug.make(name), isFolder]
    )
    return db.lastInsertedRowID
}

struct SchemaV3Tests {
    /// bug.0.4.107: Reine Index-Migrationen prüfen nicht alle Fremdschlüssel nach dem Lauf – eine Altverletzung sperrt
    /// den Start nicht.
    @Test func indexMigrationsOpenDespiteOldForeignKeyViolation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-fk-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fk.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pool = try DatabasePool(path: url.path, configuration: SchemaV3.makeConfiguration())
        try SchemaV3.migrator.migrate(pool, upTo: SchemaV3.firstMigration)
        try pool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            try db.execute(
                sql: "INSERT INTO items (storageID, parentID, name, slug, isFolder) VALUES (9999, NULL, 'waise', 'waise', 0)"
            )
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        try pool.close()
        let reopened = try SchemaV3.openPool(at: url)
        defer { try? reopened.close() }
        let indexes = try reopened.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'"))
        }
        #expect(indexes.contains("items_gone"))
        #expect(indexes.contains("items_search_natural"))
    }

    // (1) alle 11 Tabellen und Suchhilfen, Spalten und Typen
    @Test func createsAllElevenTablesAndAllIndexes() throws {
        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        try pool.read { db in
            let names = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> 'grdb_migrations'"))
            #expect(SchemaV3.tableNames.count == 11)
            #expect(names == Set(SchemaV3.tableNames))
            let indexes = Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%'"))
            #expect(Set(SchemaV3.indexNames).isSubset(of: indexes))

            func columns(_ table: String) throws -> [String: String] {
                var result: [String: String] = [:]
                for row in try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))") {
                    let name: String = row["name"]
                    let type: String = row["type"]
                    result[name] = type
                }
                return result
            }
            let items = try columns("items")
            let integers = ["id", "storageID", "parentID", "extID", "kind", "isFolder", "depth", "status", "modifiedAt",
                            "fileID", "contentStamp", "listedAt", "unreadable"]
            for name in integers { #expect(items[name] == "INTEGER", "items.\(name)") }
            #expect(items["name"] == "TEXT")
            #expect(items["slug"] == "TEXT")
            #expect(items.count == integers.count + 2)

            let storages = try columns("storages")
            #expect(storages["uuid"] == "BLOB")
            #expect(storages["volumeUUID"] == "BLOB")
            #expect(storages["firstSeenAt"] == "INTEGER")
            #expect(storages["lastIndexedAt"] == "INTEGER")
            #expect(storages["slug"] == "TEXT")
            #expect(storages.count == 21)

            let checksum = try columns("item_checksum")
            #expect(checksum["partial"] == "BLOB")
            #expect(checksum["full"] == "BLOB")
            #expect(try columns("item_meta")["source"] == "INTEGER")
            #expect(try columns("item_details")["sizeBytes"] == "INTEGER")
            #expect(try columns("favorites")["createdAt"] == "INTEGER")
            #expect(try columns("settings")["date"] == "INTEGER")
            #expect(try columns("api_queue").count == 7)

            #expect(try Int.fetchOne(db, sql: "PRAGMA foreign_keys") == 1)
            #expect(try String.fetchOne(db, sql: "PRAGMA journal_mode") == "wal")
        }
        // Die Journal-Grenze gilt für die Schreibverbindung (Leser sind schreibgeschützt).
        let limit = try pool.write { db in try Int.fetchOne(db, sql: "PRAGMA journal_size_limit") }
        #expect(limit == SchemaV3.journalSizeLimit)
    }

    // (2) AUTOINCREMENT: Kennungen werden nie wiederverwendet
    @Test func identifiersAreNeverReused() throws {
        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        try pool.write { db in
            let storage = try insertStorage(db, name: "A")
            _ = try insertItem(db, storage: storage, name: "eins")
            _ = try insertItem(db, storage: storage, name: "zwei")
            let third = try insertItem(db, storage: storage, name: "drei")
            try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [third])
            let fresh = try insertItem(db, storage: storage, name: "vier")
            #expect(fresh > third)
            try db.execute(sql: "DELETE FROM storages WHERE id = ?", arguments: [storage])
            let nextStorage = try insertStorage(db, name: "B")
            #expect(nextStorage > storage)
        }
    }

    // (3) Löschen eines Mediums entfernt alles Zugehörige
    @Test func deletingAStorageCascadesToEverythingBelow() throws {
        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        try pool.write { db in
            let storage = try insertStorage(db, name: "Stick")
            let folder = try insertItem(db, storage: storage, name: "Ordner", isFolder: true)
            let file = try insertItem(db, storage: storage, parent: folder, name: "datei.txt")
            try db.execute(sql: "INSERT INTO meta_keys (key) VALUES ('width')")
            let key = db.lastInsertedRowID
            try db.execute(sql: "INSERT INTO item_details (itemID, sizeBytes) VALUES (?, 5)", arguments: [file])
            try db.execute(sql: "INSERT INTO item_meta (itemID, keyID, value) VALUES (?, ?, '10')", arguments: [file, key])
            try db.execute(sql: "INSERT INTO item_checksum (itemID, partial) VALUES (?, x'00')", arguments: [file])
            try db.execute(sql: "INSERT INTO favorites (itemID, createdAt) VALUES (?, 1)", arguments: [file])
            try db.execute(sql: "INSERT INTO storage_meta (storageID, keyID, value) VALUES (?, ?, '3')", arguments: [storage, key])

            try db.execute(sql: "DELETE FROM storages WHERE id = ?", arguments: [storage])
            for table in ["items", "item_details", "item_meta", "item_checksum", "favorites", "storage_meta"] {
                #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") == 0, "\(table)")
            }
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM meta_keys") == 1)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM storage_meta") == 0)
        }
    }

    // 231 a): Nachschlagetabellen dürfen nicht gelöscht werden, solange benutzt; Medien-Kennung ist eindeutig.
    @Test func lookupRowsInUseCannotBeDeletedAndStorageUUIDIsUnique() throws {
        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        try pool.write { db in
            let storage = try insertStorage(db, name: "A")
            try db.execute(sql: "INSERT INTO extensions (ext) VALUES ('jpg')")
            let ext = db.lastInsertedRowID
            try db.execute(sql: "INSERT INTO meta_keys (key) VALUES ('width')")
            let key = db.lastInsertedRowID
            let item = try insertItem(db, storage: storage, name: "a.jpg")
            try db.execute(sql: "UPDATE items SET extID = ? WHERE id = ?", arguments: [ext, item])
            try db.execute(sql: "INSERT INTO item_meta (itemID, keyID, value) VALUES (?, ?, '1')", arguments: [item, key])
            try db.execute(sql: "INSERT INTO storage_meta (storageID, keyID, value) VALUES (?, ?, '1')", arguments: [storage, key])
            #expect(throws: DatabaseError.self) { try db.execute(sql: "DELETE FROM extensions WHERE id = ?", arguments: [ext]) }
            #expect(throws: DatabaseError.self) { try db.execute(sql: "DELETE FROM meta_keys WHERE id = ?", arguments: [key]) }
            let uuid = try #require(try Data.fetchOne(db, sql: "SELECT uuid FROM storages WHERE id = ?", arguments: [storage]))
            #expect(throws: DatabaseError.self) {
                try db.execute(sql: "INSERT INTO storages (uuid, name, slug) VALUES (?, 'B', 'b')", arguments: [uuid])
            }
        }
    }

    @Test func deletingAFolderRemovesItsChildren() throws {
        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        try pool.write { db in
            let storage = try insertStorage(db, name: "Stick")
            let folder = try insertItem(db, storage: storage, name: "Ordner", isFolder: true)
            let inner = try insertItem(db, storage: storage, parent: folder, name: "innen", isFolder: true)
            _ = try insertItem(db, storage: storage, parent: inner, name: "tief.txt")
            _ = try insertItem(db, storage: storage, name: "bleibt.txt")
            try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [folder])
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") == 1)
        }
    }

    // (4) Slug
    @Test func slugFoldsCaseUmlautsAccentsAndEszett() {
        #expect(Slug.make("Ärger Über Öl") == "arger uber ol")
        #expect(Slug.make("Straße") == "strasse")
        #expect(Slug.make("Café") == "cafe")
        #expect(Slug.make("README.TXT") == "readme.txt")
    }

    // (5) natürliche Sortierung in SQL und Swift gleich
    @Test func naturalOrderIsTheSameInSQLAndSwift() throws {
        let names = ["Datei 10", "datei 2", "Ordner", "Älter"]
        let expected = ["alter", "datei 2", "datei 10", "ordner"]
        let swiftOrder = names.map(Slug.make).sorted { NaturalOrder.compare($0, $1) == .orderedAscending }
        #expect(swiftOrder == expected)

        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sqlOrder = try pool.write { db -> [String] in
            let storage = try insertStorage(db, name: "S")
            for name in names { _ = try insertItem(db, storage: storage, name: name) }
            return try String.fetchAll(db, sql: "SELECT slug FROM items ORDER BY slug COLLATE \"natural\"")
        }
        #expect(sqlOrder == expected)
        #expect(NaturalOrder.compare("a2", "a02") == .orderedAscending)
        #expect(NaturalOrder.compare("a10", "a9") == .orderedDescending)
        #expect(NaturalOrder.compare("abc", "abc") == .orderedSame)
    }

    // (6) Abfragepläne
    @Test func columnQueryUsesTheColumnIndexWithoutASort() throws {
        let (pool, directory) = try makeV3()
        defer { try? FileManager.default.removeItem(at: directory) }
        try pool.read { db in
            let columns = try plan(db, """
                SELECT id, name FROM items WHERE storageID = 1 AND parentID IS 5 AND status = 0 ORDER BY slug COLLATE \"natural\"
                """)
            #expect(columns.contains("items_children"), "\(columns)")
            #expect(!columns.contains("TEMP B-TREE"), "\(columns)")
            let search = try plan(db, "SELECT id FROM items WHERE slug LIKE '%abc%' AND status = 0")
            // bug.0.4.077: genauer Indexname (Teilwort träfe beide). Ohne Sortierung wählt SQLite für die Teilwortsuche
            // die jüngere, gleich breite Suchhilfe `items_search_natural`.
            #expect(planIndexNames(search).contains("items_search_natural"), "\(search)")
        }
    }

    private func plan(_ db: Database, _ sql: String) throws -> String {
        try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN " + sql).map { (row: Row) -> String in row["detail"] }.joined(separator: " | ")
    }

    // Grundbausteine
    @Test func itemKindFollowsTheSearchFilterGroups() {
        #expect(ItemKind.allCases.compactMap(\.filter).count == SearchFileTypeFilter.allCases.count - 1)
        #expect(ItemKind.classify(ext: "PDF", isFolder: false) == .pdf)
        #expect(ItemKind.classify(ext: "txt", isFolder: false) == .text)
        #expect(ItemKind.classify(ext: "docx", isFolder: false) == .documents)
        #expect(ItemKind.classify(ext: "jpg", isFolder: false) == .image)
        #expect(ItemKind.classify(ext: "mov", isFolder: false) == .video)
        #expect(ItemKind.classify(ext: "flac", isFolder: false) == .audio)
        #expect(ItemKind.classify(ext: "zip", isFolder: false) == .archive)
        #expect(ItemKind.classify(ext: "dmg", isFolder: false) == .programs)
        #expect(ItemKind.classify(ext: "app", isFolder: true, isPackage: true) == .programs)
        #expect(ItemKind.classify(ext: "py", isFolder: false) == .scripts)
        #expect(ItemKind.classify(ext: "xyz", isFolder: false) == .other)
        #expect(ItemKind.classify(ext: nil, isFolder: true) == .other)
        #expect(ItemKind.kinds(for: .documents) == [.pdf, .text, .documents])
        #expect(ItemKind.kinds(for: .folder).isEmpty)
        // Jede Endung des Filters landet in einer Kategorie, die der Filter umfasst.
        for filter in SearchFileTypeFilter.allCases where filter != .folder {
            for ext in filter.databaseExtensions {
                #expect(ItemKind.kinds(for: filter).contains(ItemKind.classify(ext: ext, isFolder: false)), "\(ext)")
            }
        }
        #expect(ItemKind.pdf.rawValue == 1 && ItemKind.scripts.rawValue == 9 && ItemKind.other.rawValue == 0)
    }

    @Test func timeRoundTripsInWholeSeconds() {
        let date = Date(timeIntervalSince1970: 1_791_700_000.9)
        #expect(SchemaTime.seconds(date) == 1_791_700_000)
        #expect(SchemaTime.date(1_791_700_000) == Date(timeIntervalSince1970: 1_791_700_000))
        #expect(ItemStatus.visible.rawValue == 0 && ItemStatus.toDelete.rawValue == 1 && ItemStatus.gone.rawValue == 2)
        #expect(MetaSource.read.rawValue == 0 && MetaSource.user.rawValue == 1 && MetaSource.system.rawValue == 2)
    }

    // Aufgabe 233b: neue Datei muss incremental auto_vacuum (2) und WAL haben.
    @Test func openPoolRejectsDatabaseWithFutureMigration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-v3-future-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("future.sqlite")
        let pool = try SchemaV3.openPool(at: fileURL)
        try pool.write { db in
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: ["9.9-future"])
        }
        try pool.close()
        do {
            _ = try SchemaV3.openPool(at: fileURL)
            Issue.record("openPool hätte schemaSuperseded werfen müssen")
        } catch IndexStoreError.schemaSuperseded {
        } catch {
            Issue.record("falscher Fehler: \(error)")
        }
    }

    @Test func goneCandidateQueryUsesItemsGoneIndex() throws {
        let (pool, directory) = try makeV3()
        defer {
            try? pool.close()
            try? FileManager.default.removeItem(at: directory)
        }
        let storage = try pool.write { db -> Int64 in
            let id = try insertStorage(db, name: "Vol")
            for index in 0..<5_000 {
                _ = try insertItem(db, storage: id, name: "gone-\(index).txt", isFolder: false)
            }
            try db.execute(sql: "UPDATE items SET status = 2 WHERE storageID = ?", arguments: [id])
            try db.execute(sql: "ANALYZE items")
            return id
        }
        let planLines = try pool.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    EXPLAIN QUERY PLAN
                    SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                    FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                    WHERE i.storageID = ? AND i.status = 2 AND i.isFolder = ?
                    """,
                arguments: [storage, false]
            ).map { row in
                [row[0], row[1], row[2], row[3]].compactMap { $0 }.map { "\($0)" }.joined(separator: " ")
            }
        }
        let plan = planLines.joined(separator: " | ")
        #expect(plan.contains("items_gone"), "plan=\(plan)")
    }

    @Test func freshFileHasIncrementalAutoVacuumAndWAL() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-v3-vacuum-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pool = try SchemaV3.openPool(at: directory.appendingPathComponent("fresh.sqlite"))
        let autoVacuum = try pool.read { db in try Int.fetchOne(db, sql: "PRAGMA auto_vacuum") }
        #expect(autoVacuum == 2)
        let journal = try pool.read { db in try String.fetchOne(db, sql: "PRAGMA journal_mode") }
        #expect(journal == "wal")
    }
}

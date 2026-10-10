//
//  IndexDatabase.swift
//  diskindex
//
//  Öffnet index.sqlite und spielt die Migrationen ein.
//

import Foundation
import GRDB

nonisolated final class IndexDatabase: Sendable {
    let pool: DatabasePool

    init(fileURL: URL) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try Self.upgradeAutoVacuum(fileURL)
        }
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            guard !db.configuration.readonly else { return }
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")
        }
        pool = try DatabasePool(path: fileURL.path, configuration: configuration)
        try Self.migrator.migrate(pool)
        try Self.ensureHealthy(pool: pool, fileURL: fileURL)
        FilePrivacy.restrict(folder)
    }

    func checkpoint() throws {
        try pool.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    /// Bestehende Dateien einmal auf inkrementelles Vacuum umstellen. Neue Dateien setzen das vor den Tabellen.
    private static func upgradeAutoVacuum(_ fileURL: URL) throws {
        let queue = try DatabaseQueue(path: fileURL.path)
        let mode = try queue.read { db in
            try Int.fetchOne(db, sql: "PRAGMA auto_vacuum") ?? 0
        }
        guard mode == 0 else {
            try queue.close()
            return
        }
        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")
            try db.execute(sql: "VACUUM")
        }
        try queue.close()
    }

    private static func ensureHealthy(pool: DatabasePool, fileURL: URL) throws {
        let result = try pool.read { db in
            try String.fetchOne(db, sql: "PRAGMA quick_check")
        }
        guard DatabaseCare.isHealthy(result) else {
            try pool.close()
            try DatabaseCare.quarantine(fileURL)
            throw DatabaseCareError.unhealthy
        }
    }

    /// `Application Support/Disk Archive/index.sqlite`. Der Ordner wird bei Bedarf angelegt.
    static func storeFileURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("Disk Archive", isDirectory: true)
            .appendingPathComponent("index.sqlite", isDirectory: false)
    }

    func close() throws {
        try pool.close()
    }

    static func openDefault() throws -> IndexDatabase {
        let url = try storeFileURL()
        do {
            return try IndexDatabase(fileURL: url)
        } catch DatabaseCareError.unhealthy {
            return try IndexDatabase(fileURL: url)
        }
    }

    /// Zahl der Medien und der noch vorhandenen Objekte. „nicht lesbar“, wenn die Datei fehlt oder die Abfrage scheitert.
    static func inventoryLabels() -> (media: String, objects: String) {
        do {
            let url = try storeFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return ("nicht lesbar", "nicht lesbar")
            }
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: url.path, configuration: configuration)
            let counts = try queue.read { db -> (Int, Int) in
                let media = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM medium") ?? 0
                let objects = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item WHERE removedAt IS NULL") ?? 0
                return (media, objects)
            }
            return (String(counts.0), String(counts.1))
        } catch {
            return ("nicht lesbar", "nicht lesbar")
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try createMedium(db)
            try createItem(db)
            try createItemFTS(db)
        }
        migrator.registerMigration("v2-fts-name") { db in
            try db.execute(sql: "DROP TRIGGER IF EXISTS item_fts_update")
            try db.execute(sql: """
                CREATE TRIGGER item_fts_update AFTER UPDATE OF name ON item BEGIN
                    INSERT INTO item_fts(item_fts, rowid, name) VALUES ('delete', old.id, old.name);
                    INSERT INTO item_fts(rowid, name) VALUES (new.id, new.name);
                END
                """)
        }
        migrator.registerMigration("v3-content-stamp") { db in
            try db.alter(table: "item") { table in
                table.add(column: "contentStamp", .text)
            }
            try db.alter(table: "medium") { table in
                table.add(column: "rootContentStamp", .text)
            }
        }
        migrator.registerMigration("v4-decision") { db in
            try db.execute(sql: """
                UPDATE medium
                SET decision = 'dontIndex', allowIndexing = 0
                WHERE allowIndexing = 0 OR decision = 'ignore' OR decision = 'dontIndex'
                """)
            try db.execute(sql: "UPDATE medium SET autoIndexPaused = 0")
        }
        migrator.registerMigration("v5-medium-activity") { db in
            try db.alter(table: "medium") { table in
                table.add(column: "lastIndexActivityAt", .datetime)
            }
            try db.execute(sql: """
                UPDATE medium SET lastIndexActivityAt = lastIndexedAt WHERE lastIndexedAt IS NOT NULL
                """)
        }
        migrator.registerMigration("v6-scan-total") { db in
            try db.alter(table: "medium") { table in
                table.add(column: "scanTotal", .integer).notNull().defaults(to: 0)
            }
            try db.execute(sql: """
                UPDATE medium SET scanTotal = fileCount + folderCount WHERE scanTotal = 0
                """)
        }
        migrator.registerMigration("v7-folder-listed") { db in
            try db.alter(table: "item") { table in
                table.add(column: "listedAt", .datetime)
            }
        }
        migrator.registerMigration("v8-item-unreadable") { db in
            try db.alter(table: "item") { table in
                table.add(column: "unreadable", .boolean).notNull().defaults(to: false)
            }
        }
        migrator.registerMigration("v9-item-children-order") { db in
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS item_children ON item (
                    mediumID, parentID, isFolder DESC, name COLLATE NOCASE, id
                )
                """)
        }
        return migrator
    }

    private static func createMedium(_ db: Database) throws {
        try db.create(table: "medium") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("uuid", .text).notNull().unique()
            table.column("volumeUUID", .text)
            table.column("volumeCreatedAt", .datetime)
            table.column("fsType", .text).notNull()
            table.column("volumeTotalBytes", .integer).notNull()
            table.column("diskSizeBytes", .integer)
            table.column("name", .text).notNull()
            table.column("type", .text).notNull()
            table.column("decision", .text).notNull()
            table.column("rememberDecision", .integer).notNull()
            table.column("indexStatus", .text).notNull()
            table.column("allowIndexing", .integer).notNull()
            table.column("autoIndexPaused", .integer).notNull()
            table.column("capacityUsedBytes", .integer).notNull()
            table.column("fileCount", .integer).notNull()
            table.column("folderCount", .integer).notNull()
            table.column("lastSeenAt", .datetime)
            table.column("firstIndexedAt", .datetime)
            table.column("lastIndexedAt", .datetime)
            table.column("isForgotten", .integer).notNull().defaults(to: 0)
            table.column("showAbsoluteCapacity", .integer).notNull().defaults(to: 0)
            table.column("isFavorite", .integer).notNull().defaults(to: 0)
            table.column("fsEventsUUID", .text)
            table.column("lastEventID", .integer)
            table.column("completedDepth", .integer).notNull().defaults(to: 0)
            table.column("createdAt", .datetime).notNull()
        }
    }

    private static func createItem(_ db: Database) throws {
        try db.create(table: "item") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("mediumID", .integer).notNull().references("medium", onDelete: .cascade)
            table.column("parentID", .integer)
            table.column("name", .text).notNull()
            table.column("isFolder", .integer).notNull()
            table.column("isPackage", .integer).notNull()
            table.column("ext", .text)
            table.column("sizeBytes", .integer)
            table.column("modifiedAt", .datetime)
            table.column("fileID", .text)
            table.column("depth", .integer).notNull()
            table.column("path", .text).notNull()
            table.column("lastSeenAt", .datetime).notNull()
            table.column("removedAt", .datetime)
            table.column("isFavorite", .integer).notNull().defaults(to: 0)
        }
        // NULL gilt in einem UNIQUE-Constraint als verschieden. ifnull macht die Wurzel eindeutig.
        try db.execute(sql: """
            CREATE UNIQUE INDEX item_identity ON item (mediumID, ifnull(parentID, 0), name)
            """)
        try db.create(index: "item_parent", on: "item", columns: ["mediumID", "parentID"])
        try db.create(index: "item_removed", on: "item", columns: ["mediumID", "removedAt"])
        try db.create(index: "item_path", on: "item", columns: ["mediumID", "path"])
        try db.create(index: "item_modified", on: "item", columns: ["modifiedAt"])
        try db.create(index: "item_ext", on: "item", columns: ["ext"])
    }

    private static func createItemFTS(_ db: Database) throws {
        try db.execute(sql: """
            CREATE VIRTUAL TABLE item_fts USING fts5(
                name,
                content='item',
                content_rowid='id',
                tokenize='trigram case_sensitive 0'
            )
            """)
        try db.execute(sql: """
            CREATE TRIGGER item_fts_delete AFTER DELETE ON item BEGIN
                INSERT INTO item_fts(item_fts, rowid, name) VALUES ('delete', old.id, old.name);
            END
            """)
        try db.execute(sql: """
            CREATE TRIGGER item_fts_update AFTER UPDATE OF name ON item BEGIN
                INSERT INTO item_fts(item_fts, rowid, name) VALUES ('delete', old.id, old.name);
                INSERT INTO item_fts(rowid, name) VALUES (new.id, new.name);
            END
            """)
    }

    #if DEBUG
    /// Migrierte Datei für Tests (`auto_vacuum` 0 oder INCREMENTAL vor dem Pool-Öffnen).
    static func installSchemaForTesting(at fileURL: URL, autoVacuumIncremental: Bool) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            if autoVacuumIncremental {
                try db.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")
            }
        }
        let pool = try DatabasePool(path: fileURL.path, configuration: configuration)
        try migrator.migrate(pool)
        try pool.close()
    }
    #endif
}

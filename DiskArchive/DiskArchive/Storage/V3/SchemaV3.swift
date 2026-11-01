//
//  SchemaV3.swift
//  DiskArchive
//
//  Schema 0.3 eingefroren (238) — Basis-Migration `0.3.0-schema`; ab 0.4 nur Erweiterung (neue Tabellen/Keys),
//  keine Umbauten bestehender Spalten. Mess-/Abnahmebericht: `archiv/messung/*-nachher-bericht.md`.
//  Schema 0.3 (Aufgaben 230/233), Grundlage `datenbank-konzeption.md` → „Schema-Skizze“. Speichert in `archive.sqlite`.
//  Kennungen `AUTOINCREMENT` (nie wiederverwendet), Verweise `ON DELETE CASCADE` (Ausnahme: `extID`/`keyID` zeigen auf
//  Nachschlagetabellen, Löschen ist verboten, solange benutzt), Zeiten als Sekunden seit 1970.
//

import Foundation
import GRDB

nonisolated enum SchemaV3 {
    #if DEBUG
    /// bug.0.4.195: nur für Tests (Schema-Prüfung).
    static let tableNames = [
        "storages", "storage_meta", "items", "item_details", "item_meta", "item_checksum",
        "favorites", "extensions", "meta_keys", "settings", "api_queue",
    ]

    static let indexNames = [
        "items_identity", "items_children", "items_search", "items_modified", "items_fileid",
        "items_parent", "item_checksum_full", "storages_slug", "storages_uuid", "items_gone", "items_search_natural",
    ]
    #endif

    /// Teilindex für verschwundene Einträge (bug.0.4.013).
    static let itemsGoneMigration = "0.4.0-items_gone"

    /// bug.0.4.077: Suchhilfe in natürlicher Namensordnung („Rechnung 2“ vor „Rechnung 10“), damit die Datenbank die
    /// Trefferseiten nach Name schon natürlich auswählt. Nur Erweiterung (Regel 27); bei neuen Datenbanken leer
    /// angelegt, wächst beim Indizieren mit.
    static let itemsSearchNaturalMigration = "0.4.0-items_search_natural"

    /// Größe der Journal-Datei nach einem Checkpoint (64 MB).
    static let journalSizeLimit = 64 * 1024 * 1024

    /// Name der ersten Migration (Aufgabe 233). Spätere Versionen hängen nur neue Migrationen an („nach 0.3 nur erweitern“).
    static let firstMigration = "0.3.0-schema"

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration(firstMigration) { db in
            try create(in: db)
        }
        // bug.0.4.107: reine Index-Migrationen mit sofortigen Fremdschlüsselprüfungen – die Nachprüfung aller Tabellen am
        // Ende (Dauer, Sperre durch Altverletzung) entfällt.
        migrator.registerMigration(itemsGoneMigration, foreignKeyChecks: .immediate) { db in
            try db.execute(sql: "CREATE INDEX items_gone ON items(storageID, isFolder) WHERE status = 2")
        }
        migrator.registerMigration(itemsSearchNaturalMigration, foreignKeyChecks: .immediate) { db in
            try db.execute(sql: "CREATE INDEX items_search_natural ON items (slug COLLATE \"\(NaturalOrder.collationName)\", status)")
        }
        return migrator
    }

    /// Jede Verbindung: Fremdschlüssel an, WAL, Journal-Grenze, Sortierfolge „natural“.
    static func makeConfiguration(path: String? = nil) -> Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.busyMode = .timeout(10)
        // Die parallele Suche braucht mehrere Lese-Verbindungen (WAL erlaubt gleichzeitiges Lesen).
        configuration.maximumReaderCount = 16
        configuration.prepareDatabase { db in
            #if DEBUG
            // bug.0.4.144: jede Anweisung, die auf dem Hauptfaden läuft (synchroner Zugriff), wird je Datei gezählt.
            if let path {
                db.trace(options: .statement) { _ in
                    if Thread.isMainThread { OpenCounter.shared.noteMainThreadStatement(path) }
                }
            }
            #endif
            try NaturalOrder.register(on: db)
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            guard !db.configuration.readonly else { return }
            // Wirkt nur auf eine neue Datei (vor WAL und vor der ersten Tabelle): Platz mit `incremental_vacuum`.
            try db.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA journal_size_limit = \(journalSizeLimit)")
        }
        return configuration
    }

    /// Legt eine neue Datei mit `auto_vacuum = INCREMENTAL` an, bevor der Pool WAL einschaltet.
    private static func prepareNewFile(at fileURL: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")
        }
        let queue = try DatabaseQueue(path: fileURL.path, configuration: configuration)
        try queue.close()
    }

    /// Öffnet die Datei, legt sie bei Bedarf an und lässt den Migrator laufen.
    static func openPool(at fileURL: URL) throws -> DatabasePool {
        #if DEBUG
        OpenCounter.shared.note(fileURL, onMain: Thread.isMainThread)
        #endif
        let folder = fileURL.deletingLastPathComponent()
        guard WriteGuard.permitsWrite(to: folder), WriteGuard.permitsWrite(to: fileURL) else {
            throw IndexStoreError.directoryWriteFailed
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // DatabasePool schaltet WAL selbst ein; `auto_vacuum` muss davor (und vor Tabellen) stehen.
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try prepareNewFile(at: fileURL)
        }
        let pool = try DatabasePool(path: fileURL.path, configuration: makeConfiguration(path: fileURL.path))
        if try pool.read({ try migrator.hasBeenSuperseded($0) }) {
            throw IndexStoreError.schemaSuperseded
        }
        #if DEBUG
        OpenCounter.shared.beforeMigrate(fileURL)
        #endif
        try migrator.migrate(pool)
        try normalizeInterruptedIndexingStatuses(in: pool)
        FilePrivacy.restrict(folder)
        return pool
    }

    #if DEBUG
    /// Zahl der `openPool`-Aufrufe je Datei (bug.0.4.086: je Prozess genau einer für `archive.sqlite`). Je Pfad
    /// gezählt, Tests nutzen eigene Dateien; kein Schalter, nur Zählung.
    final class OpenCounter: @unchecked Sendable {
        static let shared = OpenCounter()
        private let lock = NSLock()
        private var counts: [String: Int] = [:]
        private var mainCounts: [String: Int] = [:]
        func note(_ url: URL, onMain: Bool) {
            lock.withLock {
                counts[url.standardizedFileURL.path, default: 0] += 1
                if onMain { mainCounts[url.standardizedFileURL.path, default: 0] += 1 }
            }
        }
        func count(_ url: URL) -> Int { lock.withLock { counts[url.standardizedFileURL.path] ?? 0 } }
        /// Öffnungen (samt Migration) auf dem Hauptfaden – soll 0 sein (bug.0.4.086, Regel 15).
        func mainThreadCount(_ url: URL) -> Int { lock.withLock { mainCounts[url.standardizedFileURL.path] ?? 0 } }

        private var mainStatements: [String: Int] = [:]
        func noteMainThreadStatement(_ path: String) {
            lock.withLock { mainStatements[URL(fileURLWithPath: path).standardizedFileURL.path, default: 0] += 1 }
        }
        /// Anweisungen der Datei, die auf dem Hauptfaden liefen (bug.0.4.144).
        func mainThreadStatementCount(_ url: URL) -> Int { lock.withLock { mainStatements[url.standardizedFileURL.path] ?? 0 } }

        private var mainPoolWaits: [String: Int] = [:]
        private var migrateHooks: [String: @Sendable () -> Void] = [:]
        /// bug.0.4.093: `ArchiveDatabase.pool()` auf dem Hauptfaden, solange der Pool noch nicht offen ist.
        func noteMainThreadPoolWait(_ url: URL) {
            lock.withLock { mainPoolWaits[url.standardizedFileURL.path, default: 0] += 1 }
        }
        func mainThreadPoolWaitCount(_ url: URL) -> Int {
            lock.withLock { mainPoolWaits[url.standardizedFileURL.path] ?? 0 }
        }
        /// bug.0.4.093 (Tests): Haken je Datei unmittelbar vor der Migration (kein prozessweiter Schalter).
        func setBeforeMigrateHook(_ url: URL, _ hook: (@Sendable () -> Void)?) {
            lock.withLock { migrateHooks[url.standardizedFileURL.path] = hook }
        }
        func beforeMigrate(_ url: URL) {
            let hook = lock.withLock { migrateHooks[url.standardizedFileURL.path] }
            hook?()
        }
    }
    #endif

    /// Nach Absturz/Beenden: `indexing` ohne laufenden Prozess → `indexed` oder `pending` (bug.0.4.028).
    /// „indiziert“ nur nach mindestens einem Lauf bis zum Ende (`firstIndexedAt`, bug.0.4.126); `lastIndexedAt`
    /// setzt schon jede fertige Ebene. Mit Merker `indexGaps` (Lücke, bug.0.4.151/199) wird ein unterbrochener Lauf `pending`,
    /// damit das Anschließen die Lücke nachliest.
    private static func normalizeInterruptedIndexingStatuses(in pool: DatabasePool) throws {
        let indexing = MediumCodecV3.code(.indexing)
        let indexed = MediumCodecV3.code(.indexed)
        let pending = MediumCodecV3.code(.pending)
        try pool.write { db in
            try db.execute(
                sql: """
                    UPDATE storages SET indexStatus = CASE
                        WHEN firstIndexedAt IS NOT NULL AND NOT EXISTS (
                            SELECT 1 FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                            WHERE m.storageID = storages.id AND k.key = ?
                        ) THEN ?
                        ELSE ?
                    END
                    WHERE indexStatus = ?
                    """,
                arguments: [IndexStoreV3.indexGapsKey, indexed, pending, indexing]
            )
        }
    }

    /// Legt alle Tabellen und Suchhilfen in einer **leeren** Datenbank an.
    static func create(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE storages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                uuid BLOB NOT NULL,
                volumeUUID BLOB,
                fingerprint INTEGER,
                name TEXT NOT NULL,
                slug TEXT NOT NULL,
                type INTEGER NOT NULL DEFAULT 0,
                fsType INTEGER NOT NULL DEFAULT 0,
                totalBytes INTEGER NOT NULL DEFAULT 0,
                usedBytes INTEGER,
                decision INTEGER NOT NULL DEFAULT 0,
                rememberDecision INTEGER NOT NULL DEFAULT 0,
                indexStatus INTEGER NOT NULL DEFAULT 0,
                paused INTEGER NOT NULL DEFAULT 0,
                isFavorite INTEGER NOT NULL DEFAULT 0,
                fileCount INTEGER NOT NULL DEFAULT 0,
                folderCount INTEGER NOT NULL DEFAULT 0,
                firstSeenAt INTEGER,
                lastSeenAt INTEGER,
                firstIndexedAt INTEGER,
                lastIndexedAt INTEGER
            )
            """)
        try db.execute(sql: """
            CREATE TABLE extensions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ext TEXT NOT NULL UNIQUE
            )
            """)
        try db.execute(sql: """
            CREATE TABLE meta_keys (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key TEXT NOT NULL UNIQUE
            )
            """)
        try db.execute(sql: """
            CREATE TABLE storage_meta (
                storageID INTEGER NOT NULL REFERENCES storages(id) ON DELETE CASCADE,
                keyID INTEGER NOT NULL REFERENCES meta_keys(id),
                value TEXT,
                date INTEGER,
                PRIMARY KEY (storageID, keyID)
            ) WITHOUT ROWID
            """)
        try db.execute(sql: """
            CREATE TABLE items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                storageID INTEGER NOT NULL REFERENCES storages(id) ON DELETE CASCADE,
                parentID INTEGER REFERENCES items(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                slug TEXT NOT NULL,
                extID INTEGER REFERENCES extensions(id),
                kind INTEGER NOT NULL DEFAULT 0,
                isFolder INTEGER NOT NULL DEFAULT 0,
                depth INTEGER NOT NULL DEFAULT 1,
                status INTEGER NOT NULL DEFAULT 0,
                modifiedAt INTEGER,
                fileID INTEGER,
                contentStamp INTEGER,
                listedAt INTEGER,
                unreadable INTEGER NOT NULL DEFAULT 0
            )
            """)
        try db.execute(sql: """
            CREATE TABLE item_details (
                itemID INTEGER PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
                sizeBytes INTEGER,
                createdAt INTEGER,
                isPackage INTEGER NOT NULL DEFAULT 0
            )
            """)
        try db.execute(sql: """
            CREATE TABLE item_meta (
                itemID INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
                keyID INTEGER NOT NULL REFERENCES meta_keys(id),
                value TEXT,
                source INTEGER NOT NULL DEFAULT 0,
                info TEXT,
                PRIMARY KEY (itemID, keyID)
            ) WITHOUT ROWID
            """)
        try db.execute(sql: """
            CREATE TABLE item_checksum (
                itemID INTEGER PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
                partial BLOB,
                "full" BLOB,
                info TEXT
            )
            """)
        try db.execute(sql: """
            CREATE TABLE favorites (
                itemID INTEGER PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
                createdAt INTEGER NOT NULL
            )
            """)
        try db.execute(sql: """
            CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT,
                date INTEGER
            ) WITHOUT ROWID
            """)
        try db.execute(sql: """
            CREATE TABLE api_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kind INTEGER NOT NULL DEFAULT 0,
                payload TEXT,
                createdAt INTEGER NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                lastTryAt INTEGER,
                info TEXT
            )
            """)
        try createIndexes(in: db)
    }

    private static func createIndexes(in db: Database) throws {
        // Eindeutigkeit; ifnull, weil NULL im UNIQUE-Constraint sonst als verschieden gilt (Wurzel).
        try db.execute(sql: "CREATE UNIQUE INDEX items_identity ON items (storageID, ifnull(parentID, 0), name)")
        // Spaltenansicht: Ordner und Dateien gemischt, natürlich nach Suchname sortiert.
        try db.execute(sql: """
            CREATE INDEX items_children ON items (storageID, parentID, status, slug COLLATE \"\(NaturalOrder.collationName)\")
            """)
        // Suche: schmale Hilfe für slug LIKE '%…%'.
        try db.execute(sql: "CREATE INDEX items_search ON items (slug, status)")
        try db.execute(sql: "CREATE INDEX items_modified ON items (modifiedAt)")
        try db.execute(sql: "CREATE INDEX items_fileid ON items (storageID, fileID) WHERE fileID IS NOT NULL")
        // Fremdschlüssel `parentID` (Kaskade): ohne diese Suchhilfe liest jedes Löschen eines Ordners die ganze Tabelle.
        try db.execute(sql: "CREATE INDEX items_parent ON items (parentID)")
        try db.execute(sql: "CREATE INDEX item_checksum_full ON item_checksum (\"full\") WHERE \"full\" IS NOT NULL")
        try db.execute(sql: "CREATE INDEX storages_slug ON storages (slug)")
        try db.execute(sql: "CREATE UNIQUE INDEX storages_uuid ON storages (uuid)")
    }
}

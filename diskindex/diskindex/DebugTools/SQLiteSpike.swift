#if DEBUG
//
//  SQLiteSpike.swift
//  diskindex
//
//  Aufgabe 35, Abschnitt E. System-SQLite, synthetische Zeilen, temporäre Datei.
//

import Foundation
import SQLite3

enum SQLiteSpike {
    nonisolated private static let words = [
        "foto", "rechnung", "ablage", "archiv", "projekt", "bericht", "kamera", "urlaub",
        "backup", "dokument", "notiz", "musik", "video", "vertrag", "scan", "export",
        "rohdaten", "katalog", "kunde", "final",
    ]

    nonisolated static func run(rowCount: Int, report: @escaping @Sendable (String) async -> Void) async {
        var handle: OpaquePointer?
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-spike-\(UUID().uuidString).sqlite")
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let db = handle else {
            let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 fehlgeschlagen"
            sqlite3_close(handle)
            await report(message)
            return
        }
        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(at: url)
        }

        do {
            let version = try queryText(db, "SELECT sqlite_version()")
            await report("sqlite_version=\(version)")
            let wal = try exec(db, "PRAGMA journal_mode=WAL")
            await report("journal_mode=\(wal)")
            try await probeTokenizer(db, report: report)
            try createTables(db)
            let inserted = try await insertItems(db, rowCount: rowCount, report: report)
            let indexStart = ContinuousClock.now
            try execVoid(db, "CREATE INDEX item_medium_parent ON item(mediumID, parentID)")
            try execVoid(db, "CREATE INDEX item_modified ON item(modified)")
            await report("Index medium+parent und modified: \(indexDiagnosticsFormat(seconds: indexDiagnosticsSeconds(indexStart.duration(to: .now))))")
            let ftsOK = try await buildFTS(db, report: report)
            try await measureQueries(db, fts: ftsOK, report: report)
            await report("Eingefügte item-Zeilen=\(inserted). Datei danach gelöscht.")
        } catch {
            await report("SQLite-Fehler: \(error)")
        }
    }

    nonisolated private static func probeTokenizer(_ db: OpaquePointer, report: @escaping @Sendable (String) async -> Void) async throws {
        do {
            try execVoid(db, "CREATE VIRTUAL TABLE temp.trigram_probe USING fts5(x, tokenize='trigram')")
            try execVoid(db, "DROP TABLE temp.trigram_probe")
            await report("fts5: ja | Tokenizer trigram: ja")
        } catch {
            await report("fts5/trigram: nein | \(error)")
        }
    }

    nonisolated private static func createTables(_ db: OpaquePointer) throws {
        try execVoid(db, """
        CREATE TABLE medium (
            id INTEGER PRIMARY KEY,
            volumeUUID TEXT,
            name TEXT,
            type TEXT,
            capacity INTEGER,
            decision TEXT,
            connectionStatus TEXT,
            indexStatus TEXT,
            firstRun REAL,
            lastRun REAL,
            lastSeen REAL,
            fsEventsUUID TEXT,
            lastEventID INTEGER,
            favorite INTEGER,
            paused INTEGER
        )
        """)
        try execVoid(db, """
        CREATE TABLE item (
            id INTEGER PRIMARY KEY,
            mediumID INTEGER,
            parentID INTEGER,
            name TEXT,
            isFolder INTEGER,
            ext TEXT,
            size INTEGER,
            modified REAL,
            fileID TEXT,
            level INTEGER,
            lastSeen REAL,
            removedAt REAL,
            favorite INTEGER
        )
        """)
        try execVoid(db, """
        INSERT INTO medium (
            volumeUUID, name, type, capacity, decision, connectionStatus, indexStatus,
            firstRun, lastRun, lastSeen, fsEventsUUID, lastEventID, favorite, paused
        ) VALUES (
            'spike', 'synthetisch', 'apfs', 1, 'index', 'online', 'running',
            0, 0, 0, '', 0, 0, 0
        )
        """)
    }

    nonisolated private static func insertItems(
        _ db: OpaquePointer,
        rowCount: Int,
        report: @escaping @Sendable (String) async -> Void
    ) async throws -> Int {
        try execVoid(db, """
        INSERT INTO item (
            mediumID, parentID, name, isFolder, ext, size, modified, fileID, level, lastSeen, removedAt, favorite
        ) VALUES (1, NULL, 'root', 1, NULL, 0, 0, 'root', 0, 0, NULL, 0)
        """)
        let sql = """
        INSERT INTO item (
            mediumID, parentID, name, isFolder, ext, size, modified, fileID, level, lastSeen, removedAt, favorite
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 0)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw spikeError(db)
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let now = Date().timeIntervalSince1970
        var folderIDs: [Int64] = [1]
        let start = ContinuousClock.now
        try execVoid(db, "BEGIN")
        var pending = 0
        for index in 1...rowCount {
            let word = words[index % words.count]
            let name = "\(word)_\(index)"
            let isFolder: Int32 = index % 8 == 0 ? 1 : 0
            let parent: Int64 = index % 4 == 0 ? 1 : folderIDs[index % folderIDs.count]
            let level = Int32((index % 6) + 1)
            let modified = now - Double(index % 365) * 86_400
            sqlite3_bind_int64(statement, 1, 1)
            sqlite3_bind_int64(statement, 2, parent)
            sqlite3_bind_text(statement, 3, name, -1, transient)
            sqlite3_bind_int(statement, 4, isFolder)
            sqlite3_bind_text(statement, 5, "dat", -1, transient)
            sqlite3_bind_int64(statement, 6, Int64(index * 10))
            sqlite3_bind_double(statement, 7, modified)
            sqlite3_bind_text(statement, 8, "file-\(index)", -1, transient)
            sqlite3_bind_int(statement, 9, level)
            sqlite3_bind_double(statement, 10, now)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw spikeError(db) }
            if isFolder == 1 {
                folderIDs.append(sqlite3_last_insert_rowid(db))
            }
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            pending += 1
            if pending == 5_000 {
                try execVoid(db, "COMMIT")
                try execVoid(db, "BEGIN")
                pending = 0
                if index % 50_000 == 0 {
                    await report("Eingefügt \(index) / \(rowCount)")
                }
            }
        }
        try execVoid(db, "COMMIT")
        let seconds = indexDiagnosticsSeconds(start.duration(to: .now))
        let rate = seconds > 0 ? Double(rowCount) / seconds : 0
        await report(String(format: "Insert %d Zeilen in Stapeln à 5000: %.3f s, %.0f Zeilen/s (ohne FTS, Indizes danach)", rowCount, seconds, rate))
        return rowCount + 1
    }

    nonisolated private static func buildFTS(_ db: OpaquePointer, report: @escaping @Sendable (String) async -> Void) async throws -> Bool {
        let start = ContinuousClock.now
        do {
            try execVoid(db, "CREATE VIRTUAL TABLE item_fts USING fts5(name, tokenize='trigram')")
            try execVoid(db, "INSERT INTO item_fts(rowid, name) SELECT id, name FROM item")
            await report("FTS5-Trigram-Aufbau: \(indexDiagnosticsFormat(seconds: indexDiagnosticsSeconds(start.duration(to: .now))))")
            return true
        } catch {
            await report("FTS5-Trigram-Aufbau fehlgeschlagen: \(error)")
            return false
        }
    }

    nonisolated private static func measureQueries(
        _ db: OpaquePointer,
        fts: Bool,
        report: @escaping @Sendable (String) async -> Void
    ) async throws {
        for term in ["foto", "rechn", "ab"] {
            if fts {
                do {
                    let result = try timedCount(db, "SELECT count(*) FROM item_fts WHERE item_fts MATCH ?", text: term)
                    await report("FTS „\(term)“: \(result.count) Treffer, \(indexDiagnosticsFormat(seconds: result.seconds))")
                } catch {
                    await report("FTS „\(term)“: \(error)")
                }
            }
            let like = try timedCount(db, "SELECT count(*) FROM item WHERE name LIKE ?", text: "%\(term)%")
            await report("LIKE „\(term)“: \(like.count) Treffer, \(indexDiagnosticsFormat(seconds: like.seconds))")
            if term == "ab" {
                await report("Hinweis: „ab“ hat nur zwei Buchstaben. Trigram trägt das nicht; die Suche weicht dann auf LIKE aus.")
            }
        }
        let children = try timedCount(db, "SELECT count(*) FROM item WHERE mediumID = 1 AND parentID = 1", text: nil)
        await report("Kinder von Ordner 1: \(children.count) Treffer, \(indexDiagnosticsFormat(seconds: children.seconds))")
        let cutoff = Date().timeIntervalSince1970 - 30 * 86_400
        let recent = try timedCount(db, "SELECT count(*) FROM item WHERE modified >= ?", double: cutoff)
        await report("Änderungsdatum letzte 30 Tage: \(recent.count) Treffer, \(indexDiagnosticsFormat(seconds: recent.seconds))")
    }

    nonisolated private static func timedCount(
        _ db: OpaquePointer,
        _ sql: String,
        text: String? = nil,
        double: Double? = nil
    ) throws -> (count: Int64, seconds: Double) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw spikeError(db)
        }
        defer { sqlite3_finalize(statement) }
        if let text {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, text, -1, transient)
        } else if let double {
            sqlite3_bind_double(statement, 1, double)
        }
        let start = ContinuousClock.now
        var count: Int64 = -1
        if sqlite3_step(statement) == SQLITE_ROW {
            count = sqlite3_column_int64(statement, 0)
        } else {
            throw spikeError(db)
        }
        return (count, indexDiagnosticsSeconds(start.duration(to: .now)))
    }

    nonisolated private static func queryText(_ db: OpaquePointer, _ sql: String) throws -> String {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw spikeError(db)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let cString = sqlite3_column_text(statement, 0) else {
            throw spikeError(db)
        }
        return String(cString: cString)
    }

    @discardableResult
    nonisolated private static func exec(_ db: OpaquePointer, _ sql: String) throws -> String {
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(db, sql, nil, nil, &error)
        if code != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "sqlite \(code)"
            sqlite3_free(error)
            throw SpikeSQLError(message: message)
        }
        return try queryText(db, sql)
    }

    nonisolated private static func execVoid(_ db: OpaquePointer, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(db, sql, nil, nil, &error)
        if code != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "sqlite \(code)"
            sqlite3_free(error)
            throw SpikeSQLError(message: message)
        }
    }

    nonisolated private static func spikeError(_ db: OpaquePointer) -> SpikeSQLError {
        SpikeSQLError(message: String(cString: sqlite3_errmsg(db)))
    }
}

private struct SpikeSQLError: Error, CustomStringConvertible {
    var message: String
    var description: String { message }
}
#endif

//
//  IndexStore+Search.swift
//  diskindex
//
//  Aus IndexStore.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import Foundation
import GRDB

extension IndexStore {
    func search(query: String, filters: SearchFilters, limit: Int = 500, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> [StoredItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !filters.hasActiveFilters { return [] }
        guard limit > 0 else { return [] }
        let request = IndexSQL.searchRequest(query: trimmed, filters: filters, limit: limit, maxDepth: scope?.maxDepth ?? maxDepth)
        let rows = try await pool.read { db in
            try IndexSQL.items(db, sql: request.sql, arguments: request.arguments)
        }
        // Tiefe steht schon im SQL; Namen nur prüfen, solange eine Bereinigung aussteht.
        guard let scope, scope.checksNames else { return rows }
        nameChecks.add(rows.count)
        return rows.filter { !scope.hides(name: $0.name, depth: $0.depth) }
    }

    /// Genaue Zahl der Treffer, ohne Obergrenze. Tiefe und die festen Ausschlüsse (`._…`, Systemordner, versteckte
    /// Namen) als SQL-Bedingung; Artefakt-Regeln und Namensmuster über einen Cursor (nur Name und Tiefe, kein Array).
    func searchCount(query: String, filters: SearchFilters, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> Int {
        #if DEBUG
        if let delay = searchCountDelay { try await Task.sleep(for: delay) }
        #endif
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = IndexSQL.searchRequest(
            query: trimmed,
            filters: filters,
            limit: nil,
            maxDepth: scope?.maxDepth ?? maxDepth,
            ordered: false
        )
        guard let scope, scope.checksNames else {
            // Kein Bereich oder keine ausstehende Bereinigung: reines SQL (Tiefe steht schon in der Anfrage).
            return try await pool.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM (\(request.sql))", arguments: request.arguments) ?? 0
            }
        }
        var conditions = ["name NOT LIKE '.\\_%' ESCAPE '\\'"]
        let always = IgnoreMatcher.alwaysSkipped.sorted()
        conditions.append("name NOT IN (\(always.map { _ in "?" }.joined(separator: ",")))")
        if scope.matcher.ignoreHiddenFiles {
            conditions.append("name NOT LIKE '.%'")
        }
        let arguments = request.arguments + StatementArguments(always)
        let whereClause = conditions.joined(separator: " AND ")
        let counter = nameChecks
        let needsSwiftCheck = scope.matcher.artifactsIgnored || !scope.matcher.excludedPatterns.isEmpty
        return try await pool.read { db in
            if !needsSwiftCheck {
                return try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM (\(request.sql)) WHERE \(whereClause)",
                    arguments: arguments
                ) ?? 0
            }
            let cursor = try Row.fetchCursor(
                db,
                sql: "SELECT name, depth FROM (\(request.sql)) WHERE \(whereClause)",
                arguments: arguments
            )
            var count = 0
            var checked = 0
            while let row = try cursor.next() {
                let name: String = row["name"]
                let depth: Int = row["depth"]
                checked += 1
                if !scope.hides(name: name, depth: depth) { count += 1 }
            }
            counter.add(checked)
            return count
        }
    }

    func setFavorite(itemID: Int64, _ isFavorite: Bool) async throws {
        try await setFavorites(itemIDs: [itemID], isFavorite)
    }

    func setFavorites(itemIDs: [Int64], _ isFavorite: Bool) async throws {
        let ids = Array(Set(itemIDs))
        guard !ids.isEmpty else { return }
        do {
            let mediumUUIDs: [UUID] = try await pool.write { db in
                for id in ids {
                    try db.execute(
                        sql: "UPDATE item SET isFavorite = ? WHERE id = ?",
                        arguments: [isFavorite ? 1 : 0, id]
                    )
                    if db.changesCount == 0 { throw IndexStoreError.unknownItem }
                }
                let rows = try String.fetchAll(
                    db,
                    sql: """
                        SELECT DISTINCT medium.uuid
                        FROM item JOIN medium ON medium.id = item.mediumID
                        WHERE item.id IN (\(ids.map { _ in "?" }.joined(separator: ",")))
                        """,
                    arguments: StatementArguments(ids)
                )
                return rows.compactMap(UUID.init(uuidString:))
            }
            DiskIndexLog.shared.record(.store, .info, "setFavorites count=\(ids.count)")
            for uuid in mediumUUIDs {
                emit(.counts(uuid))
            }
        } catch {
            DiskIndexLog.shared.record(.store, .error, "setFavorites \(error)")
            throw error
        }
    }

    func favorites(maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> [StoredItem] {
        let rows = try await pool.read { db in
            var sql = """
                SELECT item.*, medium.uuid AS mediumUUID
                FROM item JOIN medium ON medium.id = item.mediumID
                WHERE item.isFavorite = 1 AND item.removedAt IS NULL
                """
            var arguments: StatementArguments = []
            let depth = scope?.maxDepth ?? maxDepth
            if let depth {
                sql += " AND item.depth <= ?"
                arguments += [depth]
            }
            sql += " ORDER BY item.name COLLATE NOCASE, item.id"
            return try IndexSQL.items(db, sql: sql, arguments: arguments)
        }
        guard let scope, scope.checksNames else { return rows }
        nameChecks.add(rows.count)
        return rows.filter { !scope.hides(name: $0.name, depth: $0.depth) }
    }

    #if DEBUG
    /// Tests prüfen Tabellen und Pragmas.
    func schemaSnapshot() async throws -> IndexSchemaSnapshot {
        try await pool.read { db in
            let names = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master")
            let journal = try String.fetchOne(db, sql: "PRAGMA journal_mode") ?? ""
            let foreignKeys = try Int64.fetchOne(db, sql: "PRAGMA foreign_keys") ?? 0
            let synchronous = try Int64.fetchOne(db, sql: "PRAGMA synchronous") ?? -1
            let updateSQL = try String.fetchOne(db, sql: "SELECT sql FROM sqlite_master WHERE name = 'item_fts_update'") ?? ""
            return IndexSchemaSnapshot(
                names: Set(names),
                journalMode: journal,
                foreignKeys: foreignKeys,
                synchronous: synchronous,
                fullTextUpdateSQL: updateSQL
            )
        }
    }

    /// Summe der Volltext-Blöcke. Tests prüfen, ob ein Lauf den Index neu schreibt.
    func fullTextByteLength() async throws -> Int {
        try await pool.read { db in
            try Int.fetchOne(db, sql: "SELECT ifnull(sum(length(block)), 0) FROM item_fts_data") ?? 0
        }
    }
    #endif
}

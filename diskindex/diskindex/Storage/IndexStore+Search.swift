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
        guard let scope else { return rows }
        return rows.filter { !scope.hides(name: $0.name, depth: $0.depth) }
    }

    func searchCount(query: String, filters: SearchFilters, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> Int {
        if scope != nil {
            return try await search(query: query, filters: filters, limit: 50_000, maxDepth: maxDepth, scope: scope).count
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = IndexSQL.searchRequest(query: trimmed, filters: filters, limit: nil, maxDepth: maxDepth)
        return try await pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM (\(request.sql))", arguments: request.arguments) ?? 0
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
        guard let scope else { return rows }
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

//
//  IndexStoreV3+Reading.swift
//  diskindex
//
//  Aufgabe 232: Lesewege auf dem Schema V3 Nur `status = 0`.
//  - Spalten: natürlich sortiert, Ordner und Dateien gemischt, Seiten mit Cursor `(slug, id)` über die Spalten-Suchhilfe.
//  - Pfad: aus der Kette der Elternordner, einmal je Abfrage (kein Nachschlagen je Zeile).
//  - Suche: `slug LIKE '%…%'`, parallel in Kennungs-Bereichen mit je eigener Lese-Verbindung.
//

import Foundation
import GRDB

extension IndexStoreV3 {
    // MARK: Spalten

    func childCount(mediumUUID: UUID, parentID: Int64?, scope: IndexScope? = nil) async throws -> Int {
        if childrenReadsFail { throw IndexStoreError.childrenReadFailed }
        let counter = nameChecks
        return try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return 0 }
            if let scope, scope.checksNames {
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT name, depth FROM items WHERE storageID = ? AND parentID IS ? AND status = 0",
                    arguments: [storageID, parentID]
                )
                counter.add(rows.count)
                return rows.filter { !scope.hides(name: $0["name"], depth: $0["depth"]) }.count
            }
            var sql = "SELECT COUNT(*) FROM items WHERE storageID = ? AND parentID IS ? AND status = 0"
            var arguments: StatementArguments = [storageID, parentID]
            if let maxDepth = scope?.maxDepth {
                sql += " AND depth <= ?"
                arguments += [maxDepth]
            }
            return try Int.fetchOne(db, sql: sql, arguments: arguments) ?? 0
        }
    }

    func children(
        mediumUUID: UUID,
        parentID: Int64?,
        limit: Int? = nil,
        offset: Int = 0,
        scope: IndexScope? = nil
    ) async throws -> [StoredItem] {
        if offset == 0, limit == nil {
            var all: [StoredItem] = []
            var cursor: ItemChildrenCursor?
            while true {
                let page = try await childrenPage(mediumUUID: mediumUUID, parentID: parentID, limit: 5_000, after: cursor, scope: scope)
                all.append(contentsOf: page.items)
                guard let next = page.nextCursor else { break }
                cursor = next
            }
            return all
        }
        return try await childrenPage(mediumUUID: mediumUUID, parentID: parentID, limit: limit ?? 5_000, offset: offset, scope: scope).items
    }

    /// Cursor: `name` trägt hier den Suchnamen (`slug`) des letzten Eintrags, `isFolder` bleibt ohne Bedeutung.
    func childrenPage(
        mediumUUID: UUID,
        parentID: Int64?,
        limit: Int,
        after: ItemChildrenCursor? = nil,
        offset: Int = 0,
        scope: IndexScope? = nil
    ) async throws -> (items: [StoredItem], nextCursor: ItemChildrenCursor?) {
        if childrenReadsFail { throw IndexStoreError.childrenReadFailed }
        let rows: [StoredItem] = try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let natural = "\"\(NaturalOrder.collationName)\""
            var ids: [Int64] = []
            if let after {
                // Erst gleiche Suchnamen mit größerer Kennung, dann größere Suchnamen: beides Bereichsabfragen auf der Suchhilfe.
                ids += try Int64.fetchAll(
                    db,
                    sql: """
                        SELECT id FROM items
                        WHERE storageID = ? AND parentID IS ? AND status = 0 AND slug COLLATE \(natural) = ? AND id > ?
                        ORDER BY id LIMIT ?
                        """,
                    arguments: [storageID, parentID, after.name, after.id, limit]
                )
                if ids.count < limit {
                    ids += try Int64.fetchAll(
                        db,
                        sql: """
                            SELECT id FROM items
                            WHERE storageID = ? AND parentID IS ? AND status = 0 AND slug COLLATE \(natural) > ?
                            ORDER BY slug COLLATE \(natural), id LIMIT ?
                            """,
                        arguments: [storageID, parentID, after.name, limit - ids.count]
                    )
                }
            } else {
                ids = try Int64.fetchAll(db, sql: Self.columnFirstPageSQL, arguments: [storageID, parentID, limit, offset])
            }
            return try Self.items(db, ids: ids)
        }
        let filtered: [StoredItem]
        if let scope {
            if scope.checksNames { nameChecks.add(rows.count) }
            filtered = rows.filter { !scope.hides(name: $0.name, depth: $0.depth) }
        } else {
            filtered = rows
        }
        let next: ItemChildrenCursor?
        if rows.count < limit {
            next = nil
        } else if let last = rows.last {
            next = ItemChildrenCursor(isFolder: last.isFolder, name: Slug.make(last.name), id: last.id)
        } else {
            next = nil
        }
        return (filtered, next)
    }

    /// Erste Seite einer Spalte: über die Spalten-Suchhilfe, ohne Zwischensortierung (Test: Abfrageplan).
    nonisolated static let columnFirstPageSQL = """
        SELECT id FROM items
        WHERE storageID = ? AND parentID IS ? AND status = 0
        ORDER BY slug COLLATE "\(NaturalOrder.collationName)", id LIMIT ? OFFSET ?
        """

    /// Trefferkennungen der Suche nach `(slug, id)` (Test: Abfrageplan).
    nonisolated static func searchHitsSQL(whereClause: String) -> String {
        "SELECT i.id, i.slug FROM items i WHERE \(whereClause) ORDER BY i.slug, i.id LIMIT ?"
    }

    /// Nur sichtbare Einträge (`status = 0`); ein verschwundener Eintrag ist hier nicht mehr da.
    func item(id: Int64) async throws -> StoredItem? {
        try await pool.read { db in
            guard try Int.fetchOne(db, sql: "SELECT status FROM items WHERE id = ?", arguments: [id]) == ItemStatus.visible.rawValue else { return nil }
            return try Self.items(db, ids: [id]).first
        }
    }

    #if DEBUG
    /// Tests: Status eines Eintrags (auch verschwundene).
    func statusOfItem(id: Int64) async throws -> Int? {
        try await pool.read { db in try Int.fetchOne(db, sql: "SELECT status FROM items WHERE id = ?", arguments: [id]) }
    }
    #endif

    // MARK: Zähler

    func counts(mediumUUID: UUID, scope: IndexScope? = nil) async throws -> (files: Int, folders: Int) {
        let counter = nameChecks
        return try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return (files: 0, folders: 0) }
            if let scope, scope.checksNames {
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT name, isFolder, depth FROM items WHERE storageID = ? AND status = 0",
                    arguments: [storageID]
                )
                counter.add(rows.count)
                var files = 0
                var folders = 0
                for row in rows {
                    if scope.hides(name: row["name"], depth: row["depth"]) { continue }
                    if row["isFolder"] as Bool { folders += 1 } else { files += 1 }
                }
                return (files, folders)
            }
            let depthClause = scope?.maxDepth.map { " AND depth <= \($0)" } ?? ""
            let files = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM items WHERE storageID = ? AND isFolder = 0 AND status = 0" + depthClause, arguments: [storageID]
            ) ?? 0
            let folders = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM items WHERE storageID = ? AND isFolder = 1 AND status = 0" + depthClause, arguments: [storageID]
            ) ?? 0
            return (files, folders)
        }
    }

    // MARK: Favoriten

    func favorites(maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> [StoredItem] {
        let rows: [StoredItem] = try await pool.read { db in
            var sql = "SELECT i.id FROM favorites f JOIN items i ON i.id = f.itemID WHERE i.status = 0"
            var arguments: StatementArguments = []
            if let depth = scope?.maxDepth ?? maxDepth {
                sql += " AND i.depth <= ?"
                arguments += [depth]
            }
            sql += " ORDER BY i.slug, i.id"
            return try Self.items(db, ids: try Int64.fetchAll(db, sql: sql, arguments: arguments))
        }
        guard let scope, scope.checksNames else { return rows }
        nameChecks.add(rows.count)
        return rows.filter { !scope.hides(name: $0.name, depth: $0.depth) }
    }

    // MARK: Suche

    func search(query: String, filters: SearchFilters, limit: Int = 500, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> [StoredItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !filters.hasActiveFilters { return [] }
        guard limit > 0 else { return [] }
        let depth = scope?.maxDepth ?? maxDepth
        let plan = try await pool.read { db in try SearchPlanV3.make(db, query: trimmed, filters: filters, maxDepth: depth) }
        let ids: [Int64]
        if let scope, scope.checksNames {
            ids = try await visibleSearchHitIDs(plan: plan, limit: limit, scope: scope)
        } else {
            ids = try await topHits(plan, limit: limit).map(\.id)
        }
        guard !ids.isEmpty else { return [] }
        return try await pool.read { db in try Self.items(db, ids: ids) }
    }

    /// Genaue Zahl der Treffer. Mit ausstehender Bereinigung (`checksNames`) prüft ein Cursor zusätzlich die Namen.
    func searchCount(query: String, filters: SearchFilters, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> Int {
        #if DEBUG
        if let delay = searchCountDelay { try await Task.sleep(for: delay) }
        #endif
        let counter = nameChecks
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let depth = scope?.maxDepth ?? maxDepth
        let plan = try await pool.read { db in try SearchPlanV3.make(db, query: trimmed, filters: filters, maxDepth: depth) }
        if let scope, scope.checksNames {
            let ranges = try await idRanges()
            if ranges.count <= 1 {
                return try await pool.read { db in
                    let cursor = try Row.fetchCursor(
                        db, sql: "SELECT i.name, i.depth FROM items i WHERE \(plan.whereClause)", arguments: plan.statementArguments()
                    )
                    var count = 0
                    var checked = 0
                    while let row = try cursor.next() {
                        checked += 1
                        if !scope.hides(name: row["name"], depth: row["depth"]) { count += 1 }
                    }
                    counter.add(checked)
                    return count
                }
            }
            let pool = pool
            return try await withThrowingTaskGroup(of: (count: Int, checked: Int).self) { group in
                for range in ranges {
                    group.addTask {
                        try await pool.read { db in
                            let cursor = try Row.fetchCursor(
                                db,
                                sql: "SELECT i.name, i.depth FROM items i WHERE \(plan.whereClause) AND i.id BETWEEN ? AND ?",
                                arguments: plan.statementArguments(extra: [range.lowerBound.databaseValue, range.upperBound.databaseValue])
                            )
                            var count = 0
                            var checked = 0
                            while let row = try cursor.next() {
                                checked += 1
                                if !scope.hides(name: row["name"], depth: row["depth"]) { count += 1 }
                            }
                            return (count, checked)
                        }
                    }
                }
                var total = 0
                var checked = 0
                for try await part in group {
                    total += part.count
                    checked += part.checked
                }
                counter.add(checked)
                return total
            }
        }
        let ranges = try await idRanges()
        if ranges.count <= 1 {
            return try await pool.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items i WHERE \(plan.whereClause)", arguments: plan.statementArguments()) ?? 0
            }
        }
        let pool = pool
        return try await withThrowingTaskGroup(of: Int.self) { group in
            for range in ranges {
                group.addTask {
                    try await pool.read { db in
                        try Int.fetchOne(
                            db,
                            sql: "SELECT COUNT(*) FROM items i WHERE \(plan.whereClause) AND i.id BETWEEN ? AND ?",
                            arguments: plan.statementArguments(extra: [range.lowerBound.databaseValue, range.upperBound.databaseValue])
                        ) ?? 0
                    }
                }
            }
            var total = 0
            for try await part in group { total += part }
            return total
        }
    }

    /// Medien, deren Suchname den Begriff enthält (Mediennamen über `storages.slug`).
    func searchMedia(query: String) async throws -> [StoredMedium] {
        let slug = Slug.make(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return try await pool.read { db in
            let all = try MediumCodecV3.fetchAll(db, whereClause: slug.isEmpty ? "" : "WHERE slug LIKE ? ESCAPE '\\'",
                                                 arguments: slug.isEmpty ? [] : ["%" + SearchPlanV3.escapeLike(slug) + "%"])
            return all.filter { !$0.isForgotten }
        }
    }

    #if DEBUG
    func storedNames() async throws -> [String] {
        try await pool.read { db in try String.fetchAll(db, sql: "SELECT name FROM items WHERE status = 0 ORDER BY id") }
    }
    #endif

    // MARK: Parallele Suche

    /// Kennungs-Bereiche für die parallele Zählung; kein oder ein Bereich = einzelne Abfrage.
    func idRanges() async throws -> [ClosedRange<Int64>] {
        let parts = searchParallelism ?? Self.automaticParallelism
        let bounds = try pool.read { db -> Row? in try Row.fetchOne(db, sql: "SELECT MIN(id) AS low, MAX(id) AS high FROM items") }
        guard parts > 1, let low: Int64 = bounds?["low"], let high: Int64 = bounds?["high"], high > low else { return [] }
        let span = high - low + 1
        let size = (span + Int64(parts) - 1) / Int64(parts)
        var ranges: [ClosedRange<Int64>] = []
        var start = low
        while start <= high {
            ranges.append(start...min(start + size - 1, high))
            start += size
        }
        return ranges
    }

    nonisolated static var automaticParallelism: Int {
        max(2, ProcessInfo.processInfo.activeProcessorCount - 1)
    }

    /// Die ersten `limit` Treffer nach `(slug, id)`. Eine einzelne Abfrage: sie liest die Suchhilfe in Namensreihenfolge
    /// und hört nach `limit` Treffern auf (gemessen in 232: schneller als Teilabfragen). Nur die Zahl läuft parallel.
    private func topHits(_ plan: SearchPlanV3, limit: Int) async throws -> [(id: Int64, slug: String)] {
        try await searchHitPage(plan: plan, after: nil, limit: limit)
    }

    private struct SearchHitCursor: Sendable, Equatable {
        var slug: String
        var id: Int64
    }

    /// SQL-Seite der Suche; Cursor auf `(slug, id)` wie in der Spalten-Pagination.
    private func searchHitPage(
        plan: SearchPlanV3,
        after: SearchHitCursor?,
        limit: Int
    ) async throws -> [(id: Int64, slug: String)] {
        try await pool.read { db in
            let natural = "\"\(NaturalOrder.collationName)\""
            if let after {
                var hits: [(Int64, String)] = []
                let sameSlug = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT i.id, i.slug FROM items i
                        WHERE \(plan.whereClause) AND i.slug COLLATE \(natural) = ? AND i.id > ?
                        ORDER BY i.slug COLLATE \(natural), i.id LIMIT ?
                        """,
                    arguments: plan.statementArguments(extra: [after.slug.databaseValue, after.id.databaseValue, limit.databaseValue])
                )
                hits += sameSlug.map { (id: $0["id"], slug: $0["slug"] as String) }
                if hits.count < limit {
                    let nextSlug = try Row.fetchAll(
                        db,
                        sql: """
                            SELECT i.id, i.slug FROM items i
                            WHERE \(plan.whereClause) AND i.slug COLLATE \(natural) > ?
                            ORDER BY i.slug COLLATE \(natural), i.id LIMIT ?
                            """,
                        arguments: plan.statementArguments(extra: [after.slug.databaseValue, (limit - hits.count).databaseValue])
                    )
                    hits += nextSlug.map { (id: $0["id"], slug: $0["slug"] as String) }
                }
                return hits
            }
            return try Row.fetchAll(
                db,
                sql: Self.searchHitsSQL(whereClause: plan.whereClause),
                arguments: plan.statementArguments(extra: [limit.databaseValue])
            ).map { (id: $0["id"], slug: $0["slug"] as String) }
        }
    }

    /// Treffer bis `limit`, wenn Namensregeln in Swift geprüft werden (`checksNames`).
    private func visibleSearchHitIDs(plan: SearchPlanV3, limit: Int, scope: IndexScope) async throws -> [Int64] {
        var visible: [Int64] = []
        var after: SearchHitCursor?
        let pageSize = max(limit, 100)
        while visible.count < limit {
            let page = try await searchHitPage(plan: plan, after: after, limit: pageSize)
            if page.isEmpty { break }
            let rows = try await pool.read { db in try Self.items(db, ids: page.map(\.id)) }
            nameChecks.add(rows.count)
            for row in rows where !scope.hides(name: row.name, depth: row.depth) {
                visible.append(row.id)
                if visible.count >= limit { break }
            }
            if page.count < pageSize { break }
            after = SearchHitCursor(slug: page[page.count - 1].slug, id: page[page.count - 1].id)
        }
        return visible
    }

    // MARK: Zeilen → StoredItem

    /// Liefert die Einträge zu den Kennungen in derselben Reihenfolge. Pfade kommen aus einer einzigen Kettenabfrage.
    nonisolated static func items(_ db: Database, ids: [Int64]) throws -> [StoredItem] {
        guard !ids.isEmpty else { return [] }
        var byID: [Int64: Row] = [:]
        var offset = 0
        while offset < ids.count {
            let chunk = Array(ids[offset..<min(offset + 400, ids.count)])
            let marks = chunk.map { _ in "?" }.joined(separator: ",")
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT i.id, i.parentID, i.name, i.isFolder, i.depth, i.status, i.modifiedAt, i.fileID,
                           i.listedAt, i.unreadable, e.ext AS ext, d.sizeBytes AS sizeBytes, d.isPackage AS isPackage,
                           s.uuid AS storageUUID, (f.itemID IS NOT NULL) AS isFavorite
                    FROM items i
                    JOIN storages s ON s.id = i.storageID
                    LEFT JOIN extensions e ON e.id = i.extID
                    LEFT JOIN item_details d ON d.itemID = i.id
                    LEFT JOIN favorites f ON f.itemID = i.id
                    WHERE i.id IN (\(marks))
                    """,
                arguments: StatementArguments(chunk)
            ) {
                byID[row["id"]] = row
            }
            offset += 400
        }
        let parentPaths = try parentPaths(db, parentIDs: Set(byID.values.compactMap { $0["parentID"] as Int64? }))
        return try ids.compactMap { id -> StoredItem? in
            guard let row = byID[id] else { return nil }
            let uuidData: Data = row["storageUUID"]
            guard let uuid = MediumCodecV3.uuid(uuidData) else { throw IndexStoreError.invalidStoredUUID }
            let parent: Int64? = row["parentID"]
            let isFolder: Bool = row["isFolder"]
            let name: String = row["name"]
            let base = parent.flatMap { parentPaths[$0] } ?? "/"
            let modified: Int64? = row["modifiedAt"]
            let fileID: Int64? = row["fileID"]
            let listed: Int64? = row["listedAt"]
            return StoredItem(
                id: id,
                mediumUUID: uuid,
                parentID: parent,
                name: name,
                isFolder: isFolder,
                isPackage: (row["isPackage"] as Bool?) ?? false,
                ext: row["ext"],
                sizeBytes: row["sizeBytes"],
                modifiedAt: modified.map(SchemaTime.date),
                fileID: fileID.map(String.init),
                depth: row["depth"],
                path: base + name + (isFolder ? "/" : ""),
                isFavorite: row["isFavorite"],
                listedAt: listed.map(SchemaTime.date),
                unreadable: row["unreadable"]
            )
        }
    }

    /// Pfade (`/A/B/`) der Ordner mit den gegebenen Kennungen: eine rekursive Abfrage nach oben je Block.
    nonisolated static func parentPaths(_ db: Database, parentIDs: Set<Int64>) throws -> [Int64: String] {
        guard !parentIDs.isEmpty else { return [:] }
        var result: [Int64: String] = [:]
        let all = Array(parentIDs)
        var offset = 0
        while offset < all.count {
            let chunk = Array(all[offset..<min(offset + 400, all.count)])
            let marks = chunk.map { _ in "?" }.joined(separator: ",")
            let rows = try Row.fetchAll(
                db,
                sql: """
                    WITH RECURSIVE up(startID, id, parentID, name, lvl) AS (
                        SELECT id, id, parentID, name, 0 FROM items WHERE id IN (\(marks))
                        UNION ALL
                        SELECT up.startID, i.id, i.parentID, i.name, up.lvl + 1 FROM items i JOIN up ON i.id = up.parentID
                    )
                    SELECT startID, name FROM up ORDER BY startID, lvl DESC
                    """,
                arguments: StatementArguments(chunk)
            )
            var current: Int64?
            var path = "/"
            for row in rows {
                let start: Int64 = row["startID"]
                if start != current {
                    if let current { result[current] = path }
                    current = start
                    path = "/"
                }
                path += (row["name"] as String) + "/"
            }
            if let current { result[current] = path }
            offset += 400
        }
        return result
    }
}

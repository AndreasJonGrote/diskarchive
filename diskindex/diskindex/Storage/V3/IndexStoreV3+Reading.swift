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
        scope: IndexScope? = nil,
        parentDirectoryPath: String? = nil
    ) async throws -> (items: [StoredItem], nextCursor: ItemChildrenCursor?) {
        if childrenReadsFail { throw IndexStoreError.childrenReadFailed }
        let rows: [StoredItem] = try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let pathBase: String?
            if let parentDirectoryPath {
                pathBase = parentDirectoryPath
            } else if parentID == nil {
                pathBase = "/"
            } else {
                pathBase = nil
            }
            let fetched = try Self.fetchColumnChildRows(
                db,
                storageID: storageID,
                parentID: parentID,
                limit: limit,
                after: after,
                offset: offset
            )
            return try Self.storedItemsFromColumnRows(
                db,
                rows: fetched,
                mediumUUID: mediumUUID,
                parentDirectoryPath: pathBase
            )
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

    nonisolated static let columnChildRowSelect = """
        SELECT i.id, i.parentID, i.name, i.isFolder, i.depth, i.status, i.modifiedAt, i.fileID,
               i.listedAt, i.unreadable, e.ext AS ext, d.sizeBytes AS sizeBytes, d.isPackage AS isPackage,
               (f.itemID IS NOT NULL) AS isFavorite
        FROM items i
        LEFT JOIN extensions e ON e.id = i.extID
        LEFT JOIN item_details d ON d.itemID = i.id
        LEFT JOIN favorites f ON f.itemID = i.id
        """

    nonisolated static func fetchColumnChildRows(
        _ db: Database,
        storageID: Int64,
        parentID: Int64?,
        limit: Int,
        after: ItemChildrenCursor?,
        offset: Int
    ) throws -> [Row] {
        let natural = "\"\(NaturalOrder.collationName)\""
        let base = columnChildRowSelect
        if let after {
            var rows = try Row.fetchAll(
                db,
                sql: """
                    \(base)
                    WHERE i.storageID = ? AND i.parentID IS ? AND i.status = 0 AND i.slug COLLATE \(natural) = ? AND i.id > ?
                    ORDER BY i.id LIMIT ?
                    """,
                arguments: [storageID, parentID, after.name, after.id, limit]
            )
            if rows.count < limit {
                rows += try Row.fetchAll(
                    db,
                    sql: """
                        \(base)
                        WHERE i.storageID = ? AND i.parentID IS ? AND i.status = 0 AND i.slug COLLATE \(natural) > ?
                        ORDER BY i.slug COLLATE \(natural), i.id LIMIT ?
                        """,
                    arguments: [storageID, parentID, after.name, limit - rows.count]
                )
            }
            return rows
        }
        return try Row.fetchAll(
            db,
            sql: """
                \(base)
                WHERE i.storageID = ? AND i.parentID IS ? AND i.status = 0
                ORDER BY i.slug COLLATE \(natural), i.id LIMIT ? OFFSET ?
                """,
            arguments: [storageID, parentID, limit, offset]
        )
    }

    nonisolated static func storedItemsFromColumnRows(
        _ db: Database,
        rows: [Row],
        mediumUUID: UUID,
        parentDirectoryPath: String?
    ) throws -> [StoredItem] {
        guard !rows.isEmpty else { return [] }
        let resolvedParentPaths: [Int64: String]
        if parentDirectoryPath != nil {
            resolvedParentPaths = [:]
        } else {
            resolvedParentPaths = try parentPaths(
                db,
                parentIDs: Set(rows.compactMap { $0["parentID"] as Int64? })
            )
        }
        return rows.map { row in
            let id: Int64 = row["id"]
            let parent: Int64? = row["parentID"]
            let isFolder: Bool = row["isFolder"]
            let name: String = row["name"]
            let base: String
            if let parentDirectoryPath {
                base = parentDirectoryPath
            } else {
                base = parent.flatMap { resolvedParentPaths[$0] } ?? "/"
            }
            let modified: Int64? = row["modifiedAt"]
            let fileID: Int64? = row["fileID"]
            let listed: Int64? = row["listedAt"]
            return StoredItem(
                id: id,
                mediumUUID: mediumUUID,
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

    /// Trefferkennungen der Suche nach `(slug, id)` (Test: Abfrageplan).
    nonisolated static func searchHitsSQL(whereClause: String) -> String {
        "SELECT i.id, i.slug FROM items i WHERE \(whereClause) ORDER BY i.slug, i.id LIMIT ?"
    }

    /// bug.0.4.038 (REPORT 83): Trefferkennungen in der gewählten Reihenfolge über **alle** Treffer, Seite per
    /// `LIMIT ? OFFSET ?`. Name: `slug` binär (Suchhilfe `items_search`; welche
    /// 500 auf die Seite kommen, die Seite sortiert der Client natürlich nach); Datum: `modifiedAt` (Suchhilfe `items_modified`, ohne Datum zuerst wie in der
    /// Client-Sortierung); Medium: `storages.slug`, innerhalb eines Mediums nach Name. Kennung entscheidet Gleichstand.
    nonisolated static func searchSortedHitsSQL(whereClause: String, sort: SearchSort) -> String {
        let desc = sort.direction == .descending ? " DESC" : ""
        switch sort.serverOrder.column {
        case .date:
            return "SELECT i.id FROM items i WHERE \(whereClause) ORDER BY i.modifiedAt\(desc), i.id\(desc) LIMIT ? OFFSET ?"
        case .medium:
            return """
                SELECT i.id FROM items i JOIN storages s ON s.id = i.storageID WHERE \(whereClause)
                ORDER BY s.slug\(desc), i.storageID\(desc), i.slug, i.id LIMIT ? OFFSET ?
                """
        case .name, .path, .status:
            return "SELECT i.id FROM items i WHERE \(whereClause) ORDER BY i.slug\(desc), i.id\(desc) LIMIT ? OFFSET ?"
        }
    }

    /// Nur sichtbare Einträge (`status = 0`); ein verschwundener Eintrag ist hier nicht mehr da.
    func item(id: Int64) async throws -> StoredItem? {
        try await pool.read { db in
            guard try Int.fetchOne(db, sql: "SELECT status FROM items WHERE id = ?", arguments: [id]) == ItemStatus.visible.rawValue else { return nil }
            return try Self.items(db, ids: [id]).first
        }
    }

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

    /// bug.0.4.037: alle Favoriten-Kennungen (`items.id`), leichte Abfrage nur auf `favorites`. Quelle für
    /// `AppState.isFavorite` bei Dateien und Ordnern, unabhängig von der geladenen Seite.
    func favoriteItemIDs() async throws -> Set<Int64> {
        try await pool.read { db in
            Set(try Int64.fetchAll(db, sql: "SELECT itemID FROM favorites"))
        }
    }

    /// bug.0.4.040 (REPORT 86): eine Seite Favoriten (nach Name, wie `favorites`) unter denselben Bedingungen wie die
    /// Suche ohne Begriff (`SearchPlanV3`: Medien, Dateityp, Alter, Tiefe). Die Medienauswahl in `filters` trägt den
    /// Verbindungsfilter (online/offline als Medienkennungen).
    func favoritePage(filters: SearchFilters, limit: Int, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> [StoredItem] {
        guard limit > 0 else { return [] }
        let depth = scope?.maxDepth ?? maxDepth
        let checksNames = scope?.checksNames ?? false
        let counter = nameChecks
        return try await pool.read { db in
            let plan = try SearchPlanV3.make(db, query: "", filters: filters, maxDepth: depth)
            let base = "SELECT i.id FROM favorites f JOIN items i ON i.id = f.itemID WHERE \(plan.whereClause) ORDER BY i.slug, i.id"
            guard checksNames, let scope else {
                let ids = try Int64.fetchAll(db, sql: base + " LIMIT ?", arguments: plan.statementArguments(extra: [limit.databaseValue]))
                return try Self.items(db, ids: ids)
            }
            // Ausstehende Bereinigung: Namen in Swift prüfen, bis die Seite voll ist.
            var visible: [StoredItem] = []
            var offset = 0
            let pageSize = max(limit, 100)
            while visible.count < limit {
                let ids = try Int64.fetchAll(
                    db,
                    sql: base + " LIMIT ? OFFSET ?",
                    arguments: plan.statementArguments(extra: [pageSize.databaseValue, offset.databaseValue])
                )
                if ids.isEmpty { break }
                let rows = try Self.items(db, ids: ids)
                counter.add(rows.count)
                for row in rows where !scope.hides(name: row.name, depth: row.depth) {
                    visible.append(row)
                    if visible.count >= limit { break }
                }
                if ids.count < pageSize { break }
                offset += ids.count
            }
            return visible
        }
    }

    /// bug.0.4.040: Zahl der Favoriten unter denselben Bedingungen wie `favoritePage`.
    func favoriteCount(filters: SearchFilters, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> Int {
        let depth = scope?.maxDepth ?? maxDepth
        let checksNames = scope?.checksNames ?? false
        let counter = nameChecks
        return try await pool.read { db in
            let plan = try SearchPlanV3.make(db, query: "", filters: filters, maxDepth: depth)
            let from = "FROM favorites f JOIN items i ON i.id = f.itemID WHERE \(plan.whereClause)"
            guard checksNames, let scope else {
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) " + from, arguments: plan.statementArguments()) ?? 0
            }
            let cursor = try Row.fetchCursor(db, sql: "SELECT i.name, i.depth " + from, arguments: plan.statementArguments())
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

    // MARK: Suche

    /// - Parameters:
    ///   - sort: Reihenfolge über alle Treffer (Name, Datum, Medium; Pfad/Status → Name aufsteigend, bug.0.4.038).
    ///   - isFolder: nur Ordner (`true`) oder nur Dateien (`false`), z. B. je eine kleine Abfrage im Popover.
    func search(
        query: String,
        filters: SearchFilters,
        limit: Int = 500,
        maxDepth: Int? = nil,
        scope: IndexScope? = nil,
        sort: SearchSort = SearchSort(),
        isFolder: Bool? = nil
    ) async throws -> [StoredItem] {
        if let delay = searchQueryDelay { try await Task.sleep(for: delay) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !filters.hasActiveFilters { return [] }
        guard limit > 0 else { return [] }
        let depth = scope?.maxDepth ?? maxDepth
        let plan = try await pool.read { db in
            try SearchPlanV3.make(db, query: trimmed, filters: filters, maxDepth: depth, isFolder: isFolder)
        }
        let order = sort.serverOrder
        let ids: [Int64]
        if order == SearchSort() {
            if let scope, scope.checksNames {
                ids = try await visibleSearchHitIDs(plan: plan, limit: limit, scope: scope)
            } else {
                ids = try await topHits(plan, limit: limit).map(\.id)
            }
        } else if let scope, scope.checksNames {
            ids = try await visibleSortedHitIDs(plan: plan, sort: order, limit: limit, scope: scope)
        } else {
            ids = try await sortedHitPage(plan: plan, sort: order, offset: 0, limit: limit)
        }
        guard !ids.isEmpty else { return [] }
        return try await pool.read { db in try Self.items(db, ids: ids) }
    }

    /// bug.0.4.038 (REPORT 131): Medien mit mindestens einem Treffer unter denselben Filtern, unabhängig von der
    /// angezeigten Seite. Je Medium bricht die Prüfung beim ersten Treffer ab (`EXISTS`).
    func searchMediumIDs(query: String, filters: SearchFilters, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> Set<UUID> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !filters.hasActiveFilters { return [] }
        let depth = scope?.maxDepth ?? maxDepth
        let counter = nameChecks
        return try await pool.read { db in
            let plan = try SearchPlanV3.make(db, query: trimmed, filters: filters, maxDepth: depth)
            let storageIDs: [Int64]
            if let scope, scope.checksNames {
                let cursor = try Row.fetchCursor(
                    db,
                    sql: "SELECT i.storageID, i.name, i.depth FROM items i WHERE \(plan.whereClause)",
                    arguments: plan.statementArguments()
                )
                var found = Set<Int64>()
                var checked = 0
                while let row = try cursor.next() {
                    let storageID: Int64 = row["storageID"]
                    if found.contains(storageID) { continue }
                    checked += 1
                    if !scope.hides(name: row["name"], depth: row["depth"]) { found.insert(storageID) }
                }
                counter.add(checked)
                storageIDs = Array(found)
            } else {
                storageIDs = try Int64.fetchAll(
                    db,
                    sql: "SELECT DISTINCT s.id FROM storages s WHERE EXISTS (SELECT 1 FROM items i WHERE i.storageID = s.id AND \(plan.whereClause))",
                    arguments: plan.statementArguments()
                )
            }
            guard !storageIDs.isEmpty else { return [] }
            let marks = storageIDs.map { _ in "?" }.joined(separator: ",")
            let blobs = try Data.fetchAll(db, sql: "SELECT uuid FROM storages WHERE id IN (\(marks))", arguments: StatementArguments(storageIDs))
            return Set(blobs.compactMap(MediumCodecV3.uuid))
        }
    }

    /// Genaue Zahl der Treffer. Mit ausstehender Bereinigung (`checksNames`) prüft ein Cursor zusätzlich die Namen.
    func searchCount(query: String, filters: SearchFilters, maxDepth: Int? = nil, scope: IndexScope? = nil) async throws -> Int {
        searchCountCalls.add(1)
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

    /// Eine Seite Trefferkennungen in der Reihenfolge `sort` (bug.0.4.038).
    private func sortedHitPage(plan: SearchPlanV3, sort: SearchSort, offset: Int, limit: Int) async throws -> [Int64] {
        try await pool.read { db in
            try Int64.fetchAll(
                db,
                sql: Self.searchSortedHitsSQL(whereClause: plan.whereClause, sort: sort),
                arguments: plan.statementArguments(extra: [limit.databaseValue, offset.databaseValue])
            )
        }
    }

    /// Wie `visibleSearchHitIDs`, aber in der Reihenfolge `sort` (Seiten per Versatz).
    private func visibleSortedHitIDs(plan: SearchPlanV3, sort: SearchSort, limit: Int, scope: IndexScope) async throws -> [Int64] {
        var visible: [Int64] = []
        var offset = 0
        let pageSize = max(limit, 100)
        while visible.count < limit {
            let page = try await sortedHitPage(plan: plan, sort: sort, offset: offset, limit: pageSize)
            if page.isEmpty { break }
            let rows = try await pool.read { db in try Self.items(db, ids: page) }
            nameChecks.add(rows.count)
            for row in rows where !scope.hides(name: row.name, depth: row.depth) {
                visible.append(row.id)
                if visible.count >= limit { break }
            }
            if page.count < pageSize { break }
            offset += page.count
        }
        return visible
    }

    // MARK: Zeilen → StoredItem

    /// Liefert die Einträge zu den Kennungen in derselben Reihenfolge. Pfade aus Kettenabfrage oder `parentDirectoryPath`.
    nonisolated static func items(_ db: Database, ids: [Int64], parentDirectoryPath: String? = nil) throws -> [StoredItem] {
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
        let resolvedParentPaths: [Int64: String]
        if parentDirectoryPath != nil {
            resolvedParentPaths = [:]
        } else {
            resolvedParentPaths = try parentPaths(db, parentIDs: Set(byID.values.compactMap { $0["parentID"] as Int64? }))
        }
        return try ids.compactMap { id -> StoredItem? in
            guard let row = byID[id] else { return nil }
            let uuidData: Data = row["storageUUID"]
            guard let uuid = MediumCodecV3.uuid(uuidData) else { throw IndexStoreError.invalidStoredUUID }
            let parent: Int64? = row["parentID"]
            let isFolder: Bool = row["isFolder"]
            let name: String = row["name"]
            let base: String
            if let parentDirectoryPath {
                base = parentDirectoryPath
            } else {
                base = parent.flatMap { resolvedParentPaths[$0] } ?? "/"
            }
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

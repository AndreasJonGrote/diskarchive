//
//  IndexStore+Queries.swift
//  diskindex
//
//  Aus IndexStore.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import Foundation
import GRDB

extension IndexStore {
    // MARK: Abfragen

    func childCount(mediumUUID: UUID, parentID: Int64?, scope: IndexScope? = nil) async throws -> Int {
        if childrenReadsFail { throw IndexStoreError.childrenReadFailed }
        _ = scope
        return try await pool.read { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else { return 0 }
            return try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM item
                    WHERE mediumID = ? AND parentID IS ? AND removedAt IS NULL
                    """,
                arguments: [mediumID, parentID]
            ) ?? 0
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
                let page = try await childrenPage(
                    mediumUUID: mediumUUID,
                    parentID: parentID,
                    limit: 5_000,
                    after: cursor,
                    scope: scope
                )
                all.append(contentsOf: page.items)
                guard let next = page.nextCursor else { break }
                cursor = next
            }
            return all
        }
        let page = try await childrenPage(
            mediumUUID: mediumUUID,
            parentID: parentID,
            limit: limit ?? 5_000,
            offset: offset,
            scope: scope
        )
        return page.items
    }

    func childrenPage(
        mediumUUID: UUID,
        parentID: Int64?,
        limit: Int,
        after: ItemChildrenCursor? = nil,
        offset: Int = 0,
        scope: IndexScope? = nil
    ) async throws -> (items: [StoredItem], nextCursor: ItemChildrenCursor?) {
        if childrenReadsFail { throw IndexStoreError.childrenReadFailed }
        let rows = try await pool.read { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else { return [StoredItem]() }
            var sql = """
                SELECT
                    item.id, item.parentID, item.name, item.isFolder, item.isPackage, item.ext,
                    item.sizeBytes, item.modifiedAt, item.fileID, item.depth, '' AS path,
                    item.lastSeenAt, item.removedAt, item.isFavorite, item.listedAt, item.unreadable,
                    ? AS mediumUUID
                FROM item
                WHERE item.mediumID = ? AND item.parentID IS ? AND item.removedAt IS NULL
                """
            var arguments: [DatabaseValueConvertible?] = [mediumUUID.uuidString, mediumID, parentID]
            if let after {
                sql += """
                     AND (
                        item.isFolder < ? OR
                        (item.isFolder = ? AND item.name COLLATE NOCASE > ?) OR
                        (item.isFolder = ? AND item.name = ? COLLATE NOCASE AND item.id > ?)
                    )
                    """
                let folderFlag: Int = after.isFolder ? 1 : 0
                arguments.append(contentsOf: [
                    folderFlag, folderFlag, after.name,
                    folderFlag, after.name, after.id,
                ] as [DatabaseValueConvertible?])
            }
            sql += " ORDER BY item.isFolder DESC, item.name COLLATE NOCASE, item.id"
            if offset > 0 {
                sql += " LIMIT ? OFFSET ?"
                arguments.append(contentsOf: [limit, offset])
            } else {
                sql += " LIMIT ?"
                arguments.append(limit)
            }
            return try IndexSQL.items(db, sql: sql, arguments: StatementArguments(arguments))
        }
        let filtered: [StoredItem]
        if let scope {
            filtered = rows.filter { !scope.hides(name: $0.name, depth: $0.depth) }
        } else {
            filtered = rows
        }
        let next: ItemChildrenCursor?
        if filtered.count < limit {
            next = nil
        } else if let last = filtered.last {
            next = ItemChildrenCursor(isFolder: last.isFolder, name: last.name, id: last.id)
        } else {
            next = nil
        }
        return (filtered, next)
    }

    func item(id: Int64) async throws -> StoredItem? {
        try await pool.read { db in
            try IndexSQL.items(
                db,
                sql: """
                    SELECT item.*, medium.uuid AS mediumUUID
                    FROM item JOIN medium ON medium.id = item.mediumID
                    WHERE item.id = ?
                    """,
                arguments: [id]
            ).first
        }
    }

}

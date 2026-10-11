//
//  IndexSQL.swift
//  diskindex
//
//  Aus IndexStore.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import Foundation
import GRDB

nonisolated struct IndexSearchRequest: Sendable {
    var sql: String
    var arguments: StatementArguments
}

/// SQL und Zeilenabbildung. Liegt außerhalb des Actors, damit die Pool-Blöcke sie nutzen können.
nonisolated enum IndexSQL {
    static func upsertMedium(_ db: Database, _ medium: StoredMedium) throws {
        if try fetchMedium(db, uuid: medium.uuid) != nil {
            try updateMedium(db, medium, keepCreatedAt: true)
        } else {
            try insertMedium(db, medium)
        }
    }

    static func insertMedium(_ db: Database, _ medium: StoredMedium) throws {
        try db.execute(
            sql: """
                INSERT INTO medium (
                    uuid, volumeUUID, volumeCreatedAt, fsType, volumeTotalBytes, diskSizeBytes, name, type, decision,
                    rememberDecision, indexStatus, allowIndexing, autoIndexPaused, capacityUsedBytes,
                    fileCount, folderCount, lastSeenAt, firstIndexedAt, lastIndexedAt, lastIndexActivityAt, isForgotten,
                    showAbsoluteCapacity, isFavorite, fsEventsUUID, lastEventID, completedDepth, createdAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: mediumArguments(medium)
        )
    }

    static func updateMedium(_ db: Database, _ medium: StoredMedium, keepCreatedAt: Bool) throws {
        try db.execute(
            sql: """
                UPDATE medium SET
                    volumeUUID = ?, volumeCreatedAt = ?, fsType = ?, volumeTotalBytes = ?, diskSizeBytes = ?, name = ?, type = ?,
                    decision = ?, rememberDecision = ?, indexStatus = ?, allowIndexing = ?, autoIndexPaused = ?,
                    capacityUsedBytes = ?, fileCount = ?, folderCount = ?, lastSeenAt = ?, firstIndexedAt = ?,
                    lastIndexedAt = ?, lastIndexActivityAt = ?, isForgotten = ?, showAbsoluteCapacity = ?, isFavorite = ?,
                    fsEventsUUID = ?, lastEventID = ?, completedDepth = ?,
                    createdAt = CASE WHEN ? THEN createdAt ELSE ? END
                WHERE uuid = ?
                """,
            arguments: [
                VolumeIdentity.canonicalVolumeUUID(medium.volumeUUID),
                VolumeIdentity.canonicalCreatedAt(medium.volumeCreatedAt),
                medium.fsType,
                medium.volumeTotalBytes,
                medium.diskSizeBytes,
                medium.name,
                medium.type.rawValue,
                medium.decision.rawValue,
                medium.rememberDecision,
                medium.indexStatus.rawValue,
                medium.allowIndexing,
                medium.autoIndexPaused,
                medium.capacityUsedBytes,
                medium.fileCount,
                medium.folderCount,
                medium.lastSeenAt,
                medium.firstIndexedAt,
                medium.lastIndexedAt,
                medium.lastIndexActivityAt,
                medium.isForgotten,
                medium.showAbsoluteCapacity,
                medium.isFavorite,
                medium.fsEventsUUID,
                medium.lastEventID,
                medium.completedDepth,
                keepCreatedAt,
                medium.createdAt,
                medium.uuid.uuidString,
            ]
        )
        if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
    }

    static func match(stored: StoredMedium, identity: VolumeIdentity) -> MatchStrength? {
        let storedUUID = VolumeIdentity.canonicalVolumeUUID(stored.volumeUUID)
        let seenUUID = identity.volumeUUID
        if let storedUUID, let seenUUID {
            return storedUUID == seenUUID ? .uuid : nil
        }
        let storedCreated = VolumeIdentity.canonicalCreatedAt(stored.volumeCreatedAt)
        let seenCreated = identity.createdAt
        let sameFileSystem = stored.fsType == identity.fsType
        let sameSize = stored.volumeTotalBytes == identity.volumeTotalBytes
        if let storedCreated, let seenCreated, sameFileSystem, sameSize, VolumeIdentity.sameSecond(storedCreated, seenCreated) {
            return .fingerprint
        }
        let createdMissing = storedCreated == nil || seenCreated == nil
        if createdMissing, sameFileSystem, sameSize, stored.name == identity.name {
            return .weak
        }
        return nil
    }

    static func fetchMedium(_ db: Database, uuid: UUID) throws -> StoredMedium? {
        try Row.fetchOne(db, sql: "SELECT * FROM medium WHERE uuid = ?", arguments: [uuid.uuidString]).map(medium)
    }

    static func mediumRowID(_ db: Database, uuid: UUID) throws -> Int64? {
        try Int64.fetchOne(db, sql: "SELECT id FROM medium WHERE uuid = ?", arguments: [uuid.uuidString])
    }

    static func medium(_ row: Row) throws -> StoredMedium {
        guard let uuid = UUID(uuidString: row["uuid"]) else { throw IndexStoreError.invalidStoredUUID }
        guard
            let type = StoredMediumType(rawValue: row["type"]),
            let indexStatus = StoredIndexStatus(rawValue: row["indexStatus"])
        else { throw IndexStoreError.invalidStoredUUID }
        let decision = StoredIndexDecision.resolved(row["decision"])
        return StoredMedium(
            uuid: uuid,
            volumeUUID: row["volumeUUID"],
            volumeCreatedAt: row["volumeCreatedAt"],
            fsType: row["fsType"],
            volumeTotalBytes: row["volumeTotalBytes"],
            diskSizeBytes: row["diskSizeBytes"],
            name: row["name"],
            type: type,
            decision: decision,
            rememberDecision: row["rememberDecision"],
            indexStatus: indexStatus,
            allowIndexing: row["allowIndexing"],
            autoIndexPaused: row["autoIndexPaused"],
            capacityUsedBytes: row["capacityUsedBytes"],
            fileCount: row["fileCount"],
            folderCount: row["folderCount"],
            lastSeenAt: row["lastSeenAt"],
            firstIndexedAt: row["firstIndexedAt"],
            lastIndexedAt: row["lastIndexedAt"],
            lastIndexActivityAt: row["lastIndexActivityAt"],
            isForgotten: row["isForgotten"],
            showAbsoluteCapacity: row["showAbsoluteCapacity"],
            isFavorite: row["isFavorite"],
            fsEventsUUID: row["fsEventsUUID"],
            lastEventID: row["lastEventID"],
            completedDepth: row["completedDepth"],
            scanTotal: row["scanTotal"] ?? 0,
            createdAt: row["createdAt"]
        )
    }

    static func applyDirectory(
        _ db: Database,
        mediumUUID: UUID,
        parentID: Int64?,
        entries: [ScannedEntry],
        seenAt: Date
    ) throws -> MediumCountDelta {
        let writer = try DirectoryWriter(db: db, mediumUUID: mediumUUID)
        return try writer.apply(parentID: parentID, path: nil, depth: nil, entries: entries, seenAt: seenAt).delta
    }

    final class DirectoryWriter {
        private let db: Database
        private let mediumID: Int64
        private let existing: Statement
        private let update: Statement
        private let insert: Statement
        private let mark: Statement

        convenience init(db: Database, mediumUUID: UUID) throws {
            guard let mediumID = try mediumRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            try self.init(db: db, mediumID: mediumID)
        }

        init(db: Database, mediumID: Int64) throws {
            self.db = db
            self.mediumID = mediumID
            existing = try db.makeStatement(sql: """
                SELECT id, name, isFolder, isPackage, ext, sizeBytes, modifiedAt, fileID, depth, path, removedAt
                FROM item WHERE mediumID = ? AND parentID IS ?
                """)
            update = try db.makeStatement(sql: """
                UPDATE item SET
                    isFolder = ?, isPackage = ?, ext = ?, sizeBytes = ?, modifiedAt = ?, fileID = ?,
                    depth = ?, path = ?, lastSeenAt = ?, removedAt = NULL
                WHERE id = ?
                """)
            insert = try db.makeStatement(sql: """
                INSERT INTO item (
                    mediumID, parentID, name, isFolder, isPackage, ext, sizeBytes, modifiedAt, fileID,
                    depth, path, lastSeenAt, removedAt, isFavorite
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 0)
                """)
            mark = try db.makeStatement(sql: """
                UPDATE item SET removedAt = ?, contentStamp = NULL
                WHERE mediumID = ? AND removedAt IS NULL AND path >= ? AND path < ?
                """)
        }

        func apply(
            parentID: Int64?,
            path knownPath: String?,
            depth knownDepth: Int?,
            entries: [ScannedEntry],
            seenAt: Date,
            finalize: Bool = true
        ) throws -> (delta: MediumCountDelta, parentPath: String) {
            let parent: (path: String, depth: Int)
            if let knownPath, let knownDepth {
                parent = (knownPath, knownDepth)
            } else {
                parent = try parentContext(db, mediumID: mediumID, parentID: parentID)
            }
            let stamp = Self.listingStamp(entries)
            if finalize, try storedStamp(parentID: parentID) == stamp { return (.zero, parent.path) }
            var delta = MediumCountDelta.zero
            var incoming: [String: ScannedEntry] = [:]
            incoming.reserveCapacity(entries.count)
            for entry in entries {
                incoming[entry.name] = entry
            }

            let cursor = try Row.fetchCursor(existing, arguments: [mediumID, parentID])
            var existingByName: [String: ListedRow] = [:]
            while let row = try cursor.next() {
                let listed = ListedRow(row)
                existingByName[listed.name] = listed
            }

            var unchanged: [Int64] = []
            unchanged.reserveCapacity(existingByName.count)
            var changed = false
            var insertedAfter: Int64?
            for entry in incoming.values {
                let ext = entry.isFolder ? nil : fileExtension(entry.name)
                let path = parent.path + entry.name + (entry.isFolder ? "/" : "")
                if let row = existingByName[entry.name] {
                    if row.matches(entry, ext: ext, path: path, depth: parent.depth) {
                        unchanged.append(row.id)
                    } else {
                        changed = true
                        if row.removedAt != nil {
                            delta.addVisible(isFolder: entry.isFolder)
                        }
                        try update.execute(arguments: [
                            entry.isFolder, entry.isPackage, ext, entry.sizeBytes, entry.modifiedAt, entry.fileID,
                            parent.depth, path, seenAt, row.id,
                        ])
                    }
                } else {
                    changed = true
                    delta.addVisible(isFolder: entry.isFolder)
                    if insertedAfter == nil {
                        insertedAfter = try Int64.fetchOne(db, sql: "SELECT coalesce(MAX(id), 0) FROM item") ?? 0
                    }
                    try insert.execute(arguments: [
                        mediumID, parentID, entry.name, entry.isFolder, entry.isPackage, ext,
                        entry.sizeBytes, entry.modifiedAt, entry.fileID, parent.depth, path, seenAt,
                    ])
                }
            }

            if finalize {
                for row in existingByName.values {
                    if incoming[row.name] != nil { continue }
                    guard row.removedAt == nil else { continue }
                    changed = true
                    delta.removeVisible(isFolder: row.isFolder)
                    try db.execute(
                        sql: "UPDATE item SET removedAt = ?, contentStamp = NULL WHERE id = ? AND removedAt IS NULL",
                        arguments: [seenAt, row.id]
                    )
                    if row.isFolder {
                        let bounds = pathPrefixBounds(row.path)
                        let subtree = try visibleCountsInPathPrefix(bounds)
                        delta.files -= subtree.files
                        delta.folders -= subtree.folders
                        try mark.execute(arguments: [seenAt, mediumID, bounds.lower, bounds.upper])
                    }
                }
            }
            if changed {
                try touchLastSeen(db, ids: unchanged, seenAt: seenAt)
            }
            if let insertedAfter {
                try db.execute(
                    sql: "INSERT INTO item_fts(rowid, name) SELECT id, name FROM item WHERE id > ?",
                    arguments: [insertedAfter]
                )
            }
            if finalize {
                try saveStamp(stamp, parentID: parentID)
                if let parentID {
                    try db.execute(
                        sql: "UPDATE item SET listedAt = ? WHERE id = ?",
                        arguments: [seenAt, parentID]
                    )
                }
            }
            return (delta, parent.path)
        }

        private func visibleCountsInPathPrefix(_ bounds: (lower: String, upper: String)) throws -> (files: Int, folders: Int) {
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT
                        SUM(CASE WHEN isFolder = 0 THEN 1 ELSE 0 END),
                        SUM(CASE WHEN isFolder = 1 THEN 1 ELSE 0 END)
                    FROM item
                    WHERE mediumID = ? AND removedAt IS NULL AND path >= ? AND path < ?
                    """,
                arguments: [mediumID, bounds.lower, bounds.upper]
            )
            return (files: row?[0] as Int? ?? 0, folders: row?[1] as Int? ?? 0)
        }

        private func storedStamp(parentID: Int64?) throws -> String? {
            if let parentID {
                return try String.fetchOne(db, sql: "SELECT contentStamp FROM item WHERE id = ?", arguments: [parentID])
            }
            return try String.fetchOne(db, sql: "SELECT rootContentStamp FROM medium WHERE id = ?", arguments: [mediumID])
        }

        private func saveStamp(_ stamp: String, parentID: Int64?) throws {
            if let parentID {
                try db.execute(sql: "UPDATE item SET contentStamp = ? WHERE id = ?", arguments: [stamp, parentID])
            } else {
                try db.execute(sql: "UPDATE medium SET rootContentStamp = ? WHERE id = ?", arguments: [stamp, mediumID])
            }
        }

        private static func listingStamp(_ entries: [ScannedEntry]) -> String {
            var hashA: UInt64 = 14_695_981_039_346_656_037
            var hashB: UInt64 = 0x6c62272e07bb0142
            for entry in entries.sorted(by: { $0.name < $1.name }) {
                mix(&hashA, &hashB, entry.name)
                mix(&hashA, &hashB, entry.isFolder ? "d" : "f")
                mix(&hashA, &hashB, entry.isPackage ? "p" : "-")
                mix(&hashA, &hashB, String(entry.sizeBytes ?? -1))
                mix(&hashA, &hashB, String(entry.modifiedAt?.timeIntervalSinceReferenceDate ?? 0))
                mix(&hashA, &hashB, entry.fileID ?? "")
            }
            return String(hashA, radix: 16) + String(hashB, radix: 16)
        }

        private static func mix(_ hashA: inout UInt64, _ hashB: inout UInt64, _ text: String) {
            for byte in text.utf8 {
                hashA ^= UInt64(byte)
                hashA &*= 1_099_511_628_211
                hashB ^= UInt64(byte)
                hashB &*= 0x100000001b3
            }
            hashA &*= 1_099_511_628_211
            hashB &*= 0x100000001b3
        }
    }

    private struct ListedRow {
        var id: Int64
        var name: String
        var isFolder: Bool
        var isPackage: Bool
        var ext: String?
        var sizeBytes: Int64?
        var modifiedAt: Date?
        var fileID: String?
        var depth: Int
        var path: String
        var removedAt: Date?

        init(_ row: Row) {
            id = row[0]
            name = row[1]
            isFolder = row[2]
            isPackage = row[3]
            ext = row[4]
            sizeBytes = row[5]
            modifiedAt = row[6]
            fileID = row[7]
            depth = row[8]
            path = row[9]
            removedAt = row[10]
        }

        func matches(_ entry: ScannedEntry, ext: String?, path: String, depth: Int) -> Bool {
            removedAt == nil
                && isFolder == entry.isFolder
                && isPackage == entry.isPackage
                && self.ext == ext
                && sizeBytes == entry.sizeBytes
                && fileID == entry.fileID
                && self.depth == depth
                && self.path == path
                && sameInstant(modifiedAt, entry.modifiedAt)
        }
    }

    static func items(_ db: Database, sql: String, arguments: StatementArguments) throws -> [StoredItem] {
        let statement = try db.makeStatement(sql: sql)
        let names = statement.columnNames
        func index(_ name: String) throws -> Int {
            guard let found = names.firstIndex(of: name) else { throw IndexStoreError.invalidStoredUUID }
            return found
        }
        let idIndex = try index("id")
        let uuidIndex = try index("mediumUUID")
        let parentIndex = try index("parentID")
        let nameIndex = try index("name")
        let folderIndex = try index("isFolder")
        let packageIndex = try index("isPackage")
        let extIndex = try index("ext")
        let sizeIndex = try index("sizeBytes")
        let modifiedIndex = try index("modifiedAt")
        let fileIndex = try index("fileID")
        let depthIndex = try index("depth")
        let pathIndex = try index("path")
        let seenIndex = try index("lastSeenAt")
        let removedIndex = try index("removedAt")
        let favoriteIndex = try index("isFavorite")
        let listedIndex = names.firstIndex(of: "listedAt")
        let unreadableIndex = names.firstIndex(of: "unreadable")
        let cursor = try Row.fetchCursor(statement, arguments: arguments)
        var result: [StoredItem] = []
        while let row = try cursor.next() {
            let rawUUID: String = row[uuidIndex]
            guard let mediumUUID = UUID(uuidString: rawUUID) else { throw IndexStoreError.invalidStoredUUID }
            let parentID: Int64? = row[parentIndex]
            let ext: String? = row[extIndex]
            let sizeBytes: Int64? = row[sizeIndex]
            let modifiedAt: Date? = row[modifiedIndex]
            let fileID: String? = row[fileIndex]
            let lastSeenAt: Date = row[seenIndex]
            let removedAt: Date? = row[removedIndex]
            result.append(StoredItem(
                id: row[idIndex],
                mediumUUID: mediumUUID,
                parentID: parentID,
                name: row[nameIndex],
                isFolder: row[folderIndex],
                isPackage: row[packageIndex],
                ext: ext,
                sizeBytes: sizeBytes,
                modifiedAt: modifiedAt,
                fileID: fileID,
                depth: row[depthIndex],
                path: row[pathIndex],
                lastSeenAt: lastSeenAt,
                removedAt: removedAt,
                isFavorite: row[favoriteIndex],
                listedAt: listedIndex.flatMap { row[$0] as Date? },
                unreadable: unreadableIndex.map { row[$0] as Bool? ?? false } ?? false
            ))
        }
        return result
    }

    static func searchRequest(query: String, filters: SearchFilters, limit: Int?, maxDepth: Int? = nil, ordered: Bool = true) -> IndexSearchRequest {
        var sql = """
            SELECT item.*, medium.uuid AS mediumUUID
            FROM item JOIN medium ON medium.id = item.mediumID
            """
        var arguments: StatementArguments = []
        if query.count >= 3 {
            sql += " JOIN item_fts ON item_fts.rowid = item.id"
        }
        sql += " WHERE item.removedAt IS NULL"
        if query.count >= 3 {
            sql += " AND item_fts MATCH ?"
            arguments += [ftsQuery(query)]
        } else if !query.isEmpty {
            sql += " AND item.name LIKE ? ESCAPE '\\'"
            arguments += ["%" + escapeLike(query) + "%"]
        }
        if !filters.selectAllMedia {
            let ids = filters.mediumIDs.map(\.uuidString).sorted()
            if ids.isEmpty {
                sql += " AND 0"
            } else {
                sql += " AND medium.uuid IN (\(ids.map { _ in "?" }.joined(separator: ",")))"
                arguments += StatementArguments(ids)
            }
        }

        let type = fileTypeClause(filters)
        let age = ageClause(filters.age, now: Date())
        let hasType = filters.hasFileTypeFilter
        let hasAge = filters.age != nil
        if hasType, hasAge, let type, let age {
            if filters.effectiveCombineWithAnd(hasSearchTerm: !query.isEmpty) {
                sql += " AND \(type.sql) AND \(age.sql)"
            } else {
                sql += " AND (\(type.sql) OR \(age.sql))"
            }
            arguments += type.arguments
            arguments += age.arguments
        } else if hasType, let type {
            sql += " AND \(type.sql)"
            arguments += type.arguments
        } else if hasAge, let age {
            sql += " AND \(age.sql)"
            arguments += age.arguments
        }

        if let maxDepth {
            sql += " AND item.depth <= ?"
            arguments += [maxDepth]
        }

        if ordered {
            sql += " ORDER BY item.name COLLATE NOCASE, item.id"
        }
        if let limit {
            sql += " LIMIT ?"
            arguments += [limit]
        }
        return IndexSearchRequest(sql: sql, arguments: arguments)
    }

    private static func mediumArguments(_ medium: StoredMedium) -> StatementArguments {
        let arguments: StatementArguments = [
            medium.uuid.uuidString,
            VolumeIdentity.canonicalVolumeUUID(medium.volumeUUID),
            VolumeIdentity.canonicalCreatedAt(medium.volumeCreatedAt),
            medium.fsType,
            medium.volumeTotalBytes,
            medium.diskSizeBytes,
            medium.name,
            medium.type.rawValue,
            medium.decision.rawValue,
            medium.rememberDecision,
            medium.indexStatus.rawValue,
            medium.allowIndexing,
            medium.autoIndexPaused,
            medium.capacityUsedBytes,
            medium.fileCount,
            medium.folderCount,
            medium.lastSeenAt,
            medium.firstIndexedAt,
            medium.lastIndexedAt,
            medium.lastIndexActivityAt,
            medium.isForgotten,
            medium.showAbsoluteCapacity,
            medium.isFavorite,
            medium.fsEventsUUID,
            medium.lastEventID,
            medium.completedDepth,
            medium.createdAt,
        ]
        return arguments
    }

    static func commitMediumMeta(
        db: Database,
        mediumID: Int64,
        activityAt: Date,
        touchLastIndexedAt: Date? = nil,
        delta: MediumCountDelta = .zero,
        forceRecount: Bool = false
    ) throws {
        let fileCountExpr: String
        let folderCountExpr: String
        var arguments = StatementArguments()
        if forceRecount {
            fileCountExpr = """
                (SELECT COUNT(*) FROM item WHERE mediumID = ? AND isFolder = 0 AND removedAt IS NULL)
                """
            folderCountExpr = """
                (SELECT COUNT(*) FROM item WHERE mediumID = ? AND isFolder = 1 AND removedAt IS NULL)
                """
            arguments += [mediumID, mediumID]
        } else {
            fileCountExpr = "MAX(0, fileCount + ?)"
            folderCountExpr = "MAX(0, folderCount + ?)"
            arguments += [delta.files, delta.folders]
        }
        var setClauses = [
            "fileCount = \(fileCountExpr)",
            "folderCount = \(folderCountExpr)",
        ]
        if let touchLastIndexedAt {
            setClauses.append("lastIndexedAt = ?")
            arguments += [touchLastIndexedAt]
        }
        setClauses.append("lastIndexActivityAt = ?")
        arguments += [activityAt, mediumID]
        let sql = """
            UPDATE medium SET \(setClauses.joined(separator: ", "))
            WHERE id = ?
            """
        try db.execute(sql: sql, arguments: arguments)
        if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
    }

    private static func parentContext(_ db: Database, mediumID: Int64, parentID: Int64?) throws -> (path: String, depth: Int) {
        guard let parentID else { return ("/", 1) }
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT path, depth, mediumID FROM item WHERE id = ?",
            arguments: [parentID]
        ), row["mediumID"] as Int64 == mediumID else {
            throw IndexStoreError.unknownParent
        }
        let depth: Int = row["depth"]
        let path: String = row["path"]
        return (path, depth + 1)
    }

    private static func sameInstant(_ stored: Date?, _ seen: Date?) -> Bool {
        switch (stored, seen) {
        case (nil, nil):
            return true
        case let (stored?, seen?):
            return abs(stored.timeIntervalSince(seen)) < 0.0005
        default:
            return false
        }
    }

    private static func touchLastSeen(_ db: Database, ids: [Int64], seenAt: Date) throws {
        var offset = 0
        while offset < ids.count {
            let end = min(offset + 400, ids.count)
            let chunk = ids[offset..<end]
            var sql = "UPDATE item SET lastSeenAt = ? WHERE id IN ("
            sql += Array(repeating: "?", count: chunk.count).joined(separator: ",")
            sql += ")"
            var arguments: StatementArguments = [seenAt]
            for id in chunk {
                arguments += [id]
            }
            try db.execute(sql: sql, arguments: arguments)
            offset = end
        }
    }

    /// Untergrenze ist der Ordnerpfad, Obergrenze das nächste Präfix in Binärreihenfolge.
    static func pathPrefixBounds(_ path: String) -> (lower: String, upper: String) {
        var scalars = Array(path.unicodeScalars)
        guard let last = scalars.last, let next = UnicodeScalar(last.value + 1) else {
            return (path, path + "\u{0}")
        }
        scalars[scalars.count - 1] = next
        return (path, String(String.UnicodeScalarView(scalars)))
    }

    private static func fileExtension(_ name: String) -> String? {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    private static func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private static func ftsQuery(_ query: String) -> String {
        "\"" + query.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private struct Clause {
        var sql: String
        var arguments: StatementArguments
    }

    private static func fileTypeClause(_ filters: SearchFilters) -> Clause? {
        guard filters.hasFileTypeFilter else { return nil }
        var parts: [String] = []
        var arguments: StatementArguments = []
        if filters.fileTypes.contains(.folder) {
            parts.append("(item.isFolder = 1 AND item.isPackage = 0)")
        }
        if filters.fileTypes.contains(.programs) {
            parts.append("(item.isPackage = 1)")
        }
        var extensions = Set<String>()
        for type in filters.fileTypes where type != .folder && type != .programs {
            extensions.formUnion(type.databaseExtensions)
        }
        if !extensions.isEmpty {
            let sorted = extensions.sorted()
            parts.append("(item.isFolder = 0 AND item.isPackage = 0 AND item.ext IN (\(sorted.map { _ in "?" }.joined(separator: ","))))")
            arguments += StatementArguments(sorted)
        }
        for raw in filters.customExtensions {
            parts.append("(item.isFolder = 0 AND lower(item.name) LIKE ? ESCAPE '\\')")
            arguments += ["%" + escapeLike(raw.lowercased())]
        }
        guard !parts.isEmpty else { return nil }
        return Clause(sql: "(" + parts.joined(separator: " OR ") + ")", arguments: arguments)
    }

    private static func ageClause(_ age: SearchAgeFilter?, now: Date) -> Clause? {
        guard let age else { return nil }
        let calendar = Calendar.current
        func limit(_ component: Calendar.Component, _ value: Int) -> Date {
            calendar.date(byAdding: component, value: -value, to: now) ?? now
        }
        let boundary: Date
        let comparison: String
        switch age {
        case .last24Hours:
            boundary = limit(.hour, 24)
            comparison = ">="
        case .last2Days:
            boundary = limit(.day, 2)
            comparison = ">="
        case .lastWeek:
            boundary = limit(.day, 7)
            comparison = ">="
        case .lastMonth:
            boundary = limit(.month, 1)
            comparison = ">="
        case .last3Months:
            boundary = limit(.month, 3)
            comparison = ">="
        case .last6Months:
            boundary = limit(.month, 6)
            comparison = ">="
        case .last9Months:
            boundary = limit(.month, 9)
            comparison = ">="
        case .lastYear:
            boundary = limit(.year, 1)
            comparison = ">="
        case .older:
            boundary = limit(.year, 1)
            comparison = "<"
        }
        // Ohne Datum schließt der Filter nicht aus, analog zu SearchItemFilter.
        let arguments: StatementArguments = [boundary]
        return Clause(
            sql: "(item.modifiedAt IS NULL OR item.modifiedAt \(comparison) ?)",
            arguments: arguments
        )
    }
}

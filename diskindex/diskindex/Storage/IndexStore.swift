//
//  IndexStore.swift
//  diskindex
//
//  Actor und Kern-API. Abfragen/Suche/SQL in eigenen Dateien (Aufgabe 111).
//

import Foundation
import GRDB

struct IndexChangeEvent: Sendable {
    let change: IndexChange
    let generation: Int
}

enum IndexChange: Sendable, Equatable {
    case medium(UUID)
    /// `folderPaths`: Ordner, deren Kindliste sich geändert hat (leeres Array = Medienwurzel).
    case items(UUID, folderPaths: [[String]])
    case layer(medium: UUID, depth: Int)
    case counts(UUID)
    case removed(UUID)

    var mediumID: UUID {
        switch self {
        case .medium(let id), .items(let id, _), .counts(let id), .removed(let id):
            return id
        case .layer(let id, _):
            return id
        }
    }
}

/// Thread-sicherer Zähler für die Namensprüfung in Swift (Lesezugriffe laufen außerhalb des Actors).
nonisolated final class NameCheckCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var total = 0

    func add(_ count: Int) {
        guard count > 0 else { return }
        lock.lock()
        total += count
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return total
    }
}

actor IndexStore {
    func checkpoint() {
        try? pool.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    /// Für Erweiterungen in `IndexStore+*.swift` (Aufgabe 111).
    let pool: DatabasePool
    private var indexingToken: [UUID: UUID] = [:]
    private var revokedIndexingTokens: Set<UUID> = []
    private var pendingMetaDelta: [UUID: MediumCountDelta] = [:]
    private var lastMetaCommitTime: [UUID: Date] = [:]
    /// Tests: das nächste `applyDirectories` schlägt fehl, ohne die Ebene abzuschließen.
    var directoryWritesFail = false
    /// Tests: Leseabfragen für Kinder werfen (Aufgabe 109).
    var childrenReadsFail = false
    var searchCountDelay: Duration?
    /// Zählt Zeilen, deren Name in Swift gegen `IndexScope` geprüft wurde (Tests: ohne ausstehende Bereinigung 0).
    nonisolated let nameChecks = NameCheckCounter()
    private let changesContinuation: AsyncStream<IndexChangeEvent>.Continuation
    let changes: AsyncStream<IndexChangeEvent>
    private(set) var changeGeneration = 0

    #if DEBUG
    nonisolated(unsafe) static var recordEventCursorCallCount = 0

    /// Tests schalten den nächsten Schreibfehler ein, ohne die Ebene abzuschließen.
    func setDirectoryWritesFailing(_ failing: Bool) {
        directoryWritesFail = failing
    }

    /// Tests: `searchCount` braucht künstlich länger (Ergebnisse erscheinen vor der Zahl, 215).
    func setSearchCountDelay(_ delay: Duration?) {
        searchCountDelay = delay
    }

    /// Tests: `children`/`childrenPage`/`childCount` werfen einen Speicherfehler.
    func setChildrenReadsFailing(_ failing: Bool) {
        childrenReadsFail = failing
    }
    #endif

    nonisolated let database: IndexDatabase

    init(database: IndexDatabase) {
        self.database = database
        pool = database.pool
        let pair = AsyncStream.makeStream(of: IndexChangeEvent.self, bufferingPolicy: .unbounded)
        changes = pair.stream
        changesContinuation = pair.continuation
    }

    func emit(_ change: IndexChange) {
        changeGeneration += 1
        changesContinuation.yield(IndexChangeEvent(change: change, generation: changeGeneration))
    }

    static func openDefault() throws -> IndexStore {
        try IndexStore(database: IndexDatabase.openDefault())
    }

    // MARK: Medien

    func upsertMedium(_ medium: StoredMedium) async throws {
        try await pool.write { db in
            try IndexSQL.upsertMedium(db, medium)
        }
        emit(.medium(medium.uuid))
    }

    func media() async throws -> [StoredMedium] {
        try await pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM medium ORDER BY name COLLATE NOCASE, uuid").map(IndexSQL.medium)
        }
    }

    func medium(uuid: UUID) async throws -> StoredMedium? {
        try await pool.read { db in
            try IndexSQL.fetchMedium(db, uuid: uuid)
        }
    }

    func updateMedium(uuid: UUID, _ medium: StoredMedium) async throws {
        do {
            try await pool.write { db in
                guard try IndexSQL.fetchMedium(db, uuid: uuid) != nil else { throw IndexStoreError.unknownMedium }
                var replacement = medium
                replacement.uuid = uuid
                try IndexSQL.updateMedium(db, replacement, keepCreatedAt: true)
            }
            DiskIndexLog.shared.record(.store, .info, "updateMedium count=1")
            emit(.medium(uuid))
        } catch {
            DiskIndexLog.shared.record(.store, .error, "updateMedium \(error)")
            throw error
        }
    }

    /// Vereinigung aller Treffer, stärkste Übereinstimmung zuerst.
    func candidates(for identity: VolumeIdentity) async throws -> [MediumCandidate] {
        try await pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM medium").map(IndexSQL.medium)
                .compactMap { stored in
                    IndexSQL.match(stored: stored, identity: identity).map {
                        MediumCandidate(medium: stored, strength: $0)
                    }
                }
                .sorted { lhs, rhs in
                    if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
                    if lhs.medium.name != rhs.medium.name { return lhs.medium.name < rhs.medium.name }
                    return lhs.medium.uuid.uuidString < rhs.medium.uuid.uuidString
                }
        }
    }

    /// Ergänzt UUID und Erstelldatum nur, wo sie noch fehlen.
    func recordIdentity(mediumUUID: UUID, _ identity: VolumeIdentity) async throws {
        try await pool.write { db in
            guard try IndexSQL.fetchMedium(db, uuid: mediumUUID) != nil else { throw IndexStoreError.unknownMedium }
            try db.execute(
                sql: """
                    UPDATE medium SET
                        volumeUUID = CASE WHEN volumeUUID IS NULL OR volumeUUID = '' THEN ? ELSE volumeUUID END,
                        volumeCreatedAt = CASE WHEN volumeCreatedAt IS NULL THEN ? ELSE volumeCreatedAt END
                    WHERE uuid = ?
                    """,
                arguments: [identity.volumeUUID, identity.createdAt, mediumUUID.uuidString]
            )
        }
    }

    /// Löscht endgültig, was nicht mehr zur Sicht passt. Jeder Aufruf macht da weiter, wo der vorige aufgehört hat.
    func pruneToMatch(_ scope: IndexScope, batchSize: Int = 5_000, maxBatches: Int? = nil) async throws -> Int {
        let started = ContinuousClock.now
        var removed = 0
        var cursor: Int64 = 0
        var batches = 0
        while true {
            if let maxBatches, batches >= maxBatches { break }
            let afterID = cursor
            let step: (deleted: Int, cursor: Int64, done: Bool) = try await pool.write { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT id, parentID, name, isFolder, path, depth
                        FROM item
                        WHERE removedAt IS NULL AND id > ?
                        ORDER BY id
                        LIMIT ?
                        """,
                    arguments: [afterID, batchSize]
                )
                guard let last = rows.last else { return (0, afterID, true) }
                let lastID: Int64 = last["id"]
                var deleted = 0
                var fileIDs: [Int64] = []
                var parents = Set<Int64>()
                for row in rows {
                    let name: String = row["name"]
                    let depth: Int = row["depth"]
                    guard scope.hides(name: name, depth: depth) else { continue }
                    let id: Int64 = row["id"]
                    let isFolder: Bool = row["isFolder"]
                    if isFolder {
                        let path: String = row["path"]
                        let bounds = IndexSQL.pathPrefixBounds(path)
                        try db.execute(
                            sql: "DELETE FROM item WHERE path >= ? AND path < ?",
                            arguments: [bounds.lower, bounds.upper]
                        )
                        deleted += db.changesCount
                        if let parent: Int64 = row["parentID"] { parents.insert(parent) }
                    } else {
                        fileIDs.append(id)
                        if let parent: Int64 = row["parentID"] { parents.insert(parent) }
                    }
                }
                if !fileIDs.isEmpty {
                    let marks = fileIDs.map { _ in "?" }.joined(separator: ",")
                    try db.execute(
                        sql: "DELETE FROM item WHERE id IN (\(marks))",
                        arguments: StatementArguments(fileIDs)
                    )
                    deleted += db.changesCount
                }
                if !parents.isEmpty {
                    let marks = parents.map { _ in "?" }.joined(separator: ",")
                    try db.execute(
                        sql: "UPDATE item SET contentStamp = NULL WHERE id IN (\(marks))",
                        arguments: StatementArguments(Array(parents))
                    )
                }
                return (deleted, lastID, false)
            }
            batches += 1
            removed += step.deleted
            if step.done { break }
            cursor = step.cursor
        }
        if let maxDepth = scope.maxDepth {
            try await pool.write { db in
                try db.execute(
                    sql: "UPDATE item SET contentStamp = NULL WHERE isFolder = 1 AND depth = ? AND removedAt IS NULL",
                    arguments: [maxDepth]
                )
                try db.execute(
                    sql: "UPDATE medium SET completedDepth = MIN(completedDepth, ?)",
                    arguments: [maxDepth]
                )
            }
        }
        if removed > 0 {
            let activityAt = Date()
            let touched: [UUID] = try await pool.write { db in
                let rows = try String.fetchAll(db, sql: "SELECT uuid FROM medium")
                var uuids: [UUID] = []
                for uuid in rows {
                    guard let parsed = UUID(uuidString: uuid),
                          let mediumID = try IndexSQL.mediumRowID(db, uuid: parsed) else { continue }
                    try IndexSQL.commitMediumMeta(
                        db: db,
                        mediumID: mediumID,
                        activityAt: activityAt,
                        forceRecount: true
                    )
                    uuids.append(parsed)
                }
                return uuids
            }
            for uuid in touched {
                emit(.counts(uuid))
            }
        }
        try? await pool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA incremental_vacuum")
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        let ms = Int(started.duration(to: .now) / Duration.milliseconds(1))
        DiskIndexLog.shared.record(.index, .info, "index prune removed=\(removed) ms=\(ms)")
        return removed
    }

    func contentStamp(mediumUUID: UUID, path: [String]) async throws -> String? {
        guard let id = try await folderID(mediumUUID: mediumUUID, path: path) else { return nil }
        return try await pool.read { db in
            try String.fetchOne(db, sql: "SELECT contentStamp FROM item WHERE id = ?", arguments: [id])
        }
    }

    #if DEBUG
    func orphanCount() async throws -> Int {
        try await pool.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM item AS child
                    LEFT JOIN item AS parent ON parent.id = child.parentID
                    WHERE child.parentID IS NOT NULL AND parent.id IS NULL AND child.removedAt IS NULL
                    """
            ) ?? 0
        }
    }

    func databaseFileBytes() -> Int {
        let path = pool.path
        let main = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        let wal = (try? FileManager.default.attributesOfItem(atPath: path + "-wal")[.size] as? NSNumber)?.intValue ?? 0
        return main + wal
    }

    func storedNames() async throws -> [String] {
        try await pool.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM item WHERE removedAt IS NULL ORDER BY id")
        }
    }
    #endif

    func forgetMedium(uuid: UUID) async throws {
        try await pool.write { db in
            try db.execute(sql: "UPDATE medium SET isForgotten = 1 WHERE uuid = ?", arguments: [uuid.uuidString])
            if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
        }
    }

    /// Einziger harter Löschweg. Einträge fallen über `ON DELETE CASCADE` mit.
    /// Bereits gelöscht → kein Fehler (idempotent, Aufgabe 141).
    func deleteMedium(uuid: UUID) async throws {
        do {
            let deleted = try await pool.write { db -> Bool in
                try db.execute(sql: "DELETE FROM medium WHERE uuid = ?", arguments: [uuid.uuidString])
                return db.changesCount > 0
            }
            guard deleted else { return }
            DiskIndexLog.shared.record(.store, .info, "deleteMedium count=1")
            emit(.removed(uuid))
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "deleteMedium \(error)")
            }
            throw error
        }
    }

    // MARK: Ebenen

    func applyDirectory(
        mediumUUID: UUID,
        parentID: Int64?,
        entries: [ScannedEntry],
        seenAt: Date
    ) async throws {
        let folderPathForCache: [String] = try await pool.write { db -> [String] in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else {
                throw IndexStoreError.unknownMedium
            }
            let delta = try IndexSQL.applyDirectory(
                db,
                mediumUUID: mediumUUID,
                parentID: parentID,
                entries: entries,
                seenAt: seenAt
            )
            try IndexSQL.commitMediumMeta(db: db, mediumID: mediumID, activityAt: seenAt, delta: delta)
            guard let parentID else { return [] }
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT path FROM item WHERE id = ? AND mediumID = ?",
                arguments: [parentID, mediumID]
            ) else { return [] }
            let path: String = row["path"]
            return IgnoreMatcher.storedPathSegments(path)
        }
        emit(.items(mediumUUID, folderPaths: [folderPathForCache]))
        emit(.counts(mediumUUID))
    }

    func completeLayer(mediumUUID: UUID, depth: Int) async throws {
        let indexedAt = Date()
        try await pool.write { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else {
                throw IndexStoreError.unknownMedium
            }
            try db.execute(
                sql: "UPDATE medium SET completedDepth = MAX(completedDepth, ?) WHERE id = ?",
                arguments: [depth, mediumID]
            )
            try IndexSQL.commitMediumMeta(
                db: db,
                mediumID: mediumID,
                activityAt: indexedAt,
                touchLastIndexedAt: indexedAt,
                forceRecount: true
            )
        }
        emit(.layer(medium: mediumUUID, depth: depth))
        emit(.counts(mediumUUID))
    }

    func folders(
        mediumUUID: UUID,
        depth: Int,
        limit: Int = 5_000,
        offset: Int = 0
    ) async throws -> [(id: Int64, path: String)] {
        try await pool.read { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, path FROM item
                    WHERE mediumID = ? AND depth = ? AND isFolder = 1 AND removedAt IS NULL
                    ORDER BY path
                    LIMIT ? OFFSET ?
                    """,
                arguments: [mediumID, depth, limit, offset]
            )
            return rows.map { (id: $0["id"], path: $0["path"]) }
        }
    }

    func setScanTotal(mediumUUID: UUID, total: Int) async throws {
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE medium SET scanTotal = ? WHERE uuid = ?",
                arguments: [total, mediumUUID.uuidString]
            )
        }
        emit(.medium(mediumUUID))
    }

    func markFolderUnreadable(mediumUUID: UUID, folderID: Int64) async throws {
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE item SET unreadable = 1 WHERE id = ?",
                arguments: [folderID]
            )
        }
        let folderPath = await folderPathSegments(parentRowID: folderID)
        emit(.items(mediumUUID, folderPaths: [folderPath]))
    }

    func flushMediumMeta(mediumUUID: UUID, force: Bool = true) async throws {
        try await commitPendingMetaIfNeeded(mediumUUID: mediumUUID, seenAt: Date(), delta: .zero, force: force)
        emit(.counts(mediumUUID))
    }

    func applyDirectories(
        mediumUUID: UUID,
        batches: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)],
        seenAt: Date
    ) async throws {
        do {
            if directoryWritesFail { throw IndexStoreError.directoryWriteFailed }
            let forceMeta = batches.contains { $0.finalize }
            let result = try await pool.write { db -> (delta: MediumCountDelta, parentPaths: [String]) in
                guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else {
                    throw IndexStoreError.unknownMedium
                }
                let writer = try IndexSQL.DirectoryWriter(db: db, mediumID: mediumID)
                var delta = MediumCountDelta.zero
                var parentPaths: [String] = []
                for batch in batches {
                    let step = try writer.apply(
                        parentID: batch.parentID,
                        path: batch.path,
                        depth: batch.depth,
                        entries: batch.entries,
                        seenAt: seenAt,
                        finalize: batch.finalize
                    )
                    delta = delta + step.delta
                    parentPaths.append(step.parentPath)
                }
                return (delta, parentPaths)
            }
            let parentPaths = result.parentPaths
            let delta = result.delta
            try await commitPendingMetaIfNeeded(mediumUUID: mediumUUID, seenAt: seenAt, delta: delta, force: forceMeta)
            DiskIndexLog.shared.record(.store, .info, "applyDirectories count=\(batches.count)")
            var seenPaths = Set<String>()
            var uniquePaths: [[String]] = []
            for parentPath in parentPaths {
                let segments = IgnoreMatcher.storedPathSegments(parentPath)
                let key = segments.joined(separator: "\u{0}")
                if seenPaths.insert(key).inserted {
                    uniquePaths.append(segments)
                }
            }
            emit(.items(mediumUUID, folderPaths: uniquePaths))
            emit(.counts(mediumUUID))
        } catch {
            DiskIndexLog.shared.record(.store, .error, "applyDirectories \(error)")
            throw error
        }
    }

    private func commitPendingMetaIfNeeded(
        mediumUUID: UUID,
        seenAt: Date,
        delta: MediumCountDelta,
        force: Bool
    ) async throws {
        pendingMetaDelta[mediumUUID, default: .zero] = pendingMetaDelta[mediumUUID, default: .zero] + delta
        let last = lastMetaCommitTime[mediumUUID] ?? .distantPast
        guard force || seenAt.timeIntervalSince(last) >= 0.35 else { return }
        let toCommit = pendingMetaDelta[mediumUUID, default: .zero]
        guard toCommit != .zero || force else { return }
        try await pool.write { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else { return }
            try IndexSQL.commitMediumMeta(db: db, mediumID: mediumID, activityAt: seenAt, delta: toCommit)
        }
        pendingMetaDelta[mediumUUID] = .zero
        lastMetaCommitTime[mediumUUID] = seenAt
    }

    func counts(mediumUUID: UUID, scope: IndexScope? = nil) async throws -> (files: Int, folders: Int) {
        let counter = nameChecks
        return try await pool.read { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else {
                return (files: 0, folders: 0)
            }
            if let scope, scope.checksNames {
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT name, isFolder, depth FROM item WHERE mediumID = ? AND removedAt IS NULL",
                    arguments: [mediumID]
                )
                counter.add(rows.count)
                var files = 0
                var folders = 0
                for row in rows {
                    let name: String = row["name"]
                    let depth: Int = row["depth"]
                    if scope.hides(name: name, depth: depth) { continue }
                    if row["isFolder"] as Bool { folders += 1 } else { files += 1 }
                }
                return (files: files, folders: folders)
            }
            // Reines SQL; die Tiefe des Bereichs gilt weiterhin.
            let depthClause = scope?.maxDepth.map { " AND depth <= \($0)" } ?? ""
            let files = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM item WHERE mediumID = ? AND isFolder = 0 AND removedAt IS NULL" + depthClause,
                arguments: [mediumID]
            ) ?? 0
            let folders = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM item WHERE mediumID = ? AND isFolder = 1 AND removedAt IS NULL" + depthClause,
                arguments: [mediumID]
            ) ?? 0
            return (files: files, folders: folders)
        }
    }

    func resetCompletedDepth(mediumUUID: UUID) async throws {
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE medium SET completedDepth = 0 WHERE uuid = ?",
                arguments: [mediumUUID.uuidString]
            )
            if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
        }
    }

    /// Start eines Laufs. `false`, wenn `finishIndexing` diesen Token schon verworfen hat.
    func beginIndexing(mediumUUID: UUID, token: UUID) async throws -> Bool {
        if revokedIndexingTokens.remove(token) != nil { return false }
        indexingToken[mediumUUID] = token
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE medium SET indexStatus = ? WHERE uuid = ?",
                arguments: [StoredIndexStatus.indexing.rawValue, mediumUUID.uuidString]
            )
            if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
        }
        guard indexingToken[mediumUUID] == token else {
            try await pool.write { db in
                try db.execute(
                    sql: "UPDATE medium SET indexStatus = ? WHERE uuid = ? AND indexStatus = ?",
                    arguments: [StoredIndexStatus.pending.rawValue, mediumUUID.uuidString, StoredIndexStatus.indexing.rawValue]
                )
            }
            return false
        }
        return true
    }

    /// Beendet den Lauf nur, wenn `token` noch der aktive ist. Sonst ist der Token verfallen.
    func finishIndexing(
        mediumUUID: UUID,
        token: UUID,
        status: StoredIndexStatus,
        firstIndexedAt: Date?
    ) async throws -> Bool {
        guard indexingToken[mediumUUID] == token else {
            revokedIndexingTokens.insert(token)
            return false
        }
        indexingToken[mediumUUID] = nil
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE medium SET indexStatus = ? WHERE uuid = ?",
                arguments: [status.rawValue, mediumUUID.uuidString]
            )
            if status == .indexed, let firstIndexedAt {
                try db.execute(
                    sql: "UPDATE medium SET firstIndexedAt = ? WHERE uuid = ? AND firstIndexedAt IS NULL",
                    arguments: [firstIndexedAt, mediumUUID.uuidString]
                )
            }
            if status == .indexed {
                try db.execute(
                    sql: """
                        UPDATE medium SET scanTotal = fileCount + folderCount
                        WHERE uuid = ?
                        """,
                    arguments: [mediumUUID.uuidString]
                )
            }
        }
        emit(.medium(mediumUUID))
        return true
    }

    func indexingIsActive(mediumUUID: UUID, token: UUID) -> Bool {
        indexingToken[mediumUUID] == token
    }

    /// Pfadsegmente des Ordners (Kindliste), dessen `parentID` in `applyDirectory` übergeben wird.
    private func folderPathSegments(parentRowID: Int64?) async -> [String] {
        guard let parentRowID else { return [] }
        let storedPath: String? = try? await pool.read { db in
            try String.fetchOne(db, sql: "SELECT path FROM item WHERE id = ?", arguments: [parentRowID])
        }
        return IgnoreMatcher.storedPathSegments(storedPath)
    }

    func folderID(mediumUUID: UUID, path: [String]) async throws -> Int64? {
        if path.isEmpty { return nil }
        let storedPath = "/" + path.joined(separator: "/") + "/"
        return try await pool.read { db in
            guard let mediumID = try IndexSQL.mediumRowID(db, uuid: mediumUUID) else { return nil }
            return try Int64.fetchOne(
                db,
                sql: """
                    SELECT id FROM item
                    WHERE mediumID = ? AND path = ? AND isFolder = 1 AND removedAt IS NULL
                    """,
                arguments: [mediumID, storedPath]
            )
        }
    }

    func recordEventCursor(mediumUUID: UUID, fsEventsUUID: String?, lastEventID: Int64) async throws {
        #if DEBUG
        Self.recordEventCursorCallCount += 1
        #endif
        try await pool.write { db in
            try db.execute(
                sql: "UPDATE medium SET fsEventsUUID = ?, lastEventID = ? WHERE uuid = ?",
                arguments: [fsEventsUUID, lastEventID, mediumUUID.uuidString]
            )
            if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
        }
    }

}

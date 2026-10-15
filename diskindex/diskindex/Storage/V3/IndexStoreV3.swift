//
//  IndexStoreV3.swift
//  diskindex
//
//  Speicherschicht der App auf dem Schema V3 (`SchemaV3`, Datei `archive.sqlite`). Schreibwege (231), Lesewege in
//  `IndexStoreV3+Reading` (232); seit Aufgabe 233 die einzige Schicht.
//

import Foundation
import GRDB

actor IndexStoreV3 {
    nonisolated let pool: DatabasePool
    private var indexingToken: [UUID: UUID] = [:]
    private var revokedIndexingTokens: Set<UUID> = []
    private var insertedIDsDuringRun: [UUID: Set<Int64>] = [:]
    private var pendingMetaDelta: [UUID: MediumCountDelta] = [:]
    private var lastMetaCommitTime: [UUID: Date] = [:]
    private let changesContinuation: AsyncStream<IndexChangeEvent>.Continuation
    nonisolated let changes: AsyncStream<IndexChangeEvent>
    private(set) var changeGeneration = 0
    /// Tests: das nächste Schreiben einer Ebene schlägt fehl.
    var directoryWritesFail = false
    /// Tests: Leseabfragen für Kinder werfen (Aufgabe 109).
    var childrenReadsFail = false
    /// Tests: `searchCount` braucht künstlich länger (Ergebnisse erscheinen vor der Zahl, 215).
    var searchCountDelay: Duration?
    /// Tests: `search` braucht künstlich länger (Abbruch / Generationswechsel, 007).
    var searchQueryDelay: Duration?
    /// Tests: `deleteMedium` schlägt für diese UUIDs fehl (forgetAll, 007).
    var deleteMediumFailUUIDs: Set<UUID> = []
    /// Tests: Teil-Prüfsummen-Abgleich (235b); kein globales Flag (bug.0.4.010).
    var partialMatchingEnabled = true

    func setPartialMatchingEnabled(_ enabled: Bool) {
        partialMatchingEnabled = enabled
    }
    /// Zählt Zeilen, deren Name in Swift gegen `IndexScope` geprüft wurde (Tests: ohne ausstehende Bereinigung 0).
    nonisolated let nameChecks = NameCheckCounter()
    /// Zahl der Bereiche der parallelen Suche; `nil` = Kerne − 1 (mindestens 2), 1 = eine einzelne Abfrage.
    var searchParallelism: Int?

    init(pool: DatabasePool) {
        self.pool = pool
        let pair = AsyncStream.makeStream(of: IndexChangeEvent.self, bufferingPolicy: .unbounded)
        changes = pair.stream
        changesContinuation = pair.continuation
    }

    static func open(at fileURL: URL) throws -> IndexStoreV3 {
        IndexStoreV3(pool: try SchemaV3.openPool(at: fileURL))
    }

    /// `Application Support/Disk Archive/archive.sqlite`. Die alte `index.sqlite` wird nie geöffnet.
    static func storeFileURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return base
            .appendingPathComponent("Disk Archive", isDirectory: true)
            .appendingPathComponent("archive.sqlite", isDirectory: false)
    }

    static func openDefault() throws -> IndexStoreV3 {
        try open(at: storeFileURL())
    }

    /// Zahl der Medien und der sichtbaren Einträge für Protokoll und Fehlerbericht. „nicht lesbar“ bei fehlender Datei.
    static func inventoryLabels() -> (media: String, objects: String) {
        do {
            let url = try storeFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return ("nicht lesbar", "nicht lesbar") }
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: url.path, configuration: configuration)
            let counts = try queue.read { db -> (Int, Int) in
                (
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM storages") ?? 0,
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE status = 0") ?? 0
                )
            }
            return (String(counts.0), String(counts.1))
        } catch {
            return ("nicht lesbar", "nicht lesbar")
        }
    }

    /// `PRAGMA quick_check` über die ganze Datei (läuft im Hintergrund nach dem Start, `IntegrityCheckPolicy`).
    /// Bei Schaden: Datei wegsperren und `DatabaseCareError.unhealthy` werfen.
    nonisolated func runIntegrityCheck() throws {
        let result = try pool.read { db in try String.fetchOne(db, sql: "PRAGMA quick_check") }
        guard DatabaseCare.isHealthy(result) else {
            let url = URL(fileURLWithPath: pool.path)
            try pool.close()
            try DatabaseCare.quarantine(url)
            throw DatabaseCareError.unhealthy
        }
    }

    func emit(_ change: IndexChange) {
        changeGeneration += 1
        changesContinuation.yield(IndexChangeEvent(change: change, generation: changeGeneration))
    }

    func setSearchParallelism(_ parts: Int?) {
        searchParallelism = parts
    }

    #if DEBUG
    func setDirectoryWritesFailing(_ failing: Bool) {
        directoryWritesFail = failing
    }

    /// Tests: `children`/`childrenPage`/`childCount` werfen einen Speicherfehler.
    func setChildrenReadsFailing(_ failing: Bool) {
        childrenReadsFail = failing
    }

    /// Tests: `searchCount` braucht künstlich länger.
    func setSearchCountDelay(_ delay: Duration?) {
        searchCountDelay = delay
    }

    /// Tests: `search` braucht künstlich länger.
    func setSearchQueryDelay(_ delay: Duration?) {
        searchQueryDelay = delay
    }

    /// Tests: `deleteMedium` für UUIDs fehlschlagen lassen.
    func setDeleteMediumFailUUIDs(_ uuids: Set<UUID>) {
        deleteMediumFailUUIDs = uuids
    }

    /// Tests: `reconcileScopeToStatus` künstlich verlangsamen (234).
    var reconcileBatchDelay: Duration?

    func setReconcileBatchDelay(_ delay: Duration?) {
        reconcileBatchDelay = delay
    }

    /// Tests: Reconcile wirft einmal fehl.
    var reconcileShouldFail = false

    func setReconcileShouldFail(_ fail: Bool) {
        reconcileShouldFail = fail
    }

    nonisolated(unsafe) static var recordEventCursorCallCount = 0
    #endif

    nonisolated func checkpoint() {
        try? pool.writeWithoutTransaction { db in
            try DatabaseMaintenance.truncateWriteAheadLog(db)
        }
    }

    // MARK: App-Einstellungen (237)

    func loadPersistedAppSettings() async -> PersistedAppSettings? {
        try? await pool.read { db in try SettingsPersistence.readAppSettings(db) }
    }

    func savePersistedAppSettings(_ settings: PersistedAppSettings) async throws {
        try await pool.write { db in
            try SettingsPersistence.writeAppSettings(db, settings)
        }
    }

    // MARK: Wartung (236)

    func maintenanceDebt() async -> Int {
        (try? await pool.read { db in
            try DatabaseMaintenance.readDebt(db)
        }) ?? 0
    }

    func hasAnyActiveIndexingToken() -> Bool {
        !indexingToken.isEmpty
    }

    func runCompactionIfNeeded(minDebt: Int = MaintenancePolicy.changeThreshold) async {
        let debt = await maintenanceDebt()
        guard debt >= minDebt else { return }
        let started = ContinuousClock.now
        do {
            let freelistBefore = try await pool.writeWithoutTransaction { db -> Int in
                let before = try DatabaseMaintenance.freelistCount(db)
                try DatabaseMaintenance.runIncrementalVacuum(db)
                try DatabaseMaintenance.truncateWriteAheadLog(db)
                return before
            }
            try await pool.write { db in
                try DatabaseMaintenance.setDebt(db, 0)
                try DatabaseMaintenance.setLastCompaction(db, atSeconds: SchemaTime.seconds(Date()))
            }
            let ms = Int(started.duration(to: .now) / Duration.milliseconds(1))
            let freelistAfter = (try? await pool.read { db in try DatabaseMaintenance.freelistCount(db) }) ?? freelistBefore
            DiskIndexLog.shared.record(
                .index,
                .info,
                "index maintenance debt=\(debt) freelist=\(freelistBefore)->\(freelistAfter) ms=\(ms)"
            )
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "index maintenance \(error)")
            }
        }
    }

    // MARK: Medien

    func upsertMedium(_ medium: StoredMedium) async throws {
        try await pool.write { db in
            if let id = try MediumCodecV3.storageRowID(db, uuid: medium.uuid) {
                try MediumCodecV3.update(db, storageID: id, medium)
            } else {
                _ = try MediumCodecV3.insert(db, medium)
            }
        }
        emit(.medium(medium.uuid))
    }

    func media() async throws -> [StoredMedium] {
        try await pool.read { db in try MediumCodecV3.fetchAll(db) }
    }

    func medium(uuid: UUID) async throws -> StoredMedium? {
        try await pool.read { db in try MediumCodecV3.fetch(db, uuid: uuid) }
    }

    func updateMedium(uuid: UUID, _ medium: StoredMedium) async throws {
        do {
            try await pool.write { db in
                guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
                var replacement = medium
                replacement.uuid = uuid
                try MediumCodecV3.update(db, storageID: id, replacement)
            }
            DiskIndexLog.shared.record(.store, .info, "updateMedium count=1")
            emit(.medium(uuid))
        } catch {
            DiskIndexLog.shared.record(.store, .error, "updateMedium \(error)")
            throw error
        }
    }

    /// Vereinigung aller Treffer, stärkste Übereinstimmung zuerst (gleiche Regeln wie `IndexStoreV3`).
    func candidates(for identity: VolumeIdentity) async throws -> [MediumCandidate] {
        try await pool.read { db in
            try MediumCodecV3.fetchAll(db)
                .compactMap { stored in
                    MediumCodecV3.match(stored: stored, identity: identity).map {
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
            guard let stored = try MediumCodecV3.fetch(db, uuid: mediumUUID),
                  let id = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            let volume = stored.volumeUUID ?? identity.volumeUUID
            let created = stored.volumeCreatedAt ?? identity.createdAt
            try db.execute(
                sql: "UPDATE storages SET volumeUUID = ?, fingerprint = ? WHERE id = ?",
                arguments: [
                    MediumCodecV3.volumeData(volume),
                    MediumCodecV3.fingerprint(fsType: stored.fsType, createdAt: created, totalBytes: stored.volumeTotalBytes),
                    id,
                ]
            )
            try MediumCodecV3.setMeta(db, id, .volumeCreatedAt, date: created.map(SchemaTime.seconds))
        }
    }

    func forgetMedium(uuid: UUID) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.setMeta(db, id, .isForgotten, value: "1")
        }
    }

    /// Einziger harter Löschweg. Alles Zugehörige fällt über `ON DELETE CASCADE` mit. Bereits gelöscht → kein Fehler.
    func deleteMedium(uuid: UUID) async throws {
        if deleteMediumFailUUIDs.contains(uuid) {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            let deleted = try await pool.write { db -> Bool in
                try db.execute(sql: "DELETE FROM storages WHERE uuid = ?", arguments: [MediumCodecV3.data(uuid)])
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
        seenAt: Date,
        mountPath: String? = nil
    ) async throws {
        let partialMatching = partialMatchingEnabled
        let folderPath: [String] = try await pool.write { db -> [String] in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
            let step = try writer.apply(
                parentID: parentID, path: nil, depth: nil, entries: entries, seenAt: seenAt, finalize: true,
                mountPath: mountPath
            )
            try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: seenAt, delta: step.delta)
            guard let parentID else { return [] }
            return try DirectoryWriterV3.segments(db, itemID: parentID)
        }
        emit(.items(mediumUUID, folderPaths: [folderPath]))
        emit(.counts(mediumUUID))
    }

    func applyDirectories(
        mediumUUID: UUID,
        batches: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)],
        seenAt: Date,
        mountPath: String? = nil
    ) async throws {
        do {
            if directoryWritesFail { throw IndexStoreError.directoryWriteFailed }
            let forceMeta = batches.contains { $0.finalize }
            let partialMatching = partialMatchingEnabled
            let trackInserts = indexingToken[mediumUUID] != nil
            let result = try await pool.write { db -> (delta: MediumCountDelta, parentPaths: [String], inserted: [Int64]) in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
                let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
                var delta = MediumCountDelta.zero
                var parentPaths: [String] = []
                var inserted: [Int64] = []
                if trackInserts {
                    writer.onInsertedItemID = { inserted.append($0) }
                }
                for batch in batches {
                    let step = try writer.apply(
                        parentID: batch.parentID, path: batch.path, depth: batch.depth,
                        entries: batch.entries, seenAt: seenAt, finalize: batch.finalize,
                        mountPath: mountPath
                    )
                    delta = delta + step.delta
                    parentPaths.append(step.parentPath)
                }
                return (delta, parentPaths, inserted)
            }
            if trackInserts, !result.inserted.isEmpty {
                insertedIDsDuringRun[mediumUUID, default: []].formUnion(result.inserted)
            }
            try await commitPendingMetaIfNeeded(mediumUUID: mediumUUID, seenAt: seenAt, delta: result.delta, force: forceMeta)
            DiskIndexLog.shared.record(.store, .info, "applyDirectories count=\(batches.count)")
            var seenPaths = Set<String>()
            var uniquePaths: [[String]] = []
            for parentPath in result.parentPaths {
                let segments = IgnoreMatcher.storedPathSegments(parentPath)
                let key = segments.joined(separator: "\u{0}")
                if seenPaths.insert(key).inserted { uniquePaths.append(segments) }
            }
            emit(.items(mediumUUID, folderPaths: uniquePaths))
            emit(.counts(mediumUUID))
        } catch {
            DiskIndexLog.shared.record(.store, .error, "applyDirectories \(error)")
            throw error
        }
    }

    func completeLayer(mediumUUID: UUID, depth: Int) async throws {
        let indexedAt = Date()
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            let current = try MediumCodecV3.metaValue(db, storageID, .completedDepth).flatMap(Int.init) ?? 0
            try MediumCodecV3.setMeta(db, storageID, .completedDepth, value: String(max(current, depth)))
            try Self.commitMediumMeta(
                db: db, storageID: storageID, activityAt: indexedAt, touchLastIndexedAt: indexedAt, forceRecount: true
            )
        }
        emit(.layer(medium: mediumUUID, depth: depth))
        emit(.counts(mediumUUID))
    }

    /// Ordner einer Tiefe samt Pfad (`/A/B/`), nach Pfad sortiert.
    func folders(mediumUUID: UUID, depth: Int, limit: Int = 5_000, offset: Int = 0) async throws -> [(id: Int64, path: String)] {
        try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: """
                    WITH RECURSIVE chain(id, path, depth) AS (
                        SELECT id, '/' || name || '/', depth FROM items
                        WHERE storageID = ?1 AND parentID IS NULL AND isFolder = 1 AND status = 0
                        UNION ALL
                        SELECT i.id, chain.path || i.name || '/', i.depth FROM items i JOIN chain ON i.parentID = chain.id
                        WHERE i.isFolder = 1 AND i.status = 0 AND chain.depth < ?2
                    )
                    SELECT id, path FROM chain WHERE depth = ?2 ORDER BY path LIMIT ?3 OFFSET ?4
                    """,
                arguments: [storageID, depth, limit, offset]
            )
            return rows.map { (id: $0["id"], path: $0["path"]) }
        }
    }

    func folderID(mediumUUID: UUID, path: [String]) async throws -> Int64? {
        if path.isEmpty { return nil }
        return try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return nil }
            var parent: Int64?
            for name in path {
                if let exact = try Int64.fetchOne(
                    db,
                    sql: "SELECT id FROM items WHERE storageID = ? AND parentID IS ? AND name = ? AND isFolder = 1 AND status = 0",
                    arguments: [storageID, parent, name]
                ) {
                    parent = exact
                    continue
                }
                let slug = Slug.make(name)
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT id, name FROM items
                        WHERE storageID = ? AND parentID IS ? AND slug = ? AND isFolder = 1 AND status = 0
                        """,
                    arguments: [storageID, parent, slug]
                )
                let exactName = rows.filter { ($0["name"] as String) == name }
                if exactName.count == 1 {
                    parent = exactName[0]["id"]
                    continue
                }
                if rows.count == 1 {
                    parent = rows[0]["id"]
                    continue
                }
                return nil
            }
            return parent
        }
    }

    func setScanTotal(mediumUUID: UUID, total: Int) async throws {
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return }
            try MediumCodecV3.setMeta(db, storageID, .scanTotal, value: String(total))
        }
        emit(.medium(mediumUUID))
    }

    func markFolderUnreadable(mediumUUID: UUID, folderID: Int64) async throws {
        let folderPath: [String] = try await pool.write { db in
            try db.execute(sql: "UPDATE items SET unreadable = 1 WHERE id = ?", arguments: [folderID])
            return try DirectoryWriterV3.segments(db, itemID: folderID)
        }
        emit(.items(mediumUUID, folderPaths: [folderPath]))
    }

    func flushMediumMeta(mediumUUID: UUID, force: Bool = true) async throws {
        try await commitPendingMetaIfNeeded(mediumUUID: mediumUUID, seenAt: Date(), delta: .zero, force: force)
        emit(.counts(mediumUUID))
    }

    func resetCompletedDepth(mediumUUID: UUID) async throws {
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.setMeta(db, storageID, .completedDepth, value: nil)
        }
    }

    // MARK: Läufe

    /// Start eines Laufs. `false`, wenn `finishIndexing` den Token schon verworfen hat.
    func beginIndexing(mediumUUID: UUID, token: UUID) async throws -> Bool {
        if revokedIndexingTokens.remove(token) != nil { return false }
        indexingToken[mediumUUID] = token
        insertedIDsDuringRun[mediumUUID] = []
        do {
            try await pool.write { db in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
                try db.execute(
                    sql: "UPDATE storages SET indexStatus = ? WHERE id = ?",
                    arguments: [MediumCodecV3.code(.indexing), storageID]
                )
            }
        } catch {
            if indexingToken[mediumUUID] == token { indexingToken[mediumUUID] = nil }
            throw error
        }
        guard indexingToken[mediumUUID] == token else {
            try await pool.write { db in
                try db.execute(
                    sql: "UPDATE storages SET indexStatus = ? WHERE uuid = ? AND indexStatus = ?",
                    arguments: [MediumCodecV3.code(.pending), MediumCodecV3.data(mediumUUID), MediumCodecV3.code(.indexing)]
                )
            }
            return false
        }
        return true
    }

    /// Beendet den Lauf nur, wenn `token` noch der aktive ist. Löscht alle verschwundenen Einträge (`status = 2`)
    /// und kürzt danach die Journal-Datei (F26).
    func finishIndexing(
        mediumUUID: UUID,
        token: UUID,
        status: StoredIndexStatus,
        firstIndexedAt: Date?,
        interrupted: Bool = false,
        mountPath: String? = nil
    ) async throws -> Bool {
        guard indexingToken[mediumUUID] == token else {
            revokedIndexingTokens.insert(token)
            return false
        }
        let insertedIDs = insertedIDsDuringRun.removeValue(forKey: mediumUUID) ?? []
        let partialMatching = partialMatchingEnabled
        indexingToken[mediumUUID] = nil
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return }
            try db.execute(
                sql: "UPDATE storages SET indexStatus = ? WHERE id = ?",
                arguments: [MediumCodecV3.code(status), storageID]
            )
            if status == .indexed, let firstIndexedAt {
                try db.execute(
                    sql: "UPDATE storages SET firstIndexedAt = ? WHERE id = ? AND firstIndexedAt IS NULL",
                    arguments: [SchemaTime.seconds(firstIndexedAt), storageID]
                )
            }
            if status == .indexed, !interrupted {
                let total = try Int.fetchOne(db, sql: "SELECT fileCount + folderCount FROM storages WHERE id = ?", arguments: [storageID]) ?? 0
                try MediumCodecV3.setMeta(db, storageID, .scanTotal, value: String(total))
            }
            if status == .indexed, !interrupted {
                let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
                let reconnectDelta = try writer.reconnectInsertedWithGone(
                    insertedIDs: insertedIDs, mountPath: mountPath
                )
                if reconnectDelta != .zero {
                    try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: Date(), delta: reconnectDelta)
                }
                let deleted = try Self.deleteGoneItems(db, storageID: storageID)
                if deleted > 0 {
                    try DatabaseMaintenance.addDebt(db, rows: deleted)
                }
            }
        }
        try? await pool.writeWithoutTransaction { db in
            try DatabaseMaintenance.truncateWriteAheadLog(db)
        }
        emit(.medium(mediumUUID))
        return true
    }

    @discardableResult
    private nonisolated static func deleteGoneItems(_ db: Database, storageID: Int64) throws -> Int {
        try db.execute(
            sql: "DELETE FROM items WHERE storageID = ? AND status = ?",
            arguments: [storageID, ItemStatus.gone.rawValue]
        )
        return db.changesCount
    }

    func indexingIsActive(mediumUUID: UUID, token: UUID) -> Bool {
        indexingToken[mediumUUID] == token
    }

    func hasActiveIndexingToken(mediumUUID: UUID) -> Bool {
        indexingToken[mediumUUID] != nil
    }

    func recordEventCursor(mediumUUID: UUID, fsEventsUUID: String?, lastEventID: Int64) async throws {
        #if DEBUG
        Self.recordEventCursorCallCount += 1
        #endif
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.setMeta(db, storageID, .fsEventsUUID, value: fsEventsUUID)
            try MediumCodecV3.setMeta(db, storageID, .lastEventID, value: String(lastEventID))
        }
    }

    func contentStamp(mediumUUID: UUID, path: [String]) async throws -> String? {
        guard let id = try await folderID(mediumUUID: mediumUUID, path: path) else { return nil }
        return try await pool.read { db in
            try Int64.fetchOne(db, sql: "SELECT contentStamp FROM items WHERE id = ?", arguments: [id]).map { String($0, radix: 16) }
        }
    }

    // MARK: Favoriten

    func setFavorite(itemID: Int64, _ isFavorite: Bool) async throws {
        try await setFavorites(itemIDs: [itemID], isFavorite)
    }

    func setFavorites(itemIDs: [Int64], _ isFavorite: Bool) async throws {
        let ids = Array(Set(itemIDs))
        guard !ids.isEmpty else { return }
        do {
            let now = SchemaTime.seconds(Date())
            let mediumUUIDs: [UUID] = try await pool.write { db in
                let marks = ids.map { _ in "?" }.joined(separator: ",")
                let existing = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE id IN (\(marks))", arguments: StatementArguments(ids)) ?? 0
                if existing != ids.count { throw IndexStoreError.unknownItem }
                for id in ids {
                    if isFavorite {
                        try db.execute(sql: "INSERT OR IGNORE INTO favorites (itemID, createdAt) VALUES (?, ?)", arguments: [id, now])
                    } else {
                        try db.execute(sql: "DELETE FROM favorites WHERE itemID = ?", arguments: [id])
                    }
                }
                let rows = try Data.fetchAll(
                    db,
                    sql: "SELECT DISTINCT storages.uuid FROM items JOIN storages ON storages.id = items.storageID WHERE items.id IN (\(marks))",
                    arguments: StatementArguments(ids)
                )
                return rows.compactMap(MediumCodecV3.uuid)
            }
            DiskIndexLog.shared.record(.store, .info, "setFavorites count=\(ids.count)")
            for uuid in mediumUUIDs { emit(.counts(uuid)) }
        } catch {
            DiskIndexLog.shared.record(.store, .error, "setFavorites \(error)")
            throw error
        }
    }

    /// Live-Rename aus FSEvents-Paar (235b).
    func applyLiveRename(mediumUUID: UUID, mountPath: String, fromPath: String, toPath: String) async throws -> Bool {
        let partialMatching = partialMatchingEnabled
        let folderPaths: [[String]] = try await pool.write { db -> [[String]] in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
            let step = try writer.applyLivePathRename(
                mountPath: mountPath,
                fromAbsolute: fromPath,
                toAbsolute: toPath,
                seenAt: Date()
            )
            guard step.applied else { return [] }
            try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: Date(), delta: step.delta)
            var paths: [[String]] = []
            if let fromParts = DirectoryWriterV3.relativeComponents(absolute: fromPath, mountPath: mountPath) {
                paths.append(Array(fromParts.dropLast()))
            }
            if let toParts = DirectoryWriterV3.relativeComponents(absolute: toPath, mountPath: mountPath) {
                paths.append(Array(toParts.dropLast()))
            }
            return paths
        }
        guard !folderPaths.isEmpty else { return false }
        emit(.items(mediumUUID, folderPaths: folderPaths))
        emit(.counts(mediumUUID))
        return true
    }

    /// Favoriten ohne gespeicherte Teil-Prüfsumme (235b, nächstes Anschließen).
    func backfillMissingFavoritePartials(mediumUUID: UUID, mountPath: String) async throws {
        let itemIDs: [Int64] = try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT f.itemID FROM favorites f
                    JOIN items i ON i.id = f.itemID
                    LEFT JOIN item_checksum c ON c.itemID = f.itemID
                    WHERE i.storageID = ? AND i.isFolder = 0 AND i.status = 0 AND c.partial IS NULL
                    """,
                arguments: [storageID]
            )
            return rows.map { $0["itemID"] as Int64 }
        }
        for itemID in itemIDs {
            try await storePartialChecksum(itemID: itemID, mountPath: mountPath)
        }
    }

    /// Teil-Prüfsumme für Favoriten (235); `mountPath` = Medienwurzel.
    func storePartialChecksum(itemID: Int64, mountPath: String) async throws {
        let fileURL: URL? = try await pool.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT i.isFolder, i.name FROM items i WHERE i.id = ? AND i.status = 0",
                arguments: [itemID]
            ) else { return nil }
            let isFolder: Bool = row["isFolder"]
            if isFolder { return nil }
            let path = try DirectoryWriterV3.path(db, itemID: itemID)
            let relative = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relative.isEmpty else { return nil }
            var url = URL(fileURLWithPath: mountPath, isDirectory: true)
            for part in relative.split(separator: "/") {
                url.appendPathComponent(String(part))
            }
            return url
        }
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let computed = try PartialChecksum.compute(at: fileURL) else { return }
        let modified = try await pool.read { db in
            try Int64.fetchOne(db, sql: "SELECT modifiedAt FROM items WHERE id = ?", arguments: [itemID])
        }
        let info = "\(computed.info)|\(modified ?? 0)"
        try await pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO item_checksum (itemID, partial, info) VALUES (?, ?, ?)
                    ON CONFLICT(itemID) DO UPDATE SET partial = excluded.partial, info = excluded.info
                    """,
                arguments: [itemID, computed.partial, info]
            )
        }
    }

    // MARK: Bereinigen

    /// Setzt `status` je Eintrag passend zum Scope (sichtbar vs. zu-löschen), ohne Zeilen zu löschen (234).
    func reconcileScopeToStatus(_ scope: IndexScope, batchSize: Int = 5_000, maxBatches: Int? = nil) async throws -> Int {
        #if DEBUG
        if reconcileShouldFail {
            reconcileShouldFail = false
            throw CocoaError(.fileWriteUnknown)
        }
        #endif
        let started = ContinuousClock.now
        var changed = 0
        var batches = 0
        var cursor: Int64 = 0
        var touched = Set<Int64>()
        let visible = ItemStatus.visible.rawValue
        let toDelete = ItemStatus.toDelete.rawValue

        while true {
            if let maxBatches, batches >= maxBatches { break }
            #if DEBUG
            if let delay = reconcileBatchDelay { try await Task.sleep(for: delay) }
            #endif
            let afterID = cursor
            let step: (updated: Int, last: Int64?, storages: Set<Int64>) = try await pool.write { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT id, storageID, name, depth, status FROM items WHERE id > ? AND status IN (?, ?) ORDER BY id LIMIT ?",
                    arguments: [afterID, visible, toDelete, batchSize]
                )
                guard let last: Int64 = rows.last?["id"] else { return (0, nil, []) }
                var hideIDs: [Int64] = []
                var showIDs: [Int64] = []
                var storages = Set<Int64>()
                for row in rows {
                    let id: Int64 = row["id"]
                    let storageID: Int64 = row["storageID"]
                    let name: String = row["name"]
                    let depth: Int = row["depth"]
                    let status: Int = row["status"]
                    let shouldHide = scope.shouldHide(name: name, depth: depth)
                    if shouldHide, status == visible {
                        hideIDs.append(id)
                        storages.insert(storageID)
                    } else if !shouldHide, status == toDelete {
                        showIDs.append(id)
                        storages.insert(storageID)
                    }
                }
                let hidden = try Self.setItemStatus(db, ids: hideIDs, status: toDelete)
                let shown = try Self.setItemStatus(db, ids: showIDs, status: visible)
                let updated = hidden + shown
                return (updated, last, storages)
            }
            batches += 1
            changed += step.updated
            touched.formUnion(step.storages)
            guard let last = step.last else { break }
            cursor = last
            await Task.yield()
        }

        if !touched.isEmpty || scope.maxDepth != nil {
            try await applyReconcileMeta(touchedStorages: touched, maxDepth: scope.maxDepth)
        }
        let ms = Int(started.duration(to: .now) / Duration.milliseconds(1))
        DiskIndexLog.shared.record(.index, .info, "index reconcile status=\(changed) ms=\(ms)")
        return changed
    }

    /// Löscht alle Einträge mit `status = zu-löschen` endgültig (234).
    func purgeMarkedItems(batchSize: Int = 5_000, maxBatches: Int? = nil) async throws -> Int {
        let started = ContinuousClock.now
        var removed = 0
        var batches = 0
        var cursor: Int64 = 0
        let toDelete = ItemStatus.toDelete.rawValue

        while true {
            if let maxBatches, batches >= maxBatches { break }
            let afterID = cursor
            let step: (deleted: Int, last: Int64?) = try await pool.write { db in
                let ids = try Int64.fetchAll(
                    db,
                    sql: "SELECT id FROM items WHERE status = ? AND id > ? ORDER BY id LIMIT ?",
                    arguments: [toDelete, afterID, batchSize]
                )
                guard let last = ids.last else { return (0, nil) }
                let deleted = try Self.deleteItems(db, ids: ids)
                return (deleted, last)
            }
            batches += 1
            removed += step.deleted
            guard let last = step.last else { break }
            cursor = last
        }
        if removed > 0 {
            let debtRows = removed
            try? await pool.write { db in
                try DatabaseMaintenance.addDebt(db, rows: debtRows)
            }
            try? await pool.writeWithoutTransaction { db in
                try DatabaseMaintenance.compactAfterLargeDelete(db)
            }
        }
        let ms = Int(started.duration(to: .now) / Duration.milliseconds(1))
        DiskIndexLog.shared.record(.index, .info, "index purge marked=\(removed) ms=\(ms)")
        return removed
    }

    /// Markiert passend zum Scope und löscht danach `zu-löschen` (Button „Index jetzt bereinigen“, Frist).
    func pruneToMatch(_ scope: IndexScope, batchSize: Int = 5_000, maxBatches: Int? = nil) async throws -> Int {
        _ = try await reconcileScopeToStatus(scope, batchSize: batchSize, maxBatches: maxBatches)
        return try await purgeMarkedItems(batchSize: batchSize, maxBatches: maxBatches)
    }

    private func applyReconcileMeta(touchedStorages: Set<Int64>, maxDepth: Int?) async throws {
        let uuids: [UUID] = try await pool.write { db in
            var uuids: [UUID] = []
            let ids = try Int64.fetchAll(db, sql: "SELECT id FROM storages")
            let activityAt = Date()
            for id in ids where touchedStorages.contains(id) {
                try Self.commitMediumMeta(db: db, storageID: id, activityAt: activityAt, forceRecount: true)
                if let data = try Data.fetchOne(db, sql: "SELECT uuid FROM storages WHERE id = ?", arguments: [id]),
                   let uuid = MediumCodecV3.uuid(data) { uuids.append(uuid) }
            }
            if let maxDepth {
                let touchedIDs = ids.filter { touchedStorages.contains($0) }
                if !touchedIDs.isEmpty {
                    let placeholders = Array(repeating: "?", count: touchedIDs.count).joined(separator: ", ")
                    var arguments = StatementArguments(touchedIDs)
                    arguments += [maxDepth]
                    try db.execute(
                        sql: """
                            UPDATE items SET contentStamp = NULL
                            WHERE storageID IN (\(placeholders)) AND isFolder = 1 AND depth = ? AND status = 0
                            """,
                        arguments: arguments
                    )
                }
                for id in touchedIDs {
                    let current = try MediumCodecV3.metaValue(db, id, .completedDepth).flatMap(Int.init) ?? 0
                    if current > maxDepth { try MediumCodecV3.setMeta(db, id, .completedDepth, value: String(maxDepth)) }
                }
            }
            return uuids
        }
        for uuid in uuids { emit(.counts(uuid)) }
    }

    private nonisolated static func setItemStatus(_ db: Database, ids: [Int64], status: Int) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        var updated = 0
        var offset = 0
        while offset < ids.count {
            let chunk = Array(ids[offset..<min(offset + 1_000, ids.count)])
            let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            try db.execute(
                sql: "UPDATE items SET status = ? WHERE id IN (\(marks))",
                arguments: StatementArguments([status] + chunk)
            )
            updated += db.changesCount
            offset += 1_000
        }
        return updated
    }

    /// Löscht die Einträge (die Zusatztabellen folgen per Kaskade) und liefert die Zahl der gelöschten Einträge.
    @discardableResult
    private nonisolated static func deleteItems(_ db: Database, ids: [Int64]) throws -> Int {
        var offset = 0
        var deleted = 0
        while offset < ids.count {
            let chunk = ids[offset..<min(offset + 1_000, ids.count)]
            let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            try db.execute(sql: "DELETE FROM items WHERE id IN (\(marks))", arguments: StatementArguments(Array(chunk)))
            deleted += db.changesCount
            offset += 1_000
        }
        return deleted
    }

    // MARK: Zähler im Medium

    private func commitPendingMetaIfNeeded(mediumUUID: UUID, seenAt: Date, delta: MediumCountDelta, force: Bool) async throws {
        pendingMetaDelta[mediumUUID, default: .zero] = pendingMetaDelta[mediumUUID, default: .zero] + delta
        let last = lastMetaCommitTime[mediumUUID] ?? .distantPast
        guard force || seenAt.timeIntervalSince(last) >= 0.35 else { return }
        let toCommit = pendingMetaDelta[mediumUUID, default: .zero]
        guard toCommit != .zero || force else { return }
        pendingMetaDelta[mediumUUID] = .zero
        let commitTime = seenAt
        do {
            try await pool.write { db in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return }
                try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: commitTime, delta: toCommit)
            }
            lastMetaCommitTime[mediumUUID] = commitTime
        } catch {
            pendingMetaDelta[mediumUUID, default: .zero] = pendingMetaDelta[mediumUUID, default: .zero] + toCommit
            throw error
        }
    }

    /// Zähler über die Änderungs-Differenzen (nicht durch Zählen der ganzen Tabelle); `forceRecount` zählt neu.
    nonisolated static func commitMediumMeta(
        db: Database,
        storageID: Int64,
        activityAt: Date,
        touchLastIndexedAt: Date? = nil,
        delta: MediumCountDelta = .zero,
        forceRecount: Bool = false
    ) throws {
        if forceRecount {
            try db.execute(
                sql: """
                    UPDATE storages SET
                        fileCount = (SELECT COUNT(*) FROM items WHERE storageID = ?1 AND isFolder = 0 AND status = 0),
                        folderCount = (SELECT COUNT(*) FROM items WHERE storageID = ?1 AND isFolder = 1 AND status = 0)
                    WHERE id = ?1
                    """,
                arguments: [storageID]
            )
        } else {
            try db.execute(
                sql: "UPDATE storages SET fileCount = MAX(0, fileCount + ?), folderCount = MAX(0, folderCount + ?) WHERE id = ?",
                arguments: [delta.files, delta.folders, storageID]
            )
        }
        if db.changesCount == 0 { throw IndexStoreError.unknownMedium }
        if let touchLastIndexedAt {
            try db.execute(
                sql: "UPDATE storages SET lastIndexedAt = ? WHERE id = ?",
                arguments: [SchemaTime.seconds(touchLastIndexedAt), storageID]
            )
        }
        try MediumCodecV3.setMeta(db, storageID, .lastIndexActivityAt, date: SchemaTime.seconds(activityAt))
    }
}

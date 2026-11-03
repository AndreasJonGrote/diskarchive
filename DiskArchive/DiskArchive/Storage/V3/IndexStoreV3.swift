//
//  IndexStoreV3.swift
//  DiskArchive
//
//  Speicherschicht der App auf dem Schema V3 (`SchemaV3`, Datei `archive.sqlite`). Schreibwege (231), Lesewege in
//  `IndexStoreV3+Reading` (232); seit Aufgabe 233 die einzige Schicht.
//

import Foundation
import GRDB

actor IndexStoreV3 {
    nonisolated let pool: DatabasePool
    private var indexingToken: [UUID: UUID] = [:]
    /// Widerrufene Tokens → ihr Medium (bug.0.4.180 c: beim Vergessen des Mediums aufräumen).
    private var revokedIndexingTokens: [UUID: UUID] = [:]
    private var insertedIDsDuringRun: [UUID: Set<Int64>] = [:]
    /// bug.0.4.229: je Medium die Namen, die verschwundene Ordner in diesem Lauf an andere Ordner abgegeben haben
    /// (bisheriger Elternordner → Namen). Das Laufende vergleicht damit verschobene Ordner.
    private var goneNamesMovedOutDuringRun: [UUID: [Int64: Set<String>]] = [:]
    /// bug.0.4.169 (b): Zeitgrenze je gelesener Teil-Prüfsumme am Laufende und für alle zusammen.
    private var partialReadTimeout: Duration = .seconds(5)
    private var partialReadBudget: Duration = .seconds(30)
    /// bug.0.4.179: Zeitgrenze der Prüfung „dieses Medium ist eingehängt“ (Tests kürzer).
    private var mountLookupTimeout: TimeInterval = VolumeLookup.defaultTimeout
    /// Obergrenze der Länge des Merkers (≈ 50.000 IDs, Zeichen; bug.0.4.171 je Store, Tests kleiner).
    private var pendingReconnectMaxLength = 50_000 * 8
    /// bug.0.4.169 (c): Medien, deren Laufende gerade liest bzw. schreibt; ein neuer Lauf desselben Mediums wartet so
    /// lange (sonst überschriebe der alte Abschluss seinen Status).
    private var finishingMedia: Set<UUID> = []
    /// bug.0.4.176 (b): Lesevorgänge je Medium, die über ihre Zeitgrenze hinaus noch hängen (auch aus früheren Läufen).
    private var hangingPartialReads: [UUID: Int] = [:]
    /// bug.0.4.185 (d): Zählung der Vergessen/Löschen-Vorgänge je Medium; ein hängender Zugriff aus einer früheren Zeit
    /// meldet seine Rückkehr nicht gegen den Zähler eines späteren Zugriffs.
    private var hangingEpoch: [UUID: Int] = [:]
    private var finishWaiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]
    private var pendingMetaDelta: [UUID: MediumCountDelta] = [:]
    private var lastMetaCommitTime: [UUID: Date] = [:]
    private let changesContinuation: AsyncStream<IndexChangeEvent>.Continuation
    nonisolated let changes: AsyncStream<IndexChangeEvent>
    private(set) var changeGeneration = 0
    /// Tests: das nächste Schreiben einer Ebene schlägt fehl.
    var directoryWritesFail = false
    var beginIndexingRejected = false
    /// Tests (bug.0.4.201 e): `beginIndexing` wirft einen Speicherfehler.
    var beginIndexingFails = false
    #if DEBUG
    /// bug.0.4.169: läuft synchron unmittelbar vor dem Lesen einer Teil-Prüfsumme am Laufende (auf dem lesenden Faden).
    var partialReadHookForTesting: (@Sendable (URL) -> Void)?
    func setPartialReadHookForTesting(_ hook: (@Sendable (URL) -> Void)?) { partialReadHookForTesting = hook }
    /// bug.0.4.225/226: läuft auf dem Store unmittelbar vor jedem Lesen einer Teil-Prüfsumme beim Schreiben eines Stapels
    /// (`precomputedPartials`), als Zähler oder Signal. Je Store.
    nonisolated let precomputeReadHookForTesting = CheckpointHook()
    /// bug.0.4.169 (b): Zeitgrenzen des Lesens am Laufende (je Datei, gesamt) – Tests kürzer.
    func setPartialReadLimitsForTesting(perFile: Duration, total: Duration) {
        partialReadTimeout = perFile
        partialReadBudget = total
    }
    /// bug.0.4.169 (c): Aufrufe von `beginIndexing` (positives Signal „Beginn ist angekommen“, nur Tests).
    private(set) var beginIndexingCallsForTesting = 0
    /// bug.0.4.156 (a): Segment-Abfragen beim Wiederverbinden am Laufende (Summe, nur Tests).
    private(set) var reconnectSegmentLookupsForTesting = 0
    #endif
    /// Tests: Leseabfragen für Kinder werfen (Aufgabe 109).
    var childrenReadsFail = false
    /// Tests: `searchCount` braucht künstlich länger (Ergebnisse erscheinen vor der Zahl, 215).
    var searchCountDelay: Duration?
    /// Tests: `search` braucht künstlich länger (Abbruch / Generationswechsel, 007).
    var searchQueryDelay: Duration?
    /// Tests: `search` für einen Suchtext ohne Abbruch anhalten (bug.0.3.9.005 d).
    var searchQueryHold: (query: String, duration: Duration)?
    /// Zahl der Aufrufe von `search` an diesem Store (Tests).
    nonisolated let searchCalls = NameCheckCounter()
    #if DEBUG
    /// Tests: `deleteMedium` schlägt für diese UUIDs fehl (forgetAll, 007).
    var deleteMediumFailUUIDs: Set<UUID> = []
    #endif
    /// Tests: Teil-Prüfsummen-Abgleich (235b); kein globales Flag (bug.0.4.010).
    var partialMatchingEnabled = true
    /// bug.0.4.228: Größen der Dateien mit gespeicherter Teil-Prüfsumme je Medium (`precomputedPartials`). Einmal gefragt,
    /// danach gemerkt, bis eine Teil-Prüfsumme gespeichert wird – vorher fragte jeder Ordner das ganze Medium ab („Daten I“,
    /// 283 000 Einträge: 0,1 s je Ordner, ein Abgleich über 30 Minuten). Gelöschte Teil-Prüfsummen (Kaskade, geänderte
    /// Datei) lassen die Menge höchstens zu groß: dann wird eine Datei mehr gelesen, verglichen wird trotzdem richtig.
    private var comparableSizesByMedium: [UUID: Set<Int64?>] = [:]
    /// Zählt das Verwerfen hoch; ein Lesen, das davor begann, legt sein Ergebnis nicht mehr ab.
    private var comparableSizesGeneration = 0
    #if DEBUG
    /// bug.0.4.228: Abfragen der vergleichbaren Größen (Summe, nur Tests).
    private(set) var comparableSizeQueriesForTesting = 0
    #endif

    #if DEBUG
    func setPartialMatchingEnabled(_ enabled: Bool) {
        partialMatchingEnabled = enabled
    }
    #endif
    /// Zählt Zeilen, deren Name in Swift gegen `IndexScope` geprüft wurde (Tests: ohne ausstehende Bereinigung 0).
    nonisolated let nameChecks = NameCheckCounter()
    /// Zahl der Aufrufe von `searchCount` an diesem Store (Tests: Entprellung des Popovers, bug.0.4.039).
    nonisolated let searchCountCalls = NameCheckCounter()
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
        _ = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return AppDataFolder.url.appendingPathComponent("archive.sqlite", isDirectory: false)
    }

    /// Der eine Pool des Prozesses (bug.0.4.086), gemeinsam mit Warteschlange und Fehlerbericht.
    /// `archive`: nur Tests geben eine eigene Datei an (bug.0.4.093: derselbe Weg wie in der App).
    static func openDefault(archive: ArchiveDatabase = .shared) throws -> IndexStoreV3 {
        IndexStoreV3(pool: try archive.pool())
    }

    /// bug.0.4.224: vergessene Medien zählen nicht mit, auch solange ihre Einträge noch gelöscht werden.
    private static let inventoryMediaSQL = "SELECT COUNT(*) FROM storages WHERE \(MediumCodecV3.notPendingDeletionSQL)"
    private static let inventoryObjectsSQL =
        "SELECT COALESCE(SUM(fileCount + folderCount), 0) FROM storages WHERE \(MediumCodecV3.notPendingDeletionSQL)"

    /// Zahl der Medien und der sichtbaren Einträge für Protokoll und Fehlerbericht. „nicht lesbar“ bei fehlender Datei.
    static func inventoryLabels(using pool: DatabasePool? = nil) -> (media: String, objects: String) {
        do {
            if let pool {
                return try pool.read { db in
                    let counts = (
                        try Int.fetchOne(db, sql: Self.inventoryMediaSQL) ?? 0,
                        try Int.fetchOne(db, sql: Self.inventoryObjectsSQL) ?? 0
                    )
                    return (String(counts.0), String(counts.1))
                }
            }
            let url = try storeFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return ("nicht lesbar", "nicht lesbar") }
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: url.path, configuration: configuration)
            let counts = try queue.read { db -> (Int, Int) in
                (
                    try Int.fetchOne(db, sql: Self.inventoryMediaSQL) ?? 0,
                    try Int.fetchOne(db, sql: Self.inventoryObjectsSQL) ?? 0
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
            ArchiveDatabase.shared.discard(pool)
            try pool.close()
            try DatabaseCare.quarantine(url)
            throw DatabaseCareError.unhealthy
        }
    }

    func emit(_ change: IndexChange) {
        changeGeneration += 1
        changesContinuation.yield(IndexChangeEvent(change: change, generation: changeGeneration))
    }

    #if DEBUG
    func setSearchParallelism(_ parts: Int?) {
        searchParallelism = parts
    }
    #endif

    #if DEBUG
    func setDirectoryWritesFailing(_ failing: Bool) {
        directoryWritesFail = failing
    }

    /// Tests (bug.0.4.152): `beginIndexing` lehnt ab, als wäre der Token schon verworfen.
    func setBeginIndexingRejected(_ rejected: Bool) {
        beginIndexingRejected = rejected
    }

    /// Tests (bug.0.4.201 e): `beginIndexing` wirft, bevor ein Lauf beginnt.
    func setBeginIndexingFailing(_ failing: Bool) {
        beginIndexingFails = failing
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

    /// Tests (bug.0.3.9.005 d): `search` mit genau diesem Suchtext hält so lange an, ohne Abbruch (wie eine laufende
    /// SQLite-Abfrage) — eine überholte Seite kommt so wirklich nach der neuen an.
    func setSearchQueryHold(_ hold: (query: String, duration: Duration)?) {
        searchQueryHold = hold
    }

    #if DEBUG
    /// Tests: `deleteMedium` für UUIDs fehlschlagen lassen.
    func setDeleteMediumFailUUIDs(_ uuids: Set<UUID>) {
        deleteMediumFailUUIDs = uuids
    }
    #endif

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

    var recordEventCursorCallCountForTesting = 0
    var partialChecksumComputeDelayForTesting: TimeInterval?

    func setPartialChecksumComputeDelayForTesting(_ delay: TimeInterval?) {
        partialChecksumComputeDelayForTesting = delay
    }
    #endif

    /// Tests: Zahl der Checkpoints je Store (bug.0.4.042, Beenden über SIGTERM).
    nonisolated let checkpointCalls = NameCheckCounter()
    #if DEBUG
    /// Tests (bug.0.3.9.011): läuft synchron vor dem Checkpoint, z. B. als hängende Platte. Je Store, kein Schalter.
    nonisolated let checkpointHookForTesting = CheckpointHook()
    /// Tests (bug.0.4.062): läuft einmal vor dem `skip + 1`-ten Aufruf von `medium(uuid:)` nach dem Setzen, z. B. um
    /// genau während eines `await` des Koordinators auszuhängen. Je Store.
    nonisolated let mediumReadHookForTesting = MediumReadHook()

    nonisolated final class MediumReadHook: @unchecked Sendable {
        private let lock = NSLock()
        private var action: (@Sendable () async -> Void)?
        private var remainingSkips = 0

        func set(skip: Int, _ action: (@Sendable () async -> Void)?) {
            lock.withLock {
                remainingSkips = skip
                self.action = action
            }
        }

        func run() async {
            let due = lock.withLock { () -> (@Sendable () async -> Void)? in
                guard let action else { return nil }
                if remainingSkips > 0 {
                    remainingSkips -= 1
                    return nil
                }
                self.action = nil
                return action
            }
            await due?()
        }
    }

    nonisolated final class CheckpointHook: @unchecked Sendable {
        private let lock = NSLock()
        private var action: (@Sendable () -> Void)?

        func set(_ action: (@Sendable () -> Void)?) {
            lock.withLock { self.action = action }
        }

        func run() {
            let action = lock.withLock { self.action }
            action?()
        }
    }
    #endif

    nonisolated func checkpoint() {
        checkpointCalls.add(1)
        #if DEBUG
        checkpointHookForTesting.run()
        #endif
        try? pool.writeWithoutTransaction { db in
            try DatabaseMaintenance.truncateWriteAheadLog(db)
        }
    }

    /// Checkpoint auf einer Hintergrund-Queue (bug.0.3.9.011): hält ein Indexer die Schreibsperre oder hängt die
    /// Platte, wartet nur der Aufrufer, nicht der Hauptthread (Beenden, Ruhezustand).
    nonisolated func checkpointInBackground() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                checkpoint()
                continuation.resume()
            }
        }
    }

    // MARK: App-Einstellungen (237)

    #if DEBUG
    func loadPersistedAppSettings() async -> PersistedAppSettings? {
        if case .loaded(let settings) = await loadPersistedAppSettingsResult() { return settings }
        return nil
    }
    #endif

    /// bug.0.4.105: unterscheidet „kein Eintrag“ von „Lesefehler“ (kaputter Text, Datenbankfehler).
    func loadPersistedAppSettingsResult() async -> PersistedAppSettingsLoad {
        do {
            guard let settings = try await pool.read({ db in try SettingsPersistence.readAppSettings(db) }) else {
                return .missing
            }
            return .loaded(settings)
        } catch {
            return .unreadable
        }
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
            DiskArchiveLog.shared.record(
                .index,
                .info,
                "index maintenance debt=\(debt) freelist=\(freelistBefore)->\(freelistAfter) ms=\(ms)"
            )
        } catch {
            if DiskArchiveLog.isOperationalFailure(error) {
                DiskArchiveLog.shared.record(.index, .error, "index maintenance \(DiskArchiveLog.errorSummary(error))")
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
        #if DEBUG
        await mediumReadHookForTesting.run()
        #endif
        return try await pool.read { db in try MediumCodecV3.fetch(db, uuid: uuid) }
    }

    func updateMedium(uuid: UUID, _ medium: StoredMedium) async throws {
        do {
            try await pool.write { db in
                guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
                var replacement = medium
                replacement.uuid = uuid
                try MediumCodecV3.update(db, storageID: id, replacement)
            }
            DiskArchiveLog.shared.record(.store, .info, "updateMedium count=1")
            emit(.medium(uuid))
        } catch {
            DiskArchiveLog.shared.record(.store, .error, "updateMedium \(DiskArchiveLog.errorSummary(error))")
            throw error
        }
    }

    func updateMediumUserFields(uuid: UUID, _ medium: StoredMedium) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.updateUserFields(db, storageID: id, medium)
        }
        emit(.medium(uuid))
    }

    /// todo.0.4.2.002: eigener Name aus der Eingabe im Details-Modal. Leer oder gleich dem Originalnamen löscht den
    /// Schlüssel (zurück zum Originalnamen); `storages.name` und `slug` bleiben unverändert.
    func setCustomName(mediumUUID: UUID, input: String) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: mediumUUID),
                  let original = try String.fetchOne(db, sql: "SELECT name FROM storages WHERE id = ?", arguments: [id])
            else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.setMeta(db, id, .customName, value: Medium.normalizedCustomName(input, original: original))
        }
        emit(.medium(mediumUUID))
    }

    /// todo.0.4.3.010 (Layout 06.03): Grund des letzten Fehlers am Medium merken (`nil` = löschen), damit das
    /// Details-Fenster ihn zeigt, solange der Status „Fehler“ ist.
    func setFailureReason(mediumUUID: UUID, code: String?) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return }
            try MediumCodecV3.setMeta(db, id, .failureReason, value: code)
        }
    }

    func updateMediumRecognition(uuid: UUID, _ medium: StoredMedium) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.updateRecognitionFields(db, storageID: id, medium)
        }
        emit(.medium(uuid))
    }

    func updateMediumIndexStatus(uuid: UUID, _ status: StoredIndexStatus) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.updateIndexStatus(db, storageID: id, status)
        }
        emit(.medium(uuid))
    }

    func updateMediumLastSeen(uuid: UUID, at date: Date) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.updateLastSeen(db, storageID: id, at: date)
        }
        emit(.medium(uuid))
    }

    func updateMediumDecision(uuid: UUID, _ medium: StoredMedium) async throws {
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.updateDecisionFields(db, storageID: id, medium)
        }
        emit(.medium(uuid))
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
        clearRunLeftovers(uuid)
        try await pool.write { db in
            guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { throw IndexStoreError.unknownMedium }
            try MediumCodecV3.setMeta(db, id, .isForgotten, value: "1")
        }
    }

    /// Einziger harter Löschweg. Bereits gelöscht → kein Fehler.
    func deleteMedium(uuid: UUID) async throws {
        try await deleteMedia(uuids: [uuid])
    }

    /// bug.0.4.224: Vergessen ist mit einer kurzen Transaktion dauerhaft (Markierung, neue Kennung, Favoriten weg); die
    /// Einträge löscht danach `purgePendingDeletions` in Stücken. Eine Löschung in einem Zug dauerte bei 1,6 Mio.
    /// Zeilen 25 s und rollte beim Beenden zurück. Kehrt zurück, wenn alles gelöscht ist; bricht der Prozess vorher ab,
    /// setzt der nächste Start fort (`MediumRecognitionStartup`).
    func deleteMedia(uuids: [UUID]) async throws {
        #if DEBUG
        let failing = uuids.filter { deleteMediumFailUUIDs.contains($0) }
        let uuids = uuids.filter { !deleteMediumFailUUIDs.contains($0) }
        #endif
        uuids.forEach(clearRunLeftovers)
        do {
            let marked = try await pool.write { db -> [UUID] in
                try uuids.filter { try Self.markForDeletion(db, uuid: $0) }
            }
            for uuid in marked {
                DiskArchiveLog.shared.record(.store, .info, "deleteMedium count=1")
                emit(.removed(uuid))
            }
        } catch {
            if DiskArchiveLog.isOperationalFailure(error) {
                DiskArchiveLog.shared.record(.store, .error, "deleteMedium \(DiskArchiveLog.errorSummary(error))")
            }
            throw error
        }
        await purgePendingDeletions()
        #if DEBUG
        if !failing.isEmpty { throw CocoaError(.fileWriteUnknown) }
        #endif
    }

    /// Markiert das Medium und gibt seine Kennung frei: dasselbe Medium kann sofort neu registriert werden, und kein
    /// Schreiber findet die alte Zeile noch. `false`: schon gelöscht.
    private nonisolated static func markForDeletion(_ db: Database, uuid: UUID) throws -> Bool {
        guard let id = try MediumCodecV3.storageRowID(db, uuid: uuid) else { return false }
        try db.execute(sql: "UPDATE storages SET uuid = ? WHERE id = ?", arguments: [MediumCodecV3.data(UUID()), id])
        try MediumCodecV3.setMeta(db, id, .pendingDeletion, value: "1")
        try db.execute(
            sql: """
                DELETE FROM favorites WHERE itemID IN (
                    SELECT f.itemID FROM favorites f JOIN items i ON i.id = f.itemID WHERE i.storageID = ?
                )
                """,
            arguments: [id]
        )
        return true
    }

    /// bug.0.4.224: Zeilen je Transaktion beim Löschen der Einträge eines vergessenen Mediums.
    nonisolated static let purgeChunkSize = 10_000
    private var purgeTask: Task<Void, Never>?
    #if DEBUG
    /// Tests: läuft vor jedem Stück; ein Fehler hält das Löschen an (wie ein Ende des Prozesses).
    private var purgeChunkHookForTesting: (@Sendable () async throws -> Void)?
    func setPurgeChunkHookForTesting(_ hook: (@Sendable () async throws -> Void)?) { purgeChunkHookForTesting = hook }
    #endif

    /// Löscht die Einträge aller markierten Medien, zuletzt ihre Zeile in `storages`. Läuft höchstens einmal zugleich;
    /// wer währenddessen ruft, wartet und lässt danach selbst noch einen Durchgang laufen (keine Markierung bleibt liegen).
    func purgePendingDeletions() async {
        while let running = purgeTask { await running.value }
        let task = Task {
            await drainPendingDeletions()
            purgeTask = nil
        }
        purgeTask = task
        await task.value
    }

    private func drainPendingDeletions() async {
        do {
            while let storageID = try await pool.read({ db in try MediumCodecV3.pendingDeletionStorageIDs(db).first }) {
                try await purgeItems(storageID: storageID)
                try await pool.write { db in
                    // bug.0.4.108: die gelöschten Zeilen als Wartungsschuld buchen, sonst bleibt die Datei groß.
                    let rows = try Int.fetchOne(
                        db, sql: "SELECT fileCount + folderCount FROM storages WHERE id = ?", arguments: [storageID]
                    ) ?? 0
                    try db.execute(sql: "DELETE FROM storages WHERE id = ?", arguments: [storageID])
                    if db.changesCount > 0 { try DatabaseMaintenance.addDebt(db, rows: rows) }
                }
            }
        } catch {
            guard DiskArchiveLog.isOperationalFailure(error) else { return }
            DiskArchiveLog.shared.record(.store, .error, "purgePendingDeletions \(DiskArchiveLog.errorSummary(error))")
        }
    }

    /// Von der höchsten Kennung abwärts: Kinder liegen meist über ihrem Ordner, so löscht die Kaskade je Stück kaum mehr.
    /// `NOT INDEXED`: über die Kennung lesen, statt alle Zeilen des Mediums je Stück zu sortieren.
    private func purgeItems(storageID: Int64) async throws {
        var upper = Int64.max
        while true {
            #if DEBUG
            try await purgeChunkHookForTesting?()
            #endif
            let below = upper
            let lowest = try await pool.write { db -> Int64? in
                let ids = try Int64.fetchAll(
                    db,
                    sql: "SELECT id FROM items NOT INDEXED WHERE storageID = ? AND id <= ? ORDER BY id DESC LIMIT ?",
                    arguments: [storageID, below, Self.purgeChunkSize]
                )
                guard let lowest = ids.last else { return nil }
                try db.execute(
                    sql: "DELETE FROM items WHERE storageID = ? AND id BETWEEN ? AND ?", arguments: [storageID, lowest, below]
                )
                return lowest
            }
            guard let lowest else { return }
            upper = lowest - 1
        }
    }

    // MARK: Ebenen

    #if DEBUG
    func applyDirectory(
        mediumUUID: UUID,
        parentID: Int64?,
        entries: [ScannedEntry],
        seenAt: Date,
        mountPath: String? = nil
    ) async throws {
        let partialMatching = partialMatchingEnabled
        let partials = try await precomputedPartials(
            mediumUUID: mediumUUID, mountPath: mountPath, parentID: parentID, entries: entries, enabled: partialMatching
        )
        let folderPath: [String] = try await pool.write { db -> [String] in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
            let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
            let step = try writer.apply(
                parentID: parentID, path: nil, depth: nil, entries: entries, seenAt: seenAt, finalize: true,
                mountPath: mountPath, precomputedPartials: partials
            )
            try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: seenAt, delta: step.delta)
            guard let parentID else { return [] }
            return try DirectoryWriterV3.segments(db, itemID: parentID)
        }
        emit(.items(mediumUUID, folderPaths: [folderPath]))
        emit(.counts(mediumUUID))
    }
    #endif

    /// Gibt zurück, um wie viel sich die Zahl der Einträge geändert hat (neu gespeicherte, abzüglich entfernter).
    @discardableResult
    func applyDirectories(
        mediumUUID: UUID,
        batches: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)],
        seenAt: Date,
        mountPath: String? = nil
    ) async throws -> MediumCountDelta {
        do {
            if directoryWritesFail { throw IndexStoreError.directoryWriteFailed }
            let partialMatching = partialMatchingEnabled
            // bug.0.4.176 (c): Das Token steht bis nach dem Laufende (169 c). In der Abschlussphase schreibt hier praktisch
            // niemand: der Lauf selbst ist fertig, und die Live-Überwachung schiebt auf, solange ein Token steht
            // (`ChangeWatcherEngine`, `hasActiveIndexingToken` → `.deferred`). Nur wenn ein Schreiber die Prüfung vor dem
            // Beginn bestand und erst im Abschluss schreibt, ginge dessen Einfügung als Hinweis fürs Wiederverbinden verloren.
            let trackInserts = indexingToken[mediumUUID] != nil
            let merkerMaxLength = pendingReconnectMaxLength
            var partialMaps: [[String: Data]?] = []
            partialMaps.reserveCapacity(batches.count)
            for batch in batches {
                let map = try await precomputedPartials(
                    mediumUUID: mediumUUID, mountPath: mountPath, parentID: batch.parentID, entries: batch.entries,
                    enabled: partialMatching
                )
                partialMaps.append(map)
            }
            let batchPartials = partialMaps
            let result = try await pool.write { db -> (
                delta: MediumCountDelta, parentPaths: [String], inserted: [Int64], movedOut: [(Int64, String)], merkerWritten: Bool
            ) in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
                let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
                var delta = MediumCountDelta.zero
                var parentPaths: [String] = []
                var inserted: [Int64] = []
                var movedOut: [(Int64, String)] = []
                if trackInserts {
                    writer.onInsertedItemID = { inserted.append($0) }
                    writer.onGoneRowMovedOut = { movedOut.append(($0, $1)) }
                }
                for (batch, partials) in zip(batches, batchPartials) {
                    let step = try writer.apply(
                        parentID: batch.parentID, path: batch.path, depth: batch.depth,
                        entries: batch.entries, seenAt: seenAt, finalize: batch.finalize,
                        mountPath: mountPath, precomputedPartials: partials
                    )
                    delta = delta + step.delta
                    parentPaths.append(step.parentPath)
                }
                // bug.0.4.156 (c): neue Zeilen schon mit diesem Stapel merken (nicht erst am Laufende) – bricht der Lauf
                // vorher ab, findet der Folgelauf die Zuordnung. Nur, wo wiederverbunden wird (ohne verlässliche fileID).
                // bug.0.4.165 (a): nur, wo es etwas wiederzuverbinden gibt (verschwundene Zeilen oder schon einmal
                // vollständig indiziert) – beim Erstindex nicht; und nur die neuen IDs anhängen.
                var merkerWritten = false
                if trackInserts, !inserted.isEmpty, !writer.trustsFileID, try Self.mayReconnect(db, storageID) {
                    try Self.appendPendingReconnectIDs(db, storageID, inserted, maxLength: merkerMaxLength)
                    merkerWritten = true
                }
                // bug.0.4.222: Zähler im selben Schreibvorgang wie die Einträge – gespeichert ist, was gezählt ist. Getrennt
                // nachgeschrieben ging er beim Abziehen verloren (das Nachschreiben trifft den Abbruch).
                try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: seenAt, delta: delta)
                return (delta, parentPaths, inserted, movedOut, merkerWritten)
            }
            #if DEBUG
            if result.merkerWritten { pendingReconnectWritesForTesting += 1 }
            #endif
            if trackInserts, !result.inserted.isEmpty {
                insertedIDsDuringRun[mediumUUID, default: []].formUnion(result.inserted)
            }
            if trackInserts, !result.movedOut.isEmpty {
                var names = goneNamesMovedOutDuringRun[mediumUUID] ?? [:]
                for (previousParentID, name) in result.movedOut { names[previousParentID, default: []].insert(name) }
                goneNamesMovedOutDuringRun[mediumUUID] = names
            }
            DiskArchiveLog.shared.record(.store, .info, "applyDirectories count=\(batches.count)")
            var seenPaths = Set<String>()
            var uniquePaths: [[String]] = []
            for parentPath in result.parentPaths {
                let segments = IgnoreMatcher.storedPathSegments(parentPath)
                let key = segments.joined(separator: "\u{0}")
                if seenPaths.insert(key).inserted { uniquePaths.append(segments) }
            }
            emit(.items(mediumUUID, folderPaths: uniquePaths))
            emit(.counts(mediumUUID))
            return result.delta
        } catch {
            DiskArchiveLog.shared.record(.store, .error, "applyDirectories \(DiskArchiveLog.errorSummary(error))")
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
            try Self.setScanTotalIncomplete(db, storageID, false)
        }
        emit(.medium(mediumUUID))
    }

    /// bug.0.4.054 (REPORT 95): Merker „Zählung unvollständig“ in `storage_meta` (neuer Schlüssel, Schema unverändert).
    /// Gesetzt beim Beginn einer Zählphase, gelöscht mit der vollständigen Gesamtzahl (`setScanTotal`, `finishIndexing`).
    nonisolated static let scanTotalIncompleteKey = "scanTotalIncomplete"

    func markScanTotalIncomplete(mediumUUID: UUID) async throws {
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return }
            try Self.setScanTotalIncomplete(db, storageID, true)
        }
    }

    func scanTotalIsIncomplete(mediumUUID: UUID) async throws -> Bool {
        try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return false }
            let value = try String.fetchOne(
                db,
                sql: """
                    SELECT m.value FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                    WHERE m.storageID = ? AND k.key = ?
                    """,
                arguments: [storageID, Self.scanTotalIncompleteKey]
            )
            return value == "1"
        }
    }

    private nonisolated static func setScanTotalIncomplete(_ db: Database, _ storageID: Int64, _ incomplete: Bool) throws {
        let key = scanTotalIncompleteKey
        if !incomplete {
            try db.execute(
                sql: "DELETE FROM storage_meta WHERE storageID = ? AND keyID IN (SELECT id FROM meta_keys WHERE key = ?)",
                arguments: [storageID, key]
            )
            return
        }
        try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES (?)", arguments: [key])
        try db.execute(
            sql: """
                INSERT OR REPLACE INTO storage_meta (storageID, keyID, value, date)
                SELECT ?, id, '1', NULL FROM meta_keys WHERE key = ?
                """,
            arguments: [storageID, key]
        )
    }

    /// bug.0.4.151: Merker „der letzte Lauf bis zum Ende fand eine Lücke“ in `storage_meta` (neuer Schlüssel, Regel 27).
    nonisolated static let indexGapsKey = "indexGaps"

    func indexHasGaps(mediumUUID: UUID) async throws -> Bool {
        try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return false }
            return try String.fetchOne(
                db,
                sql: """
                    SELECT m.value FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                    WHERE m.storageID = ? AND k.key = ?
                    """,
                arguments: [storageID, Self.indexGapsKey]
            ) == "1"
        }
    }

    /// bug.0.4.200 (d): Zugriff beim Anschließen verweigert – der letzte Fehler ist nicht mehr die Lücke.
    func clearIndexGaps(mediumUUID: UUID) async throws {
        try await pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return }
            try Self.setIndexGaps(db, storageID, false)
        }
    }

    private nonisolated static func setIndexGaps(_ db: Database, _ storageID: Int64, _ gaps: Bool) throws {
        let key = indexGapsKey
        guard gaps else {
            try db.execute(
                sql: "DELETE FROM storage_meta WHERE storageID = ? AND keyID IN (SELECT id FROM meta_keys WHERE key = ?)",
                arguments: [storageID, key]
            )
            return
        }
        try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES (?)", arguments: [key])
        try db.execute(
            sql: """
                INSERT OR REPLACE INTO storage_meta (storageID, keyID, value, date)
                SELECT ?, id, '1', NULL FROM meta_keys WHERE key = ?
                """,
            arguments: [storageID, key]
        )
    }

    /// bug.0.4.127: Ob das Medium Ordner hat, die beim letzten Lesen nicht lesbar waren (Lücke im Index).
    func hasUnreadableFolders(mediumUUID: UUID) async throws -> Bool {
        try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return false }
            return try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM items WHERE storageID = ? AND unreadable = 1 AND status = 0)",
                arguments: [storageID]
            ) ?? false
        }
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
        #if DEBUG
        beginIndexingCallsForTesting += 1
        #endif
        // bug.0.4.169 (c): erst wenn das Laufende desselben Mediums geschrieben ist.
        while finishingMedia.contains(mediumUUID) {
            await withCheckedContinuation { finishWaiters[mediumUUID, default: []].append($0) }
        }
        if revokedIndexingTokens.removeValue(forKey: token) != nil { return false }
        #if DEBUG
        if beginIndexingRejected { return false }
        if beginIndexingFails { throw IndexStoreError.unknownMedium }
        #endif
        indexingToken[mediumUUID] = token
        insertedIDsDuringRun[mediumUUID] = []
        goneNamesMovedOutDuringRun[mediumUUID] = nil
        do {
            let pending: Set<Int64>? = try await pool.write { db in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { throw IndexStoreError.unknownMedium }
                // bug.0.4.185 (b): ein vergessenes Medium wird nicht mehr indiziert (ein Beginn nach dem Vergessen, dessen
                // Widerruf mit dem Vergessen abgeräumt wurde, setzt sonst `indexing` auf das vergessene Medium).
                if try MediumCodecV3.fetch(db, uuid: mediumUUID)?.isForgotten == true { return nil }
                try db.execute(
                    sql: "UPDATE storages SET indexStatus = ? WHERE id = ?",
                    arguments: [MediumCodecV3.code(.indexing), storageID]
                )
                return try Self.pendingReconnectIDs(db, storageID)
            }
            guard let pending else {
                if indexingToken[mediumUUID] == token {
                    indexingToken[mediumUUID] = nil
                    insertedIDsDuringRun[mediumUUID] = nil
                    goneNamesMovedOutDuringRun[mediumUUID] = nil
                }
                return false
            }
            // bug.0.4.141 (b): Zuordnung aus einem unterbrochenen Lauf bleibt bis zum nächsten vollständigen Ende.
            if indexingToken[mediumUUID] == token, !pending.isEmpty {
                insertedIDsDuringRun[mediumUUID, default: []].formUnion(pending)
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
        mountPath: String? = nil,
        ranToEnd: Bool = false
    ) async throws -> Bool {
        // bug.0.4.127: Lauf bis zum Ende mit nicht lesbaren Ordnern (seit bug.0.4.199 `.error`) räumt auf wie ein
        // vollständiger Lauf;
        // Ordner, die nicht gelesen wurden, haben keine Kinder auf „verschwunden“ gesetzt.
        let completesRun = (status == .indexed || ranToEnd) && !interrupted
        // Während der Abschluss des Mediums noch liest/schreibt: ein zweiter Abschluss desselben Laufs tut nichts; ein
        // anderes Token (wartender Nachhol-Lauf, abgebrochen) wird widerrufen, damit `beginIndexing` nach dem Warten
        // abbricht (bug.0.4.174).
        if finishingMedia.contains(mediumUUID) {
            if indexingToken[mediumUUID] != token { revokedIndexingTokens[token] = mediumUUID }
            return false
        }
        guard indexingToken[mediumUUID] == token else {
            revokedIndexingTokens[token] = mediumUUID
            return false
        }
        let insertedIDs = insertedIDsDuringRun.removeValue(forKey: mediumUUID) ?? []
        let movedOutGoneNames = goneNamesMovedOutDuringRun.removeValue(forKey: mediumUUID) ?? [:]
        let partialMatching = partialMatchingEnabled
        // bug.0.4.169 (c): Lauf-Zustand erst nach dem Schreiben freigeben; bis dahin wartet ein neuer Beginn.
        finishingMedia.insert(mediumUUID)
        defer {
            if indexingToken[mediumUUID] == token {
                indexingToken[mediumUUID] = nil
                insertedIDsDuringRun[mediumUUID] = nil
                goneNamesMovedOutDuringRun[mediumUUID] = nil
            }
            finishingMedia.remove(mediumUUID)
            for waiter in finishWaiters.removeValue(forKey: mediumUUID) ?? [] { waiter.resume() }
        }
        // bug.0.4.169: Teil-Prüfsummen der Kandidaten **vor** der Schreibtransaktion von der Platte lesen – ein langsames
        // oder hängendes Medium hält sonst alle anderen Schreiber auf (Live-Änderungen, Favoriten, Einstellungen).
        var externalPartials: [Int64: PartialReadOutcome]?
        if !insertedIDs.isEmpty, completesRun || mountPath != nil, let mountPath, partialMatching {
            let (requests, lookups, stored): ([(id: Int64, url: URL)], Int, StoredMedium?) = try await pool.read { db in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return ([], 0, nil) }
                let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
                let requests = try writer.partialReadRequests(insertedIDs: insertedIDs, mountPath: mountPath)
                return (requests, writer.reconnectSegmentLookups, try MediumCodecV3.fetch(db, uuid: mediumUUID))
            }
            #if DEBUG
            reconnectSegmentLookupsForTesting += lookups
            let hook = partialReadHookForTesting
            #else
            _ = lookups
            let hook: (@Sendable (URL) -> Void)? = nil
            #endif
            // bug.0.4.169 (b): Zeitgrenze je Datei und gesamt; nach der ersten Zeitüberschreitung (Medium hängt) kein
            // weiteres Lesen – die übrigen Kandidaten gelten als unlesbar und bleiben.
            #if DEBUG
            let testFolderCheck: @Sendable (String) -> Bool = { MountedMediumCheck.testFolderExists($0) }
            let realCheck: @Sendable (String) -> Bool = { MountedMediumCheck.isMountPoint($0) }
            let mountPointCheck: @Sendable (String) -> Bool = mountPointCheckForTesting
                ?? (mountCheckForTesting != nil ? testFolderCheck : realCheck)
            #else
            let mountPointCheck: @Sendable (String) -> Bool = { MountedMediumCheck.isMountPoint($0) }
            #endif
            var outcomes: [Int64: PartialReadOutcome] = [:]
            let clock = ContinuousClock()
            let deadline = clock.now + partialReadBudget
            // bug.0.4.175: nur lesen, wenn unter dem Pfad wirklich dieses Medium eingehängt ist – sonst sagt eine fehlende
            // Datei nichts (leerer Einhängepunkt nach Absturz, anderes Medium unter demselben Pfad): alle unlesbar.
            var stopped = false
            if !requests.isEmpty {
                if hangingPartialReads[mediumUUID, default: 0] > 0 {
                    // bug.0.4.176 (b)/179: ein früherer Zugriff (Lesen oder Prüfung) hängt noch – keinen weiteren starten.
                    stopped = true
                    DiskArchiveLog.shared.record(.index, .info, "reconnect earlier read still hanging candidates=\(requests.count)")
                } else if !(await mediumIsMounted(stored, mountPath: mountPath, mediumUUID: mediumUUID)) {
                    stopped = true
                    DiskArchiveLog.shared.record(.index, .info, "reconnect medium not mounted candidates=\(requests.count)")
                }
            }
            for request in requests {
                let remaining = deadline - clock.now
                guard !stopped, remaining > .zero else {
                    outcomes[request.id] = .unreadable
                    continue
                }
                let completion = PartialReadCompletion()
                let read = await PartialChecksum.readOffActor(
                    at: request.url, mountPath: mountPath, timeout: min(partialReadTimeout, remaining), beforeRead: hook,
                    afterRead: { completion.finish() }, isMountPoint: mountPointCheck
                )
                outcomes[request.id] = read.outcome
                if read.timedOut {
                    stopped = true
                    noteHanging(completion, mediumUUID: mediumUUID)
                    DiskArchiveLog.shared.record(.index, .info, "reconnect read timeout remaining=\(requests.count - outcomes.count)")
                }
            }
            externalPartials = outcomes
        }
        let readPartials = externalPartials
        #if DEBUG
        let readHook = partialReadHookForTesting
        let lookupHook = partialLookupHookForTesting
        #endif
        let merkerMaxLength = pendingReconnectMaxLength
        let segmentLookupsDone: Int = try await pool.write { db -> Int in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return 0 }
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
            if completesRun {
                // bug.0.4.151: Lücke merken bzw. aufheben, getrennt von `firstIndexedAt` (das bleibt nach dem ersten
                // vollständigen Lauf stehen).
                try Self.setIndexGaps(db, storageID, status != .indexed)
                let total = try Int.fetchOne(db, sql: "SELECT fileCount + folderCount FROM storages WHERE id = ?", arguments: [storageID]) ?? 0
                try MediumCodecV3.setMeta(db, storageID, .scanTotal, value: String(total))
                try Self.setScanTotalIncomplete(db, storageID, false)
            } else if status == .error, !interrupted {
                // bug.0.4.200 (d): der Lauf scheiterte aus anderem Grund – der letzte Fehler ist nicht mehr die Lücke
                // (Aktivieren der App prüft dann wieder, z. B. nach der Freigabe in den Systemeinstellungen).
                try Self.setIndexGaps(db, storageID, false)
            }
            // bug.0.4.104: Wiederverbinden auch beim unterbrochenen Ende — sonst geht die Zuordnung verloren und
            // der nächste Lauf löscht die alte Zeile samt Favorit, Teil-Prüfsumme und `item_meta`.
            // Ohne Einhängepfad (Fehlerwege) keine Prüfung der Teil-Prüfsumme möglich → dort nicht wiederverbinden.
            var unreadable: Set<Int64> = []
            var segmentLookups = 0
            if !insertedIDs.isEmpty, completesRun || mountPath != nil {
                let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
                writer.externalPartials = readPartials
                writer.movedOutGoneNames = movedOutGoneNames
                #if DEBUG
                writer.partialReadHook = readHook
                writer.partialLookupHook = lookupHook
                #endif
                let reconnectDelta = try writer.reconnectInsertedWithGone(
                    insertedIDs: insertedIDs, mountPath: mountPath
                )
                if reconnectDelta != .zero {
                    try Self.commitMediumMeta(db: db, storageID: storageID, activityAt: Date(), delta: reconnectDelta)
                }
                unreadable = writer.unreadableGoneCandidateIDs
                segmentLookups = writer.reconnectSegmentLookups
            }
            // bug.0.4.141 (b): unterbrochen → noch nicht zugeordnete neue Zeilen für den Folgelauf merken (der alte Ort
            // wird vielleicht erst dort gelesen); vollständig beendet → Merker löschen. bug.0.4.156 (b): konnte eine
            // neue Datei nicht gelesen werden, bleibt der Merker (Folgelauf versucht es erneut).
            try Self.storePendingReconnectIDs(
                db, storageID, completesRun && unreadable.isEmpty ? [] : insertedIDs, maxLength: merkerMaxLength
            )
            if completesRun {
                let deleted = try Self.deleteGoneItems(db, storageID: storageID, keeping: unreadable)
                if deleted > 0 {
                    try DatabaseMaintenance.addDebt(db, rows: deleted)
                }
            }
            if !unreadable.isEmpty {
                DiskArchiveLog.shared.record(.index, .info, "reconnect unreadable kept=\(unreadable.count)")
            }
            return segmentLookups
        }
        #if DEBUG
        reconnectSegmentLookupsForTesting += segmentLookupsDone
        #else
        _ = segmentLookupsDone
        #endif
        try? await pool.writeWithoutTransaction { db in
            try DatabaseMaintenance.truncateWriteAheadLog(db)
        }
        emit(.medium(mediumUUID))
        return true
    }

    /// bug.0.4.175/179: Ist unter dem Pfad dieses Medium eingehängt? Hängt die Prüfung über ihre Zeitgrenze hinaus, zählt
    /// sie als hängender Zugriff des Mediums (wie ein Lesevorgang, bug.0.4.176 b).
    private func mediumIsMounted(_ stored: StoredMedium?, mountPath: String, mediumUUID: UUID) async -> Bool {
        guard let stored else { return false }
        #if DEBUG
        if let check = mountCheckForTesting { return await check(mountPath, stored) }
        let lookup = mountLookupForTesting
        #else
        let lookup: (@Sendable (URL) -> VolumeInfo?)? = nil
        #endif
        let completion = PartialReadCompletion()
        let mounted: Bool
        if let lookup {
            mounted = await MountedMediumCheck.isMounted(stored, at: mountPath, timeout: mountLookupTimeout, lookup: lookup, completion: completion)
        } else {
            mounted = await MountedMediumCheck.isMounted(stored, at: mountPath, timeout: mountLookupTimeout, completion: completion)
        }
        noteHanging(completion, mediumUUID: mediumUUID)
        return mounted
    }

    /// bug.0.4.185 (a): Prüfung „Medium eingehängt?“ des Indexers über denselben Weg – hängt sie, zählt sie als hängender
    /// Zugriff des Mediums; solange ein früherer Zugriff hängt, wird keine neue gestartet (gilt als nicht bestätigt).
    func confirmMounted(_ stored: StoredMedium, mountPath: String, access: any MediumAccess) async -> Bool {
        let mediumUUID = stored.uuid
        if hangingPartialReads[mediumUUID, default: 0] > 0 { return false }
        let epoch = hangingEpoch[mediumUUID, default: 0]
        let completion = PartialReadCompletion()
        let mounted = await access.mediumIsMounted(stored, mountPath: mountPath, completion: completion)
        noteHanging(completion, mediumUUID: mediumUUID, epoch: epoch)
        return mounted
    }

    /// Läuft der Zugriff noch (`completion` nicht beendet), zählt er, bis er zurückkehrt – nur gegen die Zeit, in der
    /// er begann (`hangingEpoch`).
    private func noteHanging(_ completion: PartialReadCompletion, mediumUUID: UUID, epoch: Int? = nil) {
        let epoch = epoch ?? hangingEpoch[mediumUUID, default: 0]
        // Der Zugriff begann in einer früheren Zeit (Medium inzwischen vergessen): nicht gegen die neue zählen.
        guard epoch == hangingEpoch[mediumUUID, default: 0] else { return }
        if completion.markHanging(onEnd: { Task { await self.partialReadReturned(mediumUUID, epoch: epoch) } }) {
            hangingPartialReads[mediumUUID, default: 0] += 1
        }
    }

    /// bug.0.4.180 (c, d): Reste früherer Läufe eines vergessenen oder gelöschten Mediums – widerrufene Tokens, deren
    /// Beginn nie kommt, und noch hängende Zugriffe – nicht mehr führen.
    private func clearRunLeftovers(_ mediumUUID: UUID) {
        // Wartet noch ein Beginn auf den Abschluss dieses Mediums, braucht er seinen Widerruf (bug.0.4.174) – dann bleibt
        // er stehen und wird beim Beginn verbraucht.
        if !finishingMedia.contains(mediumUUID), finishWaiters[mediumUUID, default: []].isEmpty {
            revokedIndexingTokens = revokedIndexingTokens.filter { $0.value != mediumUUID }
        }
        hangingPartialReads[mediumUUID] = nil
        hangingEpoch[mediumUUID, default: 0] += 1
    }

    /// bug.0.4.176 (b): ein hängender Lesevorgang ist zurückgekehrt (nur, wenn er aus der laufenden Zeit stammt).
    private func partialReadReturned(_ mediumUUID: UUID, epoch: Int) {
        guard epoch == hangingEpoch[mediumUUID, default: 0] else { return }
        let left = (hangingPartialReads[mediumUUID] ?? 1) - 1
        hangingPartialReads[mediumUUID] = left > 0 ? left : nil
    }

    /// bug.0.4.141: Schlüssel in `storage_meta` (neuer Schlüssel, Schema unverändert, Regel 27); Liste der Zeilen-IDs.
    nonisolated static let pendingReconnectKey = "pendingReconnectIDs"
    private nonisolated static let pendingReconnectLimit = 50_000

    private nonisolated static func pendingReconnectIDs(_ db: Database, _ storageID: Int64) throws -> Set<Int64> {
        let value = try String.fetchOne(
            db,
            sql: """
                SELECT m.value FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                WHERE m.storageID = ? AND k.key = ?
                """,
            arguments: [storageID, pendingReconnectKey]
        )
        guard let value, !value.isEmpty else { return [] }
        return Set(value.split(separator: ",").compactMap { Int64($0) })
    }

    /// bug.0.4.165 (a): Wiederverbinden ist möglich – das Medium hat verschwundene Zeilen (`status = 2`) oder war schon
    /// einmal vollständig indiziert (dann kann der alte Ort einer verschobenen Datei auch erst später gelesen werden).
    /// bug.0.4.228: `status` als Literal und `INDEXED BY items_gone` – sonst las die Abfrage beim Erstindex je Stapel alle
    /// Einträge des Mediums, in der Schreibtransaktion. Mit gebundenem Wert greift der Teilindex nicht, und auch mit Literal
    /// nahm SQLite in der App `items_children` (Spalte `storageID` vorn, Sortierung „natural“ registriert).
    private nonisolated static func mayReconnect(_ db: Database, _ storageID: Int64) throws -> Bool {
        if try Int64.fetchOne(db, sql: "SELECT firstIndexedAt FROM storages WHERE id = ?", arguments: [storageID]) != nil {
            return true
        }
        return try Bool.fetchOne(
            db,
            sql: """
                SELECT EXISTS (
                    SELECT 1 FROM items INDEXED BY items_gone WHERE storageID = ? AND status = \(ItemStatus.gone.rawValue)
                )
                """,
            arguments: [storageID]
        ) ?? false
    }

    /// bug.0.4.156 (c)/165 (a): neue Zeilen an den Merker anhängen – nur die neuen IDs (SQL hängt an, kein Lesen und
    /// Neuschreiben des Ganzen je Stapel). Bis zur Grenze (Länge des Werts); Abschneiden wird einmal protokolliert.
    /// Doppelte IDs stören nicht (gelesen wird als Menge, am Laufende neu geschrieben).
    private nonisolated static func appendPendingReconnectIDs(
        _ db: Database, _ storageID: Int64, _ ids: [Int64], maxLength pendingReconnectMaxLength: Int
    ) throws {
        let key = pendingReconnectKey
        try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES (?)", arguments: [key])
        let current = try Int.fetchOne(
            db,
            sql: """
                SELECT length(m.value) FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                WHERE m.storageID = ? AND k.key = ?
                """,
            arguments: [storageID, key]
        )
        // bug.0.4.171: nur so viele IDs, wie bis zur Grenze passen (nicht den ganzen Stapel darüber hinaus).
        let room = pendingReconnectMaxLength - (current.map { $0 + 1 } ?? 0)
        guard room > 0 else { return }  // schon voll (einmal protokolliert, als die Grenze erreicht wurde)
        let (piece, cut) = fittingPiece(ids, room: room)
        guard !piece.isEmpty else { return }
        if cut {
            DiskArchiveLog.shared.record(.index, .info, "reconnect pending truncated limit=\(pendingReconnectMaxLength)")
        }
        guard current != nil else {
            try db.execute(
                sql: "INSERT INTO storage_meta (storageID, keyID, value, date) SELECT ?, id, ?, NULL FROM meta_keys WHERE key = ?",
                arguments: [storageID, piece, key]
            )
            return
        }
        try db.execute(
            sql: """
                UPDATE storage_meta SET value = CASE WHEN value = '' THEN ? ELSE value || ',' || ? END
                WHERE storageID = ? AND keyID = (SELECT id FROM meta_keys WHERE key = ?)
                """,
            arguments: [piece, piece, storageID, key]
        )
    }


    /// bug.0.4.171: so viele IDs (kommagetrennt), wie in `room` Zeichen passen; `cut`: nicht alle passten.
    private nonisolated static func fittingPiece(_ ids: [Int64], room: Int) -> (piece: String, cut: Bool) {
        var parts: [String] = []
        var length = 0
        for id in ids {
            let text = String(id)
            let added = (parts.isEmpty ? 0 : 1) + text.utf8.count
            guard length + added <= room else { return (parts.joined(separator: ","), true) }
            parts.append(text)
            length += added
        }
        return (parts.joined(separator: ","), false)
    }

    private nonisolated static func writePendingReconnectIDs(
        _ db: Database, _ storageID: Int64, _ ids: [Int64], maxLength: Int
    ) throws {
        let key = pendingReconnectKey
        // bug.0.4.176 (a): dieselbe Grenze wie beim Anhängen je Stapel.
        let (value, cut) = fittingPiece(ids, room: maxLength)
        if cut {
            DiskArchiveLog.shared.record(.index, .info, "reconnect pending truncated limit=\(maxLength)")
        }
        try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES (?)", arguments: [key])
        try db.execute(
            sql: """
                INSERT OR REPLACE INTO storage_meta (storageID, keyID, value, date)
                SELECT ?, id, ?, NULL FROM meta_keys WHERE key = ?
                """,
            arguments: [storageID, value, key]
        )
    }

    #if DEBUG
    /// Tests (bug.0.4.165 a): Stapel, die den Merker beschrieben haben.
    private(set) var pendingReconnectWritesForTesting = 0
    /// Tests (bug.0.4.180 c): widerrufene Tokens eines Mediums, deren Beginn noch aussteht.
    func revokedIndexingTokensForTesting(mediumUUID: UUID) -> Int {
        revokedIndexingTokens.values.filter { $0 == mediumUUID }.count
    }
    /// Tests (bug.0.4.176 b): Lesevorgänge des Mediums, die noch über ihre Zeitgrenze hinaus hängen.
    func hangingPartialReadsForTesting(mediumUUID: UUID) -> Int { hangingPartialReads[mediumUUID] ?? 0 }
    /// Tests (bug.0.4.171): Länge des gespeicherten Merkers (Zeichen).
    func pendingReconnectValueLengthForTesting(mediumUUID: UUID) async throws -> Int {
        try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return 0 }
            return try Int.fetchOne(
                db,
                sql: """
                    SELECT length(m.value) FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                    WHERE m.storageID = ? AND k.key = ?
                    """,
                arguments: [storageID, Self.pendingReconnectKey]
            ) ?? 0
        }
    }
    /// Tests (bug.0.4.175): ersetzt die Prüfung „unter diesem Pfad ist dieses Medium eingehängt“ (Testordner stehen für
    /// ein eingehängtes Medium).
    func setMountCheckForTesting(_ check: (@Sendable (String, StoredMedium) async -> Bool)?) { mountCheckForTesting = check }
    private var mountCheckForTesting: (@Sendable (String, StoredMedium) async -> Bool)?
    /// Tests (bug.0.4.177 c): ersetzt die Prüfung „der Einhängepunkt ist noch einer“ beim Lesen (lesender Faden). Ohne
    /// diesen Haken, aber mit `mountCheckForTesting`, gilt der Testordner als Einhängepunkt, solange es ihn gibt.
    func setMountPointCheckForTesting(_ check: (@Sendable (String) -> Bool)?) { mountPointCheckForTesting = check }
    private var mountPointCheckForTesting: (@Sendable (String) -> Bool)?
    /// Tests (bug.0.4.179): ersetzt nur die Volume-Abfrage der echten Prüfung (mit eigener Zeitgrenze).
    func setMountLookupForTesting(_ lookup: (@Sendable (URL) -> VolumeInfo?)?, timeout: TimeInterval) {
        mountLookupForTesting = lookup
        mountLookupTimeout = timeout
    }
    private var mountLookupForTesting: (@Sendable (URL) -> VolumeInfo?)?
    /// Tests (bug.0.4.171): Obergrenze des Merkers (Zeichen) kleiner setzen.
    func setPendingReconnectMaxLengthForTesting(_ length: Int) { pendingReconnectMaxLength = length }
    /// Tests (bug.0.4.171): läuft vor jedem Nachschlagen einer vorab gelesenen Teil-Prüfsumme in der Transaktion.
    func setPartialLookupHookForTesting(_ hook: (@Sendable () throws -> Void)?) { partialLookupHookForTesting = hook }
    private var partialLookupHookForTesting: (@Sendable () throws -> Void)?
    /// Tests (bug.0.4.156 c): gemerkte Zuordnung eines Mediums.
    func pendingReconnectIDsForTesting(mediumUUID: UUID) async throws -> Set<Int64> {
        try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            return try Self.pendingReconnectIDs(db, storageID)
        }
    }
    #endif

    private nonisolated static func storePendingReconnectIDs(
        _ db: Database, _ storageID: Int64, _ ids: Set<Int64>, maxLength: Int
    ) throws {
        let key = pendingReconnectKey
        var keep: [Int64] = []
        if !ids.isEmpty {
            // Nur noch sichtbare, nicht wiederverbundene Zeilen.
            let all = Array(ids)
            var offset = 0
            while offset < all.count {
                let chunk = Array(all[offset..<min(offset + 500, all.count)])
                offset += 500
                let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
                let found = try Int64.fetchAll(
                    db,
                    sql: "SELECT id FROM items WHERE storageID = ? AND status = 0 AND id IN (\(marks))",
                    arguments: StatementArguments([storageID] + chunk)
                )
                keep.append(contentsOf: found)
                if keep.count >= pendingReconnectLimit { break }
            }
        }
        if keep.isEmpty {
            try db.execute(
                sql: "DELETE FROM storage_meta WHERE storageID = ? AND keyID IN (SELECT id FROM meta_keys WHERE key = ?)",
                arguments: [storageID, key]
            )
            return
        }
        keep.sort()
        if keep.count > pendingReconnectLimit || ids.count > keep.count && keep.count >= pendingReconnectLimit {
            DiskArchiveLog.shared.record(.index, .info, "reconnect pending truncated limit=\(pendingReconnectLimit) ids=\(ids.count)")
        }
        try writePendingReconnectIDs(db, storageID, Array(keep.prefix(pendingReconnectLimit)), maxLength: maxLength)
    }

    @discardableResult
    private nonisolated static func deleteGoneItems(_ db: Database, storageID: Int64, keeping: Set<Int64> = []) throws -> Int {
        guard !keeping.isEmpty else {
            try db.execute(
                sql: "DELETE FROM items WHERE storageID = ? AND status = ?",
                arguments: [storageID, ItemStatus.gone.rawValue]
            )
            return db.changesCount
        }
        // bug.0.4.156 (b): Kandidaten mit unlesbarem Gegenstück bleiben (samt Favorit) bis zum Folgelauf.
        try db.execute(sql: "CREATE TEMP TABLE IF NOT EXISTS keep_gone (id INTEGER PRIMARY KEY)")
        try db.execute(sql: "DELETE FROM keep_gone")
        for id in keeping {
            try db.execute(sql: "INSERT OR IGNORE INTO keep_gone (id) VALUES (?)", arguments: [id])
        }
        try db.execute(
            sql: "DELETE FROM items WHERE storageID = ? AND status = ? AND id NOT IN (SELECT id FROM keep_gone)",
            arguments: [storageID, ItemStatus.gone.rawValue]
        )
        let deleted = db.changesCount
        try db.execute(sql: "DELETE FROM keep_gone")
        return deleted
    }

    func indexingIsActive(mediumUUID: UUID, token: UUID) -> Bool {
        indexingToken[mediumUUID] == token
    }

    func hasActiveIndexingToken(mediumUUID: UUID) -> Bool {
        indexingToken[mediumUUID] != nil
    }

    func recordEventCursor(mediumUUID: UUID, fsEventsUUID: String?, lastEventID: Int64) async throws {
        #if DEBUG
        recordEventCursorCallCountForTesting += 1
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
            DiskArchiveLog.shared.record(.store, .info, "setFavorites count=\(ids.count)")
            for uuid in mediumUUIDs { emit(.counts(uuid)) }
        } catch {
            DiskArchiveLog.shared.record(.store, .error, "setFavorites \(DiskArchiveLog.errorSummary(error))")
            throw error
        }
    }

    /// Live-Rename aus FSEvents-Paar (235b).
    func applyLiveRename(mediumUUID: UUID, mountPath: String, fromPath: String, toPath: String) async throws -> Bool {
        let partialMatching = partialMatchingEnabled
        let (renameSizeBytes, renameModifiedAt, renamePartialDigest) = try await LiveRenameTarget.fields(
            toPath: toPath,
            partialMatching: partialMatching
        )
        let folderPaths: [[String]] = try await pool.write { db -> [[String]] in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let writer = try DirectoryWriterV3(db: db, storageID: storageID, partialMatchingEnabled: partialMatching)
            let step = try writer.applyLivePathRename(
                mountPath: mountPath,
                fromAbsolute: fromPath,
                toAbsolute: toPath,
                seenAt: Date(),
                toSizeBytes: renameSizeBytes,
                toModifiedAt: renameModifiedAt,
                toPartialDigest: renamePartialDigest
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
            let parts = path.split(separator: "/").map(String.init)
            guard let name = parts.last else { return nil }
            // bug.0.4.226: Pfad ohne Plattenzugriff.
            return DirectoryWriterV3.fileURL(mountPath: mountPath, parentSegments: Array(parts.dropLast()), name: name)
        }
        guard let fileURL else { return }
        #if DEBUG
        let testDelay = partialChecksumComputeDelayForTesting
        #else
        let testDelay: TimeInterval? = nil
        #endif
        guard let computed = try await PartialChecksum.computeOffActor(at: fileURL, testComputeDelay: testDelay) else { return }
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
        // bug.0.4.228: erst nach dem Schreiben verwerfen – ein danach begonnenes Lesen sieht die neue Größe.
        comparableSizesByMedium.removeAll()
        comparableSizesGeneration += 1
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
                    sql: "SELECT id, storageID, parentID, name, depth, status FROM items WHERE id > ? AND status IN (?, ?) ORDER BY id LIMIT ?",
                    arguments: [afterID, visible, toDelete, batchSize]
                )
                guard let last: Int64 = rows.last?["id"] else { return (0, nil, []) }
                var hideIDs: [Int64] = []
                var showIDs: [Int64] = []
                var storages = Set<Int64>()
                var hiddenAncestors: [Int64: Bool] = [:]
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
                        // bug.0.4.103: nicht wieder sichtbar machen, solange ein Vorfahre verdeckt ist (Nachfahre
                        // eines ignorierten Ordners, dessen eigener Name nicht passt).
                        let parentID: Int64? = row["parentID"]
                        guard try !Self.hasHiddenAncestor(db, parentID: parentID, scope: scope, memo: &hiddenAncestors) else {
                            continue
                        }
                        showIDs.append(id)
                        storages.insert(storageID)
                    }
                }
                let hidden = try Self.markItemSubtrees(db, roots: hideIDs, newStatus: toDelete, priorStatus: visible)
                let shown = try Self.markItemSubtrees(db, roots: showIDs, newStatus: visible, priorStatus: toDelete)
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
        DiskArchiveLog.shared.record(.index, .info, "index reconcile status=\(changed) ms=\(ms)")
        return changed
    }

    /// bug.0.4.103: Ob ein Vorfahre (ab `parentID` aufwärts) laut `scope` verdeckt ist; `memo` je Stapel.
    private nonisolated static func hasHiddenAncestor(
        _ db: Database,
        parentID: Int64?,
        scope: IndexScope,
        memo: inout [Int64: Bool]
    ) throws -> Bool {
        var chain: [Int64] = []
        var current = parentID
        var hidden = false
        while let id = current {
            if let known = memo[id] {
                hidden = known
                break
            }
            chain.append(id)
            guard let row = try Row.fetchOne(db, sql: "SELECT parentID, name, depth FROM items WHERE id = ?", arguments: [id]) else {
                break
            }
            let name: String = row["name"]
            let depth: Int = row["depth"]
            if scope.shouldHide(name: name, depth: depth) {
                hidden = true
                break
            }
            current = row["parentID"]
        }
        for id in chain { memo[id] = hidden }
        return hidden
    }

    /// Löscht alle Einträge mit `status = zu-löschen` endgültig (234).
    func purgeMarkedItems(batchSize: Int = 5_000, maxBatches: Int? = nil) async throws -> Int {
        let started = ContinuousClock.now
        var removed = 0
        var batches = 0
        var cursor: Int64 = 0
        var touchedStorages = Set<Int64>()
        let toDelete = ItemStatus.toDelete.rawValue

        while true {
            if let maxBatches, batches >= maxBatches { break }
            let afterID = cursor
            let step: (deleted: Int, last: Int64?, storages: Set<Int64>) = try await pool.write { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT id, storageID FROM items WHERE status = ? AND id > ? ORDER BY id LIMIT ?",
                    arguments: [toDelete, afterID, batchSize]
                )
                guard let last: Int64 = rows.last?["id"] else { return (0, nil, []) }
                let ids = rows.map { $0["id"] as Int64 }
                let storages = Set(rows.map { $0["storageID"] as Int64 })
                let deleted = try Self.deleteItems(db, ids: ids)
                return (deleted, last, storages)
            }
            batches += 1
            removed += step.deleted
            touchedStorages.formUnion(step.storages)
            guard let last = step.last else { break }
            cursor = last
        }
        if !touchedStorages.isEmpty {
            try await applyReconcileMeta(touchedStorages: touchedStorages, maxDepth: nil)
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
        DiskArchiveLog.shared.record(.index, .info, "index purge marked=\(removed) ms=\(ms)")
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

    private nonisolated static func markItemSubtrees(
        _ db: Database,
        roots: [Int64],
        newStatus: Int,
        priorStatus: Int
    ) throws -> Int {
        guard !roots.isEmpty else { return 0 }
        var updated = 0
        var offset = 0
        while offset < roots.count {
            let chunk = Array(roots[offset..<min(offset + 100, roots.count)])
            let marks = Array(repeating: "?", count: chunk.count).joined(separator: ", ")
            try db.execute(
                sql: """
                    WITH RECURSIVE sub(id) AS (
                        SELECT id FROM items WHERE id IN (\(marks))
                        UNION ALL
                        SELECT i.id FROM items i INNER JOIN sub ON i.parentID = sub.id
                    )
                    UPDATE items SET status = ?
                    WHERE id IN (SELECT id FROM sub) AND status = ?
                    """,
                arguments: StatementArguments(chunk + [newStatus, priorStatus])
            )
            updated += db.changesCount
            offset += 100
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

    /// bug.0.4.225: Teil-Prüfsummen nur für Dateien, die gegen einen Eintrag mit gespeicherter Teil-Prüfsumme verglichen
    /// werden können. Jeder Vergleich (`DirectoryWriterV3.resolveIdentityMatch`) verlangt dieselbe Größe; Dateien ohne
    /// solchen Gegenpart werden nicht gelesen – beim Erstindex und ohne Favoriten also keine. Vorher las jeder Stapel
    /// Anfang und Ende jeder Datei (exFAT mit großen Dateien: eine Datei pro Minute).
    private func precomputedPartials(
        mediumUUID: UUID,
        mountPath: String?,
        parentID: Int64?,
        entries: [ScannedEntry],
        enabled: Bool
    ) async throws -> [String: Data]? {
        guard enabled, let mountPath else { return nil }
        // Pakete sind auf der Platte Ordner: keine Teil-Prüfsumme (das Lesen wirft, der Live-Abgleich fiel dann auf einen
        // Vollabgleich zurück – `PackageAndTrashesWatcherTests`).
        let files = entries.filter { !$0.isFolder && !$0.isPackage }
        guard !files.isEmpty else { return nil }
        let comparableSizes = try await comparableSizes(mediumUUID: mediumUUID)
        let wanted = files.filter { comparableSizes.contains($0.sizeBytes) }
        guard !wanted.isEmpty else { return nil }
        let segments: [String] = try await pool.read { db in
            guard let parentID else { return [] }
            return try DirectoryWriterV3.segments(db, itemID: parentID)
        }
        var map: [String: Data] = [:]
        #if DEBUG
        let testDelay = partialChecksumComputeDelayForTesting
        #else
        let testDelay: TimeInterval? = nil
        #endif
        for entry in wanted {
            let url = DirectoryWriterV3.fileURL(mountPath: mountPath, parentSegments: segments, name: entry.name)
            #if DEBUG
            precomputeReadHookForTesting.run()
            #endif
            if let computed = try await PartialChecksum.computeOffActor(at: url, testComputeDelay: testDelay) {
                map[entry.name] = computed.partial
            }
        }
        return map.isEmpty ? nil : map
    }

    /// bug.0.4.228: vergleichbare Größen des Mediums, gemerkt bis zum nächsten Speichern einer Teil-Prüfsumme. Die Abfrage
    /// geht von `item_checksum` aus (`CROSS JOIN` legt die Reihenfolge fest) – sonst nahm SQLite alle Einträge des Mediums
    /// über `items_identity` und sah je Zeile in `item_checksum` nach, auch wenn die Tabelle leer ist.
    private func comparableSizes(mediumUUID: UUID) async throws -> Set<Int64?> {
        if let cached = comparableSizesByMedium[mediumUUID] { return cached }
        let generation = comparableSizesGeneration
        #if DEBUG
        comparableSizeQueriesForTesting += 1
        #endif
        let sizes: Set<Int64?> = try await pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT d.sizeBytes FROM item_checksum c
                    CROSS JOIN items i ON i.id = c.itemID
                    LEFT JOIN item_details d ON d.itemID = c.itemID
                    WHERE i.storageID = ? AND i.isFolder = 0
                    """,
                arguments: [storageID]
            )
            return Set(rows.map { $0["sizeBytes"] as Int64? })
        }
        if generation == comparableSizesGeneration { comparableSizesByMedium[mediumUUID] = sizes }
        return sizes
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

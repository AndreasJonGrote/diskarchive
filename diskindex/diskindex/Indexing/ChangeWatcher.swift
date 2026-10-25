//
//  ChangeWatcher.swift
//  diskindex
//

import CoreServices
import Foundation

struct VolumeChange: Sendable, Equatable {
    var path: String
    var eventID: Int64
    var fileSystemUUID: String?
    var mustScanSubDirs: Bool = false
    var rootChanged: Bool = false
    var unmounted: Bool = false
    var itemCreated: Bool = false
    var itemRemoved: Bool = false
    var itemRenamed: Bool = false
}

protocol ChangeSource: Sendable {
    func changes() -> AsyncStream<VolumeChange>
}

@MainActor
final class ChangeWatcher {
    private let store: IndexStoreV3
    private let access: any MediumAccess
    private let appState: AppState
    /// Voller ebenenweiser Abgleich. Zeilen bleiben erhalten (`fromScratch` setzt nur die Tiefe zurück).
    var onFullReconcile: ((UUID, VolumeInfo) -> Void)?
    var connectedVolumes: () -> [(id: UUID, volume: VolumeInfo)] = { [] }
    /// Laufender Index-Lauf (LiveWiring setzt das); Flush ohne DB-Schreiben.
    var isIndexingActive: (UUID) -> Bool = { _ in false }
    /// Produktion: 2 Sekunden. Tests setzen einen kürzeren Wert.
    var quietInterval: Duration = .seconds(2)
    /// Tests ohne echte Dateien am Mount (235b Live-Paare).
    nonisolated(unsafe) var pathExistsForLiveRename: @Sendable (String) -> Bool = {
        FileManager.default.fileExists(atPath: $0)
    }
    /// Spätestens nach dieser Zeit wird trotz weiterer Ereignisse nachgelesen.
    var maxQuietInterval: Duration = .seconds(30)
    /// Takt, in dem der Ereignisstand gesichert wird; `nil` schaltet den Zeitgeber ab (Tests, bug.0.3.8.007).
    var cursorSaveInterval: Duration? = .seconds(5)

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var sources: [UUID: any ChangeSource] = [:]
    private var quietTasks: [UUID: Task<Void, Never>] = [:]
    private var pending: [UUID: Set<String>] = [:]
    private var pendingItemEvents: [UUID: [ItemPathEvent]] = [:]
    /// bug.0.4.130: je Medium höchstens ein Vollabgleich aus „MustScanSubDirs“ je Bündel.
    private var fullReconcileRequested: Set<UUID> = []
    private var pendingSince: [UUID: ContinuousClock.Instant] = [:]
    private var cursors: [UUID: (uuid: String?, eventID: Int64)] = [:]
    private var savedCursors: [UUID: Int64] = [:]
    private var mounts: [UUID: String] = [:]
    private var volumes: [UUID: VolumeInfo] = [:]
    private var cursorTimer: Task<Void, Never>?
    private var watchGenerations: [UUID: Int] = [:]
    /// Laufender Flush je Medium mit eigener Nummer (bug.0.4.080 c): Das `defer` eines alten Flushes entfernt nur seine
    /// eigene Marke, nicht die eines neuen Flushes nach `stopAllForVersionLock` und schnellem Entsperren.
    private var flushInFlight: [UUID: Int] = [:]
    private var flushSerial = 0
    private var flushAgain: Set<UUID> = []
    private var pauseGeneration = 0
    /// Nur `stopAllForVersionLock` erhöht sie (bug.0.4.076 d): ein laufender Flush aus der Zeit davor legt keine
    /// Pfade zurück und schreibt nicht mehr, auch nicht nach schnellem Entsperren. Normales stop/start lässt sie stehen.
    private var versionLockGeneration = 0
    private let engine: ChangeWatcherEngine
    #if DEBUG
    /// Tests (bug.0.4.076 d): läuft im Flush nach dem Vorbereiten, vor der erneuten Sperr-Prüfung. Je Instanz.
    var flushAfterPrepareHookForTesting: (@MainActor () async -> Void)?
    func pendingPathsForTesting(_ mediumID: UUID) -> Set<String> { pending[mediumID] ?? [] }
    func pendingItemEventCountForTesting(_ mediumID: UUID) -> Int { pendingItemEvents[mediumID]?.count ?? 0 }
    func watchGenerationForTesting(_ mediumID: UUID) -> Int { watchGenerations[mediumID, default: 0] }
    var versionLockGenerationForTesting: Int { versionLockGeneration }
    func hasEventCursorForTesting(_ mediumID: UUID) -> Bool { cursors[mediumID] != nil || savedCursors[mediumID] != nil }
    func isFlushInFlightForTesting(_ mediumID: UUID) -> Bool { flushInFlight[mediumID] != nil }
    /// Quelle je Instanz statt FSEvents, wenn der Start keine mitgibt (bug.0.4.084: Start über `LiveWiring`).
    var makeSourceForTesting: ((VolumeInfo) -> ChangeSource)?
    #endif

    init(store: IndexStoreV3, access: any MediumAccess, appState: AppState) {
        self.store = store
        self.access = access
        self.appState = appState
        engine = ChangeWatcherEngine(store: store, access: access)
    }

    func start(
        mediumID: UUID,
        volume: VolumeInfo,
        source: ChangeSource? = nil,
        resumeFSEventsUUID: String? = nil,
        resumeLastEventID: Int64 = 0
    ) {
        guard tasks[mediumID] == nil else { return }
        // bug.0.4.063: gesperrt = nur ansehen; kein Start, auch nicht über Pausenende oder Neustart nach dem Aufwachen.
        guard appState.featureAccess.canWriteIndex else {
            DiskIndexLog.shared.record(.watcher, .info, "start übersprungen gesperrt medium=\(mediumID)")
            return
        }
        #if DEBUG
        let injected = source ?? makeSourceForTesting?(volume)
        #else
        let injected = source
        #endif
        let source = injected ?? FSEventsChangeSource(
            mountPath: volume.mountPath,
            resumeVolumeUUID: resumeFSEventsUUID,
            resumeLastEventID: resumeLastEventID > 0 ? FSEventStreamEventId(resumeLastEventID) : nil
        )
        sources[mediumID] = source
        mounts[mediumID] = volume.mountPath
        volumes[mediumID] = volume
        let generation = watchGenerations[mediumID, default: 0] + 1
        watchGenerations[mediumID] = generation
        tasks[mediumID] = Task { [weak self] in
            defer { Task { @MainActor in await self?.watchStreamEnded(mediumID, generation: generation) } }
            for await change in source.changes() {
                guard let self else { return }
                await self.ingest(mediumID, change)
            }
        }
        DiskIndexLog.shared.record(.watcher, .info, "start medium=\(mediumID)")
        startCursorTimer()
    }

    func saveCursor(mediumID: UUID) async {
        guard appState.featureAccess.canWriteIndex else { return }
        guard let cursor = cursors[mediumID] else { return }
        guard cursor.eventID != savedCursors[mediumID] else { return }
        // Vor dem Schreiben vormerken: ein zweiter Aufruf während des Schreibens (Flush, Zeitgeber) schreibt
        // denselben Stand nicht noch einmal (bug.0.3.8.007). Bei Fehler zurücknehmen.
        let previous = savedCursors[mediumID]
        savedCursors[mediumID] = cursor.eventID
        do {
            try await store.recordEventCursor(
                mediumUUID: mediumID,
                fsEventsUUID: cursor.uuid,
                lastEventID: cursor.eventID
            )
            DiskIndexLog.shared.record(.watcher, .info, "ereignisstand id=\(cursor.eventID) medium=\(mediumID)")
        } catch {
            if savedCursors[mediumID] == cursor.eventID {
                savedCursors[mediumID] = previous
            }
            DiskIndexLog.shared.record(.watcher, .error, "ereignisstand \(DiskIndexLog.errorSummary(error))")
        }
    }

    func stopAllForTermination() {
        cursorTimer?.cancel()
        cursorTimer = nil
        for id in Array(tasks.keys) {
            quietTasks[id]?.cancel()
            tasks[id]?.cancel()
        }
        quietTasks.removeAll()
        tasks.removeAll()
        sources.removeAll()
        pending.removeAll()
        pendingItemEvents.removeAll()
        pendingSince.removeAll()
        mounts.removeAll()
        volumes.removeAll()
    }

    /// bug.0.4.063: Sperre rastet ein. Alles stoppen ohne Schreiben; alte Ereignisstände verwerfen (nach dem
    /// Entsperren gilt der gespeicherte Stand), laufende Starts und Flushes über die Generation entwerten.
    func stopAllForVersionLock() {
        for id in Array(tasks.keys) {
            watchGenerations[id, default: 0] += 1
        }
        versionLockGeneration += 1
        stopAllForTermination()
        cursors.removeAll()
        savedCursors.removeAll()
        flushInFlight.removeAll()
        flushAgain.removeAll()
        pauseGeneration += 1
        DiskIndexLog.shared.record(.watcher, .info, "alle gestoppt sperre")
    }

    func isWatching(mediumID: UUID) -> Bool {
        tasks[mediumID] != nil
    }

    /// bug.0.4.161: Der angeforderte Abgleich ist gestartet (oder wurde verworfen) – eine neue Anforderung zählt wieder.
    func fullReconcileStarted(mediumID: UUID) {
        fullReconcileRequested.remove(mediumID)
    }

    func stop(mediumID: UUID) async {
        DiskIndexLog.shared.record(.watcher, .info, "stop medium=\(mediumID)")
        fullReconcileRequested.remove(mediumID)
        let cursor = cursors[mediumID]
        watchGenerations[mediumID, default: 0] += 1
        savedCursors[mediumID] = nil
        quietTasks[mediumID]?.cancel()
        quietTasks[mediumID] = nil
        tasks[mediumID]?.cancel()
        tasks[mediumID] = nil
        sources[mediumID] = nil
        pending[mediumID] = nil
        pendingItemEvents[mediumID] = nil
        pendingSince[mediumID] = nil
        mounts[mediumID] = nil
        volumes[mediumID] = nil
        flushInFlight[mediumID] = nil
        flushAgain.remove(mediumID)
        if let cursor, appState.featureAccess.canWriteIndex {
            do {
                try await store.recordEventCursor(
                    mediumUUID: mediumID,
                    fsEventsUUID: cursor.uuid,
                    lastEventID: cursor.eventID
                )
                savedCursors[mediumID] = cursor.eventID
            } catch {
                DiskIndexLog.shared.record(.watcher, .error, "ereignisstand \(DiskIndexLog.errorSummary(error))")
            }
        }
    }

    /// `skipping`: Medien, deren Überwachung erst nach einem gerade gestarteten Abgleich beginnt (über `onRunIndexed`,
    /// bug.0.4.080 b).
    func pauseChanged(skipping: Set<UUID> = []) {
        pauseGeneration += 1
        let generation = pauseGeneration
        Task { await applyPause(generation: generation, skipping: skipping) }
    }

    private func applyPause(generation: Int, skipping: Set<UUID>) async {
        if appState.globalAutoIndexPaused {
            for id in Array(tasks.keys) {
                guard generation == pauseGeneration else { return }
                await stop(mediumID: id)
            }
            return
        }
        for pair in connectedVolumes() {
            guard generation == pauseGeneration, !appState.globalAutoIndexPaused else { return }
            let id = pair.id
            guard tasks[id] == nil, !skipping.contains(id) else { continue }
            let stored: StoredMedium?
            do {
                stored = try await store.medium(uuid: id)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error medium pause \(DiskIndexLog.errorSummary(error))")
                }
                continue
            }
            guard let stored else { continue }
            guard stored.decision == .index, stored.hasCompleteIndexExceptGaps else { continue }
            start(
                mediumID: id,
                volume: pair.volume,
                resumeFSEventsUUID: stored.fsEventsUUID,
                resumeLastEventID: stored.lastEventID ?? 0
            )
        }
    }

    private func handleStreamUnmount(mediumID: UUID) async {
        DiskIndexLog.shared.record(.watcher, .info, "stream unmount medium=\(mediumID)")
        await saveCursor(mediumID: mediumID)
        quietTasks[mediumID]?.cancel()
        quietTasks[mediumID] = nil
        tasks[mediumID]?.cancel()
        tasks[mediumID] = nil
        sources[mediumID] = nil
        await restartWatchIfConnected(mediumID: mediumID)
    }

    private func watchStreamEnded(_ mediumID: UUID, generation: Int) async {
        guard watchGenerations[mediumID] == generation else { return }
        tasks[mediumID] = nil
        sources[mediumID] = nil
    }

    private func restartWatchIfConnected(mediumID: UUID) async {
        guard tasks[mediumID] == nil else { return }
        guard let pair = connectedVolumes().first(where: { $0.id == mediumID }) else { return }
        let stored: StoredMedium?
        do {
            stored = try await store.medium(uuid: mediumID)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error medium restart \(DiskIndexLog.errorSummary(error))")
            }
            return
        }
        guard let stored, stored.decision == .index else { return }
        let cursor = cursors[mediumID]
        start(
            mediumID: mediumID,
            volume: pair.volume,
            resumeFSEventsUUID: cursor?.uuid ?? stored.fsEventsUUID,
            resumeLastEventID: cursor?.eventID ?? stored.lastEventID ?? 0
        )
    }

    private func ingest(_ mediumID: UUID, _ change: VolumeChange) async {
        let previous = cursors[mediumID]?.eventID ?? 0
        cursors[mediumID] = (change.fileSystemUUID ?? cursors[mediumID]?.uuid, max(previous, change.eventID))
        if change.unmounted {
            await handleStreamUnmount(mediumID: mediumID)
            return
        }
        if change.rootChanged {
            // `WatchRoot` (bug.0.4.031): kommt beim Abziehen oft vor dem Aushängen, nach einer Umbenennung noch vom
            // alten Strom. Beides melden eigene Ereignisse (`.disappeared`, `.renamed`); hier kein Abgleich ins Leere.
            DiskIndexLog.shared.record(.watcher, .info, "wurzel geändert medium=\(mediumID), warte auf aushängen/umbenennen")
            return
        }
        if change.mustScanSubDirs, let mount = mounts[mediumID] {
            let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
            let eventPath = URL(fileURLWithPath: change.path).standardizedFileURL.path
            let mountPrefix = mountPath.hasSuffix("/") ? mountPath : mountPath + "/"
            if eventPath != mountPath, !eventPath.hasPrefix(mountPrefix) {
                return
            }
            // bug.0.4.130 (b)/161: höchstens ein ausstehender Abgleich – weitere „MustScanSubDirs“ (z. B. im selben
            // Bündel) zählen erst wieder, wenn er gestartet oder verworfen ist (`fullReconcileStarted`); eine Anforderung
            // während des Laufs fängt der Dienst ab (`rerunAfterFinish`).
            guard !fullReconcileRequested.contains(mediumID) else { return }
            if let volume = volumes[mediumID] {
                fullReconcileRequested.insert(mediumID)
                onFullReconcile?(mediumID, volume)
            }
            return
        }
        if change.itemCreated || change.itemRemoved || change.itemRenamed {
            pendingItemEvents[mediumID, default: []].append(
                ItemPathEvent(
                    path: change.path,
                    itemCreated: change.itemCreated,
                    itemRemoved: change.itemRemoved,
                    itemRenamed: change.itemRenamed
                )
            )
        }
        guard let mount = mounts[mediumID] else { return }
        let mountPath = MediaMountPath.normalizedMount(mount)
        let eventPath = URL(fileURLWithPath: change.path).standardizedFileURL.path
        let mountPrefix = mountPath.hasSuffix("/") ? mountPath : mountPath + "/"
        guard eventPath == mountPath || eventPath.hasPrefix(mountPrefix) else { return }
        pending[mediumID, default: []].insert(change.path)
        if flushInFlight[mediumID] != nil {
            flushAgain.insert(mediumID)
            return
        }
        let now = ContinuousClock.now
        if pendingSince[mediumID] == nil {
            pendingSince[mediumID] = now
        }
        if let since = pendingSince[mediumID], since.duration(to: now) >= maxQuietInterval {
            quietTasks[mediumID]?.cancel()
            quietTasks[mediumID] = nil
            pendingSince[mediumID] = nil
            await flush(mediumID)
            return
        }
        quietTasks[mediumID]?.cancel()
        let interval = quietInterval
        quietTasks[mediumID] = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard let self, !Task.isCancelled else { return }
            self.quietTasks[mediumID] = nil
            self.pendingSince[mediumID] = nil
            await self.flush(mediumID)
        }
    }

    private func flush(_ mediumID: UUID) async {
        if flushInFlight[mediumID] != nil {
            flushAgain.insert(mediumID)
            return
        }
        flushSerial += 1
        let token = flushSerial
        flushInFlight[mediumID] = token
        defer {
            // Inzwischen gestoppt und neu gestartet: Marke und `flushAgain` gehören dem neuen Flush.
            if flushInFlight[mediumID] == token {
                flushInFlight[mediumID] = nil
                if flushAgain.remove(mediumID) != nil {
                    Task { await self.flush(mediumID) }
                }
            }
        }
        guard let mount = mounts[mediumID] else { return }
        guard appState.featureAccess.canWriteIndex else { return }
        if isIndexingActive(mediumID) {
            scheduleDeferredFlush(mediumID)
            return
        }
        let lockGeneration = versionLockGeneration
        let rawPaths = pending[mediumID] ?? []
        pending[mediumID] = []
        let rawItemEvents = pendingItemEvents[mediumID] ?? []
        pendingItemEvents[mediumID] = []
        pendingSince[mediumID] = nil
        let matcher = appState.appSettings.matcher
        let maxDepth = appState.appSettings.indexedMaxDepth
        let exists = pathExistsForLiveRename
        let prep = await engine.prepareFlush(
            rawPaths: rawPaths,
            itemEvents: rawItemEvents,
            mount: mount,
            matcher: matcher,
            maxDepth: maxDepth,
            fileExists: exists
        )
        #if DEBUG
        await flushAfterPrepareHookForTesting?()
        #endif
        var events = prep.directories
        // Erneut prüfen: Sperre kann zwischen Guard und Schreiben greifen (VersionLock-Tests).
        guard appState.featureAccess.canWriteIndex else {
            requeue(mediumID, lockGeneration: lockGeneration, paths: rawPaths, itemEvents: rawItemEvents)
            return
        }
        // Inzwischen gesperrt und wieder entsperrt: Stand von vor der Sperre verwerfen, nichts schreiben.
        guard lockGeneration == versionLockGeneration else { return }
        for (index, pair) in prep.renamePairs.enumerated() {
            guard appState.featureAccess.canWriteIndex else {
                requeue(mediumID, lockGeneration: lockGeneration, paths: rawPaths, itemEvents: rawItemEvents)
                return
            }
            guard lockGeneration == versionLockGeneration else { return }
            if (try? await store.applyLiveRename(
                mediumUUID: mediumID,
                mountPath: mount,
                fromPath: pair.fromPath,
                toPath: pair.toPath
            )) == true, index < prep.renameFollowUps.count {
                let followUp = prep.renameFollowUps[index]
                if let fromParent = followUp.fromParent {
                    events.insert(fromParent)
                }
                if let toParent = followUp.toParent {
                    events.insert(toParent)
                }
            }
        }
        guard appState.featureAccess.canWriteIndex else {
            requeue(mediumID, lockGeneration: lockGeneration, paths: rawPaths, itemEvents: rawItemEvents)
            return
        }
        guard lockGeneration == versionLockGeneration else { return }
        appState.beginMediumLiveSync(mediumID)
        defer { appState.endMediumLiveSync(mediumID) }
        let outcome = await engine.processPending(
            mediumID: mediumID,
            mount: mount,
            directories: Array(events),
            matcher: matcher,
            maxDepth: maxDepth,
            writeAllowed: { @MainActor [weak self, appState] in
                appState.featureAccess.canWriteIndex && self?.versionLockGeneration == lockGeneration
            }
        )
        guard lockGeneration == versionLockGeneration else { return }
        switch outcome {
        case .ok:
            await saveCursor(mediumID: mediumID)
        case .needsFullReconcile:
            if let volume = volumes[mediumID] {
                onFullReconcile?(mediumID, volume)
            }
        case .deferred:
            requeue(mediumID, lockGeneration: lockGeneration, paths: rawPaths, itemEvents: rawItemEvents)
            // Bei Sperre nicht erneut planen — nächster Flush nach Entsperren.
            if appState.featureAccess.canWriteIndex {
                scheduleDeferredFlush(mediumID)
            }
        }
    }

    /// Nicht geschriebene Pfade zurücklegen – nur, wenn seit Beginn des Flushes `stopAllForVersionLock` die Liste
    /// nicht geleert hat (bug.0.4.076 d: sonst alte Pfade nach dem Entsperren).
    private func requeue(_ mediumID: UUID, lockGeneration: Int, paths: Set<String>, itemEvents: [ItemPathEvent]) {
        guard versionLockGeneration == lockGeneration else { return }
        pending[mediumID, default: []].formUnion(paths)
        pendingItemEvents[mediumID, default: []].append(contentsOf: itemEvents)
    }

    private func scheduleDeferredFlush(_ mediumID: UUID) {
        guard quietTasks[mediumID] == nil else { return }
        let interval = quietInterval
        quietTasks[mediumID] = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard let self, !Task.isCancelled else { return }
            self.quietTasks[mediumID] = nil
            await self.flush(mediumID)
        }
    }

    private func startCursorTimer() {
        guard cursorTimer == nil, let interval = cursorSaveInterval else { return }
        cursorTimer = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: interval)
                for id in Array(self.tasks.keys) {
                    await self.saveCursor(mediumID: id)
                }
            }
        }
    }

}

private extension AppSettings {
    var matcher: IgnoreMatcher {
        IgnoreMatcher(
            ignoreHiddenFiles: ignoreHiddenFiles,
            excludedPatterns: excludedPatterns,
            artifactsIgnored: artifactsIgnored
        )
    }
}

nonisolated final class FSEventsChangeSource: ChangeSource, @unchecked Sendable {
    let mountPath: String
    private let resumeVolumeUUID: String?
    private let resumeLastEventID: FSEventStreamEventId?
    private let queue = DispatchQueue(label: "diskindex.fsevents")
    /// Erkennt, ob `close` schon auf `queue` läuft (kein `sync` auf die eigene Queue).
    private let queueKey = DispatchSpecificKey<UInt8>()
    #if DEBUG
    /// Tests (bug.0.4.062): das letzte `close` lief auf der Callback-Queue (gelesen über die Queue).
    private var lastCloseRanOnQueue: Bool?
    var lastCloseRanOnQueueForTesting: Bool? { queue.sync { lastCloseRanOnQueue } }
    private let testingLock = NSLock()
    private var receiveHook: (@Sendable () -> Void)?
    private var closeFinished = false
    /// Läuft synchron in jedem Callback auf `queue` (vor dem Weiterreichen). Je Instanz.
    func setReceiveHookForTesting(_ hook: (@Sendable () -> Void)?) { testingLock.withLock { receiveHook = hook } }
    /// Der Stream ist geschlossen (ohne `queue.sync` lesbar).
    var closeFinishedForTesting: Bool { testingLock.withLock { closeFinished } }
    #endif
    #if DEBUG
    /// Tests (bug.0.4.140): `open` lief auf der Callback-Queue.
    private var openRanOnQueue: Bool?
    var openRanOnQueueForTesting: Bool? { testingLock.withLock { openRanOnQueue } }
    /// Tests (bug.0.4.157): das Öffnen auf der Queue künstlich verzögern (je Instanz).
    var openDelayForTesting: TimeInterval?
    /// Tests (bug.0.4.157): andere Pfade beobachten (leer → `FSEventStreamCreate` schlägt über den echten Weg fehl).
    var watchedPathsForTesting: [String]?
    #endif
    /// bug.0.4.157: „Jetzt“ zum Zeitpunkt von `changes()` (synchron gelesen). Das Öffnen läuft asynchron; mit
    /// `sinceNow` gälte „jetzt“ erst dort, Ereignisse dazwischen gingen verloren.
    private var startEventID: FSEventStreamEventId?
    /// Fehlschlag beim Öffnen des Streams (Protokoll `.watcher .error`); Tests ersetzen die Senke.
    var logOpenFailure: @Sendable (String) -> Void = { DiskIndexLog.shared.record(.watcher, .error, $0) }
    private var stream: FSEventStreamRef?
    private var continuation: AsyncStream<VolumeChange>.Continuation?
    private var fileSystemUUID: String?

    init(mountPath: String, resumeVolumeUUID: String? = nil, resumeLastEventID: FSEventStreamEventId? = nil) {
        self.mountPath = mountPath
        self.resumeVolumeUUID = resumeVolumeUUID
        self.resumeLastEventID = resumeLastEventID
        queue.setSpecific(key: queueKey, value: 1)
    }

    deinit {
        close()
    }

    func changes() -> AsyncStream<VolumeChange> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.startEventID = FSEventsGetCurrentEventId()
            // bug.0.4.140: `stat`, UUID-Abfrage und Stream-Aufbau auf der eigenen Queue, nicht auf dem aufrufenden
            // (Haupt-)Faden – ein langsames Volume hielte sonst die Oberfläche an.
            self.queue.async { [self] in self.open() }
            continuation.onTermination = { [weak self] _ in
                // Nicht `sync`: ein Callback, der gerade `yield` ruft, wartete sonst auf diesen Abbruch (Verklemmung).
                self?.closeAsync()
            }
        }
    }

    private func open() {
        #if DEBUG
        testingLock.withLock { openRanOnQueue = DispatchQueue.getSpecific(key: queueKey) != nil }
        if let delay = openDelayForTesting { Thread.sleep(forTimeInterval: delay) }
        #endif
        var info = stat()
        let statResult = mountPath.withCString { stat($0, &info) }
        if statResult == 0, let uuid = FSEventsCopyUUIDForDevice(info.st_dev) {
            fileSystemUUID = CFUUIDCreateString(nil, uuid) as String
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        var watched = [mountPath]
        #if DEBUG
        if let override = watchedPathsForTesting { watched = override }
        #endif
        let paths = watched as CFArray
        // `WatchRoot` (bug.0.4.031 b): Umbenennen/Abziehen meldet `rootChanged`; das wird nur protokolliert, den Abgleich
        // bzw. das Offline-Setzen übernehmen `.renamed` und `.disappeared`.
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot
        )
        let start = FSEventsResume.streamStart(
            resumeVolumeUUID: resumeVolumeUUID,
            resumeLastEventID: resumeLastEventID,
            currentVolumeUUID: fileSystemUUID
        )
        if start.usesStoredCursor {
            DiskIndexLog.shared.record(.watcher, .info, "fsevents resume id=\(start.sinceEventID)")
        }
        // bug.0.4.157: ohne gespeicherten Stand ab dem Zeitpunkt von `changes()`, nicht ab dem (späteren) Öffnen.
        let since = start.usesStoredCursor ? start.sinceEventID : (startEventID ?? start.sinceEventID)
        guard let stream = FSEventStreamCreate(nil, Self.callback, &context, paths, since, 1.0, flags) else {
            logOpenFailure("fsevents stream konnte nicht erzeugt werden")
            continuation?.finish()
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        if !FSEventStreamStart(stream) {
            logOpenFailure("fsevents stream konnte nicht gestartet werden")
            close()
            continuation?.finish()
        }
    }

    /// bug.0.4.062 (REPORT 132): Der Kontext hält `self` unretained. Geschlossen wird immer auf der Callback-Queue:
    /// dort läuft kein Callback gleichzeitig, und nach `Invalidate` auf dieser Queue wird keiner mehr zugestellt.
    /// `deinit` und `open` warten (`sync`); `onTermination` reiht ein und hält `self` bis dahin (`closeAsync`).
    private func close() {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            closeOnQueue()
        } else {
            queue.sync { closeOnQueue() }
        }
    }

    private func closeAsync() {
        queue.async { [self] in closeOnQueue() }
    }

    private func closeOnQueue() {
        guard let stream else { return }
        #if DEBUG
        lastCloseRanOnQueue = DispatchQueue.getSpecific(key: queueKey) != nil
        #endif
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        #if DEBUG
        testingLock.withLock { closeFinished = true }
        #endif
    }

    private func receive(paths: [String], flags: [FSEventStreamEventFlags], ids: [FSEventStreamEventId]) {
        #if DEBUG
        let hook = testingLock.withLock { receiveHook }
        hook?()
        #endif
        for index in paths.indices where flags.indices.contains(index) && ids.indices.contains(index) {
            let flag = flags[index]
            // bug.0.4.157: Ende des Rückblicks (Start ab festem Stand) ist keine Änderung.
            if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) != 0 { continue }
            continuation?.yield(VolumeChange(
                path: paths[index],
                eventID: Int64(bitPattern: UInt64(ids[index])),
                fileSystemUUID: fileSystemUUID,
                mustScanSubDirs: flag & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0,
                rootChanged: flag & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0,
                unmounted: flag & FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount) != 0,
                itemCreated: flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0,
                itemRemoved: flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0,
                itemRenamed: flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
            ))
        }
    }

    private nonisolated static let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, eventIds in
        guard let info, numEvents > 0 else { return }
        let source = Unmanaged<FSEventsChangeSource>.fromOpaque(info).takeUnretainedValue()
        let array = unsafeBitCast(eventPaths, to: NSArray.self)
        var paths: [String] = []
        var flags: [FSEventStreamEventFlags] = []
        var ids: [FSEventStreamEventId] = []
        for index in 0..<numEvents {
            paths.append(array[index] as? String ?? "")
            flags.append(eventFlags[index])
            ids.append(eventIds[index])
        }
        source.receive(paths: paths, flags: flags, ids: ids)
    }
}

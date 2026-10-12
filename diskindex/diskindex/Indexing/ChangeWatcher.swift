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

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var sources: [UUID: any ChangeSource] = [:]
    private var quietTasks: [UUID: Task<Void, Never>] = [:]
    private var pending: [UUID: Set<String>] = [:]
    private var pendingItemEvents: [UUID: [ItemPathEvent]] = [:]
    private var pendingSince: [UUID: ContinuousClock.Instant] = [:]
    private var cursors: [UUID: (uuid: String?, eventID: Int64)] = [:]
    private var savedCursors: [UUID: Int64] = [:]
    private var mounts: [UUID: String] = [:]
    private var volumes: [UUID: VolumeInfo] = [:]
    private var cursorTimer: Task<Void, Never>?
    private var watchGenerations: [UUID: Int] = [:]
    private let engine: ChangeWatcherEngine

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
        let source = source ?? FSEventsChangeSource(
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
        guard let cursor = cursors[mediumID] else { return }
        guard cursor.eventID != savedCursors[mediumID] else { return }
        do {
            try await store.recordEventCursor(
                mediumUUID: mediumID,
                fsEventsUUID: cursor.uuid,
                lastEventID: cursor.eventID
            )
            savedCursors[mediumID] = cursor.eventID
            DiskIndexLog.shared.record(.watcher, .info, "ereignisstand id=\(cursor.eventID) medium=\(mediumID)")
        } catch {
            DiskIndexLog.shared.record(.watcher, .error, "ereignisstand \(error)")
        }
    }

    /// Beenden der App: alle FSEvents-Streams schließen (ohne async-Warten auf DB).
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

    func isWatching(mediumID: UUID) -> Bool {
        tasks[mediumID] != nil
    }

    func stop(mediumID: UUID) async {
        DiskIndexLog.shared.record(.watcher, .info, "stop medium=\(mediumID)")
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
        await saveCursor(mediumID: mediumID)
        mounts[mediumID] = nil
        volumes[mediumID] = nil
    }

    func pauseChanged() {
        Task { await applyPause() }
    }

    private func applyPause() async {
        if appState.globalAutoIndexPaused {
            for id in Array(tasks.keys) { await stop(mediumID: id) }
            return
        }
        for pair in connectedVolumes() {
            let id = pair.id
            guard tasks[id] == nil else { continue }
            let stored: StoredMedium?
            do {
                stored = try await store.medium(uuid: id)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error medium pause \(error)")
                }
                continue
            }
            guard let stored else { continue }
            guard stored.decision == .index, stored.indexStatus == .indexed else { continue }
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
                DiskIndexLog.shared.record(.store, .error, "store error medium restart \(error)")
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
            if let volume = volumes[mediumID] {
                onFullReconcile?(mediumID, volume)
            }
            return
        }
        if change.mustScanSubDirs, let mount = mounts[mediumID] {
            let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
            let eventPath = URL(fileURLWithPath: change.path).standardizedFileURL.path
            let mountPrefix = mountPath.hasSuffix("/") ? mountPath : mountPath + "/"
            if eventPath != mountPath, !eventPath.hasPrefix(mountPrefix) {
                return
            }
            if let volume = volumes[mediumID] {
                onFullReconcile?(mediumID, volume)
            }
            return
        }
        if change.itemCreated || change.itemRemoved || change.itemRenamed {
            let std = URL(fileURLWithPath: change.path).standardizedFileURL.path
            pendingItemEvents[mediumID, default: []].append(
                ItemPathEvent(
                    path: std,
                    itemCreated: change.itemCreated,
                    itemRemoved: change.itemRemoved,
                    itemRenamed: change.itemRenamed
                )
            )
        }
        guard let mount = mounts[mediumID],
              let directory = directoryToReread(change.path, mount: mount, mediumID: mediumID) else { return }
        pending[mediumID, default: []].insert(directory)
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
            self.pendingSince[mediumID] = nil
            await self.flush(mediumID)
        }
    }

    private func flush(_ mediumID: UUID) async {
        guard let mount = mounts[mediumID] else { return }
        if isIndexingActive(mediumID) {
            scheduleDeferredFlush(mediumID)
            return
        }
        var events = pending[mediumID] ?? []
        pending[mediumID] = []
        let itemEvents = pendingItemEvents[mediumID] ?? []
        pendingItemEvents[mediumID] = []
        pendingSince[mediumID] = nil
        let exists = pathExistsForLiveRename
        let pairs = LiveRenamePairs.pair(events: itemEvents, fileExists: exists)
        for pair in pairs {
            if (try? await store.applyLiveRename(
                mediumUUID: mediumID,
                mountPath: mount,
                fromPath: pair.fromPath,
                toPath: pair.toPath
            )) == true {
                events.insert(parentDirectory(pair.fromPath, mount: mount))
                events.insert(parentDirectory(pair.toPath, mount: mount))
            }
        }
        let matcher = appState.appSettings.matcher
        let maxDepth = appState.appSettings.indexedMaxDepth
        appState.beginMediumLiveSync(mediumID)
        defer { appState.endMediumLiveSync(mediumID) }
        let outcome = await engine.processPending(
            mediumID: mediumID,
            mount: mount,
            directories: Array(events),
            matcher: matcher,
            maxDepth: maxDepth
        )
        switch outcome {
        case .ok:
            await saveCursor(mediumID: mediumID)
        case .needsFullReconcile:
            if let volume = volumes[mediumID] {
                onFullReconcile?(mediumID, volume)
            }
        case .deferred:
            pending[mediumID, default: []].formUnion(events)
            pendingItemEvents[mediumID, default: []].append(contentsOf: itemEvents)
            scheduleDeferredFlush(mediumID)
        }
    }

    private func parentDirectory(_ path: String, mount: String) -> String {
        let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
        var parent = (URL(fileURLWithPath: path).standardizedFileURL.path as NSString).deletingLastPathComponent
        if parent.count < mountPath.count { parent = mountPath }
        return parent
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

    private func directoryToReread(_ path: String, mount: String, mediumID: UUID) -> String? {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
        guard standardized == mountPath || standardized.hasPrefix(mountPath + "/") else { return nil }
        let matcher = appState.appSettings.matcher
        let fileName = (standardized as NSString).lastPathComponent
        if matcher.shouldSkip(name: fileName, isHidden: fileName.hasPrefix(".")) { return nil }
        var parent = (standardized as NSString).deletingLastPathComponent
        if parent.count < mountPath.count { parent = mountPath }
        var relative = relativeComponents(parent, mount: mountPath)
        if relative.contains(where: { matcher.shouldSkip(name: $0, isHidden: $0.hasPrefix(".")) }) { return nil }
        if let maxDepth = appState.appSettings.indexedMaxDepth {
            let limit = max(0, maxDepth - 1)
            if relative.count > limit {
                relative = Array(relative.prefix(limit))
                var url = URL(fileURLWithPath: mountPath, isDirectory: true)
                for part in relative { url.appendPathComponent(part) }
                return url.path
            }
        }
        return parent
    }

    private func relativeComponents(_ path: String, mount: String) -> [String] {
        let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardized != mountPath else { return [] }
        let prefix = mountPath.hasSuffix("/") ? mountPath : mountPath + "/"
        guard standardized.hasPrefix(prefix) else { return [] }
        return standardized.dropFirst(prefix.count).split(separator: "/").map(String.init)
    }

    private func startCursorTimer() {
        guard cursorTimer == nil else { return }
        cursorTimer = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
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

nonisolated private final class FSEventsChangeSource: ChangeSource, @unchecked Sendable {
    let mountPath: String
    private let resumeVolumeUUID: String?
    private let resumeLastEventID: FSEventStreamEventId?
    private let queue = DispatchQueue(label: "diskindex.fsevents")
    private var stream: FSEventStreamRef?
    private var continuation: AsyncStream<VolumeChange>.Continuation?
    private var fileSystemUUID: String?

    init(mountPath: String, resumeVolumeUUID: String? = nil, resumeLastEventID: FSEventStreamEventId? = nil) {
        self.mountPath = mountPath
        self.resumeVolumeUUID = resumeVolumeUUID
        self.resumeLastEventID = resumeLastEventID
    }

    deinit {
        close()
    }

    func changes() -> AsyncStream<VolumeChange> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.open()
            continuation.onTermination = { [weak self] _ in
                self?.close()
            }
        }
    }

    private func open() {
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
        let paths = [mountPath] as CFArray
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        let start = FSEventsResume.streamStart(
            resumeVolumeUUID: resumeVolumeUUID,
            resumeLastEventID: resumeLastEventID,
            currentVolumeUUID: fileSystemUUID
        )
        if start.usesStoredCursor {
            DiskIndexLog.shared.record(.watcher, .info, "fsevents resume id=\(start.sinceEventID)")
        }
        let since = start.sinceEventID
        guard let stream = FSEventStreamCreate(nil, Self.callback, &context, paths, since, 1.0, flags) else {
            continuation?.finish()
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        if !FSEventStreamStart(stream) {
            close()
            continuation?.finish()
        }
    }

    private func close() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func receive(paths: [String], flags: [FSEventStreamEventFlags], ids: [FSEventStreamEventId]) {
        for index in paths.indices {
            let flag = flags[index]
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

//
//  MediumCoordinator.swift
//  diskindex
//

import AppKit
import Foundation

@MainActor
final class MediumCoordinator {
    private let store: IndexStoreV3
    private let access: any MediumAccess
    private let appState: AppState
    private var onIndexRequested: (UUID, VolumeInfo) -> Void
    var onIndexingInterrupted: ((UUID) async -> Void)?
    /// Fertig indiziertes Medium: Ereignisstrom, danach vollständiger Abgleich.
    var onReconcileRequested: ((UUID, VolumeInfo) -> Void)?
    var onWillUnmount: ((UUID) async -> Void)?
    var onMediumDisappeared: ((UUID) async -> Void)?
    /// Verbundenes Medium unter neuem Pfad (Umbenennung): Watcher bzw. Lauf mit neuem Volume neu starten.
    var onMediumRenamed: ((UUID, VolumeInfo) async -> Void)?
    /// Laufender Index für `connectKnown` (bug.0.4.028).
    var isIndexingActive: ((UUID) -> Bool)?
    private var requestedIndex: Set<UUID> = []
    private var mounted: [String: VolumeInfo] = [:]
    private var mediumByPath: [String: UUID] = [:]
    private var eventsTask: Task<Void, Never>?
    private var choiceTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?

    init(
        store: IndexStoreV3,
        access: any MediumAccess,
        appState: AppState,
        onIndexRequested: @escaping (UUID, VolumeInfo) -> Void = { _, _ in }
    ) {
        self.store = store
        self.access = access
        self.appState = appState
        self.onIndexRequested = onIndexRequested
        appState.onNewMediumChoice = { [weak self] id, allowIndexing, remember in
            self?.applyChoice(mediumID: id, allowIndexing: allowIndexing, remember: remember)
        }
    }

    func setIndexHandler(_ handler: @escaping (UUID, VolumeInfo) -> Void) {
        onIndexRequested = handler
    }

    func start(events: AsyncStream<MediumEvent>) {
        eventsTask = Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.applicationDidBecomeActive()
            }
        }
    }

    func stop() {
        eventsTask?.cancel()
        eventsTask = nil
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    func handle(_ event: MediumEvent) async {
        switch event {
        case .appeared(let volume):
            DiskIndexLog.shared.record(.medium, .info, "event appeared pathLen=\(volume.mountPath.count)")
            await volumeAppeared(volume)
        case .willDisappear(let path):
            DiskIndexLog.shared.record(.medium, .info, "event willDisappear pathLen=\(path.count)")
            if let id = mediumByPath[path] {
                await onWillUnmount?(id)
            }
        case .disappeared(let path):
            DiskIndexLog.shared.record(.medium, .info, "event disappeared pathLen=\(path.count)")
            await volumeDisappeared(path)
        case .renamed(let oldPath, let volume):
            DiskIndexLog.shared.record(.medium, .info, "event renamed pathLen=\(volume.mountPath.count)")
            await volumeRenamed(from: oldPath, to: volume)
        }
    }

    func applicationDidBecomeActive() async {
        await reprobeDeniedVolumes()
    }

    /// Tests warten darauf, dass der Dialog entschieden ist.
    func waitForChoice() async {
        await choiceTask?.value
    }

    private func volumeAppeared(_ volume: VolumeInfo) async {
        mounted[volume.mountPath] = volume
        let candidate = VolumeCandidateRule.isCandidate(volume.candidateInput)
        guard candidate else {
            DiskIndexLog.shared.record(.medium, .info, "candidate=nein pathLen=\(volume.mountPath.count)")
            return
        }
        do {
            let allMatches = try await store.candidates(for: volume.identity)
            // Klon (gleiche Volume-UUID): ein Medium, das schon unter einem anderen eingehängten Pfad steht, scheidet aus.
            // Nie zwei Pfade für ein Medium (bug.0.4.031 a).
            let matches = allMatches.filter { !isMountedElsewhere($0.medium.uuid, than: volume.mountPath) }
            if matches.count < allMatches.count {
                DiskIndexLog.shared.record(.medium, .info, "candidate=ja klon belegt=\(allMatches.count - matches.count) pathLen=\(volume.mountPath.count)")
            }
            if let known = singleStrongMatch(matches) {
                DiskIndexLog.shared.record(.medium, .info, "candidate=ja eingehängt id=\(known.medium.uuid) stärke=\(known.strength) entscheidung=\(known.medium.decision.rawValue)")
                try await connectKnown(known.medium, volume: volume)
                return
            }
            // Klon allein gesteckt (Nutzer 17.10.): gleich starke Treffer, keiner anderswo eingehängt → zuletzt gesehenes.
            if matches.count == allMatches.count, let recent = mostRecentlySeen(matches) {
                DiskIndexLog.shared.record(.medium, .info, "candidate=ja mehrdeutig zuletzt gesehen id=\(recent.medium.uuid) treffer=\(matches.count)")
                try await connectKnown(recent.medium, volume: volume)
                return
            }
            if matches.isEmpty {
                DiskIndexLog.shared.record(.medium, .info, "candidate=ja unbekannt pathLen=\(volume.mountPath.count)")
            } else {
                DiskIndexLog.shared.record(.medium, .info, "candidate=ja mehrdeutig treffer=\(matches.count) pathLen=\(volume.mountPath.count)")
            }
            await receiveUnknown(volume)
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.medium, .error, "erkennen \(error) pathLen=\(volume.mountPath.count)")
        }
    }

    private func isMountedElsewhere(_ mediumID: UUID, than path: String) -> Bool {
        mediumByPath.contains { $0.value == mediumID && $0.key != path && mounted[$0.key] != nil }
    }

    private func volumeRenamed(from oldPath: String, to volume: VolumeInfo) async {
        mounted[oldPath] = nil
        guard let id = mediumByPath.removeValue(forKey: oldPath) else {
            await volumeAppeared(volume)
            return
        }
        mounted[volume.mountPath] = volume
        mediumByPath[volume.mountPath] = id
        DiskIndexLog.shared.record(.medium, .info, "umbenannt id=\(id)", privateDetail: volume.mountPath)
        do {
            if var stored = try await store.medium(uuid: id) {
                stored.name = volume.name
                stored.lastSeenAt = Date()
                try await store.updateMediumRecognition(uuid: id, stored)
                publish(stored, connection: .connected)
            }
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "umbenennen \(error)")
            }
        }
        await onMediumRenamed?(id, volume)
    }

    /// Alle Treffer haben dieselbe starke Kennung: das Medium mit dem jüngsten `lastSeenAt` (Gleichstand: `uuid`, fest).
    private func mostRecentlySeen(_ matches: [MediumCandidate]) -> MediumCandidate? {
        guard matches.count >= 2, let first = matches.first,
              first.strength == .uuid || first.strength == .fingerprint,
              matches.allSatisfy({ $0.strength == first.strength }) else { return nil }
        return matches.max { lhs, rhs in
            let left = lhs.medium.lastSeenAt ?? .distantPast
            let right = rhs.medium.lastSeenAt ?? .distantPast
            if left != right { return left < right }
            return lhs.medium.uuid.uuidString < rhs.medium.uuid.uuidString
        }
    }

    /// Mehrere gleich starke Treffer werden nicht automatisch vermischt.
    private func singleStrongMatch(_ matches: [MediumCandidate]) -> MediumCandidate? {
        let strong = matches.filter { $0.strength == .uuid || $0.strength == .fingerprint }
        guard let best = strong.map(\.strength).max() else { return nil }
        let atBest = strong.filter { $0.strength == best }
        return atBest.count == 1 ? atBest[0] : nil
    }

    private func connectKnown(_ stored: StoredMedium, volume: VolumeInfo) async throws {
        let started = ContinuousClock.now
        defer { DiskIndexLog.shared.perfIfSlow("abgleich", since: started) }
        if !appState.featureAccess.canWriteIndex {
            publishConnectKnownReadOnly(stored, volume: volume)
            return
        }
        var recoveredFromError = false
        if stored.indexStatus == .error {
            switch await access.probe(volume) {
            case .denied:
                DiskIndexLog.shared.record(.medium, .error, "kein Zugriff", privateDetail: volume.mountPath)
                var denied = stored
                denied.lastSeenAt = Date()
                try await store.updateMediumRecognition(uuid: denied.uuid, denied)
                mediumByPath[volume.mountPath] = denied.uuid
                publish(denied, connection: .connected)
                DiskIndexLog.shared.record(.medium, .info, "abbruch kein Zugriff id=\(stored.uuid)")
                return
            case .granted:
                recoveredFromError = true
            }
        }
        try await store.recordIdentity(mediumUUID: stored.uuid, volume.identity)
        guard var fresh = try await store.medium(uuid: stored.uuid) else {
            DiskIndexLog.shared.record(.medium, .error, "abbruch medium fehlt id=\(stored.uuid)")
            return
        }
        fresh.name = volume.name
        fresh.fsType = volume.fsType
        fresh.volumeTotalBytes = volume.volumeTotalBytes
        fresh.diskSizeBytes = volume.diskSizeBytes
        fresh.type = volume.mediumType
        fresh.lastSeenAt = Date()
        if recoveredFromError {
            fresh.indexStatus = fresh.lastIndexedAt != nil ? .indexed : .pending
        }
        if let free = volume.volumeFreeBytes {
            fresh.capacityUsedBytes = max(0, volume.volumeTotalBytes - free)
        }
        try await store.updateMediumRecognition(uuid: fresh.uuid, fresh)
        if recoveredFromError {
            try await store.updateMediumIndexStatus(uuid: fresh.uuid, fresh.indexStatus)
        }
        mediumByPath[volume.mountPath] = fresh.uuid
        let wasOffline = appState.medium(with: fresh.uuid)?.connectionStatus != .connected
        publish(fresh, connection: .connected)
        if wasOffline, !Self.isRunningUnitTests {
            let mediumID = fresh.uuid
            let name = fresh.name
            let isFavoriteMedium = fresh.isFavorite
            // Nicht den Anschlusspfad blockieren.
            let mountPath = volume.mountPath
            Task { @MainActor [weak self] in
                await self?.notifyFavoritesOnlineIfNeeded(
                    mediumID: mediumID,
                    name: name,
                    isFavoriteMedium: isFavoriteMedium
                )
                try? await self?.store.backfillMissingFavoritePartials(
                    mediumUUID: mediumID,
                    mountPath: mountPath
                )
            }
        }
        if fresh.decision.refusesIndexing {
            DiskIndexLog.shared.record(.medium, .info, "abbruch indizierung verweigert id=\(fresh.uuid)")
            return
        }
        if fresh.decision == .undecided {
            requestDialog(fresh.uuid)
            DiskIndexLog.shared.record(.medium, .info, "dialog id=\(fresh.uuid)")
            return
        }
        if fresh.indexStatus == .indexing, isIndexingActive?(fresh.uuid) != true {
            fresh.indexStatus = fresh.lastIndexedAt != nil ? .indexed : .pending
            try await store.updateMediumIndexStatus(uuid: fresh.uuid, fresh.indexStatus)
            publish(fresh, connection: .connected)
        }
        if fresh.decision == .index, fresh.indexStatus == .indexed {
            let paused = appState.globalAutoIndexPaused
            if !paused {
                onReconcileRequested?(fresh.uuid, volume)
                DiskIndexLog.shared.record(.medium, .info, "abgleich id=\(fresh.uuid)")
            } else {
                DiskIndexLog.shared.record(.medium, .info, "abgleich wartet pause id=\(fresh.uuid)")
            }
            return
        }
        if fresh.decision == .index, fresh.indexStatus == .pending {
            requestIndex(mediumID: fresh.uuid, volume: volume)
            DiskIndexLog.shared.record(.medium, .info, "index anfordern id=\(fresh.uuid)")
        }
    }

    private func receiveUnknown(_ volume: VolumeInfo) async {
        guard appState.featureAccess.canWriteIndex else { return }
        let result = await access.probe(volume)
        switch result {
        case .granted:
            DiskIndexLog.shared.record(.medium, .info, "neu speichern pathLen=\(volume.mountPath.count)")
            await storeAndPresent(volume, status: .pending, openDialog: true)
        case .denied(let reason):
            DiskIndexLog.shared.record(.medium, .error, "kein Zugriff \(reason) pathLen=\(volume.mountPath.count)")
            await storeAndPresent(volume, status: .error, openDialog: false)
        }
    }

    private func storeAndPresent(_ volume: VolumeInfo, status: StoredIndexStatus, openDialog: Bool) async {
        guard appState.featureAccess.canWriteIndex else { return }
        if let existingID = mediumByPath[volume.mountPath], var existing = try? await store.medium(uuid: existingID) {
            existing.indexStatus = status
            existing.lastSeenAt = Date()
            existing.name = volume.name
            if status == .pending { existing.decision = .undecided }
            do {
                try await store.updateMediumRecognition(uuid: existing.uuid, existing)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.medium, .error, "updateMedium \(error)")
            }
            publish(existing, connection: .connected)
            if openDialog { requestDialog(existing.uuid) }
            return
        }
        let stored = StoredMedium(
            volumeUUID: volume.identity.volumeUUID,
            volumeCreatedAt: volume.identity.createdAt,
            fsType: volume.fsType,
            volumeTotalBytes: volume.volumeTotalBytes,
            diskSizeBytes: volume.diskSizeBytes,
            name: volume.name,
            type: volume.mediumType,
            decision: .undecided,
            indexStatus: status,
            allowIndexing: true,
            capacityUsedBytes: usedBytes(volume),
            lastSeenAt: Date()
        )
        do {
            try await store.upsertMedium(stored)
            mediumByPath[volume.mountPath] = stored.uuid
            publish(stored, connection: .connected)
            if openDialog { requestDialog(stored.uuid) }
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.medium, .error, "speichern \(error)")
        }
    }

    private func reprobeDeniedVolumes() async {
        for (path, volume) in mounted {
            guard let id = mediumByPath[path],
                  let stored = try? await store.medium(uuid: id),
                  stored.indexStatus == .error else { continue }
            guard case .granted = await access.probe(volume) else { continue }
            guard mounted[path] != nil else { continue }
            switch stored.decision {
            case .undecided:
                await storeAndPresent(volume, status: .pending, openDialog: true)
            case .dontIndex, .ignore:
                var updated = stored
                updated.indexStatus = .pending
                updated.lastSeenAt = Date()
                updated.name = volume.name
                do {
                    try await store.updateMediumRecognition(uuid: updated.uuid, updated)
                    mediumByPath[path] = updated.uuid
                    publish(updated, connection: .connected)
                } catch {
                    guard DiskIndexLog.isOperationalFailure(error) else { continue }
                    DiskIndexLog.shared.record(.medium, .error, "reprobe dontIndex \(error)")
                }
            case .index:
                do {
                    try await connectKnown(stored, volume: volume)
                } catch {
                    guard DiskIndexLog.isOperationalFailure(error) else { continue }
                    DiskIndexLog.shared.record(.medium, .error, "reprobe index \(error)")
                }
            }
        }
    }

    private func volumeDisappeared(_ path: String) async {
        mounted[path] = nil
        guard let id = mediumByPath.removeValue(forKey: path) else { return }
        DiskIndexLog.shared.record(.medium, .info, "ausgehängt id=\(id)", privateDetail: path)
        requestedIndex.remove(id)
        await onMediumDisappeared?(id)
        await onIndexingInterrupted?(id)
        do {
            if var stored = try await store.medium(uuid: id) {
                stored.lastSeenAt = Date()
                try await store.updateMediumLastSeen(uuid: id, at: stored.lastSeenAt ?? Date())
                publish(stored, connection: .offline)
                if !Self.isRunningUnitTests {
                    AppWindowPresenter.syncNewMediumPanels(appState: appState)
                }
            } else {
                appState.updateMedium(id: id) {
                    $0.connectionStatus = .offline
                    $0.lastSeenAt = Date()
                }
            }
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else {
                appState.updateMedium(id: id) {
                    $0.connectionStatus = .offline
                    $0.lastSeenAt = Date()
                }
                return
            }
            DiskIndexLog.shared.record(.store, .error, "aushängen \(error)")
            appState.updateMedium(id: id) {
                $0.connectionStatus = .offline
                $0.lastSeenAt = Date()
            }
        }
    }

    private func applyChoice(mediumID: UUID, allowIndexing: Bool, remember: Bool) {
        choiceTask = Task {
            guard appState.featureAccess.canWriteIndex else { return }
            let stored: StoredMedium
            do {
                guard var row = try await store.medium(uuid: mediumID) else {
                    DiskIndexLog.shared.record(.medium, .error, "entscheidung medium fehlt id=\(mediumID)")
                    return
                }
                row.rememberDecision = remember
                row.allowIndexing = allowIndexing
                if allowIndexing {
                    row.decision = .index
                    row.indexStatus = .pending
                } else {
                    row.decision = .dontIndex
                    let hasIndex = row.completedDepth >= 1 || row.fileCount + row.folderCount > 0
                    row.indexStatus = hasIndex ? .indexed : .pending
                }
                try await store.updateMediumDecision(uuid: mediumID, row)
                stored = row
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.medium, .error, "entscheidung \(error)")
                return
            }
            let connection: ConnectionStatus = volume(for: mediumID) != nil ? .connected : .offline
            publish(stored, connection: connection)
            if appState.offerReplaceMediumPrompt(newID: mediumID), !Self.isRunningUnitTests {
                AppWindowPresenter.openReplaceMediumPrompt(appState: appState)
            }
            guard allowIndexing, let volume = volume(for: mediumID) else { return }
            requestIndex(mediumID: mediumID, volume: volume)
        }
    }

    private func requestIndex(mediumID: UUID, volume: VolumeInfo) {
        guard appState.featureAccess.canWriteIndex else { return }
        guard requestedIndex.insert(mediumID).inserted else {
            DiskIndexLog.shared.record(.medium, .info, "index bereits angefordert id=\(mediumID)")
            return
        }
        onIndexRequested(mediumID, volume)
    }

    func clearIndexRequest(mediumID: UUID) {
        requestedIndex.remove(mediumID)
    }

    func requestIndexingAfterDecision(mediumID: UUID) {
        guard let volume = volume(for: mediumID) else { return }
        requestIndex(mediumID: mediumID, volume: volume)
    }

    func forget(mediumID: UUID) {
        mediumByPath = mediumByPath.filter { $0.value != mediumID }
        requestedIndex.remove(mediumID)
    }

    func volume(for mediumID: UUID) -> VolumeInfo? {
        connectedVolumes().first { $0.id == mediumID }?.volume
    }

    func connectedVolumes() -> [(id: UUID, volume: VolumeInfo)] {
        mediumByPath.compactMap { path, id in
            guard let volume = mounted[path] else { return nil }
            return (id: id, volume: volume)
        }
    }

    func isKnownConnected(volume: VolumeInfo) -> Bool {
        guard let id = mediumByPath[volume.mountPath], mounted[volume.mountPath] != nil else { return false }
        guard appState.medium(with: id)?.connectionStatus == .connected else { return false }
        return true
    }

    private func notifyFavoritesOnlineIfNeeded(mediumID: UUID, name: String, isFavoriteMedium: Bool) async {
        var count = isFavoriteMedium ? 1 : 0
        do {
            let items = try await store.favorites()
            count += items.filter { $0.mediumUUID == mediumID }.count
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "favorites notice \(error)")
            }
        }
        SystemNotice.postFavoritesOnline(name: name, favoriteCount: count, settings: appState.appSettings)
    }

    private func publishConnectKnownReadOnly(_ stored: StoredMedium, volume: VolumeInfo) {
        var display = stored
        display.name = volume.name
        display.fsType = volume.fsType
        display.volumeTotalBytes = volume.volumeTotalBytes
        display.diskSizeBytes = volume.diskSizeBytes
        display.type = volume.mediumType
        if let free = volume.volumeFreeBytes {
            display.capacityUsedBytes = max(0, volume.volumeTotalBytes - free)
        }
        mediumByPath[volume.mountPath] = display.uuid
        publish(display, connection: .connected)
        DiskIndexLog.shared.record(.medium, .info, "abgleich read-only id=\(display.uuid)")
    }

    private func requestDialog(_ id: UUID) {
        appState.enqueueNewMediumDecision(id)
        guard !Self.isRunningUnitTests else { return }
        AppWindowPresenter.syncNewMediumPanels(appState: appState)
    }

    private func publish(_ stored: StoredMedium, connection: ConnectionStatus) {
        let medium = stored.asMedium(connection: connection)
        if appState.medium(with: medium.id) == nil {
            appState.media.append(medium)
        } else {
            let preserveUserFields = appState.pendingMediumWrites[medium.id] != nil
            appState.updateMedium(id: medium.id) { current in
                let progress = current.indexingProgress
                current.name = medium.name
                current.type = medium.type
                current.connectionStatus = connection
                current.indexStatus = medium.indexStatus
                current.capacityTotalBytes = medium.capacityTotalBytes
                current.capacityUsedBytes = medium.capacityUsedBytes
                current.fileCount = medium.fileCount
                current.folderCount = medium.folderCount
                current.lastSeenAt = medium.lastSeenAt
                current.lastIndexedAt = medium.lastIndexedAt
                current.lastIndexActivityAt = medium.lastIndexActivityAt
                current.completedDepth = medium.completedDepth
                current.isForgotten = medium.isForgotten
                if !preserveUserFields {
                    // bug.0.4.043: Nutzerfelder nicht zurücksetzen, solange ein Write aussteht.
                    current.allowIndexing = medium.allowIndexing
                    current.autoIndexPaused = medium.autoIndexPaused
                    current.decision = medium.decision
                    current.showAbsoluteCapacity = medium.showAbsoluteCapacity
                    current.isFavorite = medium.isFavorite
                }
                if medium.indexStatus == .indexing {
                    current.indexingProgress = progress
                } else {
                    current.indexingProgress = medium.indexingProgress
                }
            }
        }
    }

    private func usedBytes(_ volume: VolumeInfo) -> Int64 {
        guard let free = volume.volumeFreeBytes else { return 0 }
        return max(0, volume.volumeTotalBytes - free)
    }

    private static var isRunningUnitTests: Bool { RuntimeEnvironment.isRunningTests }

}

extension StoredMedium {
    func asMedium(connection: ConnectionStatus) -> Medium {
        Medium(
            id: uuid,
            name: name,
            type: MediumType(rawValue: type.rawValue) ?? .hdd,
            connectionStatus: connection,
            indexStatus: IndexStatus(rawValue: indexStatus.rawValue) ?? .pending,
            allowIndexing: decision == .index,
            autoIndexPaused: autoIndexPaused,
            decision: decision,
            capacityTotalBytes: volumeTotalBytes,
            capacityUsedBytes: capacityUsedBytes,
            fileCount: fileCount,
            folderCount: folderCount,
            scanTotal: scanTotal,
            lastSeenAt: lastSeenAt,
            firstIndexedAt: firstIndexedAt,
            lastIndexedAt: lastIndexedAt,
            lastIndexActivityAt: lastIndexActivityAt,
            completedDepth: completedDepth,
            isForgotten: isForgotten,
            indexingProgress: 0,
            showAbsoluteCapacity: showAbsoluteCapacity,
            isFavorite: isFavorite
        )
    }
}

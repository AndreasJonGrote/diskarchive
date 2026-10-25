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

    #if DEBUG
    /// Tests warten darauf, dass der Dialog entschieden ist.
    func waitForChoice() async {
        await choiceTask?.value
    }
    #endif

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
            DiskIndexLog.shared.record(.medium, .error, "erkennen \(DiskIndexLog.errorSummary(error)) pathLen=\(volume.mountPath.count)")
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
                DiskIndexLog.shared.record(.store, .error, "umbenennen \(DiskIndexLog.errorSummary(error))")
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

    /// `askAgain: false` (Reprobe nach Fehler): in dieser Sitzung schon gefragt, Erkennungs-Dialog nicht erneut.
    private func connectKnown(_ stored: StoredMedium, volume: VolumeInfo, askAgain: Bool = true) async throws {
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
                // bug.0.4.062: während des Schreibens ausgehängt → nicht „verbunden“ melden.
                guard isPathStill(for: denied.uuid, at: volume.mountPath) else { return }
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
            // bug.0.4.126: „indiziert“ nur nach einem Lauf bis zum Ende, nicht nach der ersten fertigen Ebene.
            fresh.indexStatus = await settledStatus(fresh)
        }
        if let free = volume.volumeFreeBytes {
            fresh.capacityUsedBytes = max(0, volume.volumeTotalBytes - free)
        }
        try await store.updateMediumRecognition(uuid: fresh.uuid, fresh)
        if recoveredFromError {
            try await store.updateMediumIndexStatus(uuid: fresh.uuid, fresh.indexStatus)
        }
        // bug.0.4.062: während der Store-Schritte ausgehängt → nicht wieder eintragen, nicht „verbunden“ melden.
        guard isPathStill(for: fresh.uuid, at: volume.mountPath) else {
            DiskIndexLog.shared.record(.medium, .info, "abbruch ausgehängt id=\(fresh.uuid)")
            return
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
        // todo.0.4.026: ohne „Für dieses Medium merken“ erscheint der Erkennungs-Dialog beim Anschließen wieder
        // (Vorbelegung = letzte Entscheidung). Bis zur Antwort gilt die letzte Entscheidung weiter.
        if askAgain, Self.asksAgainOnConnect(fresh) {
            requestDialog(fresh.uuid)
            DiskIndexLog.shared.record(.medium, .info, "dialog erneut id=\(fresh.uuid) entscheidung=\(fresh.decision.rawValue)")
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
            fresh.indexStatus = await settledStatus(fresh)
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

    /// bug.0.4.126/151: „indiziert“ nur nach einem Lauf bis zum Ende und ohne später gefundene Lücke.
    private func settledStatus(_ medium: StoredMedium) async -> StoredIndexStatus {
        guard medium.firstIndexedAt != nil else { return .pending }
        // Lesefehler: lieber „unvollständig“ (holt den Lauf nach) als fälschlich „indiziert“.
        guard let gaps = try? await store.indexHasGaps(mediumUUID: medium.uuid) else { return .pending }
        return gaps ? .pending : .indexed
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

    /// `reprobedID` (Reprobe, bug.0.4.062): nur dieses Medium aktualisieren, nie ein neues anlegen, und abbrechen,
    /// sobald es nach einem `await` nicht mehr unter dem Pfad eingehängt ist.
    private func storeAndPresent(
        _ volume: VolumeInfo,
        status: StoredIndexStatus,
        openDialog: Bool,
        reprobedID: UUID? = nil
    ) async {
        guard appState.featureAccess.canWriteIndex else { return }
        if let existingID = reprobedID ?? mediumByPath[volume.mountPath],
           var existing = try? await store.medium(uuid: existingID) {
            if let reprobedID, !isStillMounted(reprobedID, at: volume.mountPath) { return }
            existing.indexStatus = status
            existing.lastSeenAt = Date()
            existing.name = volume.name
            if status == .pending { existing.decision = .undecided }
            do {
                try await store.updateMediumRecognition(uuid: existing.uuid, existing)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.medium, .error, "updateMedium \(DiskIndexLog.errorSummary(error))")
            }
            if let reprobedID, !isStillMounted(reprobedID, at: volume.mountPath) { return }
            publish(existing, connection: .connected)
            if openDialog { requestDialog(existing.uuid) }
            return
        }
        guard reprobedID == nil else { return }
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
            DiskIndexLog.shared.record(.medium, .error, "speichern \(DiskIndexLog.errorSummary(error))")
        }
    }

    private func isStillMounted(_ id: UUID, at path: String) -> Bool {
        mounted[path] != nil && mediumByPath[path] == id
    }

    /// Wie `isStillMounted`, erlaubt aber einen noch nicht eingetragenen Pfad (erstes Anschließen in `connectKnown`).
    private func isPathStill(for id: UUID, at path: String) -> Bool {
        mounted[path] != nil && (mediumByPath[path] ?? id) == id
    }

    private func reprobeDeniedVolumes() async {
        for (path, volume) in mounted {
            guard let id = mediumByPath[path],
                  let stored = try? await store.medium(uuid: id),
                  stored.indexStatus == .error else { continue }
            guard case .granted = await access.probe(volume) else { continue }
            // bug.0.4.062 (REPORT 132): während der Probe ausgehängt oder ein anderes Medium unter dem Pfad → nichts tun.
            guard isStillMounted(id, at: path) else { continue }
            switch stored.decision {
            case .undecided:
                await storeAndPresent(volume, status: .pending, openDialog: true, reprobedID: id)
            case .dontIndex, .ignore:
                var updated = stored
                updated.indexStatus = .pending
                updated.lastSeenAt = Date()
                updated.name = volume.name
                do {
                    try await store.updateMediumRecognition(uuid: updated.uuid, updated)
                    // Während des Schreibens ausgehängt: den Pfad nicht wieder eintragen, nicht „verbunden“ melden.
                    guard isStillMounted(id, at: path) else { continue }
                    publish(updated, connection: .connected)
                } catch {
                    guard DiskIndexLog.isOperationalFailure(error) else { continue }
                    DiskIndexLog.shared.record(.medium, .error, "reprobe dontIndex \(DiskIndexLog.errorSummary(error))")
                }
            case .index:
                do {
                    try await connectKnown(stored, volume: volume, askAgain: false)
                } catch {
                    guard DiskIndexLog.isOperationalFailure(error) else { continue }
                    DiskIndexLog.shared.record(.medium, .error, "reprobe index \(DiskIndexLog.errorSummary(error))")
                }
            }
        }
    }

    private func volumeDisappeared(_ path: String) async {
        mounted[path] = nil
        guard let id = mediumByPath.removeValue(forKey: path) else { return }
        DiskIndexLog.shared.record(.medium, .info, "ausgehängt id=\(id)", privateDetail: path)
        requestedIndex.remove(id)
        // bug.0.4.187 (a): kam das Aushängen erst nach der Karenz des Laufs, steht der Hinweis „nicht bestätigt“ zu Unrecht.
        if let notice = appState.indexingFailure, notice.id == id, notice.reason == .unconfirmed {
            appState.indexingFailure = nil
        }
        // bug.0.4.193: die zugestellte Mitteilung zurückziehen, auch wenn der Hinweis schon geschlossen oder von einem
        // anderen Medium überschrieben ist.
        if appState.unconfirmedNoticeMedia.remove(id) != nil {
            SystemNotice.withdrawIndexingFailure(mediumID: id)
        }
        await onMediumDisappeared?(id)
        await onIndexingInterrupted?(id)
        do {
            if var stored = try await store.medium(uuid: id) {
                stored.lastSeenAt = Date()
                try await store.updateMediumLastSeen(uuid: id, at: stored.lastSeenAt ?? Date())
                publish(stored, connection: .offline)
                // bug.0.4.117: Lage statt Test-Ausschluss (`promptPanelPlacement`; Tests: `nil` oder `.offscreen`).
                AppWindowPresenter.syncNewMediumPanels(appState: appState)
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
            DiskIndexLog.shared.record(.store, .error, "aushängen \(DiskIndexLog.errorSummary(error))")
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
            let previous: StoredIndexDecision
            do {
                guard var row = try await store.medium(uuid: mediumID) else {
                    DiskIndexLog.shared.record(.medium, .error, "entscheidung medium fehlt id=\(mediumID)")
                    return
                }
                previous = row.decision
                row.rememberDecision = remember
                row.allowIndexing = allowIndexing
                // bug.0.4.128 (README 2a): Der Dialog ändert den Index-Status nicht – wie 05/06 (`writeMedium`).
                // „Ja“ setzt einen unvollständigen Index fort (Lauf mit Fortschritt), ein vollständiger wird
                // abgeglichen; „Nein“ lässt ihn „x % indiziert“.
                row.decision = allowIndexing ? .index : .dontIndex
                try await store.updateMediumDecision(uuid: mediumID, row)
                stored = row
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.medium, .error, "entscheidung \(DiskIndexLog.errorSummary(error))")
                return
            }
            let connection: ConnectionStatus = volume(for: mediumID) != nil ? .connected : .offline
            publish(stored, connection: connection)
            // todo.0.4.026: die Antwort beantwortet den Dialog; sonst bliebe ein entschiedenes Medium in der Warteschlange.
            appState.completeNewMediumDecision(mediumID)
            if Self.isRecognitionDecision(previous) {
                // todo.0.4.026: erneut gefragtes Medium. Keine Ersetzen-Rückfrage (kein neues Medium); eine geänderte
                // Antwort wirkt wie die Änderung in 05/06 (Nein stoppt Lauf und Überwachung, Ja fordert an).
                guard stored.decision != previous else { return }
                if stored.decision == .dontIndex {
                    requestedIndex.remove(mediumID)
                    appState.onMediumDecisionChanged?(mediumID, .dontIndex, false)
                    return
                }
                guard let volume = volume(for: mediumID) else { return }
                requestIndex(mediumID: mediumID, volume: volume)
                return
            }
            // Öffnet das Panel selbst, wenn `appState.promptPanelPlacement` gesetzt ist (bug.0.3.9.005 c).
            appState.offerReplaceMediumPrompt(newID: mediumID)
            guard allowIndexing, let volume = volume(for: mediumID) else { return }
            requestIndex(mediumID: mediumID, volume: volume)
        }
    }

    /// Im Erkennungs-Dialog getroffene Entscheidung (Ja/Nein); `.undecided` und `.ignore` gehören nicht dazu.
    private static func isRecognitionDecision(_ decision: StoredIndexDecision) -> Bool {
        decision == .index || decision == .dontIndex
    }

    /// todo.0.4.026 (README 2.3): entschieden, aber ohne „Für dieses Medium merken“ → Dialog beim Anschließen wieder.
    static func asksAgainOnConnect(_ stored: StoredMedium) -> Bool {
        isRecognitionDecision(stored.decision) && !stored.rememberDecision
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
                DiskIndexLog.shared.record(.store, .error, "favorites notice \(DiskIndexLog.errorSummary(error))")
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
        // bug.0.4.117: Lage statt Test-Ausschluss (`promptPanelPlacement`; Tests: `nil` oder `.offscreen`).
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

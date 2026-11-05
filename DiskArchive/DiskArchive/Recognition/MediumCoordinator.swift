//
//  MediumCoordinator.swift
//  DiskArchive
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
    /// bug.0.4.233: eingehängte Pfade ohne Volume-Zugriff (`getmntinfo`); Tests: eigene Liste, sonst leer.
    var mountedVolumePaths: @MainActor () -> [String] = {
        RuntimeEnvironment.isRunningTests ? [] : LocalVolumeMounts.candidateMountPaths()
    }
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
        appState.onReplaceMediumResolved = { [weak self] prompt, forgetOld in
            self?.resolveReplace(prompt, forgetOld: forgetOld)
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
            DiskArchiveLog.shared.record(.medium, .info, "event appeared pathLen=\(volume.mountPath.count)")
            await volumeAppeared(volume)
        case .willDisappear(let path):
            DiskArchiveLog.shared.record(.medium, .info, "event willDisappear pathLen=\(path.count)")
            if let id = mediumByPath[path] {
                await onWillUnmount?(id)
            }
        case .disappeared(let path):
            DiskArchiveLog.shared.record(.medium, .info, "event disappeared pathLen=\(path.count)")
            await volumeDisappeared(path)
        case .renamed(let oldPath, let volume):
            DiskArchiveLog.shared.record(.medium, .info, "event renamed pathLen=\(volume.mountPath.count)")
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

    /// Tests (bug.0.4.201 d): läuft in `connectKnown`, sobald der Status feststeht, vor dem Eintragen des Pfads. Je Instanz.
    var connectStatusDecidedHookForTesting: (@MainActor (UUID) async -> Void)?
    /// Tests (bug.0.4.203 a): eine Anforderung zum Indizieren steht.
    func isIndexRequestedForTesting(_ mediumID: UUID) -> Bool { requestedIndex.contains(mediumID) }
    #endif

    private func volumeAppeared(_ volume: VolumeInfo) async {
        mounted[volume.mountPath] = volume
        let candidate = VolumeCandidateRule.isCandidate(volume.candidateInput)
        guard candidate else {
            DiskArchiveLog.shared.record(.medium, .info, "candidate=nein pathLen=\(volume.mountPath.count)")
            return
        }
        do {
            let allMatches = try await store.candidates(for: volume.identity)
            // Klon (gleiche Volume-UUID): ein Medium, das schon unter einem anderen eingehängten Pfad steht, scheidet aus.
            // Nie zwei Pfade für ein Medium (bug.0.4.031 a).
            let matches = allMatches.filter { !isMountedElsewhere($0.medium.uuid, than: volume.mountPath) }
            if matches.count < allMatches.count {
                DiskArchiveLog.shared.record(.medium, .info, "candidate=ja klon belegt=\(allMatches.count - matches.count) pathLen=\(volume.mountPath.count)")
            }
            if let known = singleStrongMatch(matches) {
                DiskArchiveLog.shared.record(.medium, .info, "candidate=ja eingehängt id=\(known.medium.uuid) stärke=\(known.strength) entscheidung=\(known.medium.decision.rawValue)")
                try await connectKnown(known.medium, volume: volume)
                return
            }
            // Klon allein gesteckt (Nutzer 17.10.): gleich starke Treffer, keiner anderswo eingehängt → zuletzt gesehenes.
            if matches.count == allMatches.count, let recent = mostRecentlySeen(matches) {
                DiskArchiveLog.shared.record(.medium, .info, "candidate=ja mehrdeutig zuletzt gesehen id=\(recent.medium.uuid) treffer=\(matches.count)")
                try await connectKnown(recent.medium, volume: volume)
                return
            }
            if matches.isEmpty {
                DiskArchiveLog.shared.record(.medium, .info, "candidate=ja unbekannt pathLen=\(volume.mountPath.count)")
            } else {
                DiskArchiveLog.shared.record(.medium, .info, "candidate=ja mehrdeutig treffer=\(matches.count) pathLen=\(volume.mountPath.count)")
            }
            await receiveUnknown(volume)
        } catch {
            guard DiskArchiveLog.isOperationalFailure(error) else { return }
            DiskArchiveLog.shared.record(.medium, .error, "erkennen \(DiskArchiveLog.errorSummary(error)) pathLen=\(volume.mountPath.count)")
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
        DiskArchiveLog.shared.record(.medium, .info, "umbenannt id=\(id)", privateDetail: volume.mountPath)
        do {
            if var stored = try await store.medium(uuid: id) {
                stored.name = volume.name
                stored.lastSeenAt = Date()
                try await store.updateMediumRecognition(uuid: id, stored)
                publish(stored, connection: .connected)
            }
        } catch {
            if DiskArchiveLog.isOperationalFailure(error) {
                DiskArchiveLog.shared.record(.store, .error, "umbenennen \(DiskArchiveLog.errorSummary(error))")
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
        defer { DiskArchiveLog.shared.perfIfSlow("abgleich", since: started) }
        if !appState.featureAccess.canWriteIndex {
            publishConnectKnownReadOnly(stored, volume: volume)
            return
        }
        var recoveredFromError = false
        if stored.indexStatus == .error {
            switch await access.probe(volume) {
            case .denied:
                DiskArchiveLog.shared.record(.medium, .error, "kein Zugriff", privateDetail: volume.mountPath)
                var denied = stored
                denied.lastSeenAt = Date()
                // bug.0.4.231: Typ des angeschlossenen Volumes auch ohne Zugriff (Konzept `medien.md` 2c).
                denied.type = volume.mediumType
                // bug.0.4.200 (d): Fehler ist jetzt der Zugriff, nicht mehr die Lücke (Aktivieren prüft wieder).
                denied.hasIndexGaps = false
                try await store.updateMediumRecognition(uuid: denied.uuid, denied)
                try await store.clearIndexGaps(mediumUUID: denied.uuid)
                // bug.0.4.062: während des Schreibens ausgehängt → nicht „verbunden“ melden.
                guard isPathStill(for: denied.uuid, at: volume.mountPath) else { return }
                mediumByPath[volume.mountPath] = denied.uuid
                publish(denied, connection: .connected)
                DiskArchiveLog.shared.record(.medium, .info, "abbruch kein Zugriff id=\(stored.uuid)")
                return
            case .granted:
                recoveredFromError = true
            }
        }
        try await store.recordIdentity(mediumUUID: stored.uuid, volume.identity)
        guard var fresh = try await store.medium(uuid: stored.uuid) else {
            DiskArchiveLog.shared.record(.medium, .error, "abbruch medium fehlt id=\(stored.uuid)")
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
            // bug.0.4.201 (d): eine Lücke bleibt „Fehler“, bis ein Lauf sie nachliest – in der Pause startet keiner.
            let paused = appState.globalAutoIndexPaused || appState.heldForSleep || fresh.autoIndexPaused
            if fresh.hasIndexGaps, fresh.decision == .index, paused {
                fresh.indexStatus = .error
            } else {
                fresh.indexStatus = await settledStatus(fresh)
            }
        }
        #if DEBUG
        await connectStatusDecidedHookForTesting?(fresh.uuid)
        #endif
        if let free = volume.volumeFreeBytes {
            fresh.capacityUsedBytes = max(0, volume.volumeTotalBytes - free)
        }
        try await store.updateMediumRecognition(uuid: fresh.uuid, fresh)
        if recoveredFromError {
            try await store.updateMediumIndexStatus(uuid: fresh.uuid, fresh.indexStatus)
        }
        // bug.0.4.062: während der Store-Schritte ausgehängt → nicht wieder eintragen, nicht „verbunden“ melden.
        guard isPathStill(for: fresh.uuid, at: volume.mountPath) else {
            DiskArchiveLog.shared.record(.medium, .info, "abbruch ausgehängt id=\(fresh.uuid)")
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
            await requestDialogCheckingNamesakes(fresh.uuid, besides: volume.mountPath)
            DiskArchiveLog.shared.record(.medium, .info, "dialog erneut id=\(fresh.uuid) entscheidung=\(fresh.decision.rawValue)")
        }
        if fresh.decision.refusesIndexing {
            DiskArchiveLog.shared.record(.medium, .info, "abbruch indizierung verweigert id=\(fresh.uuid)")
            return
        }
        if fresh.decision == .undecided {
            await requestDialogCheckingNamesakes(fresh.uuid, besides: volume.mountPath)
            DiskArchiveLog.shared.record(.medium, .info, "dialog id=\(fresh.uuid)")
            return
        }
        if fresh.indexStatus == .indexing, isIndexingActive?(fresh.uuid) != true {
            fresh.indexStatus = await settledStatus(fresh)
            try await store.updateMediumIndexStatus(uuid: fresh.uuid, fresh.indexStatus)
            publish(fresh, connection: .connected)
        }
        // bug.0.4.201 (d): auch ein in der Pause „Fehler“ gebliebenes Medium mit Lücke – endete die Pause während der
        // Schritte oben, fand `resumePausedRuns` es noch nicht unter den verbundenen.
        if fresh.decision == .index, fresh.hasCompleteIndexExceptGaps {
            let paused = appState.globalAutoIndexPaused
            if !paused {
                onReconcileRequested?(fresh.uuid, volume)
                DiskArchiveLog.shared.record(.medium, .info, "abgleich id=\(fresh.uuid)")
            } else {
                DiskArchiveLog.shared.record(.medium, .info, "abgleich wartet pause id=\(fresh.uuid)")
            }
            return
        }
        if fresh.decision == .index, fresh.indexStatus == .pending {
            requestIndex(mediumID: fresh.uuid, volume: volume)
            DiskArchiveLog.shared.record(.medium, .info, "index anfordern id=\(fresh.uuid)")
        }
    }

    /// bug.0.4.200 (f): „Nein“ beendet einen Fehler (Konzept 2b, jeder Grund): Status nach der Tabelle in
    /// `konzept/medien.md` (vollständiger Index → Online/Offline, sonst „x % indiziert“), „!“, Hinweis und Mitteilung weg.
    func endFailureAfterDecline(mediumID: UUID) async {
        appState.endIndexingFailure(mediumID: mediumID)
        do {
            guard let stored = try await store.medium(uuid: mediumID), stored.indexStatus == .error else { return }
            let settled = await settledStatus(stored)
            try await store.updateMediumIndexStatus(uuid: mediumID, settled)
            appState.updateMedium(id: mediumID) {
                $0.indexStatus = IndexStatus(rawValue: settled.rawValue) ?? .pending
            }
        } catch {
            guard DiskArchiveLog.isOperationalFailure(error) else { return }
            DiskArchiveLog.shared.record(.medium, .error, "nein beendet fehler \(DiskArchiveLog.errorSummary(error))")
        }
    }

    /// bug.0.4.126/151: „indiziert“ nur nach einem Lauf bis zum Ende und ohne später gefundene Lücke.
    private func settledStatus(_ medium: StoredMedium) async -> StoredIndexStatus {
        guard medium.firstIndexedAt != nil else { return .pending }
        // Lesefehler: lieber „unvollständig“ (holt den Lauf nach) als fälschlich „indiziert“.
        guard let gaps = try? await store.indexHasGaps(mediumUUID: medium.uuid) else { return .pending }
        // bug.0.4.200: der Merker fällt bei einem Fehler aus anderem Grund weg – nicht lesbare Ordner im Index zählen
        // trotzdem als Lücke (das Anschließen liest sie nach, statt kurz „Online“ zu zeigen).
        guard !gaps, let unreadable = try? await store.hasUnreadableFolders(mediumUUID: medium.uuid) else { return .pending }
        return unreadable ? .pending : .indexed
    }

    private func receiveUnknown(_ volume: VolumeInfo) async {
        guard appState.featureAccess.canWriteIndex else { return }
        let result = await access.probe(volume)
        switch result {
        case .granted:
            DiskArchiveLog.shared.record(.medium, .info, "neu speichern pathLen=\(volume.mountPath.count)")
            await storeAndPresent(volume, status: .pending, openDialog: true)
        case .denied(let reason):
            DiskArchiveLog.shared.record(.medium, .error, "kein Zugriff \(reason) pathLen=\(volume.mountPath.count)")
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
                guard DiskArchiveLog.isOperationalFailure(error) else { return }
                DiskArchiveLog.shared.record(.medium, .error, "updateMedium \(DiskArchiveLog.errorSummary(error))")
            }
            if let reprobedID, !isStillMounted(reprobedID, at: volume.mountPath) { return }
            publish(existing, connection: .connected)
            if openDialog { await requestDialogCheckingNamesakes(existing.uuid, besides: volume.mountPath) }
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
            if openDialog { await requestDialogCheckingNamesakes(stored.uuid, besides: volume.mountPath) }
        } catch {
            guard DiskArchiveLog.isOperationalFailure(error) else { return }
            DiskArchiveLog.shared.record(.medium, .error, "speichern \(DiskArchiveLog.errorSummary(error))")
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
            // bug.0.4.199: Fehler wegen nicht lesbarer Ordner ist kein Zugriffsproblem – nachgelesen wird beim Anschließen,
            // beim App-Start und mit „Erneut versuchen“, nicht bei jedem Aktivieren der App.
            // bug.0.4.200 (d): der Merker steht nur, solange der letzte Fehler die Lücke ist.
            if stored.hasIndexGaps { continue }
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
                    guard DiskArchiveLog.isOperationalFailure(error) else { continue }
                    DiskArchiveLog.shared.record(.medium, .error, "reprobe dontIndex \(DiskArchiveLog.errorSummary(error))")
                }
            case .index:
                do {
                    try await connectKnown(stored, volume: volume, askAgain: false)
                } catch {
                    guard DiskArchiveLog.isOperationalFailure(error) else { continue }
                    DiskArchiveLog.shared.record(.medium, .error, "reprobe index \(DiskArchiveLog.errorSummary(error))")
                }
            }
        }
    }

    private func volumeDisappeared(_ path: String) async {
        mounted[path] = nil
        guard let id = mediumByPath.removeValue(forKey: path) else { return }
        DiskArchiveLog.shared.record(.medium, .info, "ausgehängt id=\(id)", privateDetail: path)
        requestedIndex.remove(id)
        // bug.0.4.201 (b): die Trennung zuerst sichtbar machen – ein Lauf, der gerade endet, zeigt keinen Hinweis mehr.
        appState.updateMedium(id: id) { $0.connectionStatus = .offline }
        // bug.0.4.187 (a), 193, 200 (e): Hinweis nur für angeschlossene Medien (Konzept 2b) – beim Aushängen für jeden
        // Grund schließen und die zugestellte Mitteilung zurückziehen, auch wenn der Hinweis schon geschlossen oder von
        // einem anderen Medium überschrieben ist.
        appState.endIndexingFailure(mediumID: id)
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
            guard DiskArchiveLog.isOperationalFailure(error) else {
                appState.updateMedium(id: id) {
                    $0.connectionStatus = .offline
                    $0.lastSeenAt = Date()
                }
                return
            }
            DiskArchiveLog.shared.record(.store, .error, "aushängen \(DiskArchiveLog.errorSummary(error))")
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
                    DiskArchiveLog.shared.record(.medium, .error, "entscheidung medium fehlt id=\(mediumID)")
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
                guard DiskArchiveLog.isOperationalFailure(error) else { return }
                DiskArchiveLog.shared.record(.medium, .error, "entscheidung \(DiskArchiveLog.errorSummary(error))")
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
            guard allowIndexing, let volume = volume(for: mediumID) else { return }
            requestIndex(mediumID: mediumID, volume: volume)
        }
    }

    /// bug.0.4.215 (Konzept `medien.md` Punkt 3): „Behalten“ → Erkennungs-Dialog. „Altes vergessen“ → das neue übernimmt
    /// die Entscheidung des alten samt „Für dieses Medium merken“; nicht gemerkt → der Dialog folgt (bis zur Antwort gilt
    /// sie wie beim erneuten Fragen). „Indizieren“ fordert den Lauf an. Danach der bestehende Vergessen-Weg.
    private func resolveReplace(_ prompt: ReplaceMediumPrompt, forgetOld: Bool) {
        guard forgetOld else {
            requestDialog(prompt.newID, askReplace: false)
            return
        }
        choiceTask = Task {
            guard appState.featureAccess.canWriteIndex else { return }
            var adopted: StoredMedium?
            do {
                if let old = try await store.medium(uuid: prompt.oldID), Self.isRecognitionDecision(old.decision),
                   var row = try await store.medium(uuid: prompt.newID) {
                    row.decision = old.decision
                    row.allowIndexing = old.allowIndexing
                    row.rememberDecision = old.rememberDecision
                    try await store.updateMediumDecision(uuid: prompt.newID, row)
                    adopted = row
                }
            } catch {
                guard DiskArchiveLog.isOperationalFailure(error) else { return }
                DiskArchiveLog.shared.record(.medium, .error, "ersetzen \(DiskArchiveLog.errorSummary(error))")
            }
            appState.forgetMedium(id: prompt.oldID)
            guard let adopted else {
                requestDialog(prompt.newID, askReplace: false)
                return
            }
            let volume = volume(for: prompt.newID)
            publish(adopted, connection: volume != nil ? .connected : .offline)
            DiskArchiveLog.shared.record(
                .medium, .info,
                "ersetzen übernommen id=\(prompt.newID) entscheidung=\(adopted.decision.rawValue) gemerkt=\(adopted.rememberDecision)"
            )
            if !adopted.rememberDecision {
                requestDialog(prompt.newID, askReplace: false)
            }
            guard adopted.decision == .index, let volume else { return }
            requestIndex(mediumID: prompt.newID, volume: volume)
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
            DiskArchiveLog.shared.record(.medium, .info, "index bereits angefordert id=\(mediumID)")
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
            if DiskArchiveLog.isOperationalFailure(error) {
                DiskArchiveLog.shared.record(.store, .error, "favorites notice \(DiskArchiveLog.errorSummary(error))")
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
        DiskArchiveLog.shared.record(.medium, .info, "abgleich read-only id=\(display.uuid)")
    }

    /// bug.0.4.215: ein unentschiedenes Medium mit genau einem Offline-Medium gleichen Namens bekommt zuerst und allein
    /// „Ersetzt dieses Medium?“ (öffnet sich selbst bei gesetzter `promptPanelPlacement`); der Erkennungs-Dialog wartet.
    private func requestDialog(_ id: UUID, askReplace: Bool = true, mountedIDs: Set<UUID> = []) {
        if askReplace, appState.medium(with: id)?.decision == .undecided,
           appState.offerReplaceMediumPrompt(newID: id, mountedIDs: mountedIDs) {
            return
        }
        appState.enqueueNewMediumDecision(id)
        // bug.0.4.117: Lage statt Test-Ausschluss (`promptPanelPlacement`; Tests: `nil` oder `.offscreen`).
        AppWindowPresenter.syncNewMediumPanels(appState: appState)
    }

    /// bug.0.4.233: Vor „Ersetzt dieses Medium?“ prüfen, ob ein gleichnamiges Offline-Medium gerade unter einem noch nicht
    /// verarbeiteten Pfad eingehängt ist (App-Start, Aufwachen: das neue kann vor dem bekannten an der Reihe sein).
    private func requestDialogCheckingNamesakes(_ id: UUID, besides path: String) async {
        requestDialog(id, mountedIDs: await mountedNamesakes(of: id, besides: path))
    }

    private func mountedNamesakes(of id: UUID, besides path: String) async -> Set<UUID> {
        guard let medium = appState.medium(with: id), medium.decision == .undecided else { return [] }
        let namesakes = appState.media.filter {
            $0.id != id && !$0.isForgotten && $0.connectionStatus == .offline && $0.name == medium.name
        }
        guard !namesakes.isEmpty else { return [] }
        let paths = mountedVolumePaths().filter { $0 != path && mounted[$0] == nil }
        guard !paths.isEmpty else { return [] }
        var hits: Set<UUID> = []
        for namesake in namesakes {
            guard let stored = try? await store.medium(uuid: namesake.id) else { continue }
            for candidate in paths where await access.mediumIsMounted(stored, mountPath: candidate) {
                hits.insert(namesake.id)
                break
            }
        }
        return hits
    }

    private func publish(_ stored: StoredMedium, connection: ConnectionStatus) {
        var medium = stored.asMedium(connection: connection)
        // todo.0.4.3.013: gespeichert „wird indiziert“, aber kein Lauf aktiv → „Wird geprüft“ (`awaitingRun`) statt des
        // gespeicherten Prozentwerts (kein kurzer Sprung auf 99 % beim Wiedererkennen). Ein laufender Lauf meldet
        // seine Phase selbst.
        let notRunning = medium.indexStatus == .indexing && isIndexingActive?(medium.id) != true
        if notRunning { medium.indexRunPhase = .awaitingRun }
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
                // bug.0.4.210: dieselbe Gesamtzahl wie offline.
                current.scanTotal = medium.scanTotal
                current.lastSeenAt = medium.lastSeenAt
                current.lastIndexedAt = medium.lastIndexedAt
                current.lastIndexActivityAt = medium.lastIndexActivityAt
                current.completedDepth = medium.completedDepth
                current.hasIndexGaps = medium.hasIndexGaps
                current.isForgotten = medium.isForgotten
                if !preserveUserFields {
                    // bug.0.4.043: Nutzerfelder nicht zurücksetzen, solange ein Write aussteht.
                    current.allowIndexing = medium.allowIndexing
                    current.autoIndexPaused = medium.autoIndexPaused
                    current.decision = medium.decision
                    current.showAbsoluteCapacity = medium.showAbsoluteCapacity
                    current.isFavorite = medium.isFavorite
                }
                if notRunning { current.indexRunPhase = .awaitingRun }
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
            // bug.0.4.210: „wird indiziert“ aus dem Speicher zeigt den gespeicherten Stand, nicht 0 %.
            indexingProgress: indexStatus == .indexing
                ? IndexProgress.displayed(entries: fileCount + folderCount, total: scanTotal, indexed: false) : 0,
            showAbsoluteCapacity: showAbsoluteCapacity,
            isFavorite: isFavorite,
            hasIndexGaps: hasIndexGaps,
            customName: customName,
            failureReason: failureReasonCode.flatMap(IndexFailureReason.init(notificationCode:))
        )
    }
}

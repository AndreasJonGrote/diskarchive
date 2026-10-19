//
//  IndexingService.swift
//  diskindex
//

import Foundation

/// Hält höchstens einen Lauf je Medium und schickt Fortschritt an `AppState`.
@MainActor
final class IndexingService {
    #if DEBUG
    /// Tests: gestartete Läufe je Medium, Wert = `fromScratch` (Zähler, keine Steuerung).
    private(set) var startedRunsForTesting: [UUID: [Bool]] = [:]
    #endif

    private let store: IndexStoreV3
    private let access: any MediumAccess
    private let appState: AppState
    private weak var coordinator: MediumCoordinator?
    private let indexer = DirectoryIndexer()
    private var runs: [UUID: UUID] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var pauseIDs: Set<UUID> = []
    private var lastUIUpdate: [UUID: Date] = [:]
    private var runStartedAt: [UUID: Date] = [:]
    private var runVolumes: [UUID: VolumeInfo] = [:]
    private var rerunAfterFinish: Set<UUID> = []
    /// Starts während eines laufenden Abbruchs, je Medium zusammengefasst (bug.0.4.080 a).
    private var startsWaitingForCancel: [UUID: (volume: VolumeInfo, fromScratch: Bool)] = [:]
    /// Abgleich-Lauf (bug.0.4.014), damit `cancel` wie `DirectoryIndexer.stop` endet.
    private var runFullReconcile: [UUID: Bool] = [:]
    /// Lauf zu Ende: Live-Überwachung starten (nach Erfolg und, bug.0.4.084, nach einem gescheiterten Lauf).
    var onRunIndexed: ((UUID, VolumeInfo) -> Void)?

    fileprivate func setRunFullReconcile(_ mediumUUID: UUID, _ value: Bool) {
        runFullReconcile[mediumUUID] = value
    }

    init(store: IndexStoreV3, access: any MediumAccess, appState: AppState) {
        self.store = store
        self.access = access
        self.appState = appState
    }

    func attach(_ coordinator: MediumCoordinator) {
        self.coordinator = coordinator
    }

    func isRunActive(_ mediumUUID: UUID) -> Bool {
        tasks[mediumUUID] != nil
    }

    #if DEBUG
    /// Tests: `cancel` hat den Lauf abgemeldet und wartet noch auf das Ende des Tasks.
    func isCancellingForTesting(_ mediumUUID: UUID) -> Bool {
        tasks[mediumUUID] != nil && runs[mediumUUID] == nil
    }
    /// Tests (bug.0.4.073): läuft in `cancel` nach dem Abmelden, vor dem Warten auf den Task. Je Instanz.
    var cancelBeforeAwaitHookForTesting: (@MainActor (UUID) async -> Void)?
    #endif

    fileprivate func isRunToken(_ mediumUUID: UUID, _ token: UUID) -> Bool {
        runs[mediumUUID] == token
    }

    fileprivate func markRunIndexing(_ mediumUUID: UUID) {
        appState.noteMenuBarIndexingSpinner(mediumUUID, active: true)
        appState.updateMedium(id: mediumUUID) {
            $0.indexStatus = .indexing
            $0.indexingProgress = 0
        }
    }

    func activeMediumUUIDs() -> [UUID] {
        Array(Set(tasks.keys).union(runs.keys))
    }

    /// bug.0.4.073: Die Sperre bricht einen vollständigen Abgleich ab, das Medium bleibt `.indexed` (`interrupted`).
    /// Nach dem Entsperren holt `LiveWiring` genau diese Abgleiche nach (je Instanz gemerkt).
    private var reconcilesInterruptedByVersionLock: Set<UUID> = []

    func cancelAllActiveForVersionLock() async {
        for id in activeMediumUUIDs() {
            // Inzwischen entsperrt: nichts mehr abbrechen (sonst ginge der Abgleich verloren).
            guard !appState.featureAccess.canWriteIndex else { break }
            if runFullReconcile[id] == true {
                reconcilesInterruptedByVersionLock.insert(id)
            }
            await cancel(mediumUUID: id)
        }
    }

    /// Entsperren: gemerkte, durch die Sperre abgebrochene Abgleiche abholen (danach vergessen).
    func takeReconcilesInterruptedByVersionLock() -> Set<UUID> {
        defer { reconcilesInterruptedByVersionLock.removeAll() }
        return reconcilesInterruptedByVersionLock
    }

    func start(mediumUUID: UUID, volume: VolumeInfo, fromScratch: Bool) {
        guard appState.featureAccess.canWriteIndex else {
            coordinator?.clearIndexRequest(mediumID: mediumUUID)
            return
        }
        if startsWaitingForCancel[mediumUUID] != nil || (tasks[mediumUUID] != nil && runs[mediumUUID] == nil) {
            // Abbruch läuft noch (`cancel` wartet auf den Task): `finish` dieses Laufs löst kein `rerunAfterFinish`
            // mehr ein, also auf das Ende warten und dann neu starten (bug.0.4.073). bug.0.4.080 a): Weitere Starts
            // in dieser Zeit (LiveWiring und Koordinator) warten nicht einzeln, sondern gehen in denselben Neustart,
            // auch in der Lücke zwischen Ende des Abbruchs und Neustart (`waitUntilIdle` fragt alle 20 ms ab).
            if let waiting = startsWaitingForCancel[mediumUUID] {
                startsWaitingForCancel[mediumUUID] = (volume, waiting.fromScratch || fromScratch)
                return
            }
            startsWaitingForCancel[mediumUUID] = (volume, fromScratch)
            Task {
                await waitUntilIdle(mediumUUID)
                guard let waiting = startsWaitingForCancel.removeValue(forKey: mediumUUID) else { return }
                start(mediumUUID: mediumUUID, volume: waiting.volume, fromScratch: waiting.fromScratch)
            }
            return
        }
        if tasks[mediumUUID] != nil {
            guard fromScratch else {
                rerunAfterFinish.insert(mediumUUID)
                return
            }
            Task {
                await cancel(mediumUUID: mediumUUID)
                await waitUntilIdle(mediumUUID)
                start(mediumUUID: mediumUUID, volume: volume, fromScratch: true)
            }
            return
        }
        guard !isPaused(mediumUUID) else {
            coordinator?.clearIndexRequest(mediumID: mediumUUID)
            return
        }
        guard appState.medium(with: mediumUUID)?.decision == .index else {
            DiskIndexLog.shared.record(.index, .info, "auftrag abgelehnt unentschieden medium=\(mediumUUID)")
            coordinator?.clearIndexRequest(mediumID: mediumUUID)
            return
        }
        DiskIndexLog.shared.record(.index, .info, "auftrag medium=\(mediumUUID) scratch=\(fromScratch)")
        #if DEBUG
        startedRunsForTesting[mediumUUID, default: []].append(fromScratch)
        #endif

        let token = UUID()
        runs[mediumUUID] = token
        runVolumes[mediumUUID] = volume
        runStartedAt[mediumUUID] = Date()
        let configuration = ScanConfiguration(
            maxDepth: appState.appSettings.indexedMaxDepth,
            ignoreHiddenFiles: appState.appSettings.ignoreHiddenFiles,
            artifactsIgnored: appState.appSettings.artifactsIgnored,
            excludedPatterns: appState.appSettings.excludedPatterns
        )
        let indexer = indexer
        let store = store
        let access = access
        let bridge = Bridge(service: self)
        tasks[mediumUUID] = Task.detached(priority: .utility) {
            var storedBeforeRun: StoredMedium?
            do {
                storedBeforeRun = try await store.medium(uuid: mediumUUID)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error medium beforeRun \(error)")
                }
                storedBeforeRun = nil
            }
            let fullReconcile = !fromScratch
                && storedBeforeRun?.indexStatus == .indexed
                && (storedBeforeRun?.completedDepth ?? 0) > 0
            await bridge.rememberFullReconcile(mediumUUID, fullReconcile)
            let reconcileRun = !fromScratch && storedBeforeRun?.indexStatus == .indexed
            let began = await bridge.beginRunUI(mediumUUID, token: token, reconcileRun: reconcileRun)
            guard began else { return }
            let outcome = await indexer.run(
                store: store,
                access: access,
                mediumUUID: mediumUUID,
                volume: volume,
                configuration: configuration,
                fromScratch: fromScratch,
                token: token,
                shouldHalt: { await bridge.halt(mediumUUID) },
                onProgress: { await bridge.publish(mediumUUID, $0) }
            )
            await bridge.finish(mediumUUID, token, outcome)
        }
    }

    /// App-Ende: Tasks abbrechen ohne den Main Thread zu blockieren.
    func cancelAllForTermination() {
        for id in Array(tasks.keys) {
            appState.clearMenuBarRunIndicators(id)
            runs.removeValue(forKey: id)
            tasks[id]?.cancel()
            tasks[id] = nil
        }
        pauseIDs.removeAll()
        // bug.0.4.085 a): kein wartender Start läuft nach dem Beenden noch an.
        startsWaitingForCancel.removeAll()
    }

    /// bug.0.4.085 a): Medium wird ausgehängt – ein wartender Start (mit altem Volume) läuft nicht mehr an.
    func discardWaitingStart(mediumUUID: UUID) {
        startsWaitingForCancel[mediumUUID] = nil
    }

    #if DEBUG
    func hasWaitingStartForTesting(_ mediumUUID: UUID) -> Bool { startsWaitingForCancel[mediumUUID] != nil }
    #endif

    func cancel(mediumUUID: UUID) async {
        let task = tasks[mediumUUID]
        guard task != nil || runs[mediumUUID] != nil else { return }
        task?.cancel()
        guard let token = runs.removeValue(forKey: mediumUUID) else {
            await task?.value
            tasks[mediumUUID] = nil
            return
        }
        runStartedAt.removeValue(forKey: mediumUUID)
        pauseIDs.remove(mediumUUID)
        let fullReconcile = runFullReconcile.removeValue(forKey: mediumUUID) ?? false
        let reconcileInterrupted = fullReconcile
        do {
            _ = try await store.finishIndexing(
                mediumUUID: mediumUUID,
                token: token,
                status: reconcileInterrupted ? .indexed : .pending,
                firstIndexedAt: nil,
                interrupted: reconcileInterrupted
            )
        } catch {
            DiskIndexLog.shared.record(.index, .error, "abbruch \(error)")
        }
        DiskIndexLog.shared.record(.index, .info, "abgebrochen medium=\(mediumUUID)")
        if runs[mediumUUID] == nil {
            appState.clearMenuBarRunIndicators(mediumUUID)
            appState.updateMedium(id: mediumUUID) {
                $0.indexStatus = reconcileInterrupted ? .indexed : .pending
            }
        }
        #if DEBUG
        await cancelBeforeAwaitHookForTesting?(mediumUUID)
        #endif
        await task?.value
        if runs[mediumUUID] == nil {
            tasks[mediumUUID] = nil
        }
        BulkDirectoryReader.flushReadLogSummary(force: true)
        coordinator?.clearIndexRequest(mediumID: mediumUUID)
    }

    /// Popover-Schalter „Automatisches Indizieren“.
    func pauseChanged() {
        if appState.globalAutoIndexPaused {
            pauseIDs.formUnion(runs.keys)
        } else {
            pauseIDs.removeAll()
            resumePausedRuns()
        }
    }

    func waitUntilIdle(_ mediumUUID: UUID) async {
        while tasks[mediumUUID] != nil {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func watchesAfterFailedRun(_ mediumUUID: UUID) -> Bool {
        guard appState.featureAccess.canWriteIndex, !isPaused(mediumUUID),
              let medium = appState.medium(with: mediumUUID) else { return false }
        return medium.connectionStatus == .connected && medium.decision == .index && medium.allowIndexing
    }

    private func isPaused(_ mediumUUID: UUID) -> Bool {
        if appState.globalAutoIndexPaused || appState.heldForSleep { return true }
        if appState.medium(with: mediumUUID)?.autoIndexPaused == true { return true }
        return false
    }

    fileprivate func halt(for mediumUUID: UUID) -> ScanHalt {
        guard runs[mediumUUID] != nil else { return .cancel }
        if pauseIDs.contains(mediumUUID) || isPaused(mediumUUID) { return .pause }
        return .none
    }

    fileprivate func publish(_ mediumUUID: UUID, _ progress: IndexProgress) async {
        guard runs[mediumUUID] != nil else { return }
        let now = Date()
        if !progress.finished, let last = lastUIUpdate[mediumUUID], now.timeIntervalSince(last) < 0.25 {
            return
        }
        lastUIUpdate[mediumUUID] = now
        appState.updateMedium(id: mediumUUID) {
            if $0.indexStatus != .indexed {
                $0.indexStatus = .indexing
            }
            $0.indexRunPhase = progress.phase
            if progress.phase != .counting {
                if progress.entriesTotal > 0 {
                    $0.scanTotal = progress.entriesTotal
                }
                $0.indexingProgress = progress.ratio
            }
        }
    }

    fileprivate func finish(_ mediumUUID: UUID, _ token: UUID, _ outcome: IndexRunOutcome) async {
        guard runs[mediumUUID] == token else { return }
        tasks[mediumUUID] = nil
        appState.clearMenuBarRunIndicators(mediumUUID)
        runs[mediumUUID] = nil
        let started = runStartedAt.removeValue(forKey: mediumUUID)
        DiskIndexLog.shared.record(.index, .info, "lauf ende medium=\(mediumUUID) status=\(outcome.status)")
        var stored: StoredMedium?
        do {
            stored = try await store.medium(uuid: mediumUUID)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error medium finish \(error)")
            }
            stored = nil
        }
        appState.updateMedium(id: mediumUUID) {
            if let raw = stored?.indexStatus.rawValue, let status = IndexStatus(rawValue: raw) {
                $0.indexStatus = status
            } else if outcome.status == .indexed {
                $0.indexStatus = .indexed
            } else if outcome.status == .error {
                $0.indexStatus = .error
            } else {
                $0.indexStatus = .pending
            }
            if $0.indexStatus == .indexed, !outcome.interrupted {
                $0.indexingProgress = 1
            }
            if let stored {
                $0.fileCount = stored.fileCount
                $0.folderCount = stored.folderCount
                $0.scanTotal = stored.scanTotal
                $0.completedDepth = stored.completedDepth
                $0.lastIndexedAt = stored.lastIndexedAt
                $0.lastIndexActivityAt = stored.lastIndexActivityAt
            }
            $0.indexRunPhase = .indexing
        }
        if outcome.status == .indexed, !outcome.interrupted, let medium = appState.medium(with: mediumUUID) {
            let duration = started.map { Date().timeIntervalSince($0) } ?? 0
            let objects = medium.fileCount + medium.folderCount
            SystemNotice.postIndexedComplete(
                name: medium.name,
                objectCount: objects,
                durationSeconds: duration,
                settings: appState.appSettings
            )
        }
        if outcome.status == .error, let medium = appState.medium(with: mediumUUID) {
            appState.presentIndexingFailure(mediumID: mediumUUID, name: medium.name, reason: outcome.failureReason ?? .unknown)
        }
        if outcome.status == .indexed, !outcome.interrupted, let volume = runVolumes[mediumUUID] {
            onRunIndexed?(mediumUUID, volume)
        } else if outcome.status == .error || (outcome.failureReason != nil && !outcome.interrupted),
                  watchesAfterFailedRun(mediumUUID), let volume = runVolumes[mediumUUID] {
            // bug.0.4.084 (README: beim Anschließen Lauf und sofort Live-Überwachung): Ein gescheiterter Lauf lässt die
            // Überwachung nicht aus, solange das Medium angeschlossen, „Indizieren: Ja“, nicht pausiert und nicht
            // gesperrt ist. Abbrüche (Pause, Sperre, Aushängen, Beenden) kommen hier nicht an: ihr Token ist weg.
            DiskIndexLog.shared.record(.index, .info, "überwachung nach fehler medium=\(mediumUUID)")
            onRunIndexed?(mediumUUID, volume)
        }
        if outcome.status == .indexed, !outcome.interrupted {
            appState.scheduleDatabaseMaintenance()
        }
        runFullReconcile.removeValue(forKey: mediumUUID)
        runVolumes.removeValue(forKey: mediumUUID)
        if rerunAfterFinish.contains(mediumUUID) {
            rerunAfterFinish.remove(mediumUUID)
            if let coordinator, let volume = coordinator.volume(for: mediumUUID) {
                DiskIndexLog.shared.record(.index, .info, "abgleich nachgeholt medium=\(mediumUUID)")
                start(mediumUUID: mediumUUID, volume: volume, fromScratch: false)
            }
        }
        BulkDirectoryReader.flushReadLogSummary(force: true)
        coordinator?.clearIndexRequest(mediumID: mediumUUID)
    }

    private func resumePausedRuns() {
        guard let coordinator, !appState.globalAutoIndexPaused else { return }
        for (id, volume) in coordinator.connectedVolumes() {
            // Ein aktiver Lauf ist nicht angehalten; ein Start würde nur einen zweiten Lauf nachholen (bug.0.4.028).
            guard !isPaused(id), tasks[id] == nil else { continue }
            Task {
                let stored: StoredMedium?
                do {
                    stored = try await store.medium(uuid: id)
                } catch {
                    if DiskIndexLog.isOperationalFailure(error) {
                        DiskIndexLog.shared.record(.store, .error, "store error medium resume \(error)")
                    }
                    return
                }
                guard let stored else { return }
                guard stored.decision == .index else { return }
                guard stored.indexStatus == .pending || stored.indexStatus == .indexing || stored.indexStatus == .indexed else {
                    return
                }
                guard tasks[id] == nil else { return }
                start(mediumUUID: id, volume: volume, fromScratch: false)
            }
        }
    }
}

/// Schmale Brücke, damit der Utility-Task den Main-Actor-Dienst erreicht.
private final class Bridge: @unchecked Sendable {
    private weak var service: IndexingService?

    init(service: IndexingService) {
        self.service = service
    }

    func rememberFullReconcile(_ mediumUUID: UUID, _ fullReconcile: Bool) async {
        await MainActor.run {
            service?.setRunFullReconcile(mediumUUID, fullReconcile)
        }
    }

    /// false, wenn der Lauf zwischenzeitlich abgebrochen wurde (sonst setzt UI wieder `.indexing`).
    func beginRunUI(_ mediumUUID: UUID, token: UUID, reconcileRun: Bool) async -> Bool {
        await MainActor.run {
            guard let service, service.isRunToken(mediumUUID, token) else { return false }
            if !reconcileRun {
                service.markRunIndexing(mediumUUID)
            }
            return true
        }
    }

    func halt(_ mediumUUID: UUID) async -> ScanHalt {
        await MainActor.run { service?.halt(for: mediumUUID) ?? .cancel }
    }

    func publish(_ mediumUUID: UUID, _ progress: IndexProgress) async {
        await service?.publish(mediumUUID, progress)
    }

    func finish(_ mediumUUID: UUID, _ token: UUID, _ outcome: IndexRunOutcome) async {
        await service?.finish(mediumUUID, token, outcome)
    }
}

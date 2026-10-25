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
    /// bug.0.4.162 (i): abgelehnte Starts je Medium (positives Signal für „kein Lauf“).
    private(set) var rejectedStartsForTesting: [UUID: Int] = [:]
    /// bug.0.4.199: kürzere Lese-Wiederholungen je Instanz (nicht lesbare Ordner ohne 1 + 3 + 10 s Wartezeit).
    var runLimitsForTesting: IndexingRunLimits?
    /// bug.0.4.200 (c): Status nach jeder Fortschrittsmeldung (die Abschlussmeldung wird nie gedrosselt).
    var publishedStatusHookForTesting: (@MainActor (UUID, IndexStatus) -> Void)?
    #endif
    /// bug.0.4.162 (f): ein Neustart „von vorn“ wartet auf das Ende des laufenden Laufs – bis dahin bleibt die Sperre
    /// „Neu indizieren“ stehen (der alte Lauf gibt sie beim Abbruch bzw. Ende nicht frei).
    private var scratchRestartPending: Set<UUID> = []
    /// bug.0.4.095: Medien, deren letzter Lauf scheiterte (Überwachung läuft trotzdem): kein voller Abgleich.
    private var fullReconcileSuppressed: Set<UUID> = []

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
    /// Art des laufenden Laufs (bug.0.4.014 Abgleich, damit `cancel` wie `DirectoryIndexer.stop` endet; bug.0.4.200 c
    /// stiller Abgleich bei Lücke). bug.0.4.202 (a): gehört zum Token des Laufs – ein altes `finish` räumt nur seine
    /// eigene ab, nie die eines inzwischen gestarteten Laufs.
    private var runKinds: [UUID: RememberedRunKind] = [:]
    /// Lauf zu Ende: Live-Überwachung starten (nach Erfolg und, bug.0.4.084, nach einem gescheiterten Lauf).
    var onRunIndexed: ((UUID, VolumeInfo) -> Void)?

    /// Merkt die Art aus dem Speicher (`kind`, bestätigt) bzw. behält die aus der Anzeige (`nil`: Speicher nicht lesbar)
    /// und gibt die geltende zurück – `nil`, wenn der Lauf nicht mehr läuft.
    fileprivate func rememberRunKind(_ mediumUUID: UUID, _ token: UUID, _ kind: IndexRunKind?) -> IndexRunKind? {
        // bug.0.4.201 (c): ein abgebrochener Lauf merkt sich nichts mehr (sonst bliebe der Eintrag nach `cancel` stehen).
        guard runs[mediumUUID] == token else { return nil }
        if let kind {
            runKinds[mediumUUID] = RememberedRunKind(
                token: token, kind: kind, confirmedByStore: true, fromScratch: runKinds[mediumUUID]?.fromScratch ?? false
            )
        }
        // bug.0.4.202 (c): Art und Beginn der Anzeige aus derselben Quelle.
        return runKinds[mediumUUID]?.token == token ? runKinds[mediumUUID]?.kind : nil
    }

    /// bug.0.4.203: Nach der Freigabe eines Laufs (`runs[id] = nil`) ist ein eingetragener Lauf ein neuerer – sein altes
    /// `finish` bzw. `cancel` verändert nichts mehr, was ihm gehört (Sperre des Vollabgleichs, Anforderung, Anzeige,
    /// Überwachung, Nachhol-Abgleich). Eine Stelle (Regel 7); nach jedem `await` neu fragen.
    private func newerRunOwns(_ mediumUUID: UUID) -> Bool {
        runs[mediumUUID] != nil
    }

    /// bug.0.4.202 (a): Art dieses Laufs abholen (nur mit seinem Token).
    private func takeRunKind(_ mediumUUID: UUID, _ token: UUID) -> RememberedRunKind? {
        guard runKinds[mediumUUID]?.token == token else { return nil }
        return runKinds.removeValue(forKey: mediumUUID)
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
    /// Tests (bug.0.4.166 b): ein Lauf wurde wegen der Versions-Sperre abgebrochen (vor dem Aufräumen). Je Instanz.
    var versionLockCancelHookForTesting: (@MainActor (UUID) -> Void)?
    /// Tests (bug.0.4.166): läuft in `finish` vor der Entscheidung über die Überwachung nach Fehler. Je Instanz.
    var finishDecisionHookForTesting: (@MainActor (UUID) async -> Void)?
    /// Tests (bug.0.4.073): läuft in `cancel` nach dem Abmelden, vor dem Warten auf den Task. Je Instanz.
    var cancelBeforeAwaitHookForTesting: (@MainActor (UUID) async -> Void)?
    /// Tests (bug.0.4.201 b): läuft in `finish` nach der Token-Prüfung, vor der Entscheidung über den Hinweis. Je Instanz.
    var finishBeforeFailureHookForTesting: (@MainActor (UUID) async -> Void)?
    /// Tests (bug.0.4.203 a): läuft in `finish` direkt nach der Freigabe (`runs[id] = nil`), vor dem Lesen des Speichers.
    var finishAfterReleaseHookForTesting: (@MainActor (UUID) async -> Void)?
    /// Tests (bug.0.4.203 d): das nächste Lesen des Speichers in `cancel` bzw. vor dem Lauf scheitert (nur dieser Aufrufer,
    /// je Instanz; danach wieder aus).
    var failsNextCancelStoreReadForTesting = false
    var failsNextStoreReadBeforeRunForTesting = false
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
        // bug.0.4.139: erst alle Läufe zum Anhalten bringen (merken, Task abbrechen), dann der Reihe nach aufräumen –
        // sonst schreiben die später dran kommenden Läufe weiter, bis sie an der Reihe sind.
        let ids = activeMediumUUIDs()
        var stopped: [UUID] = []
        for id in ids {
            // Inzwischen entsperrt: keine weiteren abbrechen (sonst ginge der Abgleich verloren) …
            guard !appState.featureAccess.canWriteIndex else { break }
            if runKinds[id]?.kind.fullReconcile == true {
                reconcilesInterruptedByVersionLock.insert(id)
            }
            tasks[id]?.cancel()
            stopped.append(id)
            #if DEBUG
            versionLockCancelHookForTesting?(id)
            #endif
        }
        // … die schon abgebrochenen aber immer aufräumen (bug.0.4.159: sonst blieben sie ohne Ende und Status zurück).
        for id in stopped {
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
            rejectStart(mediumUUID)
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
            scratchRestartPending.insert(mediumUUID)
            Task {
                await cancel(mediumUUID: mediumUUID)
                await waitUntilIdle(mediumUUID)
                scratchRestartPending.remove(mediumUUID)
                start(mediumUUID: mediumUUID, volume: volume, fromScratch: true)
            }
            return
        }
        guard !isPaused(mediumUUID) else {
            rejectStart(mediumUUID)
            return
        }
        guard appState.medium(with: mediumUUID)?.decision == .index else {
            DiskIndexLog.shared.record(.index, .info, "auftrag abgelehnt unentschieden medium=\(mediumUUID)")
            rejectStart(mediumUUID)
            return
        }
        DiskIndexLog.shared.record(.index, .info, "auftrag medium=\(mediumUUID) scratch=\(fromScratch)")
        #if DEBUG
        startedRunsForTesting[mediumUUID, default: []].append(fromScratch)
        #endif

        let token = UUID()
        // bug.0.4.095: ein neuer Lauf (Anschließen, Neu indizieren, Pausenende) hebt die Sperre des Vollabgleichs auf.
        fullReconcileSuppressed.remove(mediumUUID)
        runs[mediumUUID] = token
        // bug.0.4.201 (c): Art des Laufs sofort merken (aus dem angezeigten Stand), damit ein `cancel` vor dem Lesen des
        // Speichers „Fehler“ bzw. `.indexed` wiederherstellt; der Lauf berichtigt sie gleich aus dem Speicher.
        // bug.0.4.202 (c): unbestätigt – `cancel` prüft sie gegen den Speicher, bevor es den Stand davor wiederherstellt.
        if let medium = appState.medium(with: mediumUUID) {
            runKinds[mediumUUID] = RememberedRunKind(token: token, kind: IndexRunKind(
                fromScratch: fromScratch,
                completeExceptGaps: medium.hasCompleteIndexExceptGaps,
                completedDepth: medium.completedDepth,
                error: medium.indexStatus == .error
            ), confirmedByStore: false, fromScratch: fromScratch)
        } else {
            runKinds[mediumUUID] = nil
        }
        runVolumes[mediumUUID] = volume
        runStartedAt[mediumUUID] = Date()
        var configuration = ScanConfiguration(
            maxDepth: appState.appSettings.indexedMaxDepth,
            ignoreHiddenFiles: appState.appSettings.ignoreHiddenFiles,
            artifactsIgnored: appState.appSettings.artifactsIgnored,
            excludedPatterns: appState.appSettings.excludedPatterns
        )
        #if DEBUG
        if let runLimitsForTesting { configuration.limits = runLimitsForTesting }
        #endif
        let indexer = indexer
        let store = store
        let access = access
        let bridge = Bridge(service: self)
        #if DEBUG
        let failsStoreRead = failsNextStoreReadBeforeRunForTesting
        failsNextStoreReadBeforeRunForTesting = false
        #else
        let failsStoreRead = false
        #endif
        tasks[mediumUUID] = Task.detached(priority: .utility) {
            var storedBeforeRun: StoredMedium?
            do {
                if failsStoreRead { throw IndexStoreError.unknownMedium }
                storedBeforeRun = try await store.medium(uuid: mediumUUID)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error medium beforeRun \(DiskIndexLog.errorSummary(error))")
                }
                storedBeforeRun = nil
            }
            // bug.0.4.200 (c): ein Medium mit Lücke gleicht ab wie ein `.indexed`-Medium (gleiche Regel wie im Indexer).
            // bug.0.4.201 (c): Speicher nicht lesbar → die in `start` gemerkte Art bleibt (kein Überschreiben mit „kein Abgleich“).
            let storedKind = storedBeforeRun.map {
                IndexRunKind(
                    fromScratch: fromScratch,
                    completeExceptGaps: $0.hasCompleteIndexExceptGaps,
                    completedDepth: $0.completedDepth,
                    error: $0.indexStatus == .error
                )
            }
            let kind = await bridge.rememberRunKind(mediumUUID, token, storedKind)
            let began = await bridge.beginRunUI(mediumUUID, token: token, reconcileRun: kind?.reconcileRun ?? false)
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
        // bug.0.4.152: kein Start mehr, der die Sperre „Neu indizieren“ wieder löst.
        appState.reindexRequested.remove(mediumUUID)
    }

    #if DEBUG
    func hasWaitingStartForTesting(_ mediumUUID: UUID) -> Bool { startsWaitingForCancel[mediumUUID] != nil }
    func hasPendingRerunForTesting(_ mediumUUID: UUID) -> Bool { rerunAfterFinish.contains(mediumUUID) }
    #endif

    func cancel(mediumUUID: UUID) async {
        let task = tasks[mediumUUID]
        guard task != nil || runs[mediumUUID] != nil else { return }
        // bug.0.4.130 (a): ein ausstehender Nachhol-Abgleich überlebt den Abbruch nicht (Sperre, Aushängen, Pause).
        rerunAfterFinish.remove(mediumUUID)
        // bug.0.4.129: Abbruch, bevor der Lauf „wird indiziert“ meldete (Aushängen, Sperre direkt nach dem Klick) →
        // Sperre „Neu indizieren“ freigeben; ein laufender Lauf gibt sie über `.indexing` frei.
        if appState.medium(with: mediumUUID)?.indexStatus != .indexing, !scratchRestartPending.contains(mediumUUID) {
            appState.reindexRequested.remove(mediumUUID)
        }
        task?.cancel()
        guard let token = runs.removeValue(forKey: mediumUUID) else {
            await task?.value
            tasks[mediumUUID] = nil
            return
        }
        runStartedAt.removeValue(forKey: mediumUUID)
        pauseIDs.remove(mediumUUID)
        let remembered = takeRunKind(mediumUUID, token)
        var kind = remembered?.kind
        // bug.0.4.203 (b): unbestätigt immer gegen den Speicher prüfen, gleich was die Anzeige sagte (auch „kein Abgleich“).
        if let remembered, !remembered.confirmedByStore {
            // bug.0.4.202 (c): Abbruch vor dem Lesen des Speichers – den Stand davor nur so wiederherstellen, wie ihn der
            // Speicher bestätigt (nie ein `.indexed` bzw. „Fehler“ mit Lücke schreiben, das dort nicht stand); nicht
            // lesbar → `.pending`.
            var stored: StoredMedium?
            #if DEBUG
            let failsStoreRead = failsNextCancelStoreReadForTesting
            failsNextCancelStoreReadForTesting = false
            #else
            let failsStoreRead = false
            #endif
            if !failsStoreRead {
                stored = try? await store.medium(uuid: mediumUUID)
            }
            kind = stored.map {
                IndexRunKind(
                    fromScratch: remembered.fromScratch,
                    completeExceptGaps: $0.hasCompleteIndexExceptGaps,
                    completedDepth: $0.completedDepth,
                    error: $0.indexStatus == .error
                )
            }
        }
        let reconcileInterrupted = kind?.fullReconcile ?? false
        // bug.0.4.200 (c): abgebrochener Abgleich eines Mediums mit Lücke bleibt „Fehler“ (wie `DirectoryIndexer.stop`).
        let quietGap = kind?.quietGap ?? false
        let restored: StoredIndexStatus = quietGap ? .error : (reconcileInterrupted ? .indexed : .pending)
        do {
            _ = try await store.finishIndexing(
                mediumUUID: mediumUUID,
                token: token,
                status: restored,
                firstIndexedAt: nil,
                interrupted: reconcileInterrupted
            )
        } catch {
            DiskIndexLog.shared.record(.index, .error, "abbruch \(DiskIndexLog.errorSummary(error))")
        }
        DiskIndexLog.shared.record(.index, .info, "abgebrochen medium=\(mediumUUID)")
        if runs[mediumUUID] == nil {
            appState.clearMenuBarRunIndicators(mediumUUID)
            appState.updateMedium(id: mediumUUID) {
                $0.indexStatus = IndexStatus(rawValue: restored.rawValue) ?? .pending
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

    /// bug.0.4.095: Überwachung nach einem gescheiterten Lauf, aber nicht nach Zeitüberschreitung (hängendes Medium)
    /// und nicht nach einem Abbruch. bug.0.4.186: auch nicht nach „Medium konnte nicht bestätigt werden“ (unter dem
    /// Pfad kann ein anderes Medium liegen); der nächste Lauf versucht es neu.
    nonisolated static func watchesAfterFailure(_ outcome: IndexRunOutcome) -> Bool {
        guard outcome.failureReason != .timeout, outcome.failureReason != .unconfirmed, !outcome.interrupted else { return false }
        return outcome.status == .error || outcome.failureReason != nil
    }

    /// bug.0.4.095: Nach einem gescheiterten Lauf kein voller Abgleich aus der Überwachung, bis ein Lauf neu startet.
    func suppressesFullReconcile(_ mediumUUID: UUID) -> Bool {
        fullReconcileSuppressed.contains(mediumUUID)
    }

    func watchesAfterFailedRun(_ mediumUUID: UUID) -> Bool {
        guard appState.featureAccess.canWriteIndex, !isPaused(mediumUUID),
              let medium = appState.medium(with: mediumUUID) else { return false }
        return medium.connectionStatus == .connected && medium.decision == .index && medium.allowIndexing
    }

    /// Start abgelehnt: Auftrag und Sperre „Neu indizieren“ freigeben (bug.0.4.129), sonst bliebe der Knopf bis zum
    /// Neustart gesperrt.
    private func rejectStart(_ mediumUUID: UUID) {
        #if DEBUG
        rejectedStartsForTesting[mediumUUID, default: 0] += 1
        #endif
        coordinator?.clearIndexRequest(mediumID: mediumUUID)
        appState.reindexRequested.remove(mediumUUID)
    }

    private func isPaused(_ mediumUUID: UUID) -> Bool {
        if appState.globalAutoIndexPaused || appState.heldForSleep { return true }
        if appState.medium(with: mediumUUID)?.autoIndexPaused == true { return true }
        return false
    }

    fileprivate func halt(for mediumUUID: UUID) -> ScanHalt {
        guard runs[mediumUUID] != nil else { return .cancel }
        // bug.0.4.139: gesperrt (Versions-Sperre) → sofort anhalten, ohne auf den Abbruch der Reihe nach zu warten.
        if !appState.featureAccess.canWriteIndex { return .pause }
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
            // bug.0.4.200 (c): Abgleich eines Mediums mit Lücke zeigt weiter „Fehler“, wie ein `.indexed`-Medium „Online“.
            if !$0.hasCompleteIndexExceptGaps {
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
        #if DEBUG
        if let status = appState.medium(with: mediumUUID)?.indexStatus {
            publishedStatusHookForTesting?(mediumUUID, status)
        }
        #endif
    }

    fileprivate func finish(_ mediumUUID: UUID, _ token: UUID, _ outcome: IndexRunOutcome) async {
        guard runs[mediumUUID] == token else { return }
        // bug.0.4.202 (a): Merker dieses Laufs abholen, bevor er freigegeben wird – nach den `await`s unten kann schon
        // ein neuer Lauf desselben Mediums laufen (Überwachung, „Neu indizieren“).
        let kind = takeRunKind(mediumUUID, token)?.kind
        let runVolume = runVolumes.removeValue(forKey: mediumUUID)
        tasks[mediumUUID] = nil
        // bug.0.4.152: der Lauf ist zu Ende (auch ein abgelehnter Beginn) – eine Sperre „Neu indizieren“ gilt nicht mehr,
        // außer der Neustart von vorn wartet schon (bug.0.4.162 f: erst der neue Lauf gibt sie frei).
        if !scratchRestartPending.contains(mediumUUID) {
            appState.reindexRequested.remove(mediumUUID)
        }
        appState.clearMenuBarRunIndicators(mediumUUID)
        // bug.0.4.203 (a): auch die Startzeit gehört diesem Lauf – vor der Freigabe abholen.
        let started = runStartedAt.removeValue(forKey: mediumUUID)
        runs[mediumUUID] = nil
        #if DEBUG
        await finishAfterReleaseHookForTesting?(mediumUUID)
        #endif
        DiskIndexLog.shared.record(.index, .info, "lauf ende medium=\(mediumUUID) status=\(outcome.status)")
        var stored: StoredMedium?
        do {
            stored = try await store.medium(uuid: mediumUUID)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error medium finish \(DiskIndexLog.errorSummary(error))")
            }
            stored = nil
        }
        // bug.0.4.203 (a): Status, Fortschritt und Phase gehören einem inzwischen gestarteten Lauf (die Zahlen aus dem
        // Speicher gelten weiter).
        let ownsDisplay = !newerRunOwns(mediumUUID)
        appState.updateMedium(id: mediumUUID) {
            if ownsDisplay {
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
                $0.indexRunPhase = .indexing
            }
            if let stored {
                $0.fileCount = stored.fileCount
                $0.folderCount = stored.folderCount
                $0.scanTotal = stored.scanTotal
                $0.hasIndexGaps = stored.hasIndexGaps
                $0.completedDepth = stored.completedDepth
                $0.lastIndexedAt = stored.lastIndexedAt
                $0.lastIndexActivityAt = stored.lastIndexActivityAt
            }
        }
        if outcome.status == .indexed, !outcome.interrupted {
            appState.endIndexingFailure(mediumID: mediumUUID)
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
        // bug.0.4.200 (c): stiller Abgleich mit bleibender Lücke → kein neuer Hinweis, keine neue Mitteilung; ein
        // unterbrochener Abgleich (Pause, Abbruch) ist nie ein neuer Fehler. (e): Hinweis nur für angeschlossene Medien
        // (Konzept 2b).
        #if DEBUG
        await finishBeforeFailureHookForTesting?(mediumUUID)
        #endif
        let quietGap = kind?.quietGap ?? false
        let gapRemains = quietGap && outcome.failureReason == .unreadableFolders
        // bug.0.4.203: läuft schon ein neuer Lauf, meldet er selbst sein Ergebnis (kein Hinweis mitten in seinem Lauf).
        if outcome.status == .error, !gapRemains, !outcome.interrupted, !newerRunOwns(mediumUUID),
           let medium = appState.medium(with: mediumUUID), medium.connectionStatus == .connected, isStillMounted(mediumUUID) {
            appState.presentIndexingFailure(mediumID: mediumUUID, name: medium.name, reason: outcome.failureReason ?? .unknown)
        }
        #if DEBUG
        // Tests (bug.0.4.166): Zustand ändern, nachdem der Lauf geendet hat und bevor über die Überwachung entschieden wird.
        await finishDecisionHookForTesting?(mediumUUID)
        #endif
        // bug.0.4.127: auch ein Lauf bis zum Ende mit nicht lesbaren Ordnern (bug.0.4.199: `.error`) startet die Überwachung.
        let finishedRun = !outcome.interrupted && (outcome.status == .indexed || outcome.ranToEnd)
        // bug.0.4.203 (a): Sperre, Überwachung und Nachhol-Abgleich gehören einem inzwischen gestarteten Lauf.
        let superseded = newerRunOwns(mediumUUID)
        if finishedRun, !superseded {
            fullReconcileSuppressed.remove(mediumUUID)
        }
        // bug.0.4.202 (b): keine Überwachung für ein beim Laufende ausgehängtes Medium (wie beim Hinweis).
        let mounted = isStillMounted(mediumUUID)
        if superseded {
            DiskIndexLog.shared.record(.index, .info, "neuer lauf übernimmt medium=\(mediumUUID)")
        } else if finishedRun, mounted, let volume = runVolume {
            onRunIndexed?(mediumUUID, volume)
        } else if !finishedRun, mounted, Self.watchesAfterFailure(outcome), watchesAfterFailedRun(mediumUUID), let volume = runVolume {
            // bug.0.4.084 (README: beim Anschließen Lauf und sofort Live-Überwachung): Ein gescheiterter Lauf lässt die
            // Überwachung nicht aus, solange das Medium angeschlossen, „Indizieren: Ja“, nicht pausiert und nicht
            // gesperrt ist. Abbruch, Sperre, Aushängen und Beenden während des Laufs kommen hier nicht an (ihr Token ist
            // weg); eine Pause während des Laufs endet unterbrochen und fällt durch `watchesAfterFailure`. Die Prüfung
            // von Pause und Sperre in `watchesAfterFailedRun` betrifft nur Zustände, die zwischen Laufende und dieser
            // Entscheidung eintreten (bug.0.4.166/172 b).
            // bug.0.4.095: bis zum nächsten Lauf (erfolgreich oder neu angestoßen) löst die Überwachung keinen vollen
            // Abgleich aus, nur Einzeländerungen – sonst startet jede Änderung einen Lauf, der wieder scheitert.
            fullReconcileSuppressed.insert(mediumUUID)
            DiskIndexLog.shared.record(.index, .info, "überwachung nach fehler medium=\(mediumUUID)")
            onRunIndexed?(mediumUUID, volume)
        }
        if finishedRun {
            appState.scheduleDatabaseMaintenance()
        }
        if !superseded, rerunAfterFinish.contains(mediumUUID) {
            rerunAfterFinish.remove(mediumUUID)
            if let coordinator, let volume = coordinator.volume(for: mediumUUID) {
                DiskIndexLog.shared.record(.index, .info, "abgleich nachgeholt medium=\(mediumUUID)")
                start(mediumUUID: mediumUUID, volume: volume, fromScratch: false)
            }
        }
        BulkDirectoryReader.flushReadLogSummary(force: true)
        if !newerRunOwns(mediumUUID) {
            coordinator?.clearIndexRequest(mediumID: mediumUUID)
        }
    }

    /// bug.0.4.201 (b): eingehängt laut Koordinator (das Aushängen trägt den Pfad vor jedem `await` aus); ohne
    /// Koordinator (Dienst allein) zählt nur der angezeigte Verbindungsstatus.
    private func isStillMounted(_ mediumUUID: UUID) -> Bool {
        guard let coordinator else { return true }
        return coordinator.volume(for: mediumUUID) != nil
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
                        DiskIndexLog.shared.record(.store, .error, "store error medium resume \(DiskIndexLog.errorSummary(error))")
                    }
                    return
                }
                guard let stored else { return }
                guard stored.decision == .index else { return }
                // bug.0.4.201 (a): ein Medium mit Lücke gleicht ab wie ein `.indexed`-Medium.
                guard stored.indexStatus == .pending || stored.indexStatus == .indexing || stored.hasCompleteIndexExceptGaps else {
                    return
                }
                guard tasks[id] == nil else { return }
                start(mediumUUID: id, volume: volume, fromScratch: false)
            }
        }
    }
}

/// Art des Laufs aus dem Stand davor (bug.0.4.014 Abgleich, bug.0.4.200 c stiller Abgleich bei Lücke).
nonisolated struct IndexRunKind: Sendable {
    /// Voller Abgleich: unterbrochen bleibt der Stand davor.
    let fullReconcile: Bool
    /// Abgleich eines Mediums mit Lücke: Status bleibt „Fehler“, bleibt die Lücke, kein neuer Hinweis.
    let quietGap: Bool
    /// Ohne „wird indiziert“ beginnen.
    let reconcileRun: Bool

    init(fromScratch: Bool, completeExceptGaps: Bool, completedDepth: Int, error: Bool) {
        reconcileRun = !fromScratch && completeExceptGaps
        fullReconcile = reconcileRun && completedDepth > 0
        quietGap = fullReconcile && error
    }
}

/// bug.0.4.202: Art eines Laufs mit seinem Token; `confirmedByStore` = aus dem Speicher (sonst aus der Anzeige).
private struct RememberedRunKind {
    let token: UUID
    let kind: IndexRunKind
    let confirmedByStore: Bool
    /// bug.0.4.203 (b): für die Prüfung gegen den Speicher in `cancel`.
    let fromScratch: Bool
}

/// Schmale Brücke, damit der Utility-Task den Main-Actor-Dienst erreicht.
private final class Bridge: @unchecked Sendable {
    private weak var service: IndexingService?

    init(service: IndexingService) {
        self.service = service
    }

    func rememberRunKind(_ mediumUUID: UUID, _ token: UUID, _ kind: IndexRunKind?) async -> IndexRunKind? {
        await MainActor.run {
            service?.rememberRunKind(mediumUUID, token, kind)
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

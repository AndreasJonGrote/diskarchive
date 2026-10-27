//
//  IndexingService.swift
//  diskindex
//

import Foundation

/// Hält höchstens einen Lauf je Medium und schickt Fortschritt an `AppState`. bug.0.4.204: je Medium höchstens ein
/// Lebenszyklus „Start → Lauf → Abschluss bzw. Abbruch“ (`lifecycles`, Wächter in DEBUG).
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
    /// Starts während Abschluss bzw. Abbruch eines Laufs, je Medium zusammengefasst (bug.0.4.080 a). bug.0.4.204 (b):
    /// nur eine Merkliste – `endLifecycle` startet sie als letzter Schritt des Lebenszyklus (kein Task, kein Abfragen).
    private var startsWaitingForCancel: [UUID: (volume: VolumeInfo, fromScratch: Bool)] = [:]
    /// bug.0.4.204: je Medium höchstens ein Lebenszyklus „Start → Lauf → Abschluss bzw. Abbruch“. `start` legt ihn an,
    /// `finish` bzw. `cancel` setzen vor der Freigabe den Schlussmarker (`closing`) und lösen ihn als allerletzten
    /// Schritt (`endLifecycle`). Bis dahin warten ein neuer Start (`startsWaitingForCancel`) und ein weiterer `cancel`
    /// bzw. `waitUntilIdle` (Fortsetzung in `waiters`). `finish`/`cancel` warten nie selbst auf den Marker.
    private var lifecycles: [UUID: RunLifecycle] = [:]
    #if DEBUG
    /// bug.0.4.204 (d): Wächter, unabhängig vom Marker geführt – Lebenszyklus je Medium von `start` bis zur letzten Zeile
    /// von `finish` bzw. `cancel`. Ein zweiter zur selben Zeit (Marker zu früh gelöst, Start ohne Warten) bricht hart ab.
    private var guardedLifecycles: [UUID: (token: UUID, closing: Bool)] = [:]
    #endif
    /// Art des laufenden Laufs (bug.0.4.014 Abgleich, damit `cancel` wie `DirectoryIndexer.stop` endet; bug.0.4.200 c
    /// stiller Abgleich bei Lücke). bug.0.4.204: je Medium (nur ein Lebenszyklus).
    private var runKinds: [UUID: RememberedRunKind] = [:]
    /// Lauf zu Ende: Live-Überwachung starten (nach Erfolg und, bug.0.4.084, nach einem gescheiterten Lauf).
    var onRunIndexed: ((UUID, VolumeInfo) -> Void)?

    /// Merkt die Art aus dem Speicher (`kind`, bestätigt) bzw. behält die aus der Anzeige (`nil`: Speicher nicht lesbar)
    /// und gibt die geltende zurück – `nil`, wenn der Lauf nicht mehr läuft.
    fileprivate func rememberRunKind(_ mediumUUID: UUID, _ token: UUID, _ kind: IndexRunKind?) -> IndexRunKind? {
        // bug.0.4.201 (c): ein abgebrochener Lauf merkt sich nichts mehr (sonst bliebe der Eintrag nach `cancel` stehen).
        guard isRunToken(mediumUUID, token) else { return nil }
        if let kind {
            runKinds[mediumUUID] = RememberedRunKind(
                kind: kind, confirmedByStore: true, fromScratch: runKinds[mediumUUID]?.fromScratch ?? false
            )
        }
        // bug.0.4.202 (c): Art und Beginn der Anzeige aus derselben Quelle.
        return runKinds[mediumUUID]?.kind
    }

    /// bug.0.4.204: wartet, bis der laufende Lebenszyklus des Mediums endet (Fortsetzung am Marker, kein Abfragen).
    private func waitForLifecycleEnd(_ mediumUUID: UUID) async {
        guard lifecycles[mediumUUID] != nil else { return }
        await withCheckedContinuation { lifecycles[mediumUUID]?.waiters.append($0) }
    }

    /// bug.0.4.204: allerletzter Schritt von `finish` bzw. `cancel` – Marker lösen, einen wartenden Start starten, jede
    /// wartende Fortsetzung genau einmal fortsetzen.
    private func endLifecycle(_ mediumUUID: UUID, _ token: UUID) {
        guard lifecycles[mediumUUID]?.token == token, let ended = lifecycles.removeValue(forKey: mediumUUID) else { return }
        if let waiting = startsWaitingForCancel.removeValue(forKey: mediumUUID) {
            scratchRestartPending.remove(mediumUUID)
            if isStillMounted(mediumUUID) {
                start(mediumUUID: mediumUUID, volume: waiting.volume, fromScratch: waiting.fromScratch)
            } else {
                // Ausgehängt ohne `willDisappear` (Kabel gezogen): kein Lauf mit dem alten Volume (wie `discardWaitingStart`).
                appState.reindexRequested.remove(mediumUUID)
                DiskIndexLog.shared.record(.index, .info, "wartender start verworfen nicht eingehängt medium=\(mediumUUID)")
            }
        }
        for waiter in ended.waiters {
            waiter.resume()
        }
    }

    /// bug.0.4.204 (a): Aushängen, Sperre, Nein oder Pause während Abschluss bzw. Abbruch – der Endstand bleibt, aber
    /// kein Nachhol-Abgleich und keine Überwachung mehr.
    private func abortWhileClosing(_ mediumUUID: UUID) {
        rerunAfterFinish.remove(mediumUUID)
        lifecycles[mediumUUID]?.abortedWhileClosing = true
    }

    /// bug.0.4.204 (d): Wächter beim Start (kein anderer Lebenszyklus desselben Mediums), beim Beginn von Abschluss bzw.
    /// Abbruch (der eigene, noch nicht im Abschluss) und an deren letzter Zeile. Nur in DEBUG; Release unverändert.
    private func guardLifecycle(_ mediumUUID: UUID, _ token: UUID, _ step: LifecycleStep, _ place: StaticString) {
        #if DEBUG
        let owner = guardedLifecycles[mediumUUID]
        let valid = switch step {
        case .begins: owner == nil
        case .closes: owner?.token == token && owner?.closing == false
        case .ends: owner?.token == token && owner?.closing == true
        case .terminates: owner?.token == token
        }
        if !valid {
            assertionFailure("zwei lebenszyklen medium=\(mediumUUID) stelle=\(place)")
        }
        switch step {
        case .begins: guardedLifecycles[mediumUUID] = (token, false)
        case .closes: guardedLifecycles[mediumUUID] = (token, true)
        case .ends, .terminates: guardedLifecycles[mediumUUID] = nil
        }
        #endif
    }

    init(store: IndexStoreV3, access: any MediumAccess, appState: AppState) {
        self.store = store
        self.access = access
        self.appState = appState
    }

    func attach(_ coordinator: MediumCoordinator) {
        self.coordinator = coordinator
    }

    /// bug.0.4.204: auch im Abschluss und mit wartendem Start – sonst startete z. B. das Umbenennen die Überwachung neben
    /// dem gleich anlaufenden Lauf.
    func isRunActive(_ mediumUUID: UUID) -> Bool {
        lifecycles[mediumUUID] != nil || startsWaitingForCancel[mediumUUID] != nil
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
    /// Tests (bug.0.4.204 a): ein `cancel` kam an, während Abschluss bzw. Abbruch des Laufs noch läuft (vor dem Warten).
    var cancelWhileClosingHookForTesting: (@MainActor (UUID) -> Void)?
    #endif

    /// Bleibt (bug.0.4.204 c): trennt innerhalb eines Lebenszyklus den abgebrochenen Lauf von seinen späten Schritten
    /// (Beginn der Anzeige, Merken der Art).
    fileprivate func isRunToken(_ mediumUUID: UUID, _ token: UUID) -> Bool {
        runs[mediumUUID] == token
    }

    /// `progress`: Anfangswert der Anzeige (bug.0.4.210: gespeicherter Stand, bei „Neu indizieren“ 0).
    fileprivate func markRunIndexing(_ mediumUUID: UUID, progress: Double) {
        appState.noteMenuBarIndexingSpinner(mediumUUID, active: true)
        appState.updateMedium(id: mediumUUID) {
            $0.indexStatus = .indexing
            $0.indexingProgress = progress
        }
    }

    /// bug.0.4.204 (a): auch Medien im Abschluss – die Sperre erreicht sie (`cancel` streicht den Nachhol-Abgleich).
    func activeMediumUUIDs() -> [UUID] {
        Array(lifecycles.keys)
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
        if startsWaitingForCancel[mediumUUID] != nil || lifecycles[mediumUUID]?.closing == true {
            // bug.0.4.204: Abschluss bzw. Abbruch läuft noch – warten, bis `endLifecycle` diesen Start als letzten
            // Schritt startet (bug.0.4.073). bug.0.4.080 a): Weitere Starts in dieser Zeit (LiveWiring und Koordinator)
            // gehen in denselben Neustart.
            let waiting = startsWaitingForCancel[mediumUUID]
            startsWaitingForCancel[mediumUUID] = (volume, (waiting?.fromScratch ?? false) || fromScratch)
            return
        }
        if let running = lifecycles[mediumUUID] {
            guard fromScratch else {
                rerunAfterFinish.insert(mediumUUID)
                return
            }
            // bug.0.4.162 (f): Neustart von vorn – wartet als Start am Marker, bis der Abbruch dieses Laufs fertig ist.
            scratchRestartPending.insert(mediumUUID)
            startsWaitingForCancel[mediumUUID] = (volume, true)
            Task {
                // Nur diesen Lauf abbrechen (endete er inzwischen, läuft der Neustart schon).
                guard lifecycles[mediumUUID]?.token == running.token else { return }
                await cancel(mediumUUID: mediumUUID)
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
        guardLifecycle(mediumUUID, token, .begins, "start")
        lifecycles[mediumUUID] = RunLifecycle(token: token)
        // bug.0.4.095: ein neuer Lauf (Anschließen, Neu indizieren, Pausenende) hebt die Sperre des Vollabgleichs auf.
        fullReconcileSuppressed.remove(mediumUUID)
        runs[mediumUUID] = token
        // bug.0.4.201 (c): Art des Laufs sofort merken (aus dem angezeigten Stand), damit ein `cancel` vor dem Lesen des
        // Speichers „Fehler“ bzw. `.indexed` wiederherstellt; der Lauf berichtigt sie gleich aus dem Speicher.
        // bug.0.4.202 (c): unbestätigt – `cancel` prüft sie gegen den Speicher, bevor es den Stand davor wiederherstellt.
        if let medium = appState.medium(with: mediumUUID) {
            runKinds[mediumUUID] = RememberedRunKind(kind: IndexRunKind(
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
            // bug.0.4.210: dieselbe Rechnung wie die Anzeige des gespeicherten Stands; „Neu indizieren“ zählt nur sich.
            let initialProgress = fromScratch ? 0 : storedBeforeRun.map {
                IndexProgress.displayed(entries: $0.fileCount + $0.folderCount, total: $0.scanTotal, indexed: false)
            } ?? 0
            let began = await bridge.beginRunUI(
                mediumUUID, token: token, reconcileRun: kind?.reconcileRun ?? false, initialProgress: initialProgress
            )
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
        // bug.0.4.085 a), 204 (b): kein wartender Start und kein Nachhol-Abgleich läuft nach dem Beenden noch an.
        startsWaitingForCancel.removeAll()
        scratchRestartPending.removeAll()
        rerunAfterFinish.removeAll()
        for (id, lifecycle) in lifecycles {
            if lifecycle.closing {
                // Abschluss bzw. Abbruch läuft weiter und löst den Marker selbst – ohne Überwachung.
                lifecycles[id]?.abortedWhileClosing = true
            } else {
                // Laufende Läufe kommen nie zu `finish` (Token weg): ihr Lebenszyklus endet hier, Wartende laufen weiter.
                guardLifecycle(id, lifecycle.token, .terminates, "beenden")
                endLifecycle(id, lifecycle.token)
            }
        }
        for id in Array(tasks.keys) {
            appState.clearMenuBarRunIndicators(id)
            runs.removeValue(forKey: id)
            tasks[id]?.cancel()
            tasks[id] = nil
        }
        pauseIDs.removeAll()
    }

    /// bug.0.4.085 a): Medium wird ausgehängt – ein wartender Start (mit altem Volume) läuft nicht mehr an.
    func discardWaitingStart(mediumUUID: UUID) {
        startsWaitingForCancel[mediumUUID] = nil
        scratchRestartPending.remove(mediumUUID)
        // bug.0.4.152: kein Start mehr, der die Sperre „Neu indizieren“ wieder löst.
        appState.reindexRequested.remove(mediumUUID)
    }

    #if DEBUG
    func hasWaitingStartForTesting(_ mediumUUID: UUID) -> Bool { startsWaitingForCancel[mediumUUID] != nil }
    func hasPendingRerunForTesting(_ mediumUUID: UUID) -> Bool { rerunAfterFinish.contains(mediumUUID) }
    #endif

    func cancel(mediumUUID: UUID) async {
        guard let lifecycle = lifecycles[mediumUUID] else { return }
        if lifecycle.closing {
            // bug.0.4.204 (a): Abschluss bzw. Abbruch läuft – dessen Endstand bleibt (kein zweites Wiederherstellen),
            // kein Nachhol-Abgleich, keine Überwachung; auf das Ende warten. Ein wartender Start bleibt (nur Aushängen
            // und Beenden verwerfen ihn; Sperre, Nein und Pause lehnt `start` selbst ab).
            abortWhileClosing(mediumUUID)
            #if DEBUG
            cancelWhileClosingHookForTesting?(mediumUUID)
            #endif
            await waitForLifecycleEnd(mediumUUID)
            return
        }
        let token = lifecycle.token
        guardLifecycle(mediumUUID, token, .closes, "abbruch")
        lifecycles[mediumUUID]?.closing = true
        // bug.0.4.204: die Anforderung gehört diesem Lauf; was ab jetzt angefordert wird, dem nächsten Lebenszyklus.
        coordinator?.clearIndexRequest(mediumID: mediumUUID)
        let task = tasks[mediumUUID]
        // bug.0.4.130 (a): ein ausstehender Nachhol-Abgleich überlebt den Abbruch nicht (Sperre, Aushängen, Pause).
        rerunAfterFinish.remove(mediumUUID)
        // bug.0.4.129: Abbruch, bevor der Lauf „wird indiziert“ meldete (Aushängen, Sperre direkt nach dem Klick) →
        // Sperre „Neu indizieren“ freigeben; ein laufender Lauf gibt sie über `.indexing` frei.
        if appState.medium(with: mediumUUID)?.indexStatus != .indexing, !scratchRestartPending.contains(mediumUUID) {
            appState.reindexRequested.remove(mediumUUID)
        }
        task?.cancel()
        runs[mediumUUID] = nil
        runStartedAt.removeValue(forKey: mediumUUID)
        pauseIDs.remove(mediumUUID)
        let remembered = runKinds.removeValue(forKey: mediumUUID)
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
        appState.clearMenuBarRunIndicators(mediumUUID)
        appState.updateMedium(id: mediumUUID) {
            $0.indexStatus = IndexStatus(rawValue: restored.rawValue) ?? .pending
        }
        #if DEBUG
        await cancelBeforeAwaitHookForTesting?(mediumUUID)
        #endif
        await task?.value
        tasks[mediumUUID] = nil
        BulkDirectoryReader.flushReadLogSummary(force: true)
        guardLifecycle(mediumUUID, token, .ends, "abbruch ende")
        endLifecycle(mediumUUID, token)
    }

    /// Popover-Schalter „Automatisches Indizieren“.
    func pauseChanged() {
        if appState.globalAutoIndexPaused {
            pauseIDs.formUnion(runs.keys)
            // bug.0.4.204 (a): Pause während Abschluss bzw. Abbruch – kein Nachhol-Abgleich, keine Überwachung.
            for (id, lifecycle) in lifecycles where lifecycle.closing {
                abortWhileClosing(id)
            }
        } else {
            pauseIDs.removeAll()
            resumePausedRuns()
        }
    }

    /// bug.0.4.204 (b): bis kein Lebenszyklus des Mediums mehr läuft – am Marker (Fortsetzung), kein Abfragen.
    func waitUntilIdle(_ mediumUUID: UUID) async {
        while lifecycles[mediumUUID] != nil {
            await waitForLifecycleEnd(mediumUUID)
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
                // bug.0.4.210: nie fallend innerhalb eines Laufs (eine neue Zählung kann die Gesamtzahl erhöhen).
                $0.indexingProgress = max($0.indexingProgress, progress.ratio)
            }
        }
        #if DEBUG
        if let status = appState.medium(with: mediumUUID)?.indexStatus {
            publishedStatusHookForTesting?(mediumUUID, status)
        }
        #endif
    }

    fileprivate func finish(_ mediumUUID: UUID, _ token: UUID, _ outcome: IndexRunOutcome) async {
        // Bleibt (bug.0.4.204 c): trennt innerhalb eines Lebenszyklus den abgebrochenen Lauf von seinem eigenen späten
        // Ende – nach `cancel` gehört der Abschluss dem Abbruch.
        guard runs[mediumUUID] == token else { return }
        guardLifecycle(mediumUUID, token, .closes, "abschluss")
        // bug.0.4.204: Schlussmarker vor der Freigabe – bis `endLifecycle` unten startet kein neuer Lauf desselben Mediums.
        lifecycles[mediumUUID]?.closing = true
        let kind = runKinds.removeValue(forKey: mediumUUID)?.kind
        let runVolume = runVolumes.removeValue(forKey: mediumUUID)
        tasks[mediumUUID] = nil
        // bug.0.4.152: der Lauf ist zu Ende (auch ein abgelehnter Beginn) – eine Sperre „Neu indizieren“ gilt nicht mehr,
        // außer der Neustart von vorn wartet schon (bug.0.4.162 f: erst der neue Lauf gibt sie frei).
        if !scratchRestartPending.contains(mediumUUID) {
            appState.reindexRequested.remove(mediumUUID)
        }
        appState.clearMenuBarRunIndicators(mediumUUID)
        let started = runStartedAt.removeValue(forKey: mediumUUID)
        runs[mediumUUID] = nil
        // bug.0.4.204: die Anforderung gehört diesem Lauf; was ab jetzt angefordert wird, dem nächsten Lebenszyklus.
        coordinator?.clearIndexRequest(mediumID: mediumUUID)
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
        appState.updateMedium(id: mediumUUID) {
            // bug.0.4.204 (4): die Anzeige des Laufs neu bestimmen – ein danach wartender stiller Abgleich zeigt sie
            // weiter (nie das „wird indiziert“ dieses Laufs).
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
        // (Konzept 2b). bug.0.4.204 K2: „Nein“ im Abschluss (der `cancel` wartet am Marker) → kein Hinweis, keine Mitteilung.
        #if DEBUG
        await finishBeforeFailureHookForTesting?(mediumUUID)
        #endif
        let quietGap = kind?.quietGap ?? false
        let gapRemains = quietGap && outcome.failureReason == .unreadableFolders
        if outcome.status == .error, !gapRemains, !outcome.interrupted,
           let medium = appState.medium(with: mediumUUID), medium.decision == .index, medium.allowIndexing,
           medium.connectionStatus == .connected, isStillMounted(mediumUUID) {
            appState.presentIndexingFailure(mediumID: mediumUUID, name: medium.name, reason: outcome.failureReason ?? .unknown)
        }
        #if DEBUG
        // Tests (bug.0.4.166): Zustand ändern, nachdem der Lauf geendet hat und bevor über die Überwachung entschieden wird.
        await finishDecisionHookForTesting?(mediumUUID)
        #endif
        // bug.0.4.127: auch ein Lauf bis zum Ende mit nicht lesbaren Ordnern (bug.0.4.199: `.error`) startet die Überwachung.
        let finishedRun = !outcome.interrupted && (outcome.status == .indexed || outcome.ranToEnd)
        if finishedRun {
            fullReconcileSuppressed.remove(mediumUUID)
        }
        // bug.0.4.202 (b): keine Überwachung für ein beim Laufende ausgehängtes Medium (wie beim Hinweis).
        let mounted = isStillMounted(mediumUUID)
        // bug.0.4.204: nach einem Abbruch im Abschluss keine Überwachung (a); wartet ein Start, überwacht sein Lauf an
        // seinem Ende – nicht schon jetzt neben ihm (er startet ohne `ChangeWatcher.stop`). Der Nachhol-Abgleich
        // (`rerunAfterFinish`, unten) startet ebenso ohne `stop`, übernimmt die Überwachung aber bewusst nicht: sie läuft
        // neben ihm weiter, ihr Flush wartet über `isRunActive` (Entscheidung „so lassen“, Paket 29).
        let watchHandedOn = lifecycles[mediumUUID]?.abortedWhileClosing == true || startsWaitingForCancel[mediumUUID] != nil
        if finishedRun, mounted, watchHandedOn {
            DiskIndexLog.shared.record(.index, .info, "überwachung übergeben medium=\(mediumUUID)")
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
            if watchHandedOn {
                DiskIndexLog.shared.record(.index, .info, "überwachung übergeben medium=\(mediumUUID)")
            } else {
                DiskIndexLog.shared.record(.index, .info, "überwachung nach fehler medium=\(mediumUUID)")
                onRunIndexed?(mediumUUID, volume)
            }
        }
        if finishedRun {
            appState.scheduleDatabaseMaintenance()
        }
        if rerunAfterFinish.remove(mediumUUID) != nil, let coordinator, let volume = coordinator.volume(for: mediumUUID) {
            // bug.0.4.204: wartet als Start am Marker und läuft erst nach `endLifecycle` an.
            DiskIndexLog.shared.record(.index, .info, "abgleich nachgeholt medium=\(mediumUUID)")
            start(mediumUUID: mediumUUID, volume: volume, fromScratch: false)
        }
        BulkDirectoryReader.flushReadLogSummary(force: true)
        guardLifecycle(mediumUUID, token, .ends, "abschluss ende")
        endLifecycle(mediumUUID, token)
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

/// bug.0.4.204 (d): Stellen, an denen der Wächter prüft.
private enum LifecycleStep {
    case begins, closes, ends, terminates
}

/// bug.0.4.204: Lebenszyklus eines Laufs (je Medium höchstens einer).
private struct RunLifecycle {
    let token: UUID
    /// Schlussmarker: `finish` bzw. `cancel` läuft (gesetzt vor der Freigabe).
    var closing = false
    /// (a) Aushängen, Sperre, Nein oder Pause während des Abschlusses.
    var abortedWhileClosing = false
    /// Wartende `cancel` bzw. `waitUntilIdle`, je genau einmal in `endLifecycle` fortgesetzt.
    var waiters: [CheckedContinuation<Void, Never>] = []
}

/// bug.0.4.202: Art eines Laufs; `confirmedByStore` = aus dem Speicher (sonst aus der Anzeige).
private struct RememberedRunKind {
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
    func beginRunUI(_ mediumUUID: UUID, token: UUID, reconcileRun: Bool, initialProgress: Double) async -> Bool {
        await MainActor.run {
            guard let service, service.isRunToken(mediumUUID, token) else { return false }
            if !reconcileRun {
                service.markRunIndexing(mediumUUID, progress: initialProgress)
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

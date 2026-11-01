//
//  LiveWiring.swift
//  DiskArchive
//

import Foundation

/// Verdrahtung von Erkennung, Indizierung und Live-Überwachung (testbar, Aufgabe 174).
@MainActor
enum LiveWiring {
    static func startWatching(
        id: UUID,
        volume: VolumeInfo,
        store: IndexStoreV3,
        watcher: ChangeWatcher,
        appState: AppState
    ) async {
        guard appState.featureAccess.canWriteIndex else { return }
        guard !appState.globalAutoIndexPaused else { return }
        // bug.0.4.206: Stand der Überwachung vor dem Lesen; ein `stop` oder `start` im Fenster gewinnt.
        let since = watcher.watchGeneration(id)
        var stored: StoredMedium?
        do {
            stored = try await store.medium(uuid: id)
        } catch {
            if DiskArchiveLog.isOperationalFailure(error) {
                DiskArchiveLog.shared.record(.store, .error, "store error medium reconcile \(DiskArchiveLog.errorSummary(error))")
            }
            stored = nil
        }
        guard let stored, stored.decision == .index else { return }
        #if DEBUG
        await watcher.startAfterReadHookForTesting?(id)
        #endif
        // bug.0.4.204 K5, bug.0.4.205: nach dem letzten `await` gegen den aktuellen Stand prüfen (eine Prüfstelle für
        // alle Startwege).
        guard watcher.mayStartWatching(id, since: since, from: "nach lauf") else { return }
        watcher.start(
            mediumID: id,
            volume: watcher.currentVolume(id, else: volume),
            resumeFSEventsUUID: stored.fsEventsUUID,
            resumeLastEventID: stored.lastEventID ?? 0
        )
    }

    static func restartWatchersAfterWake(
        coordinator: MediumCoordinator,
        watcher: ChangeWatcher,
        store: IndexStoreV3,
        appState: AppState
    ) async {
        guard appState.featureAccess.canWriteIndex else { return }
        var count = 0
        for (id, volume) in coordinator.connectedVolumes() {
            let stored: StoredMedium?
            do {
                stored = try await store.medium(uuid: id)
            } catch {
                if DiskArchiveLog.isOperationalFailure(error) {
                    DiskArchiveLog.shared.record(.store, .error, "store error medium wake \(DiskArchiveLog.errorSummary(error))")
                }
                continue
            }
            // bug.0.4.200 (b): ein Medium mit Lücke wird überwacht wie ein `.indexed`-Medium.
            guard let stored, stored.decision == .index, stored.hasCompleteIndexExceptGaps else { continue }
            if watcher.isWatching(mediumID: id) {
                await watcher.stop(mediumID: id)
            }
            await startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: appState)
            count += 1
        }
        if count > 0 {
            DiskArchiveLog.shared.record(.watcher, .info, "wake restart count=\(count)")
        }
    }

    static func connect(
        coordinator: MediumCoordinator,
        service: IndexingService,
        watcher: ChangeWatcher,
        appState: AppState,
        startWatching: @escaping (UUID, VolumeInfo) async -> Void
    ) {
        service.attach(coordinator)
        coordinator.isIndexingActive = { [weak service] id in
            service?.isRunActive(id) ?? false
        }
        watcher.connectedVolumes = { [weak coordinator] in
            coordinator?.connectedVolumes() ?? []
        }
        watcher.isIndexingActive = { [weak service] id in
            service?.isRunActive(id) ?? false
        }
        watcher.onFullReconcile = { [weak service, weak watcher, weak coordinator] id, _ in
            guard appState.featureAccess.canWriteIndex else {
                watcher?.fullReconcileStarted(mediumID: id)
                return
            }
            // bug.0.4.095: nach einem gescheiterten Lauf kein voller Abgleich (Schleife bei dauerhaftem Schreibfehler).
            if service?.suppressesFullReconcile(id) == true {
                DiskArchiveLog.shared.record(.watcher, .info, "abgleich übersprungen nach fehler medium=\(id)")
                watcher?.fullReconcileStarted(mediumID: id)
                return
            }
            // Nicht mehr eingehängt → nichts starten (bug.0.4.031). Sonst gilt der aktuelle Pfad des Coordinators.
            guard let current = coordinator?.volume(for: id) else {
                DiskArchiveLog.shared.record(.watcher, .info, "abgleich übersprungen nicht eingehängt medium=\(id)")
                watcher?.fullReconcileStarted(mediumID: id)
                return
            }
            Task {
                await stopWatcherAndStartIndex(
                    watcher: watcher,
                    service: service,
                    id: id,
                    volume: current,
                    fromScratch: false
                )
                // bug.0.4.161: Abgleich gestartet (bzw. als Nachholer eingereiht) – die nächste Anforderung zählt wieder.
                watcher?.fullReconcileStarted(mediumID: id)
            }
        }
        service.onRunIndexed = { id, volume in
            Task { await startWatching(id, volume) }
        }
        coordinator.onIndexingInterrupted = { [weak service] id in
            await service?.cancel(mediumUUID: id)
        }
        coordinator.onWillUnmount = { [weak watcher, weak service] id in
            service?.discardWaitingStart(mediumUUID: id)
            await service?.cancel(mediumUUID: id)
            await watcher?.saveCursor(mediumID: id)
        }
        coordinator.onMediumDisappeared = { [weak watcher] id in
            await watcher?.stop(mediumID: id)
        }
        coordinator.onMediumRenamed = { [weak service, weak watcher] id, volume in
            guard appState.featureAccess.canWriteIndex else { return }
            // Genau ein Abgleich unter dem neuen Pfad; ein laufender Lauf liest noch den alten und wird ersetzt.
            // Nach dem Lauf startet `onRunIndexed` den Watcher mit dem neuen Volume.
            if service?.isRunActive(id) == true {
                await service?.cancel(mediumUUID: id)
            }
            await stopWatcherAndStartIndex(watcher: watcher, service: service, id: id, volume: volume, fromScratch: false)
            // Kein Lauf (z. B. Medium pausiert): Überwachung trotzdem unter dem neuen Pfad weiterführen – wie bei den
            // übrigen Startwegen nur, wenn der Index vollständig ist (bug.0.4.191 b).
            if service?.isRunActive(id) != true, appState.medium(with: id)?.hasCompleteIndexExceptGaps == true {
                await startWatching(id, volume)
            }
        }
        coordinator.setIndexHandler { [weak service, weak watcher] id, volume in
            guard appState.featureAccess.canWriteIndex else { return }
            Task {
                await stopWatcherAndStartIndex(
                    watcher: watcher,
                    service: service,
                    id: id,
                    volume: volume,
                    fromScratch: false
                )
            }
        }
        coordinator.onReconcileRequested = { [weak service, weak watcher] id, volume in
            guard appState.featureAccess.canWriteIndex else { return }
            Task {
                await stopWatcherAndStartIndex(
                    watcher: watcher,
                    service: service,
                    id: id,
                    volume: volume,
                    fromScratch: false
                )
            }
        }
        appState.onScopeRulesChanged = { [weak service, weak watcher, weak coordinator, weak appState] indexingIDs, scopeGrew in
            Task {
                for id in indexingIDs {
                    await service?.cancel(mediumUUID: id)
                }
                guard let appState else { return }
                var reconcileIDs = Set(indexingIDs)
                if scopeGrew {
                    reconcileIDs.formUnion(
                        appState.media
                            .filter { $0.connectionStatus == .connected && $0.decision == .index }
                            .map(\.id)
                    )
                }
                for id in reconcileIDs {
                    guard let volume = coordinator?.volume(for: id) else { continue }
                    await stopWatcherAndStartIndex(
                        watcher: watcher,
                        service: service,
                        id: id,
                        volume: volume,
                        fromScratch: false
                    )
                }
            }
        }
        appState.onReindexMedium = { [weak service, weak watcher, weak coordinator, weak appState] id in
            guard appState?.featureAccess.canWriteIndex == true, let volume = coordinator?.volume(for: id) else {
                // bug.0.4.129: kein Lauf → Sperre „Neu indizieren“ nicht stehen lassen.
                appState?.reindexRequested.remove(id)
                return
            }
            Task {
                await stopWatcherAndStartIndex(
                    watcher: watcher,
                    service: service,
                    id: id,
                    volume: volume,
                    fromScratch: true
                )
            }
        }
        appState.onMediaForgotten = { [weak watcher, weak service, weak coordinator] ids in
            for id in ids {
                await watcher?.stop(mediumID: id)
                await service?.cancel(mediumUUID: id)
                coordinator?.forget(mediumID: id)
            }
        }

        appState.onMediumDecisionChanged = { [weak coordinator, weak service, weak watcher] id, decision, allowIndexing in
            Task {
                if decision == .dontIndex || !allowIndexing {
                    await service?.cancel(mediumUUID: id)
                    await watcher?.stop(mediumID: id)
                    await coordinator?.endFailureAfterDecline(mediumID: id)
                    return
                }
                guard decision == .index, allowIndexing else { return }
                guard appState.featureAccess.canWriteIndex else { return }
                guard appState.medium(with: id)?.connectionStatus == .connected else { return }
                guard !appState.globalAutoIndexPaused else { return }
                coordinator?.requestIndexingAfterDecision(mediumID: id)
            }
        }

        appState.onAutoIndexPauseChanged = { [weak service, weak watcher] in
            service?.pauseChanged()
            watcher?.pauseChanged()
        }

        // bug.0.4.063: Sperre rastet ein → 100 % nur ansehen. Abgleich (zum Entsperren gemerkt) und Überwachung
        // sofort stoppen, laufende Läufe abbrechen. Die Überwachung speichert dabei keinen Ereignisstand (kein Schreiben).
        appState.onVersionLockEngaged = { [weak service, weak watcher, weak appState] in
            appState?.cancelRuleReconcileForVersionLock()
            watcher?.stopAllForVersionLock()
            DiskArchiveLog.shared.record(.app, .info, "sperre stoppt läufe abgleich überwachung")
            Task { await service?.cancelAllActiveForVersionLock() }
        }
        // Entsperrt → wieder normal: Überwachung der indizierten verbundenen Medien wie nach Pausenende
        // (`pauseChanged` → `applyPause`), nicht fertige verbundene Medien erneut indizieren. Den Regel-Abgleich nimmt
        // `applyVersionLockEvaluation` schon wieder auf.
        appState.onVersionLockReleased = { [weak coordinator, weak service, weak watcher, weak appState] in
            guard let appState, appState.featureAccess.canWriteIndex else { return }
            DiskArchiveLog.shared.record(.app, .info, "entsperrt nimmt überwachung und indizierung auf")
            // bug.0.4.073: Von der Sperre abgebrochene Abgleiche (Medium blieb `.indexed`) nachholen. Bei globaler
            // Pause verworfen: das Pausenende gleicht verbundene indizierte Medien ohnehin ab (`resumePausedRuns`).
            let interruptedReconciles = service?.takeReconcilesInterruptedByVersionLock() ?? []
            // bug.0.4.080 b): Erst die Abgleiche bestimmen; ihre Überwachung startet nach dem Lauf über `onRunIndexed`,
            // nicht ungeordnet daneben aus `pauseChanged`. Pausierte Medien laufen nicht an und werden gleich überwacht.
            let paused = appState.globalAutoIndexPaused
            let reconciles: [(id: UUID, volume: VolumeInfo)] = paused ? [] : interruptedReconciles.compactMap { id in
                guard let medium = appState.medium(with: id), medium.connectionStatus == .connected,
                      medium.decision == .index, medium.allowIndexing, medium.hasCompleteIndexExceptGaps,
                      !medium.autoIndexPaused, !appState.heldForSleep,
                      let volume = coordinator?.volume(for: id) else { return nil }
                return (id, volume)
            }
            watcher?.pauseChanged(skipping: Set(reconciles.map(\.id)))
            guard !paused else { return }
            for (id, volume) in reconciles {
                DiskArchiveLog.shared.record(.app, .info, "entsperrt holt abgleich nach medium=\(id)")
                Task {
                    await stopWatcherAndStartIndex(
                        watcher: watcher,
                        service: service,
                        id: id,
                        volume: volume,
                        fromScratch: false
                    )
                }
            }
            for medium in appState.media
            where medium.connectionStatus == .connected && medium.decision == .index && medium.allowIndexing
                && !medium.hasCompleteIndexExceptGaps {
                // Der vor der Sperre abgebrochene Auftrag darf den neuen nicht als „bereits angefordert“ verschlucken.
                coordinator?.clearIndexRequest(mediumID: medium.id)
                coordinator?.requestIndexingAfterDecision(mediumID: medium.id)
            }
        }
    }

    private static func stopWatcherAndStartIndex(
        watcher: ChangeWatcher?,
        service: IndexingService?,
        id: UUID,
        volume: VolumeInfo,
        fromScratch: Bool
    ) async {
        await watcher?.stop(mediumID: id)
        service?.start(mediumUUID: id, volume: volume, fromScratch: fromScratch)
    }
}

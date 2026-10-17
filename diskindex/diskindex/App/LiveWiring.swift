//
//  LiveWiring.swift
//  diskindex
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
        var stored: StoredMedium?
        do {
            stored = try await store.medium(uuid: id)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error medium reconcile \(error)")
            }
            stored = nil
        }
        guard let stored, stored.decision == .index else { return }
        watcher.start(
            mediumID: id,
            volume: volume,
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
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error medium wake \(error)")
                }
                continue
            }
            guard let stored, stored.decision == .index, stored.indexStatus == .indexed else { continue }
            if watcher.isWatching(mediumID: id) {
                await watcher.stop(mediumID: id)
            }
            await startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: appState)
            count += 1
        }
        if count > 0 {
            DiskIndexLog.shared.record(.watcher, .info, "wake restart count=\(count)")
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
            guard appState.featureAccess.canWriteIndex else { return }
            // Nicht mehr eingehängt → nichts starten (bug.0.4.031). Sonst gilt der aktuelle Pfad des Coordinators.
            guard let current = coordinator?.volume(for: id) else {
                DiskIndexLog.shared.record(.watcher, .info, "abgleich übersprungen nicht eingehängt medium=\(id)")
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
            }
        }
        service.onRunIndexed = { id, volume in
            Task { await startWatching(id, volume) }
        }
        coordinator.onIndexingInterrupted = { [weak service] id in
            await service?.cancel(mediumUUID: id)
        }
        coordinator.onWillUnmount = { [weak watcher, weak service] id in
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
            // Kein Lauf (z. B. Medium pausiert): Überwachung trotzdem unter dem neuen Pfad weiterführen.
            if service?.isRunActive(id) != true {
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
            guard appState?.featureAccess.canWriteIndex == true else { return }
            guard let volume = coordinator?.volume(for: id) else { return }
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

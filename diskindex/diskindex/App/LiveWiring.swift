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
        var count = 0
        for (id, volume) in coordinator.connectedVolumes() {
            guard watcher.isWatching(mediumID: id) else { continue }
            await watcher.stop(mediumID: id)
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
        watcher.connectedVolumes = { [weak coordinator] in
            coordinator?.connectedVolumes() ?? []
        }
        watcher.onFullReconcile = { [weak service] id, volume in
            service?.start(mediumUUID: id, volume: volume, fromScratch: false)
        }
        service.onRunIndexed = { id, volume in
            Task { await startWatching(id, volume) }
        }
        coordinator.onIndexingInterrupted = { [weak service] id in
            await service?.cancel(mediumUUID: id)
        }
        coordinator.onWillUnmount = { [weak watcher] id in
            await watcher?.saveCursor(mediumID: id)
        }
        coordinator.onMediumDisappeared = { [weak watcher] id in
            await watcher?.stop(mediumID: id)
        }
        coordinator.setIndexHandler { [weak service] id, volume in
            service?.start(mediumUUID: id, volume: volume, fromScratch: false)
            Task { await startWatching(id, volume) }
        }
        coordinator.onReconcileRequested = { [weak service, weak watcher] id, volume in
            Task {
                await watcher?.stop(mediumID: id)
                await startWatching(id, volume)
                service?.start(mediumUUID: id, volume: volume, fromScratch: false)
            }
        }
        appState.onReindexMedium = { [weak service, weak coordinator] id in
            guard let volume = coordinator?.volume(for: id) else { return }
            service?.start(mediumUUID: id, volume: volume, fromScratch: true)
            Task { await startWatching(id, volume) }
        }
        appState.onMediaForgotten = { [weak watcher, weak service, weak coordinator] ids in
            for id in ids {
                await watcher?.stop(mediumID: id)
                await service?.cancel(mediumUUID: id)
                coordinator?.forget(mediumID: id)
            }
        }
        appState.onAutoIndexPauseChanged = { [weak service, weak watcher] in
            service?.pauseChanged()
            watcher?.pauseChanged()
        }
    }
}

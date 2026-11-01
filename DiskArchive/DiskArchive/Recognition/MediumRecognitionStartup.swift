//
//  MediumRecognitionStartup.swift
//  DiskArchive
//
//  Start der Medium-Erkennung — Monitor vor dem Medien-Laden (81 A).
//

import Foundation

@MainActor
enum MediumRecognitionStartup {
    static func bootstrap(
        appState: AppState,
        store: IndexStoreV3,
        coordinator: MediumCoordinator,
        startChangeLoop: @escaping () -> Void,
        makeMonitor: @escaping @MainActor () -> MediumMonitor = { MediumMonitor() }
    ) {
        DiskArchiveLog.shared.record(.medium, .info, "recognition start")
        appState.attach(store: store)
        DiskArchiveLog.shared.record(.medium, .info, "store open ok")

        Task {
            await appState.hydrateSettingsFromStore()
            appState.didHydrateSettingsBeforeRecognition = true
            appState.didStartCoordinatorBeforeLoad = true
            let monitor = makeMonitor()
            monitor.skipWakeAppearedIfKnown = { [weak coordinator] volume in
                coordinator?.isKnownConnected(volume: volume) ?? false
            }
            coordinator.start(events: monitor.events())
            DiskArchiveLog.shared.record(.medium, .info, "monitor started")
            startChangeLoop()
            await appState.loadStoredMedia()
            await appState.pruneIfDue()
            appState.scheduleLoadedPruneDeadline()
            DiskArchiveLog.shared.record(.medium, .info, "loaded media=\(appState.media.count)")
            // bug.0.4.224: Löschungen vergessener Medien, die beim letzten Beenden noch liefen, im Hintergrund fortsetzen.
            guard appState.featureAccess.canWriteIndex else { return }
            Task { await store.purgePendingDeletions() }
        }
    }
}

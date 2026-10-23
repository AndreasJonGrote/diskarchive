//
//  MediumRecognitionStartup.swift
//  diskindex
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
        DiskIndexLog.shared.record(.medium, .info, "recognition start")
        appState.attach(store: store)
        DiskIndexLog.shared.record(.medium, .info, "store open ok")

        Task {
            await appState.hydrateSettingsFromStore()
            appState.didHydrateSettingsBeforeRecognition = true
            appState.didStartCoordinatorBeforeLoad = true
            let monitor = makeMonitor()
            monitor.skipWakeAppearedIfKnown = { [weak coordinator] volume in
                coordinator?.isKnownConnected(volume: volume) ?? false
            }
            coordinator.start(events: monitor.events())
            DiskIndexLog.shared.record(.medium, .info, "monitor started")
            startChangeLoop()
            await appState.loadStoredMedia()
            await appState.pruneIfDue()
            appState.scheduleLoadedPruneDeadline()
            DiskIndexLog.shared.record(.medium, .info, "loaded media=\(appState.media.count)")
        }
    }
}

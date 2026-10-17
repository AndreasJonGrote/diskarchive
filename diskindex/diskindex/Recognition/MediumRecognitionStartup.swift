//
//  MediumRecognitionStartup.swift
//  diskindex
//
//  Start der Medium-Erkennung — Monitor vor dem Medien-Laden (81 A).
//

import Foundation

@MainActor
enum MediumRecognitionStartup {
    /// `true`, sobald der Monitor vor `loadStoredMedia` gestartet wurde (Tests).
    private(set) static var didStartCoordinatorBeforeLoad = false
    /// `true`, sobald Einstellungen vor Monitor/Indizierung geladen wurden (todo.0.4.033 / bug.0.4.028).
    private(set) static var didHydrateSettingsBeforeRecognition = false

    #if DEBUG
    static func resetStartupFlagsForTests() {
        didStartCoordinatorBeforeLoad = false
        didHydrateSettingsBeforeRecognition = false
    }
    #endif

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
            didHydrateSettingsBeforeRecognition = true
            didStartCoordinatorBeforeLoad = true
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

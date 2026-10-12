//
//  MediumRecognitionStartup.swift
//  diskindex
//
//  Start der Medium-Erkennung — Monitor vor dem Medien-Laden (81 A).
//

import Foundation

@MainActor
enum MediumRecognitionStartup {
    /// `true`, sobald `startCoordinator` aufgerufen wurde (Tests).
    private(set) static var didStartCoordinatorBeforeLoad = false

    #if DEBUG
    static func resetStartupFlagsForTests() {
        didStartCoordinatorBeforeLoad = false
    }
    #endif

    static func bootstrap(
        appState: AppState,
        store: IndexStoreV3,
        coordinator: MediumCoordinator,
        startChangeLoop: () -> Void
    ) {
        DiskIndexLog.shared.record(.medium, .info, "recognition start")
        appState.attach(store: store)
        DiskIndexLog.shared.record(.medium, .info, "store open ok")

        didStartCoordinatorBeforeLoad = true
        coordinator.start(events: MediumMonitor().events())
        DiskIndexLog.shared.record(.medium, .info, "monitor started")

        startChangeLoop()

        Task {
            await appState.loadStoredMedia()
            DiskIndexLog.shared.record(.medium, .info, "loaded media=\(appState.media.count)")
        }
    }
}

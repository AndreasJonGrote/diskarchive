//
//  VersionCheckScheduler.swift
//  diskindex
//
//  Start + 24 h Version-Check (c.0.3.3.001).
//

import Foundation

@MainActor
final class VersionCheckScheduler {
    private var timerTask: Task<Void, Never>?
    private weak var appState: AppState?
    private weak var store: IndexStoreV3?

    func start(appState: AppState, store: IndexStoreV3) {
        self.appState = appState
        self.store = store
        VersionCheckCoordinator.reevaluateLocal(appState: appState, store: store)
        VersionCheckCoordinator.enqueueCheckIfNeeded(store: store, force: true)
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)
                guard !Task.isCancelled, let self, let appState = self.appState, let store = self.store else { return }
                VersionCheckCoordinator.reevaluateLocal(appState: appState, store: store)
                VersionCheckCoordinator.enqueueCheckIfNeeded(store: store)
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }
}

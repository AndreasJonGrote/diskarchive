//
//  AppStateStoreTests.swift
//  diskindexTests
//
//  Aufgabe 205, bug.0.4.208 — Tests schreiben nie in die echte Datei des Nutzers: Der App-Zustand des Testprozesses
//  liegt im Speicher.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct AppStateStoreTests {
    @Test func testsKeepTheAppStateInMemory() {
        #expect(RuntimeEnvironment.isRunningTests)
        #expect(AppStateStore.current.fileURL == nil)
    }

    @Test func defaultParametersWriteToTheInMemoryStore() {
        let app = AppState()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        app.presentIndexingFailure(mediumID: UUID(), name: "Stick", reason: .database)
        #expect(AppStateStore.current.data(forKey: AppState.failureCountsKey) != nil)

        app.pauseIndexing(until: start.addingTimeInterval(1), now: start)
        let paused = AppStateStore.current.data(forKey: AppState.pauseKey)
        #expect(paused != nil)
        app.refreshGlobalPause(now: start.addingTimeInterval(10))
        #expect(AppStateStore.current.data(forKey: AppState.pauseKey) != paused)
    }
}

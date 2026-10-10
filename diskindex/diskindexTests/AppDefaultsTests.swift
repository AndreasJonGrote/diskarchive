//
//  AppDefaultsTests.swift
//  diskindexTests
//
//  Aufgabe 205 — Tests schreiben nie in die echte Einstellungsdatei des Nutzers (app.diskarchive).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct AppDefaultsTests {
    private func standardSnapshot(_ keys: [String]) -> [String: Data?] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0, UserDefaults.standard.data(forKey: $0)) })
    }

    @Test func testsUseTheirOwnSuiteNotTheUsersFile() {
        #expect(AppDefaults.current !== UserDefaults.standard)
        #expect(RuntimeEnvironment.isRunningTests)
    }

    @Test func defaultParametersWriteToTheTestSuite() {
        let keys = [AppState.pauseKey, AppState.failureCountsKey]
        let before = standardSnapshot(keys)
        let app = AppState()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        app.presentIndexingFailure(mediumID: UUID(), name: "Stick", reason: .database)
        #expect(AppDefaults.current.data(forKey: AppState.failureCountsKey) != nil)

        app.pauseIndexing(until: start.addingTimeInterval(1), now: start)
        let paused = AppDefaults.current.data(forKey: AppState.pauseKey)
        #expect(paused != nil)
        app.refreshGlobalPause(now: start.addingTimeInterval(10))
        #expect(AppDefaults.current.data(forKey: AppState.pauseKey) != paused)

        // Die echte Datei bleibt unberührt.
        #expect(standardSnapshot(keys) == before)
    }
}

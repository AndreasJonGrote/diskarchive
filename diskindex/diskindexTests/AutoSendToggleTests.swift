//
//  AutoSendToggleTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@MainActor
@Suite struct AutoSendToggleTests {
    @Test func autoSendPersistsInDatabase() async throws {
        AppSettingsRuntimeCache.resetBootstrapForTests()
        let harness = try StoreHarness.make()
        let app = AppState(defaults: UserDefaults(suiteName: "autosend-\(UUID().uuidString)")!)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()

        app.setAutoSendCrashReports(true)
        try await Task.sleep(for: .milliseconds(600))

        let loaded = await harness.store.loadPersistedAppSettings()
        #expect(loaded?.autoSendCrashReports == true)
        #expect(IssueConsent.autoSendEnabled() == true)
    }

    @Test func autoSendToggleSurvivesHydrate() async throws {
        AppSettingsRuntimeCache.resetBootstrapForTests()
        let harness = try StoreHarness.make()
        var snapshot = PersistedAppSettings()
        snapshot.autoSendCrashReports = true
        try await harness.store.savePersistedAppSettings(snapshot)

        let app = AppState(defaults: UserDefaults(suiteName: "autosend2-\(UUID().uuidString)")!)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()

        #expect(app.appSettings.autoSendCrashReports == true)
        #expect(IssueConsent.autoSendEnabled() == true)
    }
}

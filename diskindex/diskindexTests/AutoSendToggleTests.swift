//
//  AutoSendToggleTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@MainActor
@Suite(.serialized)
struct AutoSendToggleTests {
    @Test func autoSendPersistsInDatabase() async throws {
        AppSettingsRuntimeCache.resetBootstrapForTests()
        let harness = try StoreHarness.make()
        let app = AppState(defaults: UserDefaults(suiteName: "autosend-\(UUID().uuidString)")!)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()

        app.setAutoSendCrashReports(true)
        await app.persistAppSettingsNow()
        #expect(IssueConsent.autoSendEnabled() == true)
        let persisted = await waitUntil(timeout: 8) {
            let loaded = await harness.store.loadPersistedAppSettings()
            return loaded?.autoSendCrashReports == true
        }
        #expect(persisted)
        // Paralleltests können `resetBootstrapForTests` den Cache leeren — Stand aus DB zurückholen.
        if let loaded = await harness.store.loadPersistedAppSettings() {
            AppSettingsRuntimeCache.setAutoSend(loaded.autoSendCrashReports)
        }
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

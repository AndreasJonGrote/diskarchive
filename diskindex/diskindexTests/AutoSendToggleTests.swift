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
        try await AppSettingsRuntimeCache.isolating { try await autoSendPersistsInDatabaseBody() }
    }

    private func autoSendPersistsInDatabaseBody() async throws {
        let harness = try StoreHarness.make()
        let app = AppState(defaults: TestDefaults.make())
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
        #expect(IssueConsent.autoSendEnabled() == true)
    }

    @Test func autoSendToggleSurvivesHydrate() async throws {
        try await AppSettingsRuntimeCache.isolating { try await autoSendToggleSurvivesHydrateBody() }
    }

    private func autoSendToggleSurvivesHydrateBody() async throws {
        let harness = try StoreHarness.make()
        var snapshot = PersistedAppSettings()
        snapshot.autoSendCrashReports = true
        try await harness.store.savePersistedAppSettings(snapshot)

        let app = AppState(defaults: TestDefaults.make())
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()

        #expect(app.appSettings.autoSendCrashReports == true)
        #expect(IssueConsent.autoSendEnabled() == true)
    }
}

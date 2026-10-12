//
//  AppSettingsPersistenceTests.swift
//  diskindexTests
//
//  Einstellungen in SQLite `settings` (237).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite struct AppSettingsPersistenceTests {
    @Test func persistedAppSettingsRoundTrip() async throws {
        let harness = try StoreHarness.make()
        var snapshot = PersistedAppSettings()
        snapshot.scanDepth = 3
        snapshot.autoSendCrashReports = true
        snapshot.excludedPatterns = ["*.tmp"]
        try await harness.store.savePersistedAppSettings(snapshot)
        let loaded = await harness.store.loadPersistedAppSettings()
        #expect(loaded == snapshot)
    }

    @Test func migratesLegacyUserDefaultsIntoDatabase() async throws {
        AppSettingsRuntimeCache.resetBootstrapForTests()
        let suite = "diskindex-settings-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        var legacy = AppSettings()
        legacy.scanDepth = 2
        legacy.autoSendCrashReports = true
        legacy.save(to: defaults)
        defaults.set(true, forKey: IssueConsent.legacyAutoSendKey)

        let harness = try StoreHarness.make()
        let app = AppState(defaults: defaults)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()

        #expect(app.appSettings.scanDepth == 2)
        #expect(app.appSettings.autoSendCrashReports == true)
        #expect(defaults.data(forKey: AppSettings.persistenceKey) == nil)
        #expect(defaults.object(forKey: IssueConsent.legacyAutoSendKey) == nil)
        let inDB = await harness.store.loadPersistedAppSettings()
        #expect(inDB?.scanDepth == 2)
        #expect(inDB?.autoSendCrashReports == true)
    }

    @Test func runtimeCacheReadsFromDatabaseBeforeStoreOpen() async throws {
        AppSettingsRuntimeCache.resetBootstrapForTests()
        let harness = try StoreHarness.make()
        var snapshot = PersistedAppSettings()
        snapshot.autoSendCrashReports = true
        try await harness.store.savePersistedAppSettings(snapshot)

        let dbURL = harness.directory.appendingPathComponent("archive.sqlite")
        AppSettingsRuntimeCache.bootstrapBeforeStoreOpen(databaseURL: dbURL, defaults: UserDefaults(suiteName: "unused-\(UUID())")!)
        #expect(IssueConsent.autoSendEnabled() == true)
    }
}

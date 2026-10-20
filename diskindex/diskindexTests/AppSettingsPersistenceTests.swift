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

@Suite @MainActor
struct AppSettingsPersistenceTests {
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

    /// bug.0.4.105: Fehlende Schlüssel (älterer Stand, neues Feld) übernehmen die übrigen Werte; der gespeicherte
    /// Text bleibt unverändert.
    @Test func partialSettingsKeepStoredValues() async throws {
        let suite = "diskindex-settings-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = try #require(UserDefaults(suiteName: suite))
        let harness = try StoreHarness.make()
        let raw = #"{"scanDepth":2}"#
        try await writeRawSettings(raw, harness: harness)
        let app = AppState(defaults: defaults)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()
        #expect(app.appSettings.scanDepth == 2)
        #expect(try await readRawSettings(harness: harness) == raw)
    }

    /// bug.0.4.105: Kaputter Eintrag → Voreinstellungen nur im Speicher, der gespeicherte Text wird nie
    /// überschrieben (auch nicht beim nächsten Speichern).
    @Test func unreadableSettingsAreNeverOverwritten() async throws {
        let suite = "diskindex-settings-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = try #require(UserDefaults(suiteName: suite))
        let harness = try StoreHarness.make()
        let raw = #"{"scanDepth":"#
        try await writeRawSettings(raw, harness: harness)
        let app = AppState(defaults: defaults)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()
        #expect(app.appSettings.scanDepth == AppSettings.defaultScanDepth)
        #expect(try await readRawSettings(harness: harness) == raw)
        await app.persistAppSettingsNow()
        #expect(try await readRawSettings(harness: harness) == raw)
        // Auch eine fällige Bereinigung läuft nicht nach den Voreinstellungen (würde sonst Einträge löschen).
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: ".versteckt", isFolder: false)], seenAt: Date()
        )
        let before = try await harness.store.storedNames()
        await app.pruneNow()
        #expect(try await harness.store.storedNames() == before, "Bereinigung nach Voreinstellungen trotz Lesefehler")
    }

    private func writeRawSettings(_ raw: String, harness: StoreHarness) async throws {
        try await harness.store.pool.write { db in
            try db.execute(
                sql: "INSERT INTO settings (key, value, date) VALUES (?, ?, NULL) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                arguments: [SettingsPersistence.appSettingsKey, raw]
            )
        }
    }

    private func readRawSettings(harness: StoreHarness) async throws -> String? {
        try await harness.store.pool.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [SettingsPersistence.appSettingsKey])
        }
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

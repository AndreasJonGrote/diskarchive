//
//  AppSettingsPersistenceTests.swift
//  DiskArchiveTests
//
//  Einstellungen in SQLite `settings` (237).
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

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

    /// todo.0.4.047 (Selbstprüfung): „Auf Updates hinweisen“ aus (Updatedialog schließen) bleibt nach dem Neustart aus.
    @Test func notifyAboutUpdatesSurvivesARestart() async throws {
        let harness = try StoreHarness.make()
        let first = AppState(defaults: TestDefaults.make())
        first.attach(store: harness.store)
        await first.hydrateSettingsFromStore()
        #expect(first.appSettings.notifyAboutUpdates, "Standard: an")
        first.updateNotice = UpdateNotice(
            offer: UpdateOffer(currentDisplay: "0.4.0", targetDisplay: "0.5", targetMajorMinor: AppVersion(major: 0, minor: 5, patch: 0), showBetaCountdown: false),
            notifyAboutUpdates: false
        )
        first.dismissUpdateNotice()
        let saved = await waitUntil(timeout: 30) { await harness.store.loadPersistedAppSettings()?.notifyAboutUpdates == false }
        #expect(saved, "Einstellung nicht gespeichert")
        let second = AppState(defaults: TestDefaults.make())
        second.attach(store: harness.store)
        await second.hydrateSettingsFromStore()
        #expect(!second.appSettings.notifyAboutUpdates, "nach dem Neustart wieder an")
    }

    /// bug.0.4.208: Fehlt der Eintrag, gelten die Standardwerte und werden gespeichert (keine Übernahme aus den
    /// Voreinstellungen).
    @Test func missingSettingsStoreTheDefaults() async throws {
        let harness = try StoreHarness.make()
        let app = AppState(defaults: TestDefaults.make())
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()
        #expect(app.appSettings.scanDepth == AppSettings.defaultScanDepth)
        let inDB = await harness.store.loadPersistedAppSettings()
        #expect(inDB?.scanDepth == AppSettings.defaultScanDepth)
    }

    /// bug.0.4.105: Fehlende Schlüssel (älterer Stand, neues Feld) übernehmen die übrigen Werte; der gespeicherte
    /// Text bleibt unverändert.
    @Test func partialSettingsKeepStoredValues() async throws {
        let defaults = TestDefaults.make()
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
        let defaults = TestDefaults.make()
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
        try await AppSettingsRuntimeCache.isolating { try await runtimeCacheReadsFromDatabaseBeforeStoreOpenBody() }
    }

    private func runtimeCacheReadsFromDatabaseBeforeStoreOpenBody() async throws {
        let harness = try StoreHarness.make()
        var snapshot = PersistedAppSettings()
        snapshot.autoSendCrashReports = true
        try await harness.store.savePersistedAppSettings(snapshot)

        let dbURL = harness.directory.appendingPathComponent("archive.sqlite")
        AppSettingsRuntimeCache.bootstrapBeforeStoreOpen(databaseURL: dbURL)
        #expect(IssueConsent.autoSendEnabled() == true)
    }
}

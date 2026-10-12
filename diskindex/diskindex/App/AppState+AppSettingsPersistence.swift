//
//  AppState+AppSettingsPersistence.swift
//  diskindex
//
//  Einstellungen aus SQLite `settings` (237).
//

import Foundation

extension AppState {
    func hydrateSettingsFromStore() async {
        guard let store = indexStore else { return }
        settingsReady = false
        let language = AppLanguagePolicy.loadDisplayLanguage(from: settingsDefaults)
            ?? appSettings.displayLanguage
        if let persisted = await store.loadPersistedAppSettings() {
            appSettings.applying(persisted)
        } else if persistsSettings {
            let legacy = AppSettings.loadLegacyPersisted(from: settingsDefaults)
            appSettings.applying(legacy)
            do {
                try await store.savePersistedAppSettings(appSettings.persistedSnapshot())
                clearLegacyAppSettingsKeys()
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "settings migrate \(error)")
                }
            }
        }
        appSettings.displayLanguage = language
        AppLanguagePolicy.saveDisplayLanguage(language, to: settingsDefaults)
        AppSettingsRuntimeCache.update(from: appSettings.persistedSnapshot())
        settingsReady = true
    }

    func setAutoSendCrashReports(_ enabled: Bool) {
        guard appSettings.autoSendCrashReports != enabled else { return }
        appSettings.autoSendCrashReports = enabled
        AppSettingsRuntimeCache.setAutoSend(enabled)
        scheduleSettingsSave()
    }

    func clearLegacyAppSettingsKeys() {
        settingsDefaults.removeObject(forKey: AppSettings.persistenceKey)
        settingsDefaults.removeObject(forKey: IssueConsent.legacyAutoSendKey)
    }

    func persistAppSettingsNow() async {
        guard storeReady, let store = indexStore, persistsSettings else { return }
        let snapshot = appSettings.persistedSnapshot()
        do {
            try await store.savePersistedAppSettings(snapshot)
            AppSettingsRuntimeCache.update(from: snapshot)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "settings save \(error)")
            }
        }
    }
}

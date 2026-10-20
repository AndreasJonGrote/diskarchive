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
        switch await store.loadPersistedAppSettingsResult() {
        case .loaded(let persisted):
            settingsUnreadable = false
            appSettings.applying(persisted)
        case .unreadable:
            // bug.0.4.105: Voreinstellungen nur im Speicher; der gespeicherte Eintrag wird nie überschrieben.
            settingsUnreadable = true
            DiskIndexLog.shared.record(.store, .error, "settings unreadable")
        case .missing where persistsSettings:
            settingsUnreadable = false
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
        case .missing:
            settingsUnreadable = false
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
        guard storeReady, let store = indexStore, persistsSettings, !settingsUnreadable else { return }
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

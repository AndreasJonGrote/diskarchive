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
            // bug.0.4.153: keine Indizierung, kein Abgleich, keine Live-Überwachung in dieser Sitzung (wie Pause, nur im
            // Speicher: `storedPause` und die gespeicherte Pause bleiben unberührt).
            globalAutoIndexPaused = true
            DiskIndexLog.shared.record(.store, .error, "settings unreadable")
        case .missing where persistsSettings:
            // bug.0.4.208: keine Übernahme alter Werte aus den Voreinstellungen; die Standardwerte werden gespeichert.
            settingsUnreadable = false
            do {
                try await store.savePersistedAppSettings(appSettings.persistedSnapshot())
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "settings save defaults \(DiskIndexLog.errorSummary(error))")
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

    func persistAppSettingsNow() async {
        guard storeReady, let store = indexStore, persistsSettings, !settingsUnreadable else { return }
        let snapshot = appSettings.persistedSnapshot()
        do {
            try await store.savePersistedAppSettings(snapshot)
            AppSettingsRuntimeCache.update(from: snapshot)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "settings save \(DiskIndexLog.errorSummary(error))")
            }
        }
    }
}

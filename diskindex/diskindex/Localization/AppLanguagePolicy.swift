//
//  AppLanguagePolicy.swift
//  diskindex
//
//  Erkennung (OS), Speicherung (AppSettings) und Anwendung (AppleLanguages) der UI-Sprache.
//

import Foundation

nonisolated enum AppLanguagePolicy {
    static let appleLanguagesKey = "AppleLanguages"

    /// Laufende UI-Sprache (sofort für `L10n`); parallel zu persistierten `AppSettings`.
    private static let lock = NSRecursiveLock()
    private static var activeDisplayLanguage: AppDisplayLanguage?

    static func resolvedDisplayLanguage(fallbackDefaults: UserDefaults = AppDefaults.current) -> AppDisplayLanguage {
        lock.lock()
        defer { lock.unlock() }
        return activeDisplayLanguage ?? AppSettings.load(from: fallbackDefaults).displayLanguage
    }

    static func noteActiveDisplayLanguage(_ language: AppDisplayLanguage) {
        lock.lock()
        defer { lock.unlock() }
        activeDisplayLanguage = language
    }

    /// Atomar für Tests: sync + Prüfung ohne Zwischen-Schreiben anderer Suites.
    static func withActiveLanguageLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    /// Erststart: OS-Sprache speichern und `AppleLanguages` setzen (Neustart wirkt vollständig; siehe docs/Lokalisierung.md).
    @discardableResult
    static func bootstrap(defaults: UserDefaults) -> AppSettings {
        let hadSavedSettings = defaults.data(forKey: AppSettings.persistenceKey) != nil
        let settings = AppSettings.load(from: defaults)
        if !hadSavedSettings {
            settings.save(to: defaults)
        }
        noteActiveDisplayLanguage(settings.displayLanguage)
        applyAppleLanguages(settings.displayLanguage, defaults: defaults)
        return settings
    }

    /// Einstellungen › Sprache — `AppleLanguages` sofort; UI-Texte über `L10n` + `activeDisplayLanguage`.
    static func applyAppleLanguages(_ language: AppDisplayLanguage, defaults: UserDefaults) {
        let primary = language.appleLanguageCode
        let secondary = language == .german ? AppDisplayLanguage.english.appleLanguageCode : AppDisplayLanguage.german.appleLanguageCode
        defaults.set([primary, secondary, "en"], forKey: appleLanguagesKey)
    }

    static func syncFromSettings(_ settings: AppSettings, defaults: UserDefaults) {
        noteActiveDisplayLanguage(settings.displayLanguage)
        applyAppleLanguages(settings.displayLanguage, defaults: defaults)
        settings.save(to: defaults)
    }
}

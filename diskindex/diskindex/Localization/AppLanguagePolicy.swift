//
//  AppLanguagePolicy.swift
//  diskindex
//
//  Erkennung (OS), Speicherung (AppSettings) und Anwendung (AppleLanguages) der UI-Sprache.
//

import Foundation

nonisolated enum AppLanguagePolicy {
    static let appleLanguagesKey = "AppleLanguages"
    static let displayLanguageKey = "diskindex.displayLanguage"

    /// Laufende UI-Sprache (sofort für `L10n`); parallel zu persistierten `AppSettings`.
    private static let lock = NSRecursiveLock()
    private static var activeDisplayLanguage: AppDisplayLanguage?

    static func resolvedDisplayLanguage(fallbackDefaults: UserDefaults = AppDefaults.current) -> AppDisplayLanguage {
        lock.lock()
        defer { lock.unlock() }
        if let activeDisplayLanguage { return activeDisplayLanguage }
        return loadDisplayLanguage(from: fallbackDefaults) ?? AppDisplayLanguage.resolveFromOperatingSystem()
    }

    static func loadDisplayLanguage(from defaults: UserDefaults) -> AppDisplayLanguage? {
        if let raw = defaults.string(forKey: displayLanguageKey),
           let language = AppDisplayLanguage(rawValue: raw) {
            return language
        }
        if let data = defaults.data(forKey: AppSettings.persistenceKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return decoded.displayLanguage
        }
        return nil
    }

    static func saveDisplayLanguage(_ language: AppDisplayLanguage, to defaults: UserDefaults) {
        defaults.set(language.rawValue, forKey: displayLanguageKey)
    }

    static func noteActiveDisplayLanguage(_ language: AppDisplayLanguage) {
        lock.lock()
        defer { lock.unlock() }
        activeDisplayLanguage = language
    }

    #if DEBUG
    /// Atomar für Tests: sync + Prüfung ohne Zwischen-Schreiben anderer Suites.
    static func withActiveLanguageLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
    #endif

    /// Erststart: OS-Sprache in UserDefaults (237: nicht in SQLite).
    @discardableResult
    static func bootstrap(defaults: UserDefaults) -> AppSettings {
        var settings = AppSettings()
        settings.displayLanguage = loadDisplayLanguage(from: defaults)
            ?? AppDisplayLanguage.resolveFromOperatingSystem()
        saveDisplayLanguage(settings.displayLanguage, to: defaults)
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
        saveDisplayLanguage(settings.displayLanguage, to: defaults)
    }
}

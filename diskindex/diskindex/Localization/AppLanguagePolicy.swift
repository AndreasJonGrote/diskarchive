//
//  AppLanguagePolicy.swift
//  diskindex
//
//  Erkennung (OS), Speicherung (AppSettings) und Anwendung (AppleLanguages) der UI-Sprache.
//

import Foundation

nonisolated enum AppLanguagePolicy {
    static let displayLanguageKey = "diskindex.displayLanguage"

    /// Laufende UI-Sprache (sofort für `L10n`); parallel zu persistierten `AppSettings`.
    private static let lock = NSRecursiveLock()
    private static var activeDisplayLanguage: AppDisplayLanguage?

    static func resolvedDisplayLanguage(fallbackDefaults: AppStateStore = .current) -> AppDisplayLanguage {
        lock.lock()
        defer { lock.unlock() }
        if let activeDisplayLanguage { return activeDisplayLanguage }
        return loadDisplayLanguage(from: fallbackDefaults) ?? AppDisplayLanguage.resolveFromOperatingSystem()
    }

    static func loadDisplayLanguage(from defaults: AppStateStore) -> AppDisplayLanguage? {
        defaults.string(forKey: displayLanguageKey).flatMap(AppDisplayLanguage.init(rawValue:))
    }

    static func saveDisplayLanguage(_ language: AppDisplayLanguage, to defaults: AppStateStore) {
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

    /// Erststart: OS-Sprache in den App-Zustand (237: nicht in SQLite; bug.0.4.208: `app-state.plist`).
    @discardableResult
    static func bootstrap(defaults: AppStateStore) -> AppSettings {
        var settings = AppSettings()
        settings.displayLanguage = loadDisplayLanguage(from: defaults)
            ?? AppDisplayLanguage.resolveFromOperatingSystem()
        saveDisplayLanguage(settings.displayLanguage, to: defaults)
        noteActiveDisplayLanguage(settings.displayLanguage)
        applyAppleLanguages(settings.displayLanguage)
        return settings
    }

    /// Einstellungen › Sprache — `AppleLanguages` sofort; UI-Texte über `L10n` + `activeDisplayLanguage`.
    static func applyAppleLanguages(_ language: AppDisplayLanguage) {
        SystemDefaults.setAppleLanguages(appleLanguages(for: language))
    }

    static func appleLanguages(for language: AppDisplayLanguage) -> [String] {
        let primary = language.appleLanguageCode
        let secondary = language == .german ? AppDisplayLanguage.english.appleLanguageCode : AppDisplayLanguage.german.appleLanguageCode
        return [primary, secondary, "en"]
    }

    static func syncFromSettings(_ settings: AppSettings, defaults: AppStateStore) {
        noteActiveDisplayLanguage(settings.displayLanguage)
        applyAppleLanguages(settings.displayLanguage)
        saveDisplayLanguage(settings.displayLanguage, to: defaults)
    }
}

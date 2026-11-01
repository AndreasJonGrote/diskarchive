//
//  L10n.swift
//  DiskArchive
//
//  UI-Texte aus Localizable.xcstrings (DE/EN). Siehe docs/Lokalisierung.md.
//

import Foundation

nonisolated enum L10n {
    /// Nur für Tests: Sprache für den aktuellen Task (kein globaler Zustand, keine Nebenwirkung auf andere Tests).
    @TaskLocal static var languageOverride: AppDisplayLanguage?

    /// Lokalisierte Zeichenkette zur App-Sprache (`AppSettings.displayLanguage`).
    static func string(
        _ key: String,
        language: AppDisplayLanguage? = nil
    ) -> String {
        let resolved = language ?? languageOverride ?? AppLanguagePolicy.resolvedDisplayLanguage()
        let bundle = localizationBundle(for: resolved)
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...,
        language: AppDisplayLanguage? = nil
    ) -> String {
        String(format: string(key, language: language), locale: locale(for: language), arguments: arguments)
    }

    static func locale(for language: AppDisplayLanguage? = nil) -> Locale {
        let resolved = language ?? languageOverride ?? AppLanguagePolicy.resolvedDisplayLanguage()
        return Locale(identifier: resolved.localeIdentifier)
    }

    private static func localizationBundle(for language: AppDisplayLanguage) -> Bundle {
        let code = language.appleLanguageCode
        let app = appResourceBundle
        guard let path = app.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return app }
        return bundle
    }

    /// App-Bundle (auch unter XCTest-Host, wenn `Bundle.main` die `.xctest` ist).
    private static var appResourceBundle: Bundle {
        var url = Bundle.main.bundleURL
        if url.pathExtension == "xctest" {
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
            if let host = Bundle(url: url) { return host }
        }
        return .main
    }
}

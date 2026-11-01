//
//  AppDisplayLanguage.swift
//  DiskArchive
//
//  Einstellungen › Sprache; Erkennung siehe `resolveFromOperatingSystem`.
//

import Foundation

nonisolated enum AppDisplayLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case german
    case english

    var id: String { rawValue }

    var label: String {
        switch self {
        case .german: L10n.string("copy.settings.language.german", language: .german)
        case .english: L10n.string("copy.settings.language.english", language: .english)
        }
    }

    var localeIdentifier: String {
        switch self {
        case .german: "de_DE"
        case .english: "en_US"
        }
    }

    /// Wert für `UserDefaults` › `AppleLanguages` (macOS-Standard für App-Sprache).
    var appleLanguageCode: String {
        switch self {
        case .german: "de"
        case .english: "en"
        }
    }

    /// Bevorzugte Systemsprache → Deutsch oder Englisch (Layout: nur diese beiden UI-Sprachen).
    static func resolveFromOperatingSystem(preferredLanguages: [String] = Locale.preferredLanguages) -> AppDisplayLanguage {
        for tag in preferredLanguages {
            let lower = tag.lowercased()
            if lower.hasPrefix("de") { return .german }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }
}

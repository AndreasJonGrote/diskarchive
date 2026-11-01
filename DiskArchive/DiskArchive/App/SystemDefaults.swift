//
//  SystemDefaults.swift
//  DiskArchive
//
//  bug.0.4.208: die einzige Stelle der App mit `UserDefaults` – nur, was macOS selbst in `app.diskarchive.plist` liest.
//  Den App-Zustand führt `AppStateStore`. Unter Tests schreibt diese Stelle nichts.
//

import Foundation

nonisolated enum SystemDefaults {
    static let appleLanguagesKey = "AppleLanguages"

    /// Schlüssel früherer Fassungen in `app.diskarchive.plist`; die App entfernt sie beim Start (keine Übernahme).
    static let legacyKeys = [
        "diskindex.globalPause", "diskindex.failureModalCounts", "diskindex.noticePermissionAsked",
        "lastIntegrityCheck", "diskindex.pruneAt", "diskindex.displayLanguage",
        "diskindex.appSettings", "diskindex.autoSendCrashReports",
    ]

    /// macOS liest die Sprache der App beim Start aus `AppleLanguages`.
    static func setAppleLanguages(_ codes: [String]) {
        guard !RuntimeEnvironment.isRunningTests else { return }
        UserDefaults.standard.set(codes, forKey: appleLanguagesKey)
    }

    /// Fenster nach dem Beenden nicht wiederherstellen (`register` schreibt keine Datei).
    static func registerWindowRestoration() {
        guard !RuntimeEnvironment.isRunningTests else { return }
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
    }

    static func removeLegacyKeys() {
        guard !RuntimeEnvironment.isRunningTests else { return }
        for key in legacyKeys where UserDefaults.standard.object(forKey: key) != nil {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

//
//  AppDefaults.swift
//  diskindex
//

import Foundation

/// Die eine Stelle für die Einstellungs-Datei der App. Unter Tests nie `UserDefaults.standard`
/// (das wäre die echte Datei `app.diskarchive` des Nutzers), sondern eine eigene Suite je Testprozess.
nonisolated enum AppDefaults {
    static let current: UserDefaults = {
        guard RuntimeEnvironment.isRunningTests else { return .standard }
        let name = "app.diskarchive.tests.\(ProcessInfo.processInfo.processIdentifier)"
        guard let suite = UserDefaults(suiteName: name) else { return .standard }
        suite.removePersistentDomain(forName: name)
        return suite
    }()
}

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
        removeStaleTestDomains(
            in: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences", isDirectory: true),
            ownPID: ProcessInfo.processInfo.processIdentifier
        )
        guard let suite = UserDefaults(suiteName: name) else { return .standard }
        suite.removePersistentDomain(forName: name)
        return suite
    }()

    static let testDomainPrefix = "app.diskarchive.tests."

    /// Namen früherer Testhelfer (bug.0.4.124): ohne Prozesskennung, darum beim Aufräumen immer entfernt.
    static let legacyTestPrefixes = [
        "app.diskarchive.tests.startup.", "PauseNoticeTextTests-", "diskindex-lang-", "diskindex-prune-",
        "diskindex-settings-", "autosend", "diskindex-term-settings-", "diskindex-lifecycle-",
    ]

    /// Löscht Test-Domänen (`app.diskarchive.tests.<pid>`) von Prozessen, die nicht mehr laufen: aus den
    /// Einstellungen und die `.plist`-Datei. Die eigene und die laufender (parallel gestarteter) Prozesse bleiben.
    static func removeStaleTestDomains(
        in directory: URL,
        ownPID: Int32,
        isRunning: (Int32) -> Bool = processIsRunning
    ) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard file.pathExtension == "plist" else { continue }
            // bug.0.4.124: Altlasten ohne Prozesskennung (frühere Testhelfer) gehen immer weg.
            if legacyTestPrefixes.contains(where: { name.hasPrefix($0) }) {
                UserDefaults.standard.removePersistentDomain(forName: name)
                if WriteGuard.permitsWrite(to: file) { try? FileManager.default.removeItem(at: file) }
                continue
            }
            // `app.diskarchive.tests.<pid>` und `app.diskarchive.tests.<pid>.<Name>` (Helfer `TestDefaults.make`).
            guard name.hasPrefix(testDomainPrefix),
                  let pid = Int32(name.dropFirst(testDomainPrefix.count).prefix { $0 != "." }),
                  pid != ownPID, !isRunning(pid)
            else { continue }
            UserDefaults.standard.removePersistentDomain(forName: name)
            guard WriteGuard.permitsWrite(to: file) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func processIsRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}

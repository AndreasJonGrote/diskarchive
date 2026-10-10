//
//  InstanceHandoff.swift
//  diskindex
//
//  Eine fremde Mitteilung darf die App nicht beenden (Aufgabe 58).
//  Aufgabe 141 — login/--background beendet nie die laufende Instanz.
//

import Foundation

enum InstanceHandoff {
    struct ProcessStamp: Equatable {
        var bundleID: String?
        var launchDate: Date?
    }

    /// Was die neue Instanz tun soll, wenn schon eine läuft.
    enum ConflictAction: Equatable {
        /// Debug-Klick aus Xcode/Finder: alte Instanz beenden, neue bleibt.
        case quitOlderInstances
        /// Release oder login/--background: Fenster an alte übergeben, neue beendet sich.
        case handOffAndQuitSelf
    }

    /// Nur beenden, wenn `object` die PID eines laufenden Prozesses derselben Bundle-ID ist und dieser später gestartet wurde.
    static func shouldQuit(object: Any?, ownPID: Int32, own: ProcessStamp, peer: (Int32) -> ProcessStamp?) -> Bool {
        guard let text = object as? String, let pid = Int32(text), pid != ownPID else { return false }
        guard let sender = peer(pid) else { return false }
        guard let bundle = sender.bundleID, bundle == own.bundleID else { return false }
        guard let senderStart = sender.launchDate, let ownStart = own.launchDate, senderStart > ownStart else { return false }
        return true
    }

    /// Aufgabe 141: `login`/`--background` darf nie die laufende Instanz beenden — auch im Debug.
    static func conflictAction(launchKind: AppLaunchKind, isDebugBuild: Bool) -> ConflictAction {
        if launchKind == .login {
            return .handOffAndQuitSelf
        }
        return isDebugBuild ? .quitOlderInstances : .handOffAndQuitSelf
    }
}

//
//  AppLaunch.swift
//  diskindex
//
//  Kaltstart (Dock/Finder): nur Menüleiste; Fenster bei Reopen/Handoff. Anmeldung still (README §7).
//

import Foundation

nonisolated enum AppLaunchKind: String, Equatable {
    case click
    case login
    case handoff
}

nonisolated enum AppLaunch {
    static let backgroundArgument = "--background"
    static let launcherServiceName = "app.diskarchive.launcher"

    static func kind(arguments: [String], environment: [String: String]) -> AppLaunchKind {
        if arguments.contains(backgroundArgument) { return .login }
        if environment["XPC_SERVICE_NAME"] == launcherServiceName { return .login }
        return .click
    }

    /// Nur Handoff öffnet beim Start sofort ein Fenster; Kaltstart und Anmeldung nicht.
    static func opensMainWindow(_ kind: AppLaunchKind) -> Bool {
        kind == .handoff
    }

    /// Dock-Klick ohne sichtbares Fenster holt das Hauptfenster nach vorn.
    static func reopenOpensMainWindow(hasVisibleWindows: Bool) -> Bool {
        !hasVisibleWindows
    }
}

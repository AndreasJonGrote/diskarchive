//
//  AppLaunch.swift
//  diskindex
//
//  Kaltstart: Menüleiste + Hauptfenster (todo.0.4.011); Anmeldung still, außer Update/Sperre.
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

    /// Kaltstart und Handoff öffnen das Hauptfenster; Anmeldung nur bei Update-Angebot oder Sperre.
    static func opensMainWindow(_ kind: AppLaunchKind, presentsUpdateOrLock: Bool = false) -> Bool {
        switch kind {
        case .click, .handoff:
            return true
        case .login:
            return presentsUpdateOrLock
        }
    }

    /// Dock-Klick ohne sichtbares Fenster holt das Hauptfenster nach vorn.
    static func reopenOpensMainWindow(hasVisibleWindows: Bool) -> Bool {
        !hasVisibleWindows
    }
}

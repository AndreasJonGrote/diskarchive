//
//  AppLaunch.swift
//  diskindex
//
//  Kaltstart: Menüleiste + Hauptfenster (todo.0.4.013).
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

    /// Jeder Start (Klick, Anmeldung, Handoff) öffnet das Hauptfenster (todo.0.4.013).
    static func opensMainWindow(_ kind: AppLaunchKind) -> Bool {
        switch kind {
        case .click, .login, .handoff:
            return true
        }
    }

    /// Dock-Klick ohne sichtbares Fenster holt das Hauptfenster nach vorn.
    static func reopenOpensMainWindow(hasVisibleWindows: Bool) -> Bool {
        !hasVisibleWindows
    }
}

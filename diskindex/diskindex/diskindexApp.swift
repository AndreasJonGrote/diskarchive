//
//  diskindexApp.swift
//  diskindex
//
//  Menu-Bar-App: Fenster ausschließlich über AppWindowPresenter (keine SwiftUI Window-Scenes).
//

import AppKit
import SwiftUI

enum BackgroundLaunchGate {
    /// Zweite Instanz mit `--background`, während die App schon läuft: sofort beenden.
    static func shouldExitImmediately(arguments: [String], runningPIDs: [pid_t], ownPID: pid_t) -> Bool {
        arguments.contains("--background") && runningPIDs.contains { $0 != ownPID }
    }
}

@main
struct diskindexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState = AppDelegateBridge.appState

    init() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .map(\.processIdentifier)
        if BackgroundLaunchGate.shouldExitImmediately(
            arguments: CommandLine.arguments,
            runningPIDs: running,
            ownPID: ProcessInfo.processInfo.processIdentifier
        ) {
            exit(0)
        }
        if CommandLine.arguments.contains("--background") {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

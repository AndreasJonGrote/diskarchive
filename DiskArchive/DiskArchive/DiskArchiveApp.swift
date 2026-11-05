//
//  DiskArchiveApp.swift
//  DiskArchive
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
struct DiskArchiveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState = AppDelegateBridge.appState

    init() {
        // todo.0.4.3.019: Archivo (Titel) für den Prozess registrieren, bevor das erste Fenster zeichnet.
        DesignFont.registerBundledFonts()
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
            CommandGroup(replacing: .appInfo) {
                Button(LayoutCopy.menuBarAbout) { AboutPanel.show() }
            }
            CommandGroup(replacing: .appSettings) {
                Button(LayoutCopy.appMenuSettings) { AppMenuCommands.openSettings(appState: appState) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

//
//  AboutPanel.swift
//  DiskArchive
//
//  Aufgabe 221 — „Über Disk Archive“: Standard-Infofenster von macOS, Inhalt aus einer Funktion (testbar).
//

import AppKit
import SwiftUI

/// todo.0.4.3.001 (Layout 17): eigenes Fenster „Über Disk Archive“ statt des Standardfensters – oben App-Icon und Name
/// auf Verlauf mit Ringen, darunter ein schwarzer Balken mit Version (immer die laufende), Datum und Link zur Website.
/// Hell und dunkel gleich; schließt nur über den roten Punkt.
@MainActor
enum AboutPanel {
    struct Content: Equatable {
        var version: String
        var build: String
        var link: String
        var buildDate: Date?
        /// Name der App aus dem Bundle („Disk Archive“).
        var name: String = ""
    }

    static func content(bundle: Bundle = .main) -> Content {
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return Content(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: build,
            link: AppLinks.website,
            buildDate: AppVersion.buildTimestamp(from: build),
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        )
    }

    /// „Version {1} (Beta)“ (Sektion 20, 17) solange 0.x; danach „Version {1}“ aus 05.
    static func versionLine(_ version: String) -> String {
        if AppVersion.parse(version)?.isBeta ?? true {
            return LayoutCopy.aboutVersionBeta(version)
        }
        return "\(LayoutCopy.aboutVersion) \(version)"
    }

    /// Datum des Builds, ausgeschrieben in der App-Sprache („9. Oktober 2026“).
    static func dateLine(_ date: Date?) -> String? {
        date.map { $0.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(L10n.locale())) }
    }

    /// Angezeigter Link ohne Schema („diskarchive.app“ wie im Layout).
    static func linkTitle(_ link: String) -> String {
        link.replacingOccurrences(of: "https://", with: "")
    }

    private static var window: NSWindow?

    /// Eine Stelle für Menüleisten-Menü und Programm-Menü. Nutzeraktion: App darf in den Vordergrund.
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = makeWindow(content: content())
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    /// Fenster mit rotem Punkt allein (Minimieren und Zoomen ausgeblendet), Titelleiste durchsichtig über dem Verlauf.
    static func makeWindow(content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AboutView.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.title = LayoutCopy.menuBarAbout
        window.contentView = NSHostingView(rootView: AboutView(content: content))
        return window
    }
}

@MainActor
enum AppMenuCommands {
    /// „Einstellungen …“ (⌘,): Hauptfenster beim Bereich Einstellungen.
    static func openSettings(
        appState: AppState,
        open: ((AppState, MainWindowDestination) -> Void)? = nil
    ) {
        if let open {
            open(appState, .settings)
        } else {
            AppWindowPresenter.openMain(appState: appState, destination: .settings)
        }
    }
}

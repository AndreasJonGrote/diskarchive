//
//  AboutPanel.swift
//  DiskArchive
//
//  Aufgabe 221 — „Über Disk Archive“: Standard-Infofenster von macOS, Inhalt aus einer Funktion (testbar).
//

import AppKit

@MainActor
enum AboutPanel {
    struct Content: Equatable {
        var version: String
        var build: String
        var link: String
    }

    static func content(bundle: Bundle = .main) -> Content {
        Content(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            link: AppLinks.website
        )
    }

    /// Zusatzangaben des Fensters: klickbarer Link auf die Webseite.
    static func credits(link: String = AppLinks.website) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: style,
        ]
        if let url = URL(string: link) {
            attributes[.link] = url
        }
        return NSAttributedString(string: link.replacingOccurrences(of: "https://", with: ""), attributes: attributes)
    }

    static func options(bundle: Bundle = .main) -> [NSApplication.AboutPanelOptionKey: Any] {
        let content = content(bundle: bundle)
        return [
            .applicationVersion: content.version,
            .version: content.build,
            .credits: credits(link: content.link),
        ]
    }

    /// Eine Stelle für Menüleisten-Menü und Programm-Menü. Nutzeraktion: App darf in den Vordergrund.
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options())
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

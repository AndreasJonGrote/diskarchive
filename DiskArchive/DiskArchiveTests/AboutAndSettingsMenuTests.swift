//
//  AboutAndSettingsMenuTests.swift
//  DiskArchiveTests
//
//  Aufgabe 221: „Über Disk Archive“ und „Einstellungen …“. Kein Fenster auf dem Bildschirm (Regel 19).
//

import AppKit
import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct AboutAndSettingsMenuTests {
    /// todo.0.4.3.006 (Layout 01.01): genau „Disk Archive anzeigen“ · „Automatisch bei Systemstart“ · „Einstellungen …“ ·
    /// „Disk Archive beenden“; „Über“ und „Protokoll im Finder zeigen“ entfallen.
    @Test func contextMenuHasTheFourLayoutEntries() throws {
        let menu = MenuBarController.shared.makeContextMenu()
        // Nur im Debug-Build: „Absturz testen“.
        let items = menu.items.filter { $0.title != "Absturz testen" }
        #expect(items.map { $0.isSeparatorItem ? "—" : $0.title } == [
            LayoutCopy.menuBarShowApp, "—", LayoutCopy.menuBarLaunchAtLogin, LayoutCopy.appMenuSettings, "—",
            LayoutCopy.menuBarQuit,
        ])
        #expect(items.filter { !$0.isSeparatorItem }.allSatisfy { $0.action != nil && $0.target != nil })
    }

    /// todo.0.4.3.001 (Layout 17): eigenes Fenster statt des Standardfensters – Version aus dem Bundle, Datum, Link.
    @Test func aboutContentComesFromTheBundleAndLinksToTheWebsite() throws {
        let content = AboutPanel.content()
        let bundleVersion = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(content.version == bundleVersion, "immer die laufende Version")
        #expect(Int(content.build).map { $0 > 1 } == true)
        #expect(content.link == "https://diskarchive.app")
        #expect(content.buildDate != nil, "Datum aus dem Build")
        #expect(content.name == "Disk Archive")
        L10n.$languageOverride.withValue(.german) {
            #expect(AboutPanel.versionLine("0.4.3") == "Version 0.4.3 (Beta)")
            #expect(AboutPanel.versionLine("1.0") == "Version 1.0")
            let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))
            #expect(AboutPanel.dateLine(date) == "9. Oktober 2026")
        }
        #expect(AboutPanel.linkTitle(content.link) == "diskarchive.app")
    }

    /// Nur der rote Punkt schließt (Minimieren und Zoomen ausgeblendet); kein Standard-„Über“-Fenster mehr.
    @Test func aboutWindowHasOnlyTheCloseButton() {
        let window = AboutPanel.makeWindow(content: AboutPanel.content())
        defer { window.close() }
        #expect(window.styleMask.contains(.closable))
        #expect(!window.styleMask.contains(.miniaturizable) && !window.styleMask.contains(.resizable))
        #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
        #expect(window.standardWindowButton(.miniaturizeButton)?.isHidden ?? true)
        #expect(window.standardWindowButton(.zoomButton)?.isHidden ?? true)
        #expect(window.contentView?.frame.size == AboutView.size)
    }

    @Test func settingsCommandOpensTheSettingsDestination() {
        let appState = AppState()
        var opened: MainWindowDestination?
        AppMenuCommands.openSettings(appState: appState) { _, destination in opened = destination }
        #expect(opened == .settings)
    }

    @Test func newTextsExistInGermanAndEnglish() {
        let german = L10n.$languageOverride.withValue(.german) { (LayoutCopy.menuBarAbout, LayoutCopy.appMenuSettings) }
        let english = L10n.$languageOverride.withValue(.english) { (LayoutCopy.menuBarAbout, LayoutCopy.appMenuSettings) }
        #expect(german.0 == "Über Disk Archive")
        #expect(german.1 == "Einstellungen …")
        #expect(english.0 == "About Disk Archive")
        #expect(english.1 == "Settings…")
    }
}

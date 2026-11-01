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
    @Test func contextMenuStartsWithAboutThenSeparatorThenShowApp() throws {
        let menu = MenuBarController.shared.makeContextMenu()
        let first = try #require(menu.items.first)
        #expect(first.title == LayoutCopy.menuBarAbout)
        #expect(first.action != nil)
        try #require(menu.items.count > 2)
        #expect(menu.items[1].isSeparatorItem)
        #expect(menu.items[2].title == LayoutCopy.menuBarShowApp)
    }

    @Test func aboutContentComesFromTheBundleAndLinksToTheWebsite() throws {
        let content = AboutPanel.content()
        #expect(content.version == "0.4.2")
        #expect(Int(content.build).map { $0 > 1 } == true)
        #expect(content.link == "https://diskarchive.app")

        let options = AboutPanel.options()
        #expect(options[.applicationVersion] as? String == content.version)
        #expect(options[.version] as? String == content.build)
        let credits = try #require(options[.credits] as? NSAttributedString)
        let link = credits.attribute(.link, at: 0, effectiveRange: nil) as? URL
        #expect(link?.absoluteString == "https://diskarchive.app")
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

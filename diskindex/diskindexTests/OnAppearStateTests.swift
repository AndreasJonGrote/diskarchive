//
//  OnAppearStateTests.swift
//  diskindexTests
//
//  bug.0.4.135 (Regel 15): Popover und Einstellungen ändern beim Erscheinen keinen Zustand. Das Pausen-Menü schließt
//  der Controller beim Öffnen; das Scroll-Ziel „Scan-Tiefe“ räumt `AppState` beim Wechsel von Tab oder Ansicht ab.
//  Echte Fenster außerhalb des Bildschirms (Regel 10/19).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct OnAppearStateTests {
    @Test func popoverAppearingLeavesThePauseMenuStateAlone() async throws {
        let app = AppState()
        app.popoverPauseMenuOpen = true
        let session = PixelProbe.open(
            MenuBarPopoverView().environment(app),
            size: CGSize(width: MenuBarPopoverLayout.panelWidth, height: 400)
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        #expect(app.popoverPauseMenuOpen, "Popover ändert beim Erscheinen den Zustand (onAppear)")
    }

    @Test func settingsFilesTabScrollsWithoutClearingTheTargetItself() async throws {
        let app = AppState()
        MediumNavigation.openSettings(appState: app, tab: .files, scrollTarget: .scanDepth)
        let session = PixelProbe.open(
            SettingsGeneralTab(section: .files).environment(app).frame(width: 720, height: 600),
            size: CGSize(width: 720, height: 600)
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        #expect(app.settingsScrollTarget == .scanDepth, "Ansicht ändert beim Erscheinen das Scroll-Ziel")
        // Abräumen über `AppState`: anderer Tab …
        app.settingsTab = .general
        #expect(app.settingsScrollTarget == nil)
        // … oder Verlassen der Einstellungen.
        MediumNavigation.openSettings(appState: app, tab: .files, scrollTarget: .scanDepth)
        #expect(app.settingsScrollTarget == .scanDepth)
        app.mainWindowDestination = .dashboard
        #expect(app.settingsScrollTarget == nil)
    }
}
}

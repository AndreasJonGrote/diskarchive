//
//  AutoSendToggleTests.swift
//  diskindexTests
//
//  Aufgabe 142 — Toggle beobachtet AppStorage und bleibt nach Neuaufbau an.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct AutoSendToggleTests {
    /// Aufgabe 205: `applyFactoryDefaults` schreibt in die Test-Suite, nicht in die echte Datei.
    @Test func factoryDefaultsWriteToTheTestSuite() {
        let key = IssueConsent.autoSendKey
        let standardBefore = UserDefaults.standard.object(forKey: key) as? Bool
        IssueConsent.setAutoSendEnabled(true, defaults: AppDefaults.current)
        AppState().applyFactoryDefaults()
        #expect(AppDefaults.current.bool(forKey: key) == false)
        #expect((UserDefaults.standard.object(forKey: key) as? Bool) == standardBefore)
        AppDefaults.current.removeObject(forKey: key)
    }


    @Test func autoSendTogglePersistsAcrossRebuild() async throws {
        let key = IssueConsent.autoSendKey
        AppDefaults.current.removeObject(forKey: key)
        defer { AppDefaults.current.removeObject(forKey: key) }

        let app = AppState()
        app.mainWindowDestination = .settings
        app.settingsTab = .advanced
        let host = NSHostingView(
            rootView: SettingsGeneralTab(section: .advanced).environment(app).frame(width: 720, height: 900)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 900),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        try await pump(0.2)

        IssueConsent.setAutoSendEnabled(true, defaults: AppDefaults.current)
        // Neuaufbau der Ansicht — @AppStorage muss anzeigen.
        host.rootView = SettingsGeneralTab(section: .advanced).environment(app).frame(width: 720, height: 900)
        try await pump(0.15)
        #expect(IssueConsent.autoSendEnabled(defaults: AppDefaults.current) == true)
        #expect(AppDefaults.current.bool(forKey: key) == true)
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

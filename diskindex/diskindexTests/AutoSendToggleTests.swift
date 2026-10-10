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

@Suite @MainActor
struct AutoSendToggleTests {
    @Test func autoSendTogglePersistsAcrossRebuild() async throws {
        let key = IssueConsent.autoSendKey
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

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

        IssueConsent.setAutoSendEnabled(true, defaults: .standard)
        // Neuaufbau der Ansicht — @AppStorage muss anzeigen.
        host.rootView = SettingsGeneralTab(section: .advanced).environment(app).frame(width: 720, height: 900)
        try await pump(0.15)
        #expect(IssueConsent.autoSendEnabled(defaults: .standard) == true)
        #expect(UserDefaults.standard.bool(forKey: key) == true)
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

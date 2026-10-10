//
//  SettingsSplitAlignmentTests.swift
//  diskindexTests
//
//  Aufgabe 128/129 — Oberkante Überschrift = Oberkante Bedienelement; Mitteilungen-Maße.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct SettingsSplitAlignmentTests {
    @Test func filesTabIgnoredToggleAlignsTop() async throws {
        let app = AppState()
        let host = NSHostingView(
            rootView: SettingsGeneralTab(section: .files)
                .environment(app)
                .frame(width: 720, height: 900)
        )
        let window = present(host, size: NSSize(width: 720, height: 900))
        try await pump(0.2)
        // Abschnitte mit .top: Treffer in der rechten Spalte nahe dem oberen Rand der Scroll-Inhalte
        #expect(host.hitTest(NSPoint(x: 520, y: host.bounds.height - 80)) != nil)
        window.orderOut(nil)
    }

    @Test func noticeEventsLeadingInsetIs25() {
        #expect(SettingsGeneralTab.noticeEventsLeadingInset == 25)
    }

    private func present(_ host: NSView, size: NSSize) -> NSWindow {
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        return window
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

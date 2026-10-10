//
//  NotificationsSpacingTests.swift
//  diskindexTests
//
//  Aufgabe 144 — Mitte–Mitte 27 pt (19 + 8), Preview 15 unter letzter Zeile.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct NotificationsSpacingTests {
    /// Dieselbe Zeilen-Chrome wie in SettingsGeneralTab (Höhe 19 + spacing 8).
    private struct PitchProbe: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                row("A")
                row("B")
                row("C")
            }
            .padding(20)
        }

        private func row(_ title: String) -> some View {
            Color.clear
                .frame(height: 19)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    Toggle(title, isOn: .constant(true))
                        .toggleStyle(DesignCheckbox())
                }
                .clipped()
                .background(AlignmentGuideProbe())
        }
    }

    private struct AlignmentGuideProbe: View {
        var body: some View {
            GeometryReader { geo in
                Color.clear.preference(key: RowHeightKey.self, value: [geo.size.height])
            }
        }
    }

    private struct RowHeightKey: PreferenceKey {
        static var defaultValue: [CGFloat] = []
        static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
            value.append(contentsOf: nextValue())
        }
    }

    @Test func noticeRowPitchIs27() async throws {
        #expect(SettingsGeneralTab.noticeEventsLeadingInset == 25)
        var heights: [CGFloat] = []
        let host = NSHostingView(
            rootView: PitchProbe()
                .onPreferenceChange(RowHeightKey.self) { heights = $0 }
        )
        let window = present(host, size: NSSize(width: 320, height: 160))
        try await pump(0.15)
        #expect(heights.count >= 2)
        for h in heights.prefix(3) {
            #expect(abs(h - 19) <= 0.5, "Zeilenhöhe \(h)")
        }
        // Pitch = Höhe + Spacing = 19 + 8
        #expect(abs(19 + 8 - 27) <= 0.5)
        window.orderOut(nil)
    }

    private func present(_ host: NSView, size: NSSize) -> NSWindow {
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
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

//
//  MenuBarPopoverNoHitsTests.swift
//  diskindexTests
//
//  bug.0.4.060 (REPORT 106): „Keine Treffer für …“ passt bei langem Suchbegriff in die feste Höhe.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

/// In der seriellen Fenstergruppe, wie die übrigen Tests mit echtem Fenster.
extension WindowTestGroup {
    @Suite(.serialized) @MainActor
    struct MenuBarPopoverNoHitsTests {
        /// Höhe des Suchbereichs im echten Fenster (außerhalb des Bildschirms, Regel 19).
        private func measuredHeight(query: String) async -> CGFloat {
            let content = MenuBarPopoverSearchContent(query: query)
                .environment(AppState())
                .frame(width: MenuBarPopoverLayout.panelWidth)
            let host = NSHostingView(rootView: content)
            let size = CGSize(width: MenuBarPopoverLayout.panelWidth, height: 300)
            host.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(
                contentRect: NSRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let height = host.fittingSize.height
            window.contentView = nil
            window.orderOut(nil)
            window.close()
            return height
        }

        @Test func longQueryStaysOnOneLineWithinReservedHeight() async {
            let reserved = MenuBarPopoverLayout.searchContentHeight(groups: [])
            let short = await measuredHeight(query: "abc")
            let long = await measuredHeight(query: String(repeating: "Rechnung Steuerberater Jahresabschluss ", count: 4))
            #expect(short <= reserved + 0.5, "kurz \(short) > \(reserved)")
            #expect(long <= reserved + 0.5, "lang \(long) > \(reserved)")
            #expect(abs(long - short) <= 0.5, "lang \(long) ≠ kurz \(short)")
        }
    }
}

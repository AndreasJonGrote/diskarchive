//
//  ToolbarNavIconTests.swift
//  diskindexTests
//
//  Aufgabe 132 — Füll-Deckkraft und Farbrollen.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct ToolbarNavIconTests {
    @Test func fillOpacityPerRole() {
        #expect(ToolbarNavIconRole.home.fillOpacity == 1.0)
        #expect(ToolbarNavIconRole.settings.fillOpacity == 0.50)
        #expect(ToolbarNavIconRole.filter.fillOpacity == 0.50)
        #expect(ToolbarNavIconRole.favorites.fillOpacity == 0.50)
        #expect(ToolbarNavIconRole.search.fillOpacity == 0.50)
    }

    @Test func activeColorsMatchOKLCHConversion() {
        // Hell oklch(0.62 0.16 h) → Settings #00A2A4, Filter #3986E4, Favoriten #9D69D2
        // Dunkel oklch(0.72 0.14 h) → Settings #00BFC0, Filter #65A7FA, Favoriten #B98CEA
        #expect(ToolbarNavIconRole.settings.activeColor(scheme: .light) != DesignColor.control)
        #expect(ToolbarNavIconRole.filter.activeColor(scheme: .light) == DesignColor.filterSearch)
        #expect(ToolbarNavIconRole.favorites.activeColor(scheme: .dark) == DesignColor.favorite)
        #expect(ToolbarNavIconRole.home.activeColor(scheme: .light) == DesignColor.control)
        #expect(ToolbarNavIconRole.home.activeColor(scheme: .dark) == DesignColor.control)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func activeIconRendersInWindow(_ scheme: ColorScheme) async {
        let host = NSHostingView(
            rootView: HStack {
                ToolbarNavIcon(fillAsset: "NavHouseLineFill", strokeAsset: "NavHouseLineStroke", role: .home, isActive: true)
                ToolbarNavIcon(fillAsset: "NavBookmarksFill", strokeAsset: "NavBookmarksStroke", role: .favorites, isActive: true)
                ToolbarNavIcon(fillAsset: "NavGearFill", strokeAsset: "NavGearStroke", role: .settings, isActive: true)
                ToolbarNavIcon(fillAsset: "IconFunnelFill", strokeAsset: "IconFunnelStroke", role: .filter, isActive: true)
                ToolbarNavIcon(fillAsset: "IconMagnifyingGlassFill", strokeAsset: "IconMagnifyingGlassStroke", role: .search, isActive: true)
            }
            .padding()
            .environment(\.colorScheme, scheme)
        )
        let window = PixelProbe.offscreenWindow(hosting: host, size: CGSize(width: 200, height: 48))
        pumpRunLoop()
        #expect(host.fittingSize.width > 80)
        window.orderOut(nil)
    }
}

private func pumpRunLoop() {
    let deadline = Date().addingTimeInterval(0.1)
    while Date() < deadline {
        CFRunLoopRunInMode(.defaultMode, 0.02, true)
    }
}

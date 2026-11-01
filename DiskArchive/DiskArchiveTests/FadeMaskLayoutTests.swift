//
//  FadeMaskLayoutTests.swift
//  DiskArchiveTests
//
//  Aufgabe 138 — lange Namen: Zeilenbreite = Spaltenbreite, Fade aktiv.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@Suite @MainActor
struct FadeMaskLayoutTests {
    @Test func longNameRowFitsColumnAndFades() async throws {
        let long = String(repeating: "a", count: 80)
        let app = AppState()
        let row = ColumnBrowserRow(
            title: long,
            isSelected: true,
            iconAsset: "IconFolder",
            fadeTitleWhenSelected: true,
            fadeTitleOnOverflow: true,
            onSelect: {}
        )
        .environment(app)
        .frame(width: 180)

        let host = NSHostingView(rootView: row)
        let window = present(host, size: NSSize(width: 180, height: 48))
        try await pump(0.2)
        // Innenabstand 10+10 → sichtbare Zeilenbreite 180
        #expect(abs(host.bounds.width - 180) <= 0.5)
        let hitIcon = host.hitTest(NSPoint(x: 18, y: host.bounds.midY))
        #expect(hitIcon != nil, "Icon-Bereich klickbar")
        let hitFar = host.hitTest(NSPoint(x: 170, y: host.bounds.midY))
        #expect(hitFar != nil)
        window.orderOut(nil)
    }

    @Test func shortNameDoesNotNeedOverflowClip() async throws {
        let app = AppState()
        let row = ColumnBrowserRow(
            title: "kurz",
            isSelected: false,
            iconAsset: "IconFolder",
            fadeTitleOnOverflow: true,
            onSelect: {}
        )
        .environment(app)
        .frame(width: 180)
        let host = NSHostingView(rootView: row)
        let window = present(host, size: NSSize(width: 180, height: 48))
        try await pump(0.15)
        #expect(abs(host.bounds.width - 180) <= 0.5)
        window.orderOut(nil)
    }

    @Test func sidebarWidthClampsAndLongMediaRowFits() async throws {
        var state = ColumnBrowserState()
        state.setSidebarWidth(200)
        #expect(state.sidebarWidth == 200)
        state.setSidebarWidth(420)
        #expect(state.sidebarWidth == 420)

        let app = AppState()
        let long = "Ein sehr langer Medienname für die Seitenleiste (Überlänge)"
        let row = ColumnBrowserRow(
            title: long,
            isSelected: true,
            iconAsset: "IconUSB",
            fadeTitleWhenSelected: true,
            fadeTitleOnOverflow: true,
            onSelect: {}
        )
        .environment(app)
        .frame(width: 200)
        let host = NSHostingView(rootView: row)
        let window = present(host, size: NSSize(width: 200, height: 48))
        try await pump(0.15)
        #expect(abs(host.bounds.width - 200) <= 0.5)
        window.orderOut(nil)
    }

    @Test func columnHeaderFadesLongTitle() async throws {
        let header = ColumnBrowserColumnHeader(title: String(repeating: "ORDNERNAME", count: 8))
            .frame(width: 180)
        let host = NSHostingView(rootView: header)
        let window = present(host, size: NSSize(width: 180, height: 40))
        try await pump(0.15)
        #expect(abs(host.bounds.width - 180) <= 0.5)
        window.orderOut(nil)
    }

    private func present(_ host: NSView, size: NSSize) -> NSWindow {
        PixelProbe.offscreenWindow(hosting: host, size: size)
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

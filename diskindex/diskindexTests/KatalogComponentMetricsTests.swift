//
//  KatalogComponentMetricsTests.swift
//  diskindexTests
//
//  Aufgabe 131 — Messtest gegen docs/Komponenten-Masse.md (±0,5 pt).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct KatalogComponentMetricsTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func primaryButtonHeightMatchesCatalog(_ scheme: ColorScheme) async throws {
        let host = NSHostingView(
            rootView: Button("Primär") {}
                .buttonStyle(PrimaryButtonStyle())
                .environment(\.colorScheme, scheme)
        )
        let window = present(host, size: NSSize(width: 200, height: 60))
        try await pump(0.05)
        #expect(abs(host.fittingSize.height - 38.8) <= 0.5, "Knopf groß Höhe \(host.fittingSize.height)")
        window.orderOut(nil)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func compactButtonHeightMatchesCatalog(_ scheme: ColorScheme) async throws {
        let host = NSHostingView(
            rootView: Button("Klein") {}
                .buttonStyle(PrimaryButtonStyle(size: .compact))
                .environment(\.colorScheme, scheme)
        )
        let window = present(host, size: NSSize(width: 160, height: 48))
        try await pump(0.05)
        #expect(abs(host.fittingSize.height - 24.4) <= 0.5, "Knopf klein Höhe \(host.fittingSize.height)")
        window.orderOut(nil)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func ignoredChipHeightMatchesCatalog(_ scheme: ColorScheme) async throws {
        let host = NSHostingView(
            rootView: IgnoredPatternChip(pattern: "*.log", onRemove: {})
                .environment(\.colorScheme, scheme)
        )
        let window = present(host, size: NSSize(width: 120, height: 40))
        try await pump(0.05)
        #expect(abs(host.fittingSize.height - 23.5) <= 0.5, "Chip Höhe \(host.fittingSize.height)")
        window.orderOut(nil)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func selectGroupHeightMatchesCatalog(_ scheme: ColorScheme) async throws {
        let host = NSHostingView(
            rootView: BinaryButtonGroup(
                firstTitle: "Ja",
                secondTitle: "Nein",
                selection: .constant(.first)
            )
            .environment(\.colorScheme, scheme)
        )
        let window = present(host, size: NSSize(width: 120, height: 40))
        try await pump(0.05)
        #expect(abs(host.fittingSize.height - 24.4) <= 0.5, "Selectgroup Höhe \(host.fittingSize.height)")
        window.orderOut(nil)
    }

    @Test func designTokensMatchCatalog() {
        #expect(DesignButtonSize.standard.height == 38.8)
        #expect(DesignButtonSize.standard.fontSize == 14)
        #expect(DesignButtonSize.standard.horizontalPadding == 18)
        #expect(DesignButtonSize.standard.verticalPadding == 10)
        #expect(DesignButtonSize.compact.height == 24.4)
        #expect(DesignButtonSize.compact.fontSize == 12)
        #expect(DesignRadius.sm == 6)
    }

    private func present(_ host: NSView, size: NSSize) -> NSWindow {
        PixelProbe.offscreenWindow(hosting: host, size: size)
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

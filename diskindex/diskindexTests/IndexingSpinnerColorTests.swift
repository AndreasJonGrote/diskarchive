//
//  IndexingSpinnerColorTests.swift
//  diskindexTests
//
//  bug.0.4.136 / bug.0.4.163 (b): Der Spinner „Wird indiziert“ hat die Farbe `DesignColor.stateOnline` – dunkel
//  #5BBD74, hell #20A04E. Pixel im echten Fenster (Regel 10/19), verglichen mit einer Fläche in derselben Farbe auf
//  demselben Weg gezeichnet (die Darstellung rechnet Farben um; Toleranz 0,06 je Kanal). Eigene Suite (vorher in
//  `SettingsUnreadableSessionTests`).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct IndexingSpinnerColorTests {
    private func bitmap(_ view: some View, appearance: NSAppearance.Name, size: CGSize) async -> NSBitmapImageRep {
        let session = PixelProbe.open(
            view.environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                .environment(\.spinnerFrozenAngle, 0)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(DesignColor.bg),
            size: size,
            appearance: appearance
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        return session.bitmap()
    }

    /// Farbe einer Fläche in `stateOnline`, gezeichnet wie der Spinner.
    private func reference(appearance: NSAppearance.Name) async -> NSColor? {
        let rep = await bitmap(Rectangle().fill(DesignColor.stateOnline), appearance: appearance, size: CGSize(width: 40, height: 40))
        return PixelProbe.color(in: rep, at: CGPoint(x: 20, y: 20)).usingColorSpace(.sRGB)
    }

    /// Pixel im Ringbereich oben links, die `target` tragen (je Kanal höchstens 0,06 daneben). Der Ring hat mehrere
    /// hundert davon; geglättete Kantenpixel einer anderen Farbe nur vereinzelt.
    private func ringPixels(matching target: NSColor, appearance: NSAppearance.Name) async -> Int {
        let rep = await bitmap(FolderPendingIndexingHint(), appearance: appearance, size: CGSize(width: 260, height: 90))
        var hits = 0
        for y in stride(from: 0.0, to: 24.0, by: 0.5) {
            for x in stride(from: 0.0, to: 26.0, by: 0.5) {
                guard let c = PixelProbe.color(in: rep, at: CGPoint(x: x + 4, y: y)).usingColorSpace(.sRGB) else { continue }
                if abs(c.redComponent - target.redComponent) <= 0.06, abs(c.greenComponent - target.greenComponent) <= 0.06,
                   abs(c.blueComponent - target.blueComponent) <= 0.06 {
                    hits += 1
                }
            }
        }
        return hits
    }

    /// Das Token selbst: dunkel #5BBD74, hell #20A04E.
    @Test func stateOnlineTokenHasTheLayoutValues() throws {
        func hex(_ appearance: NSAppearance.Name) throws -> Int {
            var value = 0
            let look = try #require(NSAppearance(named: appearance))
            look.performAsCurrentDrawingAppearance {
                guard let c = NSColor(DesignColor.stateOnline).usingColorSpace(.sRGB) else { return }
                value = (Int((c.redComponent * 255).rounded()) << 16) | (Int((c.greenComponent * 255).rounded()) << 8)
                    | Int((c.blueComponent * 255).rounded())
            }
            return value
        }
        let dark = try hex(.darkAqua)
        let light = try hex(.aqua)
        #expect(dark == 0x5BBD74, "dunkel \(String(format: "#%06X", dark))")
        #expect(light == 0x20A04E, "hell \(String(format: "#%06X", light))")
    }

    @Test func spinnerHasTheStateOnlineColorInBothSchemes() async throws {
        let darkRef = try #require(await reference(appearance: .darkAqua))
        let lightRef = try #require(await reference(appearance: .aqua))
        let dark = await ringPixels(matching: darkRef, appearance: .darkAqua)
        let light = await ringPixels(matching: lightRef, appearance: .aqua)
        #expect(dark >= 100, "dunkel: Ring nicht in stateOnline (\(dark) Pixel)")
        #expect(light >= 100, "hell: Ring nicht in stateOnline (\(light) Pixel)")
        // Gegenprobe: hell trägt der Ring nicht die dunkle Farbe (sonst wäre die Farbe fest).
        let lightAsDark = await ringPixels(matching: darkRef, appearance: .aqua)
        #expect(lightAsDark * 4 < light, "hell zeigt die dunkle Farbe (\(lightAsDark) gegen \(light) Pixel)")
    }
}
}

//
//  DarkChromeTests.swift
//  diskindexTests
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor struct DarkChromeTests {
    @Test func darkTokensAreNeutral() {
        let dark = NSAppearance(named: .darkAqua)!
        let toolbar = sample(DesignColor.toolbar, appearance: dark)
        let selection = sample(DesignColor.selection, appearance: dark)
        let divider = sample(DesignColor.divider, appearance: dark)
        #expect(near(toolbar, 0x2B, 0x2B, 0x2B))
        #expect(near(selection, 0x4A, 0x49, 0x49))
        #expect(neutral(divider))
        #expect(divider.3 > 0)
    }

    @Test func lightToolbarStaysOnTheLightGround() {
        let light = NSAppearance(named: .aqua)!
        let toolbar = sample(DesignColor.toolbar, appearance: light)
        #expect(toolbar.0 > 200 && toolbar.1 > 200 && toolbar.2 > 200)
        #expect(neutral(toolbar))
    }

    @Test func hostedPixelsMatchTheDarkRoles() throws {
        let appearance = NSAppearance(named: .darkAqua)!
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 48,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        appearance.performAsCurrentDrawingAppearance {
            NSColor(DesignColor.toolbar).setFill()
            NSRect(x: 0, y: 28, width: 40, height: 20).fill()
            NSColor(DesignColor.divider).setFill()
            NSRect(x: 0, y: 24, width: 40, height: 4).fill()
            NSColor(DesignColor.selection).setFill()
            NSRect(x: 0, y: 0, width: 40, height: 24).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        #expect(near(pixel(rep, 8, 8), 0x2B, 0x2B, 0x2B))
        #expect(neutral(pixel(rep, 8, 25)))
        #expect(near(pixel(rep, 8, 36), 0x4A, 0x49, 0x49))
    }

    private func sample(_ color: Color, appearance: NSAppearance) -> (Int, Int, Int, Int) {
        var result = (0, 0, 0, 0)
        appearance.performAsCurrentDrawingAppearance {
            let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
            result = (
                Int((ns.redComponent * 255).rounded()),
                Int((ns.greenComponent * 255).rounded()),
                Int((ns.blueComponent * 255).rounded()),
                Int((ns.alphaComponent * 255).rounded())
            )
        }
        return result
    }

    private func pixel(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> (Int, Int, Int, Int) {
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return (0, 0, 0, 0) }
        return (
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded()),
            Int((color.alphaComponent * 255).rounded())
        )
    }

    private func near(_ sample: (Int, Int, Int, Int), _ r: Int, _ g: Int, _ b: Int) -> Bool {
        abs(sample.0 - r) <= 2 && abs(sample.1 - g) <= 2 && abs(sample.2 - b) <= 2
    }

    private func neutral(_ sample: (Int, Int, Int, Int)) -> Bool {
        abs(sample.0 - sample.1) <= 2 && abs(sample.1 - sample.2) <= 2 && abs(sample.0 - sample.2) <= 2
    }
}

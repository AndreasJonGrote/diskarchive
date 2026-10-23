//
//  LayoutCheckboxTests.swift
//  diskindexTests
//
//  Aufgabe 158 — restliche System-Kästchen sind Layout-Checkboxen.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct LayoutCheckboxTests {
    @Test func filesCheckboxesAreLayoutSizedAndToggle() throws {
        let app = AppState()
        let session = PixelProbe.open(
            SettingsGeneralTab(section: .files)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 860, height: 1100, alignment: .top),
            size: CGSize(width: 860, height: 1100),
            appearance: .aqua
        )
        defer { session.close() }
        let rows = checkboxRows(in: session.window)
        #expect(rows.count >= 3, "Zeilen \(rows.count)")
        guard rows.count >= 3 else { return }
        let before = session.bitmap()
        for row in rows.prefix(3) {
            let box = CGRect(x: row.minX, y: row.minY, width: 16, height: 16)
            let ink = PixelProbe.inkBounds(
                in: before,
                rect: box.insetBy(dx: -2, dy: -2),
                background: CGPoint(x: max(0, box.minX - 8), y: box.midY),
                tolerance: 0.15
            )
            #expect(ink != nil)
            guard let ink else { continue }
            #expect(abs(ink.width - 16) <= 2, "Breite \(ink.width)")
            #expect(abs(ink.height - 16) <= 2, "Höhe \(ink.height)")
            #expect(accentBlueCount(in: before, rect: ink) == 0)
        }
        let first = try #require(rows.first)
        session.click(at: CGPoint(x: first.minX + 8, y: first.midY))
        #expect(app.appSettings.showFoldersRegardlessOfFilter == false)
        let after = session.bitmap()
        let box = CGRect(x: first.minX, y: first.minY, width: 16, height: 16)
        #expect(interiorInk(in: before, rect: box) != interiorInk(in: after, rect: box))
    }

    /// Zeilen der Layout-Checkbox (Kästchen links, Beschriftung daneben), Ursprung oben links.
    private func checkboxRows(in window: NSWindow) -> [CGRect] {
        guard let root = window.contentView else { return [] }
        let height = root.bounds.height
        return proxies(in: root).compactMap { view in
            let frame = view.convert(view.bounds, to: nil)
            guard frame.height >= 14, frame.height <= 22, frame.width > 40, frame.width < 260 else { return nil }
            return CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
        }.sorted { $0.minY < $1.minY }
    }

    private func proxies(in view: NSView) -> [NSView] {
        let name = String(describing: type(of: view))
        var found: [NSView] = name.contains("KeyViewProxy") ? [view] : []
        for subview in view.subviews {
            found.append(contentsOf: proxies(in: subview))
        }
        return found
    }

    private func accentBlueCount(in bitmap: NSBitmapImageRep, rect: CGRect) -> Int {
        var count = 0
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)).usingColorSpace(.sRGB) ?? .clear
                if color.blueComponent > 0.45, color.blueComponent > color.redComponent + 0.15 {
                    count += 1
                }
                x += 2
            }
            y += 2
        }
        return count
    }

    private func interiorInk(in bitmap: NSBitmapImageRep, rect: CGRect) -> Int {
        let inset = rect.insetBy(dx: 4, dy: 4)
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: max(0, rect.minX - 6), y: rect.midY))
        var count = 0
        var y = inset.minY
        while y < inset.maxY {
            var x = inset.minX
            while x < inset.maxX {
                let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if !near(color, background) { count += 1 }
                x += 1
            }
            y += 1
        }
        return count
    }

    private func near(_ color: NSColor, _ other: NSColor) -> Bool {
        let sample = color.usingColorSpace(.sRGB) ?? color
        let target = other.usingColorSpace(.sRGB) ?? other
        return abs(sample.redComponent - target.redComponent) < 0.12
            && abs(sample.greenComponent - target.greenComponent) < 0.12
            && abs(sample.blueComponent - target.blueComponent) < 0.12
    }
}
}

//
//  ColumnStatusIconTests.swift
//  diskindexTests
//
//  Aufgabe 164: Spinner 20 pt, Warnkreis rund, Abstand zum Titel 10 pt.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct ColumnStatusIconTests {
    @Test func spinnerDiameterWarningCircleAndGap() async {
        let loading = await metrics(FolderContentsLoadingHint(loaded: 2, total: 9).frame(width: 230, height: 160, alignment: .topLeading), size: CGSize(width: 230, height: 160))
        let pending = await metrics(FolderPendingIndexingHint().frame(width: 230, height: 160, alignment: .topLeading), size: CGSize(width: 230, height: 160))
        let app = AppState()
        let warning = await metrics(
            FolderUncapturedColumnHint(reason: .excluded).environment(app).frame(width: 230, height: 160, alignment: .topLeading),
            size: CGSize(width: 230, height: 160)
        )
        #expect(abs(loading.diameter - 20) <= 1, "Laden \(loading.diameter)")
        #expect(abs(pending.diameter - 20) <= 1, "Indiziert \(pending.diameter)")
        #expect(abs(warning.width - warning.height) <= 1, "Kreis \(warning.width) x \(warning.height)")
        #expect(abs(loading.gap - 10) <= 1, "Abstand Laden \(loading.gap)")
        #expect(abs(pending.gap - 10) <= 1, "Abstand Indiziert \(pending.gap)")
        #expect(abs(warning.gap - 10) <= 1, "Abstand Kreis \(warning.gap)")
    }

    private func metrics<V: View>(_ view: V, size: CGSize) async -> (diameter: CGFloat, width: CGFloat, height: CGFloat, gap: CGFloat) {
        let bitmap = await PixelProbe.render(view.background(Color.white), size: size, appearance: .aqua)
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: size.width - 8, y: size.height - 8))
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        func ink(_ x: Int, _ y: Int) -> Bool {
            !near(PixelProbe.color(in: bitmap, at: CGPoint(x: CGFloat(x) / scale, y: CGFloat(y) / scale)), background)
        }
        var minX = bitmap.pixelsWide
        var maxX = 0
        var minY = bitmap.pixelsHigh
        var maxY = 0
        var started = false
        var y = 0
        while y < Int(70 * scale) {
            var row = false
            var x = 0
            while x < Int(50 * scale) {
                if ink(x, y) {
                    row = true
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
                x += 1
            }
            if row { started = true }
            else if started { break }
            y += 1
        }
        let width = CGFloat(maxX - minX + 1) / scale
        let height = CGFloat(maxY - minY + 1) / scale
        var title = maxY + 1
        var scan = maxY + 1
        while scan < Int(90 * scale) {
            var row = false
            var x = 0
            while x < Int(80 * scale) {
                if ink(x, scan) { row = true; break }
                x += 1
            }
            if row {
                title = scan
                break
            }
            scan += 1
        }
        let gap = CGFloat(title - (maxY + 1)) / scale
        return (max(width, height), width, height, gap)
    }

    private func near(_ color: NSColor, _ other: NSColor) -> Bool {
        let sample = color.usingColorSpace(.sRGB) ?? color
        let target = other.usingColorSpace(.sRGB) ?? other
        return abs(sample.redComponent - target.redComponent) < 0.08
            && abs(sample.greenComponent - target.greenComponent) < 0.08
            && abs(sample.blueComponent - target.blueComponent) < 0.08
    }
}
}

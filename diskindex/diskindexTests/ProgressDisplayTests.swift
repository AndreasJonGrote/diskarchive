//
//  ProgressDisplayTests.swift
//  diskindexTests
//
//  Aufgabe 151 — Fortschritt nur als Prozent und Balken, keine Dateizahlen.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ProgressDisplayTests {
    @Test(arguments: [
        ProgressCase.counting,
        ProgressCase.fortyFive,
        ProgressCase.ninetyNine,
    ])
    func chipPopoverAndBarMatchFraction(_ sample: ProgressCase) async {
        let medium = sample.medium
        let chip = MediumChip.presentation(medium).text
        #expect(chip == sample.chipText)

        let app = AppState()
        app.media = [medium]
        let width: CGFloat = 420
        let height = MenuBarPopoverLayout.rowHeight(for: medium)
        let bitmap = await PixelProbe.render(
            MenuBarConnectedMediumRow(medium: medium)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: width, height: height),
            size: CGSize(width: width, height: height),
            appearance: .aqua
        )
        let ratio = barFillRatio(bitmap, width: width, height: height)
        #expect(abs(ratio - sample.fraction) <= 0.02, "Balken \(ratio) erwartet \(sample.fraction)")

        let label = await PixelProbe.render(
            Text(verbatim: sample.popoverText)
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255))
                .frame(width: 72, height: 18, alignment: .leading)
                .background(Color.white),
            size: CGSize(width: 72, height: 18),
            appearance: .aqua
        )
        #expect(containsLabel(label, in: bitmap, rowWidth: width, rowHeight: height))
    }

    /// Glyphen der Vorlage müssen im rechten Teil der Zeile wieder auftauchen.
    private func containsLabel(_ label: NSBitmapImageRep, in row: NSBitmapImageRep, rowWidth: CGFloat, rowHeight: CGFloat) -> Bool {
        let ink = NSColor(srgbRed: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1)
        var points: [CGPoint] = []
        for y in 0..<18 {
            for x in 0..<72 {
                let color = PixelProbe.color(in: label, at: CGPoint(x: x, y: y))
                if matches(color, ink) { points.append(CGPoint(x: x, y: y)) }
            }
        }
        guard points.count > 8 else { return false }
        let originX = points.map(\.x).min() ?? 0
        let originY = points.map(\.y).min() ?? 0
        let shifted = points.map { CGPoint(x: $0.x - originX, y: $0.y - originY) }
        let searchX0 = Int(rowWidth) - 130
        var best = 0
        for y in 0..<Int(rowHeight) {
            for x in searchX0..<Int(rowWidth) {
                var hits = 0
                for point in shifted {
                    let color = PixelProbe.color(in: row, at: CGPoint(x: x + Int(point.x), y: y + Int(point.y)))
                    if matches(color, ink) { hits += 1 }
                }
                best = max(best, hits)
            }
        }
        return Double(best) / Double(shifted.count) >= 0.72
    }

    private func barFillRatio(_ bitmap: NSBitmapImageRep, width: CGFloat, height: CGFloat) -> CGFloat {
        let track = NSColor(srgbRed: 0xD7 / 255, green: 0xD3 / 255, blue: 0xD3 / 255, alpha: 1)
        let fill = NSColor(srgbRed: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1)
        var bestY = 0
        var bestCount = 0
        var bestFillRun = 0
        var fillRunY = 0
        let yMax = Int(height)
        for y in 0..<yMax {
            var tracks = 0
            var run = 0
            var longest = 0
            for x in 0..<Int(width) {
                let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if matches(color, track) { tracks += 1 }
                if matches(color, fill) {
                    run += 1
                    longest = max(longest, run)
                } else {
                    run = 0
                }
            }
            if tracks > bestCount {
                bestCount = tracks
                bestY = y
            }
            if longest > bestFillRun {
                bestFillRun = longest
                fillRunY = y
            }
        }
        if bestCount < 2 { bestY = fillRunY }
        guard bestCount >= 2 || bestFillRun > 40 else { return -1 }
        var minX = Int.max
        var maxX = Int.min
        var fillCount = 0
        for x in 0..<Int(width) {
            let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: bestY))
            if matches(color, track) || matches(color, fill) {
                minX = min(minX, x)
                maxX = max(maxX, x)
                if matches(color, fill) { fillCount += 1 }
            }
        }
        let span = maxX - minX + 1
        guard span > 0 else { return -1 }
        return CGFloat(fillCount) / CGFloat(span)
    }

    private func matches(_ color: NSColor, _ target: NSColor) -> Bool {
        abs(color.redComponent - target.redComponent) <= 0.08
            && abs(color.greenComponent - target.greenComponent) <= 0.08
            && abs(color.blueComponent - target.blueComponent) <= 0.08
    }
}

struct ProgressCase: Sendable {
    var fraction: Double
    var chipText: String
    var popoverText: String
    var phase: IndexRunPhase
    var indexingProgress: Double
    var fileCount: Int

    // bug.0.4.210: Ein Lauf zeigt seinen Wert (`indexingProgress`, beginnt beim gespeicherten Stand); die Zählphase mit
    // gespeicherter Gesamtzahl zeigt den gespeicherten Stand, nicht 0 %.
    static let counting = ProgressCase(fraction: 0.1, chipText: "10 % indiziert", popoverText: "10 %", phase: .counting, indexingProgress: 0.1, fileCount: 100)
    static let fortyFive = ProgressCase(fraction: 0.45, chipText: "45 % indiziert", popoverText: "45 %", phase: .indexing, indexingProgress: 0.45, fileCount: 450)
    static let ninetyNine = ProgressCase(fraction: 0.99, chipText: "99 % indiziert", popoverText: "99 %", phase: .indexing, indexingProgress: 0.99, fileCount: 990)

    @MainActor
    var medium: Medium {
        var medium = Medium(
            id: UUID(),
            name: "Studio Backup",
            type: .hdd,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 4_100_000_000_000,
            capacityUsedBytes: 1_000_000_000_000,
            fileCount: fileCount,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: indexingProgress
        )
        medium.indexRunPhase = phase
        medium.scanTotal = 1_000
        return medium
    }
}
}

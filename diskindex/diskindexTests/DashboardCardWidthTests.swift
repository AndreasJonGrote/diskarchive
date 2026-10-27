//
//  DashboardCardWidthTests.swift
//  diskindexTests
//
//  bug.0.4.211 — Dashboard-Kacheln sind genau so breit wie ihre Zelle, in allen Zuständen gleich (Online, Offline,
//  „x % indiziert“, Fehler, langer Name), Mindestbreite 220 (Katalog), Abstand 16 pt waagerecht und senkrecht.
//  Echtes Fenster außerhalb des Bildschirms, Beweis über Pixel: jede Kachel ist ein Lauf von Pixeln, die sich vom
//  Fensterhintergrund (Farbe am Rand) unterscheiden.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct DashboardCardWidthTests {
    /// Gemischte Zustände; die Zeitzeilen sind die längsten, die das Dashboard zeigt (Datum statt „heute“).
    private static func media() throws -> [Medium] {
        let base = try #require(PreviewData.media.dropFirst().first)
        let now = Date()
        let calendar = Calendar.current
        let longAgo = try #require(calendar.date(byAdding: .day, value: -40, to: now))
        func variant(_ name: String, _ change: (inout Medium) -> Void) -> Medium {
            var medium = base
            medium.id = UUID()
            medium.name = name
            medium.connectionStatus = .connected
            medium.indexStatus = .indexed
            medium.completedDepth = 3
            medium.lastIndexedAt = longAgo
            change(&medium)
            return medium
        }
        return [
            variant("Archiv 2019–2021") { _ in },
            variant("Offline-Platte") { $0.connectionStatus = .offline; $0.lastSeenAt = longAgo },
            variant("Läuft") { $0.indexStatus = .indexing; $0.indexingProgress = 0.42 },
            variant("Kaputt") { $0.indexStatus = .error },
            variant("Ein sehr langer Medienname für das externe Archiv-Laufwerk mit allen Projekten 2024 bis 2026") { _ in },
            variant("Lücke") { $0.indexStatus = .error; $0.hasIndexGaps = true },
            variant("Gestern") { $0.connectionStatus = .offline; $0.lastSeenAt = calendar.date(byAdding: .day, value: -1, to: now) },
            variant("Heute") { $0.lastIndexedAt = now; $0.showAbsoluteCapacity = true },
        ]
    }

    /// Läufe (pt, halboffen) von Pixeln, die sich vom Hintergrund unterscheiden, entlang einer Linie.
    private static func runs(_ bitmap: NSBitmapImageRep, background backdrop: NSColor, horizontalAt y: CGFloat? = nil, verticalAt x: CGFloat? = nil, length: CGFloat) -> [Range<CGFloat>] {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        var result: [Range<CGFloat>] = []
        var start: Int?
        let count = Int((length * scale).rounded(.down))
        for index in 0...count {
            var differs = false
            if index < count {
                let point = y.map { CGPoint(x: (CGFloat(index) + 0.5) / scale, y: $0) }
                    ?? CGPoint(x: x ?? 0, y: (CGFloat(index) + 0.5) / scale)
                let sample = PixelProbe.color(in: bitmap, at: point)
                differs = abs(sample.redComponent - backdrop.redComponent) > 0.012
                    || abs(sample.greenComponent - backdrop.greenComponent) > 0.012
                    || abs(sample.blueComponent - backdrop.blueComponent) > 0.012
            }
            if differs, start == nil { start = index }
            if !differs, let first = start {
                result.append(CGFloat(first) / scale ..< CGFloat(index) / scale)
                start = nil
            }
        }
        return result
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func cardsFillTheirCellsWithSixteenPointGaps(appearance: NSAppearance.Name) async throws {
        let media = try Self.media()
        for width in [900.0, 1134.0, 1400.0] as [CGFloat] {
            let app = AppState()
            app.media = media
            let size = CGSize(width: width, height: 900)
            let session = PixelProbe.open(
                DashboardView()
                    .environment(app)
                    .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                    .environment(\.scrollerStyleOverride, .overlay)
                    .frame(width: size.width, height: size.height),
                size: size, appearance: appearance
            )
            defer { session.close() }
            await PixelProbe.settleOpenWindow(session)
            let bitmap = session.bitmap()
            let background = PixelProbe.color(in: bitmap, at: CGPoint(x: 4, y: 4))
            let surface = PixelProbe.color(in: bitmap, at: CGPoint(x: DashboardGridLayout.spacing + 6, y: DashboardGridLayout.spacing + 3))
            try #require(abs(surface.redComponent - background.redComponent) + abs(surface.blueComponent - background.blueComponent) > 0.03,
                         "Kachelfläche \(surface) nicht vom Hintergrund \(background) unterscheidbar")

            let columns = DashboardGridLayout.columnCount(containerWidth: width - DashboardGridLayout.spacing * 2)
            let rows = Self.runs(bitmap, background: background, verticalAt: DashboardGridLayout.spacing + 40, length: size.height)
            let expectedRows = (media.count + columns - 1) / columns
            try #require(rows.count == expectedRows, "\(width) pt: \(rows.count) Reihen statt \(expectedRows): \(rows)")
            var widths: [CGFloat] = []
            for (rowIndex, row) in rows.enumerated() {
                #expect(abs(row.lowerBound - (rowIndex == 0 ? DashboardGridLayout.spacing : rows[rowIndex - 1].upperBound + 16)) <= 0.5,
                        "\(width) pt, Reihe \(rowIndex): senkrechter Abstand nicht 16 (\(rows))")
                let cards = Self.runs(bitmap, background: background, horizontalAt: (row.lowerBound + row.upperBound) / 2, length: size.width)
                let expected = min(columns, media.count - rowIndex * columns)
                #expect(cards.count == expected, "\(width) pt, Reihe \(rowIndex): \(cards.count) Kacheln statt \(expected): \(cards)")
                if let first = cards.first {
                    #expect(abs(first.lowerBound - DashboardGridLayout.spacing) <= 0.5, "\(width) pt: erste Kachel bei \(first.lowerBound)")
                }
                for (left, right) in zip(cards, cards.dropFirst()) {
                    #expect(abs(right.lowerBound - left.upperBound - 16) <= 0.5,
                            "\(width) pt, Reihe \(rowIndex): Abstand \(right.lowerBound - left.upperBound) statt 16 (\(cards))")
                }
                widths += cards.map { $0.upperBound - $0.lowerBound }
            }
            let reference = try #require(widths.first)
            #expect(reference >= 220 - 0.5, "\(width) pt: Kachel \(reference) schmaler als 220")
            #expect(widths.allSatisfy { abs($0 - reference) <= 0.5 }, "\(width) pt: Kacheln ungleich breit: \(widths)")
        }
    }
}
}

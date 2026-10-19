//
//  ColumnDividerTests.swift
//  diskindexTests
//
//  bug.0.4.089: Trennlinie zwischen allen Spalten in jedem Zustand (echtes Fenster außerhalb des Bildschirms,
//  `PixelProbe`, Regel 10/19), hell und dunkel. Gezählt werden senkrechte Linien rechts der Seitenleiste.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnDividerTests {
    private let size = CGSize(width: 1280, height: 600)

    @Test func dividersBetweenAllColumnsInEveryStateLight() async throws {
        try await run(scheme: .light, appearance: .aqua)
    }

    @Test func dividersBetweenAllColumnsInEveryStateDark() async throws {
        try await run(scheme: .dark, appearance: .darkAqua)
    }

    private func run(scheme: ColorScheme, appearance: NSAppearance.Name) async throws {
        let (app, mediumID) = Self.app()
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, scheme)
                .frame(width: size.width, height: size.height).background(DesignColor.bg),
            size: size,
            appearance: appearance
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        func lines() async -> [CGFloat] {
            try? await Task.sleep(for: .milliseconds(150))
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return Self.verticalLines(in: session.bitmap(), from: DesignSpacing.columnBrowserSidebarWidth + 3, to: size.width - 3)
        }
        // Wurzel (voll), A (voll), B (leer): drei Spalten, drei Linien.
        let normal = await lines()
        #expect(normal.count == 3, "normal: Linien bei \(normal)")
        // Statusfläche in der mittleren Spalte (Ladehinweis wie beim Nutzer): sie füllt die Restbreite, B steht rechts.
        app.columnBrowserState.setLoadingHintVisible(true, mediumID: mediumID, path: ["A"])
        let middleRest = await lines()
        // Linien Wurzel|A und A|B (B endet am Fensterrand, seine eigene Linie liegt außerhalb des Abtastbereichs).
        let boundaryAB = size.width - DesignSpacing.columnBrowserColumnWidth
        #expect(middleRest.count == 2, "Ladehinweis Mitte: Linien bei \(middleRest)")
        #expect(middleRest.contains { abs($0 - boundaryAB) <= 2 }, "Linie zwischen A und B fehlt: \(middleRest)")
        // Nach dem Ladezustand wieder drei Spalten mit Linien.
        app.columnBrowserState.setLoadingHintVisible(false, mediumID: mediumID, path: ["A"])
        let after = await lines()
        #expect(after.count == 3, "danach: Linien bei \(after)")
        // Letzte Spalte als Statusfläche: Linien zwischen den Spalten (zwei), keine am rechten Fensterrand.
        app.columnBrowserState.setLoadingHintVisible(true, mediumID: mediumID, path: ["A", "B"])
        let lastRest = await lines()
        #expect(lastRest.count == 2, "Ladehinweis letzte Spalte: Linien bei \(lastRest)")
    }

    /// Senkrechte Linien (pt): Spalten, deren Pixel auf vier Höhen gleich sind und sich von beiden Nachbarn
    /// (2 pt links und rechts) abheben. Benachbarte Treffer zählen als eine Linie.
    static func verticalLines(in bitmap: NSBitmapImageRep, from: CGFloat, to: CGFloat) -> [CGFloat] {
        let scale = CGFloat(bitmap.pixelsWide) / max(1, bitmap.size.width)
        func color(_ x: CGFloat, _ y: CGFloat) -> (CGFloat, CGFloat, CGFloat)? {
            guard let c = bitmap.colorAt(x: Int(x * scale), y: Int(y * scale))?.usingColorSpace(.sRGB) else { return nil }
            return (c.redComponent, c.greenComponent, c.blueComponent)
        }
        func distance(_ a: (CGFloat, CGFloat, CGFloat), _ b: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
            abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2)
        }
        let ys: [CGFloat] = [250, 320, 390, 460]
        var hits: [CGFloat] = []
        var x = from
        while x <= to {
            var isLine = true
            var first: (CGFloat, CGFloat, CGFloat)?
            for y in ys {
                guard let center = color(x, y), let left = color(x - 2, y), let right = color(x + 2, y) else { isLine = false; break }
                if let first, distance(first, center) > 0.02 { isLine = false; break }
                first = first ?? center
                if distance(center, left) < 0.04 || distance(center, right) < 0.04 || distance(left, right) > 0.04 {
                    isLine = false
                    break
                }
            }
            if isLine, (hits.last.map { x - $0 > 3 } ?? true) { hits.append(x) }
            x += 0.5
        }
        return hits
    }

    private static func app() -> (AppState, UUID) {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID, name: "Linien", type: .ssd, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 100,
            fileCount: 1, folderCount: 2, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = 5
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["A", "B"]
        func item(_ row: Int64, _ name: String, _ parent: [String], folder: Bool) -> IndexedItem {
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: row), rowID: row, name: name,
                kind: folder ? .folder : .file, parentPath: parent, modifiedAt: Date(), sizeBytes: folder ? 0 : 1, listedAt: Date()
            )
        }
        app.indexRepository.seedScreenshotCache(
            mediumID: mediumID,
            entries: [
                ([], [item(1, "A", [], folder: true)]),
                (["A"], [item(2, "B", ["A"], folder: true), item(3, "x.txt", ["A"], folder: false)]),
                (["A", "B"], []),
            ]
        )
        return (app, mediumID)
    }
}
}

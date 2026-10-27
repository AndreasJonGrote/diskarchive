//
//  ColumnSurfaceColorTests.swift
//  diskindexTests
//
//  bug.0.4.219 — Seitenleiste, Offline-Leiste und Detailspalte haben dieselbe Fläche (eine Farbrolle, `DesignColor.toolbar`
//  = Katalog „Seitenleiste“, Text 6 % über dem Hintergrund), hell und dunkel. Echtes Fenster außerhalb des Bildschirms,
//  Beweis über Pixel an leeren Stellen der drei Flächen.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnSurfaceColorTests {
    private static let size = CGSize(width: 1280, height: 600)

    /// Offline-Medium, Datei in der Wurzel gewählt: Offline-Leiste und Detailspalte sind sichtbar.
    private static func app() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID, name: "Fläche", type: .ssd, connectionStatus: .offline, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 100,
            fileCount: 1, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = 5
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        let file = IndexedItem(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: 1), rowID: 1, name: "x.txt",
            kind: .file, parentPath: [], modifiedAt: Date(), sizeBytes: 1, listedAt: Date()
        )
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: [([], [file])])
        app.columnBrowserState.selection = ColumnSelection(ids: [file.id], anchorID: file.id, focusColumnIndex: 0, lastClickedID: file.id)
        return app
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func sidebarOfflineBarAndDetailShareOneSurface(appearance: NSAppearance.Name) async throws {
        let app = Self.app()
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                .frame(width: Self.size.width, height: Self.size.height).background(DesignColor.bg),
            size: Self.size,
            appearance: appearance
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let bitmap = session.bitmap()
        // Leere Stellen: Seitenleiste unter der Medienliste, Offline-Leiste am rechten Ende, Detailspalte unten rechts.
        let sidebar = PixelProbe.color(in: bitmap, at: CGPoint(x: 100, y: 450))
        let banner = PixelProbe.color(in: bitmap, at: CGPoint(x: Self.size.width - 20, y: 8))
        let detail = PixelProbe.color(in: bitmap, at: CGPoint(x: Self.size.width - 20, y: 450))
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: 200 + 115, y: 450))
        func same(_ a: NSColor, _ b: NSColor) -> Bool {
            abs(a.redComponent - b.redComponent) <= 0.006 && abs(a.greenComponent - b.greenComponent) <= 0.006
                && abs(a.blueComponent - b.blueComponent) <= 0.006
        }
        try #require(!same(sidebar, background), "Seitenleiste \(sidebar) hebt sich nicht von der Ordnerspalte \(background) ab")
        #expect(same(banner, sidebar), "Offline-Leiste \(banner) ≠ Seitenleiste \(sidebar)")
        #expect(same(detail, sidebar), "Detailspalte \(detail) ≠ Seitenleiste \(sidebar)")
    }
}
}

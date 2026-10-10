//
//  ColumnChromeTests.swift
//  diskindexTests
//
//  Aufgabe 152 / 200 — Markierung, Ladehinweis (echte Testdaten).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnChromeTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func selectedPathRowsStayFullColor(_ appearance: NSAppearance.Name) async {
        let app = chromeApp(path: [ChromeNames.projects], selectFirstChild: true)
        let scheme: ColorScheme = appearance == .darkAqua ? .dark : .light
        let bitmap = await PixelProbe.render(
            ColumnBrowserView().environment(app).environment(\.colorScheme, scheme).frame(width: 1280, height: 800),
            size: CGSize(width: 1280, height: 800),
            appearance: appearance
        )
        let swatch = await PixelProbe.render(
            Rectangle().fill(DesignColor.sidebarActiveBackground).frame(width: 40, height: 40),
            size: CGSize(width: 40, height: 40),
            appearance: appearance
        )
        let fill = PixelProbe.color(in: swatch, at: CGPoint(x: 20, y: 20))
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        for index in 0..<2 {
            let x = sidebar + CGFloat(index) * width + width - 28
            #expect(rowMatches(fill, in: bitmap, x: x), "Markierung Spalte \(index)")
        }
    }

    @Test func loadingHintAppearsAfterDelay() async throws {
        let app = chromeApp(path: [ChromeNames.projects, ChromeNames.loading], selectFirstChild: false)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        app.indexRepository.setLoadingForUITest(
            mediumID: mediumID,
            path: [ChromeNames.projects, ChromeNames.loading],
            loading: true
        )
        let size = CGSize(width: 1280, height: 800)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        // Standard-Verzögerung des Ladehinweises: 1 s.
        try await Task.sleep(for: .milliseconds(1400))
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let bitmap = session.bitmap()
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let column = DesignSpacing.columnBrowserColumnWidth
        let body = CGRect(x: sidebar + column * 2 + 16, y: 36, width: 180, height: 90)
        let ink = PixelProbe.inkBounds(in: bitmap, rect: body, background: CGPoint(x: sidebar + column * 2 + 24, y: 320))
        #expect(ink != nil)
        let left = PixelProbe.color(in: bitmap, at: CGPoint(x: sidebar + column * 2 + column - 4, y: 200))
        let right = PixelProbe.color(in: bitmap, at: CGPoint(x: 1200, y: 200))
        #expect(same(left, right))
    }

    private enum ChromeNames {
        static let projects = "Projekte"
        static let pending = "Wird indiziert"
        static let loading = "Inhalte werden geladen"
    }

    private func chromeApp(path: [String], selectFirstChild: Bool) -> AppState {
        let app = AppState()
        var medium = Medium(
            id: UUID(),
            name: "Chrome",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 3,
            folderCount: 3,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 5
        func folder(_ rowID: Int64, _ name: String, _ parent: [String]) -> IndexedItem {
            IndexedItem(
                id: IndexedItem.stableID(mediumID: medium.id, rowID: rowID),
                rowID: rowID,
                name: name,
                kind: .folder,
                parentPath: parent,
                modifiedAt: Date(),
                sizeBytes: nil,
                lastSeenAt: Date(),
                listedAt: Date()
            )
        }
        let root = [folder(1, ChromeNames.projects, [])]
        let children = [
            folder(2, ChromeNames.pending, [ChromeNames.projects]),
            folder(3, ChromeNames.loading, [ChromeNames.projects]),
        ]
        app.media = [medium]
        app.indexRepository.seedScreenshotCache(mediumID: medium.id, entries: [
            ([], root),
            ([ChromeNames.projects], children),
        ])
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.id
        app.columnBrowserState.pathStack = path
        if selectFirstChild, let first = children.first {
            var selection = ColumnSelection()
            selection.replace(id: first.id, column: 1)
            app.columnBrowserState.selection = selection
        }
        return app
    }

    /// Rechte Seite der ersten Zeile (ohne Glyphen) = Auswahlfläche, nicht abgedunkelt.
    private func rowMatches(_ fill: NSColor, in bitmap: NSBitmapImageRep, x: CGFloat) -> Bool {
        var run = 0
        var y: CGFloat = 28
        while y < 110 {
            if same(PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)), fill, tolerance: 3 / 255) {
                run += 1
                if run >= 4 { return true }
            } else {
                run = 0
            }
            y += 2
        }
        return false
    }

    private func same(_ a: NSColor, _ b: NSColor, tolerance: CGFloat = 0.08) -> Bool {
        abs(a.redComponent - b.redComponent) <= tolerance
            && abs(a.greenComponent - b.greenComponent) <= tolerance
            && abs(a.blueComponent - b.blueComponent) <= tolerance
    }
}
}

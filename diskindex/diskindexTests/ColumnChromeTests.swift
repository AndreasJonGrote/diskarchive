//
//  ColumnChromeTests.swift
//  diskindexTests
//
//  Aufgabe 152 — Markierung, Scrollbalken, Demo-Ladehinweis.
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
        let app = demoApp(path: [ColumnStateSimulation.FolderName.projects], selectPending: true)
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

    @Test func folderColumnHidesScrollTrack() async {
        let bitmap = await scrolledColumnBitmap()
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        let edge = sidebar + width
        let ground = PixelProbe.color(in: bitmap, at: CGPoint(x: edge - 40, y: 400))
        var odd = 0
        for y in stride(from: 36, to: 520, by: 2) {
            let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: edge - 8, y: CGFloat(y)))
            if !same(sample, ground, tolerance: 0.2) { odd += 1 }
        }
        #expect(odd < 8)
    }

    /// Aufgabe 172 a: auch mit klassischen Rollbalken („Rollbalken: immer“) keine Spur.
    @Test func folderColumnHidesScrollTrackWithLegacyScrollers() async {
        let bitmap = await scrolledColumnBitmap(forceLegacyScrollers: true)
        let edge = DesignSpacing.columnBrowserSidebarWidth + DesignSpacing.columnBrowserColumnWidth
        let ground = PixelProbe.color(in: bitmap, at: CGPoint(x: edge - 40, y: 400))
        var odd = 0
        for y in stride(from: 36, to: 520, by: 2) {
            let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: edge - 8, y: CGFloat(y)))
            if !same(sample, ground, tolerance: 0.2) { odd += 1 }
        }
        #expect(odd < 8)
    }

    @Test func demoLoadingHintAppearsImmediately() async {
        let projects = ColumnStateSimulation.FolderName.projects
        let loading = ColumnStateSimulation.FolderName.loadingContents
        let app = demoApp(path: [projects, loading], selectPending: false)
        let bitmap = await PixelProbe.render(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: 1280, height: 800),
            size: CGSize(width: 1280, height: 800),
            appearance: .aqua
        )
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let column = DesignSpacing.columnBrowserColumnWidth
        let body = CGRect(x: sidebar + column * 2 + 16, y: 36, width: 180, height: 90)
        let ink = PixelProbe.inkBounds(in: bitmap, rect: body, background: CGPoint(x: sidebar + column * 2 + 24, y: 320))
        #expect(ink != nil)
        let left = PixelProbe.color(in: bitmap, at: CGPoint(x: sidebar + column * 2 + column - 4, y: 200))
        let right = PixelProbe.color(in: bitmap, at: CGPoint(x: 1200, y: 200))
        #expect(same(left, right))
    }

    private func demoApp(path: [String], selectPending: Bool) -> AppState {
        let app = AppState()
        let demo = ColumnStateSimulation.makeMedium()
        app.media = [demo]
        let projects = ColumnStateSimulation.FolderName.projects
        let root = ColumnStateSimulation.rootItems(mediumID: demo.id)
        let children = ColumnStateSimulation.children(mediumID: demo.id, path: [projects]) ?? []
        app.indexRepository.seedScreenshotCache(mediumID: demo.id, entries: [
            ([], root),
            ([projects], children),
        ])
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = demo.id
        app.columnBrowserState.pathStack = path
        if path == [ColumnStateSimulation.FolderName.projects, ColumnStateSimulation.FolderName.loadingContents] {
            app.indexRepository.requestLoad(mediumID: demo.id, path: path)
        }
        if selectPending, let pending = children.first {
            var selection = ColumnSelection()
            selection.replace(id: pending.id, column: 1)
            app.columnBrowserState.selection = selection
        }
        return app
    }

    func scrolledColumnBitmap(forceLegacyScrollers: Bool = false) async -> NSBitmapImageRep {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID,
            name: "Liste",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 200,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 2
        let items = (0..<200).map { index in
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: "Datei \(index)",
                kind: .file,
                parentPath: [],
                modifiedAt: Date(),
                sizeBytes: 10,
                lastSeenAt: Date(),
                listedAt: Date()
            )
        }
        app.media = [medium]
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: [([], items)])
        app.columnBrowserState.selectedMediumID = mediumID
        let host = NSHostingView(
            rootView: ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 1280, height: 800)
        )
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = host.appearance
        window.contentView = host
        let previousAppAppearance = NSApp.appearance
        NSApp.appearance = host.appearance
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(300))
        host.layoutSubtreeIfNeeded()
        if forceLegacyScrollers {
            applyLegacyScrollerStyle(to: host)
            #expect(legacyScrollerCount(in: host) > 0)
        }
        window.display()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)
            ?? NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 1,
                pixelsHigh: 1,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        NSApp.appearance = previousAppAppearance
        return rep
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

    private func applyLegacyScrollerStyle(to view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.verticalScroller?.scrollerStyle = .legacy
            scroll.horizontalScroller?.scrollerStyle = .legacy
        }
        for subview in view.subviews {
            applyLegacyScrollerStyle(to: subview)
        }
    }

    private func legacyScrollerCount(in view: NSView) -> Int {
        var count = 0
        if let scroll = view as? NSScrollView {
            if scroll.verticalScroller?.scrollerStyle == .legacy { count += 1 }
            if scroll.horizontalScroller?.scrollerStyle == .legacy { count += 1 }
        }
        for subview in view.subviews {
            count += legacyScrollerCount(in: subview)
        }
        return count
    }

    private func same(_ a: NSColor, _ b: NSColor, tolerance: CGFloat = 0.08) -> Bool {
        abs(a.redComponent - b.redComponent) <= tolerance
            && abs(a.greenComponent - b.greenComponent) <= tolerance
            && abs(a.blueComponent - b.blueComponent) <= tolerance
    }
}
}

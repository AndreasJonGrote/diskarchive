//
//  ColumnHorizontalScrollerTests.swift
//  diskindexTests
//
//  Aufgabe 187 / 192 c / 198 — Scrollleisten (waagerecht + senkrecht), Overlay und Legacy.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnHorizontalScrollerTests {
    @Test(arguments: [NSScroller.Style.overlay, .legacy])
    func horizontalScrollerSitsAboveFooter(style: NSScroller.Style) async throws {
        let size = CGSize(width: 1000, height: 600)
        let app = fiveColumnOverflowApp()
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let host = try #require(session.window.contentView)
        applyScrollerStyle(style, to: host)
        await PixelProbe.settleOpenWindow(session)

        let scroll = try #require(mainColumnHorizontalScroll(in: session.window))
        scroll.flashScrollers()
        session.window.display()
        let scroller = try #require(scroll.horizontalScroller)
        try #require(!scroller.isHidden)
        try #require(scroller.alphaValue > 0.01)

        let scrollerInHost = scroll.convert(scroller.frame, to: host)
        let footerTop = try #require(footerTopY(in: host))
        #expect(scrollerInHost.maxY <= footerTop + 1)
        #expect(scrollerInHost.minY < footerTop)
        // Overlay: Luft zur Fußzeile (ohne Inset: Abstand 0). Legacy: bündig darüber genügt.
        if style == .overlay {
            #expect(footerTop - scrollerInHost.maxY >= 4)
        }
    }

    private func mainColumnHorizontalScroll(in window: NSWindow) -> NSScrollView? {
        guard let root = window.contentView else { return nil }
        var best: (scroll: NSScrollView, docWidth: CGFloat)?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let docW = scroll.documentView?.frame.width ?? 0
                if docW > scroll.bounds.width + 20 {
                    if best == nil || docW > best!.docWidth {
                        best = (scroll, docW)
                    }
                }
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return best?.scroll
    }

    @Test func noBottomInsetWhenColumnsFitWithoutOverflow() async throws {
        let app = AppState()
        let mediumID = UUID()
        let medium = Medium(
            id: mediumID,
            name: "Fit",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 1,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.indexRepository.seedScreenshotCache(
            mediumID: mediumID,
            entries: [([], [
                IndexedItem(
                    id: IndexedItem.stableID(mediumID: mediumID, rowID: 1),
                    rowID: 1,
                    name: "A",
                    kind: .folder,
                    parentPath: [],
                    modifiedAt: Date(),
                    sizeBytes: 0,
                    listedAt: Date()
                ),
            ])]
        )
        let size = CGSize(width: 1600, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        #expect(!horizontalScrollerIsVisible(in: session.window))
    }

    @Test(arguments: [NSScroller.Style.overlay, .legacy])
    func verticalScrollerStaysInsideFolderColumn(style: NSScroller.Style) async throws {
        let size = CGSize(width: 1280, height: 800)
        let built = tallFolderApp(itemCount: 500)
        let app = built.app
        let firstID = built.firstItemID
        var selection = ColumnSelection()
        selection.replace(id: firstID, column: 0)
        app.columnBrowserState.selection = selection
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let host = try #require(session.window.contentView)
        applyScrollerStyle(style, to: host)
        await PixelProbe.settleOpenWindow(session)

        let columnScroll = try #require(firstFolderColumnScroll(in: host))
        columnScroll.flashScrollers()
        session.window.display()
        let scroller = try #require(columnScroll.verticalScroller)
        try #require(!scroller.isHidden)
        try #require(scroller.alphaValue > 0.01 || style == .legacy)

        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        let dividerX = sidebar + width
        let scrollerInHost = columnScroll.convert(scroller.frame, to: host)
        #expect(scrollerInHost.maxX <= dividerX + 0.5)
        #expect(scrollerInHost.minX >= sidebar - 0.5)

        if style == .legacy {
            let bitmap = session.bitmap()
            let swatch = await PixelProbe.render(
                Rectangle().fill(DesignColor.sidebarActiveBackground).frame(width: 40, height: 40),
                size: CGSize(width: 40, height: 40),
                appearance: .aqua
            )
            let fill = PixelProbe.color(in: swatch, at: CGPoint(x: 20, y: 20))
            #expect(scrollerInHost.minX > sidebar + 20)
            // Auswahl irgendwo links vom Scroller in der ersten Zeile.
            var matched = false
            var x = sidebar + 16
            while x < scrollerInHost.minX - 2 {
                var y: CGFloat = 36
                while y < 100 {
                    if sameColor(PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)), fill) {
                        matched = true
                        break
                    }
                    y += 2
                }
                if matched { break }
                x += 4
            }
            // Unter dem Scroller keine Auswahlfarbe (Hintergrund endet davor).
            var underScroller = 0
            var y: CGFloat = 36
            while y < 100 {
                if sameColor(PixelProbe.color(in: bitmap, at: CGPoint(x: scrollerInHost.midX, y: y)), fill) {
                    underScroller += 1
                }
                y += 2
            }
            #expect(matched)
            #expect(underScroller < 2)
        }
    }

    @Test func shortFolderHasNoLegacyVerticalScroller() async throws {
        let size = CGSize(width: 1280, height: 800)
        let app = tallFolderApp(itemCount: 5).app
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let host = try #require(session.window.contentView)
        applyScrollerStyle(.legacy, to: host)
        await PixelProbe.settleOpenWindow(session)

        let columnScroll = try #require(firstFolderColumnScroll(in: host))
        columnScroll.flashScrollers()
        session.window.display()
        if let scroller = columnScroll.verticalScroller {
            #expect(scroller.isHidden || scroller.alphaValue < 0.01 || scroller.frame.width < 0.5
                || columnScroll.documentView.map { $0.frame.height <= columnScroll.contentView.bounds.height + 1 } == true)
        }
    }

    /// Aufgabe 199: Detail-Spalte nur bei Datei oder Mehrfachauswahl, auch bei Überlauf.
    @Test func detailColumnOnlyWithFileSelection() async throws {
        let size = CGSize(width: 1000, height: 600)
        func documentWidth(selectFile: Bool) async throws -> CGFloat {
            let built = fourFolderColumnsApp()
            var selection = ColumnSelection()
            if selectFile {
                selection.replace(id: built.fileID, column: 3)
            } else {
                selection.replace(id: built.folderID, column: 2)
            }
            built.app.columnBrowserState.selection = selection
            let session = PixelProbe.open(
                ColumnBrowserView()
                    .environment(built.app)
                    .environment(\.colorScheme, .light)
                    .frame(width: size.width, height: size.height),
                size: size,
                appearance: .aqua
            )
            defer { session.close() }
            await PixelProbe.settleOpenWindow(session)
            let scroll = try #require(mainColumnHorizontalScroll(in: session.window))
            return scroll.documentView?.frame.width ?? 0
        }
        let withoutFile = try await documentWidth(selectFile: false)
        let withFile = try await documentWidth(selectFile: true)
        // Ohne Datei: nur die Ordnerspalten, mit Datei zusätzlich die Detail-Spalte.
        #expect(withFile - withoutFile >= DesignSpacing.columnBrowserDetailWidth - 0.5)
    }

    private func fourFolderColumnsApp() -> (app: AppState, folderID: UUID, fileID: UUID) {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID,
            name: "Wide",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 1,
            folderCount: 3,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 5
        let names = ["A", "B", "C"]
        var entries: [([String], [IndexedItem])] = []
        var path: [String] = []
        var folderID = mediumID
        for (index, name) in names.enumerated() {
            let item = IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: name,
                kind: .folder,
                parentPath: path,
                modifiedAt: Date(),
                sizeBytes: 0,
                listedAt: Date()
            )
            if name == "C" { folderID = item.id }
            entries.append((path, [item]))
            path.append(name)
        }
        let file = IndexedItem(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: 99),
            rowID: 99,
            name: "datei.txt",
            kind: .file,
            parentPath: path,
            modifiedAt: Date(),
            sizeBytes: 10,
            listedAt: Date()
        )
        entries.append((path, [file]))
        app.media = [medium]
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: entries)
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = names
        return (app, folderID, file.id)
    }

    private func fiveColumnOverflowApp() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID,
            name: "Wide",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 5,
            folderCount: 5,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 5
        let names = ["A", "B", "C", "D", "E"]
        var entries: [([String], [IndexedItem])] = []
        var path: [String] = []
        for (index, name) in names.enumerated() {
            let item = IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: name,
                kind: .folder,
                parentPath: path,
                modifiedAt: Date(),
                sizeBytes: 0,
                listedAt: Date()
            )
            entries.append((path, [item]))
            path.append(name)
        }
        entries.append((path, []))
        app.media = [medium]
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: entries)
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = Array(names.dropLast())
        return app
    }

    private func tallFolderApp(itemCount: Int) -> (app: AppState, firstItemID: UUID) {
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
            fileCount: itemCount,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 2
        let items = (0..<itemCount).map { index in
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: "Datei \(index)",
                kind: .file,
                parentPath: [],
                modifiedAt: Date(),
                sizeBytes: 10,
                listedAt: Date()
            )
        }
        app.media = [medium]
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: [([], items)])
        app.columnBrowserState.selectedMediumID = mediumID
        let firstID = items.first?.id ?? mediumID
        return (app, firstID)
    }

    private func applyScrollerStyle(_ style: NSScroller.Style, to view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.scrollerStyle = style
            scroll.horizontalScroller?.scrollerStyle = style
            scroll.verticalScroller?.scrollerStyle = style
            scroll.flashScrollers()
        }
        for subview in view.subviews {
            applyScrollerStyle(style, to: subview)
        }
    }

    private func firstFolderColumnScroll(in host: NSView) -> NSScrollView? {
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        var best: NSScrollView?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let frame = scroll.convert(scroll.bounds, to: host)
                let overlapsFirstColumn = frame.minX >= sidebar - 1 && frame.minX < sidebar + width
                let isVertical = (scroll.documentView?.frame.height ?? 0) > scroll.bounds.height + 10
                    || scroll.hasVerticalScroller
                if overlapsFirstColumn, isVertical || frame.width <= width + 20 {
                    if best == nil || frame.width < (best!.convert(best!.bounds, to: host).width) {
                        best = scroll
                    }
                }
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(host)
        return best
    }

    private func footerTopY(in host: NSView) -> CGFloat? {
        var candidate: CGFloat?
        func walk(_ view: NSView) {
            let frame = view.convert(view.bounds, to: host)
            let nearBottom = frame.maxY >= host.bounds.height - 2
            let footerHeight = frame.height >= 27 && frame.height <= 52
            let wide = frame.width >= host.bounds.width * 0.55
            if nearBottom, footerHeight, wide {
                candidate = min(candidate ?? frame.minY, frame.minY)
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(host)
        return candidate
    }

    private func horizontalScrollerIsVisible(in window: NSWindow) -> Bool {
        guard let root = window.contentView else { return false }
        func walk(_ view: NSView) -> Bool {
            if let scroll = view as? NSScrollView {
                if scroll.hasHorizontalScroller,
                   let scroller = scroll.horizontalScroller,
                   !scroller.isHidden,
                   scroller.alphaValue > 0.01 {
                    return true
                }
            }
            for child in view.subviews where walk(child) { return true }
            return false
        }
        return walk(root)
    }

    private func sameColor(_ a: NSColor, _ b: NSColor, tolerance: CGFloat = 3.0 / 255) -> Bool {
        abs(a.redComponent - b.redComponent) <= tolerance
            && abs(a.greenComponent - b.greenComponent) <= tolerance
            && abs(a.blueComponent - b.blueComponent) <= tolerance
    }

}
}

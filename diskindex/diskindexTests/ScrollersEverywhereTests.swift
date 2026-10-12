//
//  ScrollersEverywhereTests.swift
//  diskindexTests
//
//  Aufgabe 212 — Systemscrollleisten auch in der Suche, in Einstellungen → Speichermedien und in großen Ordnern.
//  Fenster außerhalb des Bildschirms (Regeln 19–21), beide Leistenstile.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ScrollersEverywhereTests {
    private let size = CGSize(width: 1000, height: 600)

    @Test(arguments: [NSScroller.Style.overlay, .legacy])
    func searchResultListShowsItsVerticalScroller(style: NSScroller.Style) async throws {
        let app = AppState()
        let mediumID = UUID()
        let items = (0..<300).map { index in
            SearchResultItem(item: file("bericht-\(index).pdf", mediumID: mediumID, row: index), mediumID: mediumID, isOnline: true)
        }
        app.searchMatch = SearchMatch(media: [], items: items, itemCount: items.count)
        app.searchState.submittedQuery = "bericht"
        app.mainWindowDestination = .search
        app.screenshotFrozenLists = true
        try await expectVerticalScroller(MainWindowHostView().environment(app), style: style)
    }

    @Test(arguments: [NSScroller.Style.overlay, .legacy])
    func registryTableShowsItsVerticalScroller(style: NSScroller.Style) async throws {
        let app = AppState()
        app.media = (0..<80).map { medium("Medium \($0)") }
        app.settingsTab = .storageMedia
        app.mainWindowDestination = .settings
        try await expectVerticalScroller(MainWindowHostView().environment(app), style: style)
    }

    @Test(arguments: [NSScroller.Style.overlay, .legacy])
    func hugeFolderTableShowsItsVerticalScroller(style: NSScroller.Style) async throws {
        let app = AppState()
        let mediumID = UUID()
        let items = (0..<400).map { file("datei-\($0).txt", mediumID: mediumID, row: $0) }
        let view = ColumnFolderContents(
            mediumID: mediumID,
            path: [],
            filteredItems: items,
            selectedIDs: [],
            isLoading: false,
            loaded: 0,
            total: 0,
            tableViewMinimum: 10
        ) { item in
            Text(item.name).frame(height: 28)
        }
        .environment(app)
        .frame(width: 270)
        try await expectVerticalScroller(view, style: style)
    }

    // MARK: - Prüfung

    private func expectVerticalScroller<V: View>(_ content: V, style: NSScroller.Style) async throws {
        let session = PixelProbe.open(
            content.environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let host = try #require(session.window.contentView)
        applyStyle(style, to: host)
        await PixelProbe.settleOpenWindow(session)
        let scrolls = scrollViews(in: host).filter {
            ($0.documentView?.frame.height ?? 0) > $0.contentView.bounds.height + 10
        }
        let scroll = try #require(scrolls.max { ($0.documentView?.frame.height ?? 0) < ($1.documentView?.frame.height ?? 0) },
                                  "keine ScrollView mit überlangem Inhalt")
        scroll.flashScrollers()
        session.window.display()
        #expect(scroll.hasVerticalScroller, "hasVerticalScroller ist aus")
        let scroller = try #require(scroll.verticalScroller)
        #expect(!scroller.isHidden)
        #expect(style == .legacy || scroller.alphaValue > 0.01)
        let frame = scroll.convert(scroller.frame, to: host)
        #expect(frame.width > 3)
        #expect(frame.minX >= -0.5 && frame.maxX <= host.bounds.width + 0.5, "Leiste außerhalb des Fensters: \(frame)")
        #expect(frame.minY >= -0.5 && frame.maxY <= host.bounds.height + 0.5)
    }

    private func applyStyle(_ style: NSScroller.Style, to view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.scrollerStyle = style
            scroll.verticalScroller?.scrollerStyle = style
            scroll.horizontalScroller?.scrollerStyle = style
        }
        for sub in view.subviews { applyStyle(style, to: sub) }
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []
        if let scroll = view as? NSScrollView { found.append(scroll) }
        for sub in view.subviews { found.append(contentsOf: scrollViews(in: sub)) }
        return found
    }

    private func file(_ name: String, mediumID: UUID, row: Int) -> IndexedItem {
        IndexedItem(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(row + 1)),
            rowID: Int64(row + 1),
            name: name,
            kind: .file,
            parentPath: [],
            modifiedAt: Date(),
            sizeBytes: 10,
            listedAt: Date()
        )
    }

    private func medium(_ name: String) -> Medium {
        Medium(
            id: UUID(),
            name: name,
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 10,
            folderCount: 2,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
    }
}
}

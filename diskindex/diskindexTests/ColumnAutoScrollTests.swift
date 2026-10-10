//
//  ColumnAutoScrollTests.swift
//  diskindexTests
//
//  Aufgabe 188 b / 192 d — Scroll nach Auswahl (ohne Maus/Tinte).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnAutoScrollTests {
    @Test func selectingFileScrollsDetailColumnIntoView() async throws {
        try await ColumnAutoScrollTestSupport.runOverflowSelectionScrollsTrailing()
    }

    @Test func selectingFileDoesNotScrollWhenColumnsAlreadyFit() async throws {
        try await ColumnAutoScrollTestSupport.runSelectionWhenAlreadyFitKeepsLeadingEdge()
    }

    @Test func liveInvalidateDoesNotScrollDetailColumn() async throws {
        try await ColumnAutoScrollTestSupport.runLiveInvalidatePreservesScrollOffset()
    }
}
}

@MainActor
private enum ColumnAutoScrollTestSupport {
    static func runOverflowSelectionScrollsTrailing() async throws {
        let app = deepColumnApp()
        let size = CGSize(width: 1120, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["A", "B", "C"])
        scrollMainHorizontalToLeading(in: session.window)
        try await Task.sleep(for: .milliseconds(200))
        let scroll = try #require(mainColumnHorizontalScroll(in: session.window))
        #expect(scroll.documentVisibleRect.minX <= 1.5)
        #expect(!detailTrailingFlushWithViewport(scroll))
        let file = try #require(app.indexRepository.children(mediumID: mediumID, path: ["A", "B", "C"]).first { !$0.isFolder })
        app.columnBrowserState.selection = ColumnSelection(ids: [file.id], focusColumnIndex: 3)
        let aligned = await waitUntil(timeout: 0.5) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return detailTrailingFlushWithViewport(scroll)
        }
        #expect(aligned)
    }

    static func runSelectionWhenAlreadyFitKeepsLeadingEdge() async throws {
        let app = shallowColumnApp()
        let size = CGSize(width: 1800, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["A"])
        let file = try #require(app.indexRepository.children(mediumID: mediumID, path: ["A"]).first { !$0.isFolder })
        let before = horizontalScrollLeadingOffset(in: session.window)
        app.columnBrowserState.selection = ColumnSelection(ids: [file.id], focusColumnIndex: 1)
        try await Task.sleep(for: .milliseconds(450))
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let after = horizontalScrollLeadingOffset(in: session.window)
        #expect(abs(before - after) <= 1)
    }

    static func runLiveInvalidatePreservesScrollOffset() async throws {
        let app = deepColumnApp()
        let size = CGSize(width: 1120, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["A", "B", "C"])
        let file = try #require(app.indexRepository.children(mediumID: mediumID, path: ["A", "B", "C"]).first { !$0.isFolder })
        app.columnBrowserState.selection = ColumnSelection(ids: [file.id], focusColumnIndex: 3)
        let aligned = await waitUntil(timeout: 0.5) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return detailTrailingFlushWithViewport(scroll)
        }
        #expect(aligned)
        let scroll = try #require(mainColumnHorizontalScroll(in: session.window))
        let anchor = scroll.documentVisibleRect.minX
        app.indexRepository.invalidate(mediumID)
        try await Task.sleep(for: .milliseconds(300))
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let after = scroll.documentVisibleRect.minX
        #expect(abs(anchor - after) <= 1)
    }

    static func detailTrailingFlushWithViewport(_ scroll: NSScrollView) -> Bool {
        let docWidth = scroll.documentView?.frame.width ?? 0
        guard docWidth > scroll.bounds.width + 1 else { return true }
        let visible = scroll.documentVisibleRect
        return docWidth - visible.maxX <= 1
    }

    static func horizontalScrollLeadingOffset(in window: NSWindow) -> CGFloat {
        mainColumnHorizontalScroll(in: window)?.documentVisibleRect.minX ?? 0
    }

    static func mainColumnHorizontalScroll(in window: NSWindow) -> NSScrollView? {
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

    static func scrollMainHorizontalToLeading(in window: NSWindow) {
        guard let scroll = mainColumnHorizontalScroll(in: window) else { return }
        let clip = scroll.contentView
        var origin = clip.bounds.origin
        origin.x = 0
        clip.scroll(to: origin)
        scroll.reflectScrolledClipView(clip)
        window.display()
    }

    static func deepColumnApp() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID,
            name: "Deep",
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
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["A", "B", "C"]
        seedDeep(app: app, mediumID: mediumID)
        return app
    }

    static func shallowColumnApp() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        let medium = Medium(
            id: mediumID,
            name: "Shallow",
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
        app.columnBrowserState.pathStack = ["A"]
        app.indexRepository.seedScreenshotCache(
            mediumID: mediumID,
            entries: [([], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 1), rowID: 1, name: "A", kind: .folder, parentPath: [], modifiedAt: Date(), sizeBytes: 0, lastSeenAt: Date(), listedAt: Date()),
            ]), (["A"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 2), rowID: 2, name: "eins.txt", kind: .file, parentPath: ["A"], modifiedAt: Date(), sizeBytes: 1, lastSeenAt: Date(), listedAt: Date()),
            ])]
        )
        return app
    }

    static func seedDeep(app: AppState, mediumID: UUID) {
        let root: [( [String], [IndexedItem])] = [
            ([], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 1), rowID: 1, name: "A", kind: .folder, parentPath: [], modifiedAt: Date(), sizeBytes: 0, lastSeenAt: Date(), listedAt: Date()),
            ]),
            (["A"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 2), rowID: 2, name: "B", kind: .folder, parentPath: ["A"], modifiedAt: Date(), sizeBytes: 0, lastSeenAt: Date(), listedAt: Date()),
            ]),
            (["A", "B"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 3), rowID: 3, name: "C", kind: .folder, parentPath: ["A", "B"], modifiedAt: Date(), sizeBytes: 0, lastSeenAt: Date(), listedAt: Date()),
            ]),
            (["A", "B", "C"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 4), rowID: 4, name: "ziel.txt", kind: .file, parentPath: ["A", "B", "C"], modifiedAt: Date(), sizeBytes: 1, lastSeenAt: Date(), listedAt: Date()),
            ]),
        ]
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: root)
    }
}

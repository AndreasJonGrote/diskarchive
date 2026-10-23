//
//  ColumnScrollOrdersTests.swift
//  diskindexTests
//
//  bug.0.4.134/148: Scroll-Aufträge der Spaltenansicht kommen nur aus Nutzeraktionen. Tastenlogik im `AppState`;
//  Live-Änderungen (Nachführen der Auswahl, Neuaufbau der Tabelle) scrollen nicht.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnScrollOrdersTests {
    private func makeItems(_ count: Int, mediumID: UUID) -> [IndexedItem] {
        (0..<count).map { index in
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: String(format: "datei-%03d.txt", index),
                kind: .file,
                parentPath: [],
                modifiedAt: nil,
                sizeBytes: 1
            )
        }
    }

    private func medium(_ id: UUID) -> Medium {
        var medium = Medium(
            id: id, name: "M", type: .usb, connectionStatus: .connected, indexStatus: .indexed, allowIndexing: true,
            autoIndexPaused: false, decision: .index, capacityTotalBytes: 1_000, capacityUsedBytes: 10, fileCount: 100,
            folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(), isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 3
        return medium
    }

    @Test func downArrowFortyTimesMovesTheSelectionAndCountsEveryAction() throws {
        let app = AppState()
        let mediumID = UUID()
        let shown = medium(mediumID)
        app.media = [shown]
        let items = makeItems(100, mediumID: mediumID)
        var selection = ColumnSelection()
        selection.replace(id: try #require(items.first).id, column: 0)
        app.commitColumnSelection(selection, items: items, columnIndex: 0, medium: shown)
        let before = app.columnScrollToken
        for _ in 0..<40 {
            app.moveColumnSelection(step: 1, extend: false, items: items, visible: items, columnIndex: 0, medium: shown)
        }
        #expect(app.columnScrollToken == before + 40)
        #expect(app.columnBrowserState.selection.ids == [items[40].id])
    }

    @Test func followingTheSelectionAfterALiveChangeDoesNotCountAsAUserAction() throws {
        let app = AppState()
        let mediumID = UUID()
        let shown = medium(mediumID)
        app.media = [shown]
        let items = makeItems(10, mediumID: mediumID)
        var selection = ColumnSelection()
        selection.replace(id: try #require(items.first).id, column: 0)
        app.commitColumnSelection(selection, items: items, columnIndex: 0, medium: shown, userInitiated: false)
        #expect(app.columnScrollToken == 0)
        app.commitColumnSelection(selection, items: items, columnIndex: 0, medium: shown)
        #expect(app.columnScrollToken == 1)
    }

    private func clipOriginY(_ host: NSView) -> CGFloat? {
        func find(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            for sub in view.subviews { if let found = find(sub) { return found } }
            return nil
        }
        return find(host)?.contentView.bounds.origin.y
    }

    private func table(items: [IndexedItem], target: ColumnScrollTarget, box: ScrollTokenBox, app: AppState) -> some View {
        ColumnFolderTableView(items: items, selectedIDs: [], scrollTarget: target, scrollDone: box) { item in
            Text(item.name)
        }
        .environment(app)
        .frame(width: 280, height: 300)
    }

    @Test func rebuiltTableDoesNotScrollAgainForAnAlreadyDoneOrder() async throws {
        let app = AppState()
        let mediumID = UUID()
        let items = makeItems(200, mediumID: mediumID)
        let target = ColumnScrollTarget(id: items[150].id, token: 1)
        let box = ScrollTokenBox()
        let host = NSHostingView(rootView: AnyView(table(items: items, target: target, box: box, app: app)))
        let window = PixelProbe.offscreenWindow(hosting: host, size: CGSize(width: 280, height: 300))
        defer { window.orderOut(nil); window.close() }
        let scrolled = await waitUntil { (clipOriginY(host) ?? 0) > 100 }
        try #require(scrolled, "erste Tabelle scrollte nicht zur Auswahl")
        #expect(box.token == 1)
        // Neuaufbau (Ladezustand ersetzt die Tabelle): neue Tabelle, derselbe erledigte Auftrag.
        host.rootView = AnyView(Color.clear)
        try await Task.sleep(for: .milliseconds(100))
        host.rootView = AnyView(table(items: items, target: target, box: box, app: app))
        try await Task.sleep(for: .milliseconds(400))
        let origin = clipOriginY(host) ?? -1
        #expect(origin <= 1, "neue Tabelle sprang erneut zur Auswahl: \(origin)")
    }

    @Test func tokenZeroNeverScrollsTheTable() async throws {
        let app = AppState()
        let mediumID = UUID()
        let items = makeItems(200, mediumID: mediumID)
        let target = ColumnScrollTarget(id: items[150].id, token: 0)
        let host = NSHostingView(rootView: AnyView(table(items: items, target: target, box: ScrollTokenBox(), app: app)))
        let window = PixelProbe.offscreenWindow(hosting: host, size: CGSize(width: 280, height: 300))
        defer { window.orderOut(nil); window.close() }
        try await Task.sleep(for: .milliseconds(500))
        #expect((clipOriginY(host) ?? -1) <= 1)
    }
}
}

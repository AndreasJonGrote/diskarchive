//
//  ColumnFolderTableEnvironmentTests.swift
//  DiskArchiveTests
//
//  Aufgabe 107 — NSTableView-Zeilen mit AppState-Umgebung (kein Absturz).
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@Suite @MainActor struct ColumnFolderTableEnvironmentTests {
    @Test func tableRowsHostColumnBrowserRowWithAppState() async throws {
        let app = AppState()
        let mediumID = UUID()
        let items: [IndexedItem] = [
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: 1),
                rowID: 1,
                name: "Alpha",
                kind: .folder,
                parentPath: [],
                modifiedAt: nil,
                sizeBytes: nil),
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: 2),
                rowID: 2,
                name: "datei.txt",
                kind: .file,
                parentPath: [],
                modifiedAt: Date(),
                sizeBytes: 4),
        ]

        let firstID = try #require(items.first).id
        let root = ColumnFolderTableView(items: items, selectedIDs: [firstID]) { item in
            ColumnBrowserRow(
                title: item.name,
                isSelected: item.id == firstID,
                iconAsset: item.fileKind.assetName,
                fadeTitleOnOverflow: true,
                onSelect: {}
            )
        }
        .environment(app)
        .frame(width: 280, height: 400)

        let host = NSHostingView(rootView: root)
        let window = PixelProbe.offscreenWindow(hosting: host, size: CGSize(width: 280, height: 400))
        // Aufgabe 137: ohne manuelles reloadData – die Darstellung muss Zeilen liefern (auf die Bedingung warten).
        let shown = await waitUntil { (findTable(in: host)?.numberOfRows ?? 0) == 2 }
        try #require(shown)
        let table = try #require(findTable(in: host))
        #expect(table.numberOfRows == 2)
        #expect(table.allowsMultipleSelection == true)
        let cell = table.view(atColumn: 0, row: 0, makeIfNecessary: true)
        #expect(cell != nil)
        #expect(cell is NSHostingView<AnyView>)

        window.orderOut(nil)
    }

    private func findTable(in root: NSView) -> NSTableView? {
        if let scroll = root as? NSScrollView, let table = scroll.documentView as? NSTableView {
            return table
        }
        for child in root.subviews {
            if let found = findTable(in: child) { return found }
        }
        return nil
    }
}

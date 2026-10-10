//
//  ColumnFolderTableEnvironmentTests.swift
//  diskindexTests
//
//  Aufgabe 107 — NSTableView-Zeilen mit AppState-Umgebung (kein Absturz).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

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
                sizeBytes: nil,
                lastSeenAt: nil
            ),
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: 2),
                rowID: 2,
                name: "datei.txt",
                kind: .file,
                parentPath: [],
                modifiedAt: Date(),
                sizeBytes: 4,
                lastSeenAt: nil
            ),
        ]

        let root = ColumnFolderTableView(items: items, selectedIDs: [items[0].id]) { item in
            ColumnBrowserRow(
                title: item.name,
                isSelected: item.id == items[0].id,
                iconAsset: item.fileKind.assetName,
                fadeTitleOnOverflow: true,
                onSelect: {}
            )
        }
        .environment(app)
        .frame(width: 280, height: 400)

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 280, height: 400)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(400))

        // Aufgabe 137: ohne manuelles reloadData — Representable muss Zeilen liefern.
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

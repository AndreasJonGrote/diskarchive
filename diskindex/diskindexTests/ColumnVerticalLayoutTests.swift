//
//  ColumnVerticalLayoutTests.swift
//  diskindexTests
//
//  Aufgabe 150 — Spaltenkopf oben, nicht in der Mitte.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnVerticalLayoutTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func studioBackupColumnsStartAtTop(_ appearance: NSAppearance.Name) async {
        let app = AppState()
        let medium = studioBackup()
        app.media = [medium]
        let catalog = studioCatalog(mediumID: medium.id)
        app.indexRepository.seedScreenshotCache(mediumID: medium.id, entries: catalog.entries)
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.id
        app.columnBrowserState.pathStack = ["Rechnungen", "Rechnungen_2021"]
        var selection = ColumnSelection()
        selection.replace(id: catalog.rechnungen2021, column: 1)
        app.columnBrowserState.selection = selection

        let bitmap = await renderBrowser(app, appearance: appearance)
        assertColumnsSitAtTop(bitmap, columnCount: 3)
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func demoMediumColumnsStartAtTop(_ appearance: NSAppearance.Name) async {
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
        app.columnBrowserState.pathStack = [projects]
        if let first = children.first {
            var selection = ColumnSelection()
            selection.replace(id: first.id, column: 1)
            app.columnBrowserState.selection = selection
        }
        let bitmap = await renderBrowser(app, appearance: appearance)
        assertColumnsSitAtTop(bitmap, columnCount: 2)
    }

    @Test func fadeMaskTextStaysOneLineTall() async throws {
        let bitmap = await PixelProbe.render(
            FadeMaskText(text: "Spaltenkopf", applyFadeMask: true, font: .system(size: 10, weight: .semibold))
                .frame(width: 180, height: 300, alignment: .top)
                .background(DesignColor.bg),
            size: CGSize(width: 180, height: 300)
        )
        let ink = PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: 0, y: 0, width: 180, height: 300),
            background: CGPoint(x: 170, y: 280)
        )
        let box = try #require(ink)
        #expect(box.height <= 20)
        #expect(box.minY <= 8)
    }

    private func renderBrowser(_ app: AppState, appearance: NSAppearance.Name) async -> NSBitmapImageRep {
        let scheme: ColorScheme = appearance == .darkAqua ? .dark : .light
        return await PixelProbe.render(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, scheme)
                .frame(width: 1280, height: 800),
            size: CGSize(width: 1280, height: 800),
            appearance: appearance
        )
    }

    private func assertColumnsSitAtTop(_ bitmap: NSBitmapImageRep, columnCount: Int) {
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        let background = CGPoint(x: 1260, y: 12)
        for index in 0..<columnCount {
            let x = sidebar + CGFloat(index) * width + 8
            let header = PixelProbe.inkBounds(
                in: bitmap,
                rect: CGRect(x: x, y: 0, width: width - 24, height: 60),
                background: background
            )
            #expect(header != nil, "Kopf Spalte \(index)")
            if let header {
                #expect(header.minY <= 16, "Kopf-Oberkante \(header.minY) Spalte \(index)")
            }
            let row = PixelProbe.inkBounds(
                in: bitmap,
                rect: CGRect(x: x, y: 30, width: width - 24, height: 50),
                background: background
            )
            #expect(row != nil, "erste Zeile Spalte \(index)")
        }
    }

    private func studioBackup() -> Medium {
        var medium = Medium(
            id: UUID(),
            name: "Studio Backup",
            type: .hdd,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 2_000_000_000_000,
            capacityUsedBytes: 700_000_000_000,
            fileCount: 238_421,
            folderCount: 11_921,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 0.92
        )
        medium.completedDepth = 4
        return medium
    }

    private func studioCatalog(mediumID: UUID) -> (entries: [([String], [IndexedItem])], rechnungen2021: UUID) {
        func item(_ rowID: Int64, _ name: String, _ kind: IndexedItem.Kind, _ parent: [String]) -> IndexedItem {
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: rowID),
                rowID: rowID,
                name: name,
                kind: kind,
                parentPath: parent,
                modifiedAt: Date(),
                sizeBytes: kind == .file ? 80_000 : nil,
                lastSeenAt: Date(),
                listedAt: Date()
            )
        }
        let rechnungen = item(1, "Rechnungen", .folder, [])
        let projekte = item(2, "Projekte", .folder, [])
        let readme = item(3, "readme.txt", .file, [])
        let inv2021 = item(4, "Rechnungen_2021", .folder, ["Rechnungen"])
        let inv2022 = item(5, "Rechnungen_2022.pdf", .file, ["Rechnungen"])
        let q1 = item(6, "rechnung_q1.pdf", .file, ["Rechnungen", "Rechnungen_2021"])
        let q2 = item(7, "rechnung_q2.pdf", .file, ["Rechnungen", "Rechnungen_2021"])
        return (
            [
                ([], [rechnungen, projekte, readme]),
                (["Rechnungen"], [inv2021, inv2022]),
                (["Rechnungen", "Rechnungen_2021"], [q1, q2]),
            ],
            inv2021.id
        )
    }
}
}

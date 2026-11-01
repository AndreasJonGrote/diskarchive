//
//  ColumnBrowserNormalizeTests.swift
//  DiskArchiveTests
//
//  bug.0.4.135 (Regel 15): Auswahl und Pfad der Spaltenansicht werden im `AppState` normalisiert, nicht in `onAppear`;
//  ein vergessenes Medium nimmt Pfad und Auswahl nicht ins nächste mit.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite @MainActor
struct ColumnBrowserNormalizeTests {
    private func medium(_ name: String, depth: Int = 3) -> Medium {
        var medium = previewMedium(0)
        medium = Medium(
            id: UUID(), name: name, type: .usb, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, decision: .index, capacityTotalBytes: 1_000,
            capacityUsedBytes: 10, fileCount: 5, folderCount: 2, lastSeenAt: Date(), firstIndexedAt: Date(),
            lastIndexedAt: Date(), isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = depth
        return medium
    }

    @Test func forgettingTheOpenMediumResetsPathAndSelection() {
        let app = AppState()
        let first = medium("A")
        let second = medium("B")
        app.media = [first, second]
        app.columnBrowserState.selectedMediumID = first.id
        app.columnBrowserState.pathStack = ["X", "Y"]
        app.columnBrowserState.selection.replace(id: UUID(), column: 1)
        app.columnBrowserState.selectedUncapturedFolderID = UUID()
        app.forgetMedium(id: first.id)
        #expect(app.columnBrowserState.selectedMediumID == nil)
        #expect(app.columnBrowserState.pathStack.isEmpty, "alter Pfad im nächsten Medium")
        #expect(app.columnBrowserState.selection.ids.isEmpty)
        #expect(app.columnBrowserState.selectedUncapturedFolderID == nil)
    }

    @Test func openingTheColumnViewPicksAMediumWithoutTheViewAppearing() {
        let app = AppState()
        let only = medium("A")
        app.media = [only]
        #expect(app.columnBrowserState.selectedMediumID == nil)
        app.mainWindowDestination = .columnBrowser
        #expect(app.columnBrowserState.selectedMediumID == only.id)
    }

    @Test func pathBeyondTheScanDepthIsClampedOnOpening() {
        let app = AppState()
        let only = medium("A", depth: 2)
        app.media = [only]
        app.columnBrowserState.selectedMediumID = only.id
        app.columnBrowserState.pathStack = ["a", "b", "c", "d"]
        app.mainWindowDestination = .columnBrowser
        #expect(app.columnBrowserState.pathStack == ["a", "b"])
    }
}

/// bug.0.4.147: Der offene Pfad folgt einem Umbenennen auch ohne alten Spaltenstand und bei tieferer Auswahl.
@Suite @MainActor
struct OpenPathFollowTests {
    private func folder(_ name: String, rowID: Int64, mediumID: UUID) -> IndexedItem {
        IndexedItem(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: rowID), rowID: rowID, name: name, kind: .folder,
            parentPath: [], modifiedAt: nil, sizeBytes: nil
        )
    }

    private func app(with mediumID: UUID) -> AppState {
        let app = AppState()
        var medium = Medium(
            id: mediumID, name: "M", type: .usb, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, decision: .index, capacityTotalBytes: 1_000,
            capacityUsedBytes: 10, fileCount: 5, folderCount: 2, lastSeenAt: Date(), firstIndexedAt: Date(),
            lastIndexedAt: Date(), isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = 4
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        return app
    }

    @Test func renameIsFollowedWithoutCacheAndWithDeeperSelection() throws {
        let mediumID = UUID()
        let app = app(with: mediumID)
        let original = folder("Alt", rowID: 7, mediumID: mediumID)
        let inner = folder("Innen", rowID: 8, mediumID: mediumID)
        // Nutzer öffnet Alt (Spalte 0), dann Innen (Spalte 1): die Auswahl liegt in Spalte 1.
        var first = ColumnSelection()
        first.replace(id: original.id, column: 0)
        app.commitColumnSelection(first, items: [original], columnIndex: 0, medium: try #require(app.media.first))
        var second = ColumnSelection()
        second.replace(id: inner.id, column: 1)
        app.commitColumnSelection(second, items: [inner], columnIndex: 1, medium: try #require(app.media.first))
        #expect(app.columnBrowserState.pathStack == ["Alt", "Innen"])
        #expect(app.columnBrowserState.openFolderRowIDs == [7, 8])
        // Die Wurzelspalte wird ohne alten Stand neu gelesen; „Alt“ heißt jetzt „Neu“ (gleiche Zeile).
        let renamed = folder("Neu", rowID: 7, mediumID: mediumID)
        app.followOpenPathAfterReload(mediumID: mediumID, path: [], previous: nil, items: [renamed])
        #expect(app.columnBrowserState.pathStack == ["Neu", "Innen"], "Pfad gekürzt statt gefolgt: \(app.columnBrowserState.pathStack)")
    }

    @Test func deletionStillCutsThePath() throws {
        let mediumID = UUID()
        let app = app(with: mediumID)
        let original = folder("Alt", rowID: 7, mediumID: mediumID)
        var first = ColumnSelection()
        first.replace(id: original.id, column: 0)
        app.commitColumnSelection(first, items: [original], columnIndex: 0, medium: try #require(app.media.first))
        app.followOpenPathAfterReload(mediumID: mediumID, path: [], previous: nil, items: [folder("Anderer", rowID: 99, mediumID: mediumID)])
        #expect(app.columnBrowserState.pathStack.isEmpty)
    }
}

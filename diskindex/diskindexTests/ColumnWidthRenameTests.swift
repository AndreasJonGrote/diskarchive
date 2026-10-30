//
//  ColumnWidthRenameTests.swift
//  diskindexTests
//
//  bug.0.4.234: Eine gezogene Spaltenbreite bleibt, wenn ein offener Ordner davor von außen umbenannt wird (gleiche
//  Zeilenkennung); ein echter Wechsel in einen anderen Ordner verwirft sie wie bisher (bug.0.4.218).
//

import Foundation
import Testing
@testable import diskindex

@Suite
struct ColumnWidthRenameTests {
    private func openState() -> ColumnBrowserState {
        var state = ColumnBrowserState()
        state.pathStack = ["A", "B", "C"]
        state.openFolderRowIDs = [11, 22, 33]
        state.setFolderColumnWidth(380, at: 2)
        return state
    }

    @Test func renamedFolderKeepsTheWidthBehindIt() {
        var state = openState()
        state.renameOpenFolder(at: 1, to: "B neu", rowID: 22)
        #expect(state.pathStack == ["A", "B neu", "C"])
        #expect(state.folderColumnWidth(at: 2) == 380, "Breite nach Umbenennen weg")
    }

    @Test func otherFolderDropsTheWidth() {
        var state = openState()
        state.renameOpenFolder(at: 1, to: "X", rowID: 99)
        #expect(state.folderColumnWidth(at: 2) == DesignSpacing.columnBrowserColumnWidth, "Breite trotz anderer Zeile behalten")

        var opened = openState()
        opened.pathStack = ["A", "X"]
        #expect(opened.folderColumnWidth(at: 2) == DesignSpacing.columnBrowserColumnWidth, "Breite nach Ordnerwechsel behalten")
    }
}

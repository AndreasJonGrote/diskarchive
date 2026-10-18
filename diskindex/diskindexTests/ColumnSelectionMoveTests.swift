//
//  ColumnSelectionMoveTests.swift
//  diskindexTests
//
//  bug.0.4.050 (REPORT 84): Pfeiltasten in einer anderen Spalte als der Auswahl.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct ColumnSelectionMoveTests {
    @Test func arrowInOtherColumnStartsSelectionThere() throws {
        let folderInColumn0 = UUID()
        let column1 = [UUID(), UUID(), UUID()]
        var selection = ColumnSelection()
        selection.replace(id: folderInColumn0, column: 0)

        selection.move(step: 1, extend: false, visible: column1, column: 1)

        let first = try #require(column1.first)
        #expect(selection.focusColumnIndex == 1)
        #expect(selection.ids == [first])
        #expect(selection.anchorID == first)
        #expect(selection.lastClickedID == first)
    }

    @Test func shiftArrowInOtherColumnDoesNotExtendAcrossColumns() throws {
        let column0 = [UUID(), UUID()]
        let column1 = [UUID(), UUID(), UUID()]
        var selection = ColumnSelection()
        let start = try #require(column0.first)
        selection.replace(id: start, column: 0)

        selection.move(step: -1, extend: true, visible: column1, column: 1)

        let last = try #require(column1.last)
        #expect(selection.focusColumnIndex == 1)
        #expect(selection.ids == [last])
    }

    @Test func arrowInSameColumnStillMovesFromLastClicked() throws {
        let column1 = [UUID(), UUID(), UUID()]
        try #require(column1.count == 3)
        var selection = ColumnSelection()
        selection.replace(id: column1[1], column: 1)

        selection.move(step: 1, extend: false, visible: column1, column: 1)
        #expect(selection.ids == [column1[2]])
        #expect(selection.focusColumnIndex == 1)

        selection.move(step: -1, extend: true, visible: column1, column: 1)
        #expect(selection.ids == [column1[1], column1[2]])
        #expect(selection.anchorID == column1[2])
    }

    @Test func arrowWithoutSelectionDoesNothing() {
        var selection = ColumnSelection()
        selection.move(step: 1, extend: false, visible: [UUID()], column: 1)
        #expect(selection.ids.isEmpty)
        #expect(selection.focusColumnIndex == nil)
    }
}


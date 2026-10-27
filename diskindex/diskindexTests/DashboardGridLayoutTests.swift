//
//  DashboardGridLayoutTests.swift
//  diskindexTests
//

import CoreGraphics
import Testing
@testable import diskindex

@Suite struct DashboardGridLayoutTests {
    @Test func cardWidthNeverExceedsMax() {
        for width in [900.0, 1_400.0] {
            let content = width - DashboardGridLayout.spacing * 2
            let columns = DashboardGridLayout.columnCount(containerWidth: content)
            let cell = DashboardGridLayout.cellWidth(containerWidth: content, columns: columns)
            #expect(cell <= DashboardGridLayout.maxCardWidth)
            #expect(cell >= DashboardGridLayout.minCardWidth)
        }
    }

    @Test func singleCardUsesColumnWidthNotFullWindow() {
        let content = 1_770.0 - DashboardGridLayout.spacing * 2
        let columns = DashboardGridLayout.columnCount(containerWidth: content)
        #expect(columns >= 6)
        let cell = DashboardGridLayout.cellWidth(containerWidth: content, columns: columns)
        #expect(cell <= 255)
        #expect(cell < content)
    }

    @Test func columnCountsForFixtureWidths() {
        #expect(DashboardGridLayout.columnCount(containerWidth: 868) == 3)  // bug.0.4.211: Mindestbreite 220
        #expect(DashboardGridLayout.columnCount(containerWidth: 1368) == 5)
    }
}

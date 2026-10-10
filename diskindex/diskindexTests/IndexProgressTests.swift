//
//  IndexProgressTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

struct IndexProgressTests {
    @Test func chipAndPopoverUseSamePercentFromMedium() {
        var medium = Medium(
            id: UUID(),
            name: "T",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 500,
            fileCount: 4_500,
            folderCount: 500,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0
        )
        medium.scanTotal = 10_000
        medium.indexingProgress = 0.456
        let percent = medium.indexProgressPercent
        #expect(percent == 45)
    }

    @Test func groupedIntegerKeepsThousandsSeparator() {
        #expect(DisplayNumberFormat.groupedInteger(1_234) == "1.234")
    }

    @Test func progressPercentNeverExceeds99UntilIndexed() {
        var medium = Medium(
            id: UUID(),
            name: "T",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 500,
            fileCount: 999,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0.999
        )
        medium.scanTotal = 1_000
        #expect(medium.indexProgressPercent == 99)
        medium.indexStatus = .indexed
        medium.indexingProgress = 1
        #expect(medium.indexProgressPercent == 100)
    }

    @Test func allSurfacesUseIndexProgressPercent() {
        var medium = Medium(
            id: UUID(),
            name: "T",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 500,
            fileCount: 450,
            folderCount: 50,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0.45
        )
        medium.scanTotal = 1_000
        let percent = medium.indexProgressPercent
        let chip = MediumChip.presentation(medium).text
        #expect(chip == "\(percent) % indiziert")
    }
}

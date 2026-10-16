//
//  LiveRenamePairsTests.swift
//  diskindexTests
//
//  bug.0.4.022 — LiveRenamePairs ohne fileExists bei ≠2 Pfaden.
//

import Foundation
import Testing
@testable import diskindex

@Suite struct LiveRenamePairsTests {
    @Test func manyEventsWithMoreThanTwoPathsNeverCallsFileExists() {
        var fileExistsCalls = 0
        let events = (0..<10_000).map { index in
            ItemPathEvent(
                path: "/Volumes/DISK/p\(index).txt",
                itemCreated: index.isMultiple(of: 2),
                itemRemoved: !index.isMultiple(of: 2),
                itemRenamed: false
            )
        }
        let pairs = LiveRenamePairs.pair(events: events) { _ in
            fileExistsCalls += 1
            return false
        }
        #expect(pairs.isEmpty)
        #expect(fileExistsCalls == 0)
    }
}

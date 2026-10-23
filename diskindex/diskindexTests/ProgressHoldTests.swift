//
//  ProgressHoldTests.swift
//  diskindexTests
//
//  Aufgabe 161/169: ein kurzer Lauf läuft 0,6 s bis 100 % und bleibt dort 0,3 s.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct ProgressHoldTests {
    @Test func shortRunReachesHundredAndHolds() async {
        let app = AppState()
        let id = testUUID("D1610001-0000-4000-8000-000000000161")
        let start = Date(timeIntervalSince1970: 80_000)
        app.media = [medium(id: id, indexing: true)]
        app.noteIndexSample(id: id, status: .indexing, fraction: 1, now: start)
        if let index = app.media.firstIndex(where: { $0.id == id }) { app.media[index].indexStatus = .indexed }
        app.noteIndexSample(id: id, status: .indexed, fraction: 1, now: start.addingTimeInterval(0.1))

        #expect(near(app.displayedProgress(id, now: start.addingTimeInterval(0.3)), 0.50))
        for offset in [0.6, 0.75, 0.89] {
            let value = app.displayedProgress(id, now: start.addingTimeInterval(offset))
            #expect(value == 1, "bei \(offset) s")
            let chip = MediumChip.presentation(firstMedium(of: app), displayedFraction: value)
            #expect(chip.text.contains("100"), "Chip bei \(offset) s: \(chip.text)")
            let row = MenuBarConnectedMediumRow(medium: firstMedium(of: app))
            #expect(row.indexingProgressLabel(fraction: value ?? 0) == "100 %")
        }
        #expect(app.displayedProgress(id, now: start.addingTimeInterval(0.95)) == nil)

        let full = app.displayedProgress(id, now: start.addingTimeInterval(0.7)) ?? 0
        let bitmap = await PixelProbe.render(
            IndexingProgressBar(progress: full).frame(width: 100).padding(10),
            size: CGSize(width: 120, height: 24)
        )
        let fill = PixelProbe.color(in: bitmap, at: CGPoint(x: 15, y: 12))
        let end = PixelProbe.color(in: bitmap, at: CGPoint(x: 108, y: 12))
        #expect(close(fill, end), "Balken am rechten Ende nicht gefüllt")
    }

    @Test func displayIsPure() {
        let app = AppState()
        let id = testUUID("D1610003-0000-4000-8000-000000000161")
        let start = Date(timeIntervalSince1970: 85_000)
        app.media = [medium(id: id, indexing: true)]
        app.noteIndexSample(id: id, status: .indexing, fraction: 0.5, now: start)
        let at = start.addingTimeInterval(0.4)
        #expect(app.displayedProgress(id, now: at) == app.displayedProgress(id, now: at))
        _ = app.displayedProgress(id, now: start.addingTimeInterval(2))
        #expect(app.displayedProgress(id, now: at) == app.displayedProgress(id, now: at))
    }

    @Test func slowerRealProgressWins() {
        let app = AppState()
        let id = testUUID("D1610002-0000-4000-8000-000000000161")
        let start = Date(timeIntervalSince1970: 90_000)
        app.media = [medium(id: id, indexing: true)]
        app.noteIndexSample(id: id, status: .indexing, fraction: 0.2, now: start)
        let shown = app.displayedProgress(id, now: start.addingTimeInterval(1))
        #expect(near(shown, 0.2))
    }

    private func near(_ shown: Double?, _ target: Double) -> Bool {
        guard let shown else { return false }
        return abs(shown - target) <= 0.05
    }

    private func close(_ a: NSColor, _ b: NSColor) -> Bool {
        abs(a.redComponent - b.redComponent) < 0.05
            && abs(a.greenComponent - b.greenComponent) < 0.05
            && abs(a.blueComponent - b.blueComponent) < 0.05
    }

    private func medium(id: UUID, indexing: Bool) -> Medium {
        var medium = Medium(
            id: id,
            name: "Halt",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: indexing ? .indexing : .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 4,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 0.2
        )
        medium.completedDepth = 1
        return medium
    }
}
}

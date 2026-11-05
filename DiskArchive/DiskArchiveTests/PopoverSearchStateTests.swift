//
//  PopoverSearchStateTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.014 (Layout 03): Popover-Suche zeigt erst Warten (nach der Verzögerung den Hinweis mit Spinner), dann das
//  Ergebnis oder „Keine Suchergebnisse“ – nie sofort „Keine Treffer“. Zeile ohne Umschalter, Chip nur während eines
//  Laufs; Leerfläche 03.09/03.10 statt der Liste.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct PopoverSearchStateTests {
    @Test func searchWaitsThenShowsTheHint() async {
        let app = AppState()
        // Korrektur K4: die Suche läuft sicher länger als jede Frist (Debounce 60 s), der Hinweis hat 20 s Zeit, auch
        // wenn der Main-Actor im Parallellauf lange belegt ist. Das Ergebnis prüft der nächste Test.
        app.popoverSearchDebounce = .seconds(60)
        app.popoverSearchHintTiming = DelayedLoadingTiming(delayBeforeHint: .milliseconds(20), minimumHintVisible: .zero)
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        #expect(app.popoverSearchPhase == .pending, "nicht sofort „Keine Treffer“")
        let hint = await waitUntil(timeout: 20) { app.popoverSearchPhase == .hint }
        #expect(hint, "kein Hinweis „Suche läuft“ (Phase \(app.popoverSearchPhase))")
        #expect(app.popoverResults.groups.isEmpty, "Ergebnis vor dem Hinweis")
        app.cancelPopoverSearch()
    }

    @Test func resultArrivesOnlyAfterTheSearchThenSettled() async {
        let app = AppState()
        app.popoverSearchDebounce = .milliseconds(20)
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        #expect(app.popoverSearchPhase == .pending, "nicht sofort „Keine Treffer“")
        await app.waitForPopoverSearch()
        #expect(app.popoverSearchPhase == .settled)
        #expect(app.popoverResults.totalCount == 0 && app.popoverResults.groups.isEmpty)
    }

    @Test func emptyFieldIsIdle() {
        let app = AppState()
        app.popoverSearchText = "  "
        app.schedulePopoverSearch()
        #expect(app.popoverSearchPhase == .idle)
    }

    @Test func rowHasNoToggleAndTheChipOnlyDuringARun() {
        var medium = Medium(
            id: UUID(), name: "Unterwegs", type: .ssd, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 4_000, capacityUsedBytes: 0,
            fileCount: 10, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = 2
        medium.showAbsoluteCapacity = true
        let row = MenuBarConnectedMediumRow(medium: medium)
        #expect(row.indexingProgressLabel(fraction: 0.42) == "42 %", "Umschalter auf Bytes noch da")
        #expect(medium.popoverStatusLine(paused: false, hasProgress: false) == .lastIndexed(medium.lastIndexedValue))
        medium.indexStatus = .indexing
        #expect(medium.popoverStatusLine(paused: false, hasProgress: true) == .progress)
    }

    @Test func popoverListsUndecidedMediaAndHidesRefusedOnes() {
        let app = AppState()
        func medium(_ decision: StoredIndexDecision) -> Medium {
            var medium = Medium(
                id: UUID(), name: "\(decision)", type: .usb, connectionStatus: .connected, indexStatus: .pending,
                allowIndexing: decision == .index, autoIndexPaused: false, capacityTotalBytes: 1, capacityUsedBytes: 0,
                fileCount: 0, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: nil, lastIndexedAt: nil,
                isForgotten: false, indexingProgress: 0
            )
            medium.decision = decision
            return medium
        }
        app.media = [medium(.index), medium(.undecided), medium(.dontIndex)]
        #expect(app.popoverConnectedMedia.map(\.decision) == [.index, .undecided])
    }
}

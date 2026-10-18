//
//  CountingPauseTests.swift
//  diskindexTests
//
//  bug.0.4.054 (REPORT 95): Pause in der Zählphase speichert keine Teilsumme als `scanTotal`;
//  der Merker „Zählung unvollständig“ sorgt beim Fortsetzen für eine neue Zählung.
//

import Foundation
import Testing
@testable import diskindex

private final class CountingPauseProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var pauseRequested = false
    private var values: [IndexProgress] = []

    func note(_ progress: IndexProgress) {
        lock.lock()
        defer { lock.unlock() }
        values.append(progress)
    }

    func requestPause() {
        lock.lock()
        defer { lock.unlock() }
        pauseRequested = true
    }

    var halt: ScanHalt {
        lock.lock()
        defer { lock.unlock() }
        return pauseRequested ? .pause : .none
    }

    var events: [IndexProgress] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

@Suite(.serialized) struct CountingPauseTests {
    private func volume() -> MemoryVolume {
        let access = MemoryVolume(mountPath: "/Volumes/T")
        for index in 0..<30 { access.file("d\(index)/e/f.txt") }
        return access
    }

    @Test func pauseDuringCountingStoresNoPartialTotalAndResumeRecounts() async throws {
        let harness = try await ScanHarness.make()
        let access = volume()
        let probe = CountingPauseProbe()

        // Lauf 1: Vorlauf (Ebene 1 und 2), dann Pause beim ersten Zählereignis mit Zahl.
        let first = try await harness.run(
            access: access,
            maxDepth: nil,
            shouldHalt: { probe.halt },
            onProgress: { progress in
                if progress.phase == .counting, progress.countingCount > 0 { probe.requestPause() }
            }
        )
        #expect(first.status == .pending)
        let paused = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(paused.completedDepth == 2)
        #expect(paused.scanTotal == 0, "Teilsumme \(paused.scanTotal) gespeichert")
        #expect(try await harness.store.scanTotalIsIncomplete(mediumUUID: harness.mediumID))

        // Lauf 2: Fortsetzen zählt neu, Fortschritt beginnt nicht bei 99 %.
        let resumed = CountingPauseProbe()
        let second = try await harness.run(
            access: access,
            maxDepth: nil,
            fromScratch: false,
            onProgress: { resumed.note($0) }
        )
        #expect(second.status == .indexed)
        let events = resumed.events
        #expect(events.contains { $0.phase == .counting && $0.countingCount > 0 })
        let firstIndexing = try #require(events.first { $0.phase == .indexing })
        #expect(firstIndexing.ratio < 0.9, "erste Anzeige nach dem Fortsetzen \(firstIndexing.ratio)")
        #expect(firstIndexing.entriesTotal == 90)
        let done = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(done.scanTotal == 90)
        #expect(done.scanTotal == done.fileCount + done.folderCount)
        #expect(try await harness.store.scanTotalIsIncomplete(mediumUUID: harness.mediumID) == false)
    }

    /// Neu-Indizierung eines schon gezählten Mediums: die Pause in der Zählung lässt die alte Gesamtzahl stehen,
    /// der Merker erzwingt beim Fortsetzen trotzdem eine neue Zählung.
    @Test func resumeRecountsEvenWhenAnOlderTotalIsStored() async throws {
        let harness = try await ScanHarness.make()
        let access = volume()
        let full = try await harness.run(access: access, maxDepth: nil)
        #expect(full.status == .indexed)
        #expect(try await harness.store.medium(uuid: harness.mediumID)?.scanTotal == 90)
        for index in 30..<60 { access.file("d\(index)/e/f.txt") }

        let probe = CountingPauseProbe()
        let paused = try await harness.run(
            access: access,
            maxDepth: nil,
            fromScratch: true,
            shouldHalt: { probe.halt },
            onProgress: { progress in
                if progress.phase == .counting, progress.countingCount > 0 { probe.requestPause() }
            }
        )
        #expect(paused.status == .pending)
        #expect(try await harness.store.medium(uuid: harness.mediumID)?.scanTotal == 90)
        #expect(try await harness.store.scanTotalIsIncomplete(mediumUUID: harness.mediumID))

        let resumed = CountingPauseProbe()
        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false, onProgress: { resumed.note($0) })
        #expect(second.status == .indexed)
        let firstIndexing = try #require(resumed.events.first { $0.phase == .indexing })
        #expect(firstIndexing.entriesTotal == 180)
        #expect(firstIndexing.ratio < 0.9, "erste Anzeige nach dem Fortsetzen \(firstIndexing.ratio)")
        #expect(try await harness.store.medium(uuid: harness.mediumID)?.scanTotal == 180)
    }

    /// Pause im Vorlauf (nach Ebene 1, vor der Zählung): noch keine Gesamtzahl, also beim Fortsetzen zählen
    /// statt `scanTotal = entriesCompleted` (sofort 99 %).
    @Test func pauseInThePreludeRecountsOnResume() async throws {
        let harness = try await ScanHarness.make()
        let access = volume()
        let store = harness.store
        let mediumID = harness.mediumID
        let first = try await harness.run(access: access, maxDepth: nil, shouldHalt: {
            let depth = (try? await store.medium(uuid: mediumID))?.completedDepth ?? 0
            return depth >= 1 ? .pause : .none
        })
        #expect(first.status == .pending)
        let paused = try #require(try await store.medium(uuid: mediumID))
        #expect(paused.completedDepth == 1)
        #expect(paused.scanTotal == 0)

        let resumed = CountingPauseProbe()
        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false, onProgress: { resumed.note($0) })
        #expect(second.status == .indexed)
        let events = resumed.events
        #expect(events.contains { $0.phase == .counting && $0.countingCount > 0 })
        let firstIndexing = try #require(events.first { $0.phase == .indexing })
        #expect(firstIndexing.entriesTotal == 90)
        #expect(firstIndexing.ratio < 0.9, "erste Anzeige nach dem Fortsetzen \(firstIndexing.ratio)")
        #expect(try await store.medium(uuid: mediumID)?.scanTotal == 90)
    }

    /// bug.0.4.066: Halt nach Ebene 2, aber vor Zählbeginn. Der Merker steht seit Beginn des Vorlaufs,
    /// also zählt das Fortsetzen neu statt `scanTotal = entriesCompleted` (sofort 99 %).
    @Test func haltAfterDepthTwoBeforeCountingRecountsOnResume() async throws {
        let harness = try await ScanHarness.make()
        let access = volume()
        let store = harness.store
        let mediumID = harness.mediumID
        let first = try await harness.run(access: access, maxDepth: nil, shouldHalt: {
            let depth = (try? await store.medium(uuid: mediumID))?.completedDepth ?? 0
            return depth >= 2 ? .pause : .none
        })
        #expect(first.status == .pending)
        let paused = try #require(try await store.medium(uuid: mediumID))
        #expect(paused.completedDepth == 2)
        #expect(paused.scanTotal == 0)
        #expect(try await store.scanTotalIsIncomplete(mediumUUID: mediumID))

        let resumed = CountingPauseProbe()
        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false, onProgress: { resumed.note($0) })
        #expect(second.status == .indexed)
        let events = resumed.events
        #expect(events.contains { $0.phase == .counting && $0.countingCount > 0 })
        let firstIndexing = try #require(events.first { $0.phase == .indexing })
        #expect(firstIndexing.entriesTotal == 90)
        #expect(firstIndexing.ratio < 0.9, "erste Anzeige nach dem Fortsetzen \(firstIndexing.ratio)")
        #expect(try await store.medium(uuid: mediumID)?.scanTotal == 90)
        #expect(try await store.scanTotalIsIncomplete(mediumUUID: mediumID) == false)
    }

    /// Voller Abgleich eines indizierten Mediums: die Nachzählung im Hintergrund setzt keinen Merker
    /// (die alte Gesamtzahl bleibt gültig), auch wenn der Lauf sofort angehalten wird.
    @Test func backgroundRecountOfAFullReconcileSetsNoFlag() async throws {
        let harness = try await ScanHarness.make()
        let access = volume()
        let full = try await harness.run(access: access, maxDepth: nil)
        #expect(full.status == .indexed)

        let reconcile = try await harness.run(access: access, maxDepth: nil, fromScratch: false, shouldHalt: { .pause })
        #expect(reconcile.status == .indexed)
        // Die abgebrochene Nachzählung läuft noch kurz weiter: bis zu 1 s auf einen (falschen) Merker warten.
        var flagged = false
        let deadline = ContinuousClock.now + .seconds(1)
        while ContinuousClock.now < deadline {
            if try await harness.store.scanTotalIsIncomplete(mediumUUID: harness.mediumID) { flagged = true; break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(flagged == false)
        #expect(try await harness.store.medium(uuid: harness.mediumID)?.scanTotal == 90)
    }

    @Test func completeCountClearsTheIncompleteFlag() async throws {
        let harness = try await ScanHarness.make()
        try await harness.store.markScanTotalIncomplete(mediumUUID: harness.mediumID)
        #expect(try await harness.store.scanTotalIsIncomplete(mediumUUID: harness.mediumID))
        try await harness.store.setScanTotal(mediumUUID: harness.mediumID, total: 12)
        #expect(try await harness.store.scanTotalIsIncomplete(mediumUUID: harness.mediumID) == false)
        #expect(try await harness.store.medium(uuid: harness.mediumID)?.scanTotal == 12)
    }
}

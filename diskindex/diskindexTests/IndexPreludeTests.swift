//
//  IndexPreludeTests.swift
//  diskindexTests
//
//  Aufgabe 206 — Vorlauf: Ebene 1 und 2 sind gespeichert, bevor die Zählphase beginnt.
//

import Foundation
import Testing
@testable import diskindex

private final class PreludeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var firstCounting: (names: Set<String>, storedTotal: Int)?
    private var values: [(phase: IndexRunPhase, ratio: Double)] = []

    func note(_ progress: IndexProgress) {
        lock.lock()
        defer { lock.unlock() }
        values.append((progress.phase, progress.ratio))
    }

    func setFirstCounting(names: Set<String>, storedTotal: Int) {
        lock.lock()
        defer { lock.unlock() }
        if firstCounting == nil { firstCounting = (names, storedTotal) }
    }

    var first: (names: Set<String>, storedTotal: Int)? {
        lock.lock()
        defer { lock.unlock() }
        return firstCounting
    }

    var events: [(phase: IndexRunPhase, ratio: Double)] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

@Suite struct IndexPreludeTests {
    @Test func levelsOneAndTwoAreStoredBeforeCountingStarts() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/a1/x1/deep1.txt")
        access.file("a/a2/x2/deep2.txt")
        access.file("a/top.txt")
        access.file("b/b1/y1/deep3.txt")
        access.file("b/b1/y1/y2/deepest.txt")
        access.file("c.txt")
        access.slowListing(fromDepth: 2)
        let recorder = PreludeRecorder()
        let store = harness.store
        let mediumID = harness.mediumID

        let outcome = try await harness.run(access: access, maxDepth: nil, onProgress: { progress in
            recorder.note(progress)
            if progress.phase == .counting {
                let names = (try? await harness.names()) ?? []
                let total = (try? await store.medium(uuid: mediumID))?.scanTotal ?? -1
                recorder.setFirstCounting(names: names, storedTotal: total)
            }
        })
        #expect(outcome.status == .indexed)

        // Beim ersten Zählereignis: Ebene 1 und 2 gespeichert, Zählung noch nicht fertig, tiefere Ebenen noch nicht.
        let first = try #require(recorder.first)
        #expect(first.names.isSuperset(of: ["a", "b", "c.txt", "a1", "a2", "top.txt", "b1"]))
        #expect(!first.names.contains("deep1.txt"))
        #expect(!first.names.contains("deepest.txt"))
        #expect(first.storedTotal == 0)

        // Am Ende: alles da, Gesamtzahl = Anzahl der Einträge.
        let names = try await harness.names()
        #expect(names.contains("deepest.txt"))
        let stored = try #require(try await store.medium(uuid: mediumID))
        #expect(stored.scanTotal == stored.fileCount + stored.folderCount)
        #expect(stored.scanTotal == 15)

        // Keine Prozentzahl > 0 vor Ende der Zählung; danach nie fallend.
        let events = recorder.events
        let countingIndex = try #require(events.firstIndex { $0.phase == .counting })
        #expect(events[..<countingIndex].allSatisfy { $0.ratio == 0 })
        #expect(events[countingIndex...].filter { $0.phase == .counting }.allSatisfy { $0.ratio == 0 })
        let ratios = events.map(\.ratio)
        #expect(zip(ratios, ratios.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(outcome.progress.last == 1)
    }
}

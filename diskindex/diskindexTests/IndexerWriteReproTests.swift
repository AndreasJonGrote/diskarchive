//
//  IndexerWriteReproTests.swift
//  diskindexTests
//
//  bug.0.4.020 — Schreib-/Lesefehler, Stall-Wächter, Pause im ersten Chunk.
//

import Foundation
import Testing
@testable import diskindex

@Suite struct IndexerWriteReproTests {
    @Test func chunkWriteFailureEndsQuicklyWithError() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b.txt")
        await harness.store.setDirectoryWritesFailing(true)
        var limits = IndexingRunLimits.standard
        // bug.0.3.9.004 a: Ein Schreibfehler endet ohne Lese-Wiederholung. Grenze aus der Wiederholungspause (jede
        // Wiederholung kostet mindestens 60 s) statt der Last (vorher < 2 s bei 5 s Pause).
        let retryPause: Duration = .seconds(60)
        limits.readRetryDelays = [retryPause, retryPause]
        let started = ContinuousClock.now
        let outcome = try await harness.run(access: access, maxDepth: nil, limits: limits)
        let elapsed = started.duration(to: .now)
        #expect(outcome.status == .error)
        #expect(outcome.failureReason == .database)
        #expect(elapsed < retryPause / 2)
    }

    @Test func pauseDuringFirstChunkAvoidsReadRetries() async throws {
        let harness = try await ScanHarness.make()
        let access = PauseAfterFirstListVolume(mountPath: "/Volumes/T")
        access.file("a.txt")
        var limits = IndexingRunLimits.standard
        // bug.0.3.9.004 a: Beweis ist `listed.count == 1` (keine Wiederholung). Die Zeitgrenze leitet sich aus der
        // Wiederholungspause ab (jede Wiederholung kostet mindestens 60 s) statt die Last zu messen (vorher < 2 s).
        let retryPause: Duration = .seconds(60)
        limits.readRetryDelays = [retryPause, retryPause]
        let started = ContinuousClock.now
        let outcome = try await harness.run(
            access: access,
            maxDepth: nil,
            limits: limits,
            shouldHalt: {
                access.shouldPause ? .pause : .none
            }
        )
        let elapsed = started.duration(to: .now)
        #expect(outcome.status == .pending)
        #expect(access.listed.count == 1)
        #expect(elapsed < retryPause / 2)
    }

    @Test func hungStreamTriggersDirectoryReadStalled() async throws {
        let harness = try await ScanHarness.make()
        let access = HungListVolume(mountPath: "/Volumes/T")
        access.file("a.txt")
        var limits = IndexingRunLimits.standard
        limits.directoryStallTimeout = 1
        limits.consecutiveTimeoutLimit = 1
        // Eine Wiederholung nach dem Stillstand würde 60 s warten (gibt es nicht; sonst rot über die Obergrenze).
        limits.readRetryDelays = [.seconds(60)]
        // bug.0.3.9.008: Die Grenze misst, dass der Wächter rechtzeitig auslöst: Stillstand + höchstens 2 Takte des
        // Wächters (`DirectoryIndexer.stallWatchdogTick`) + 5 s Reserve für Last. Kein Bezug zur Wiederholungspause.
        // bug.0.3.9.014 c: beide Werte aus `limits` bzw. dem Produktcode, nicht fest eingetragen.
        let stall: Duration = .seconds(limits.directoryStallTimeout)
        let watchdogTick = DirectoryIndexer.stallWatchdogTick
        let bound = stall + watchdogTick * 2 + .seconds(5)
        let started = ContinuousClock.now
        let outcome = try await harness.run(access: access, maxDepth: nil, limits: limits)
        let elapsed = started.duration(to: .now)
        #expect(outcome.status == .pending)
        #expect(outcome.failureReason == .timeout)
        #expect(elapsed >= stall)
        #expect(elapsed < bound, "Wächter nach \(elapsed), Grenze \(bound)")
    }
}

private final class PauseAfterFirstListVolume: MediumAccess, @unchecked Sendable {
    let mountPath: String
    private let inner: MemoryVolume
    private(set) var shouldPause = false
    var listed: [String] { inner.listed }

    init(mountPath: String) {
        self.mountPath = mountPath
        inner = MemoryVolume(mountPath: mountPath)
    }

    func file(_ relative: String) { inner.file(relative) }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let rows = try await inner.listDirectory(at: url)
        shouldPause = true
        return rows
    }
}

private final class HungListVolume: MediumAccess, @unchecked Sendable {
    let mountPath: String
    private let inner: MemoryVolume

    init(mountPath: String) {
        self.mountPath = mountPath
        inner = MemoryVolume(mountPath: mountPath)
    }

    func file(_ relative: String) {
        inner.file(relative)
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        try await Task.sleep(for: .seconds(120))
        return []
    }

    func listDirectoryChunks(at url: URL, chunkSize: Int) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        AsyncStream { _ in }
    }
}

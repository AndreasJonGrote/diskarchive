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
        limits.readRetryDelays = [.seconds(5), .seconds(5)]
        let started = ContinuousClock.now
        let outcome = try await harness.run(access: access, maxDepth: nil, limits: limits)
        let elapsed = started.duration(to: .now)
        #expect(outcome.status == .error)
        #expect(outcome.failureReason == .database)
        #expect(elapsed < .seconds(2))
    }

    @Test func pauseDuringFirstChunkAvoidsReadRetries() async throws {
        let harness = try await ScanHarness.make()
        let access = PauseAfterFirstListVolume(mountPath: "/Volumes/T")
        access.file("a.txt")
        var limits = IndexingRunLimits.standard
        limits.readRetryDelays = [.seconds(8), .seconds(8)]
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
        #expect(elapsed < .seconds(2))
    }

    @Test func hungStreamTriggersDirectoryReadStalled() async throws {
        let harness = try await ScanHarness.make()
        let access = HungListVolume(mountPath: "/Volumes/T")
        access.file("a.txt")
        var limits = IndexingRunLimits.standard
        limits.directoryStallTimeout = 1
        limits.consecutiveTimeoutLimit = 1
        limits.readRetryDelays = [.seconds(5)]
        let started = ContinuousClock.now
        let outcome = try await harness.run(access: access, maxDepth: nil, limits: limits)
        let elapsed = started.duration(to: .now)
        #expect(outcome.status == .pending)
        #expect(outcome.failureReason == .timeout)
        #expect(elapsed >= .seconds(1))
        #expect(elapsed < .seconds(4))
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

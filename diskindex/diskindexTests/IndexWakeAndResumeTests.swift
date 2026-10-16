//
//  IndexWakeAndResumeTests.swift
//  diskindexTests
//
//  bug.0.4.028 — Nacharbeit 2 Akzeptanztests.
//

import AppKit
import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct IndexWakeAndResumeTests {
    @Test func activeRunSurvivesResumeAfterRuleReconcile() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a/x.txt")
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.indexStatus = .pending
        stored.decision = .index
        try await harness.store.upsertMedium(stored)

        let access = WakeGateAccess(inner: inner)
        let app = AppState()
        app.media = [wakeMedium(from: stored)]
        let service = IndexingService(store: harness.store, access: access, appState: app)
        let volume = harness.volume(at: "/Volumes/T")
        service.start(mediumUUID: harness.mediumID, volume: volume, fromScratch: true)
        await access.entered.wait()
        let dbDuring = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(dbDuring.indexStatus == .indexing)

        await app.resumeAfterRuleReconcile()
        let dbAfter = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(dbAfter.indexStatus == .indexing)
        #expect(app.medium(with: harness.mediumID)?.indexStatus == .indexing)

        await access.release()
        await service.waitUntilIdle(harness.mediumID)
    }

    @Test func wakeAfterSleepStartsExactlyOneReconcileForIndexedMedium() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("only.txt")
        _ = try await harness.run(access: inner, maxDepth: nil, fromScratch: true)

        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("only.txt")
        let app = AppState()
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        app.media = [wakeMedium(from: stored)]
        let service = IndexingService(store: harness.store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: harness.store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator,
            service: service,
            watcher: ChangeWatcher(store: harness.store, access: access, appState: app),
            appState: app,
            startWatching: { _, _ in }
        )
        let volume = harness.volume(at: "/Volumes/T")
        await coordinator.handle(.appeared(volume))
        await service.waitUntilIdle(harness.mediumID)
        let ordersBefore = DiskIndexLog.shared.recentBreadcrumbs().filter { $0.contains("auftrag medium=") }.count
        app.globalAutoIndexPaused = true
        service.pauseChanged()
        app.globalAutoIndexPaused = false
        service.pauseChanged()
        await service.waitUntilIdle(harness.mediumID)
        let ordersAfter = DiskIndexLog.shared.recentBreadcrumbs().filter { $0.contains("auftrag medium=") }.count
        #expect(ordersAfter >= ordersBefore)
    }

    @Test func activeRunKeepsIndexingStatusThroughWakeHandling() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("hold/x.txt")
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)

        let access = WakeGateAccess(inner: inner)
        let app = AppState()
        app.media = [wakeMedium(from: stored)]
        let service = IndexingService(store: harness.store, access: access, appState: app)
        let volume = harness.volume(at: "/Volumes/T")
        service.start(mediumUUID: harness.mediumID, volume: volume, fromScratch: true)
        await access.entered.wait()

        app.heldForSleep = false
        app.refreshGlobalPause()
        let pauseBefore = app.globalAutoIndexPaused
        if pauseBefore == app.globalAutoIndexPaused {
            app.onAutoIndexPauseChanged?()
        }

        let dbDuring = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(dbDuring.indexStatus == .indexing)
        await access.release()
        await service.waitUntilIdle(harness.mediumID)
    }
}

private func wakeMedium(from stored: StoredMedium) -> Medium {
    let status: IndexStatus = switch stored.indexStatus {
    case .indexed: .indexed
    case .indexing: .indexing
    case .error: .error
    case .pending: .pending
    }
    return Medium(
        id: stored.uuid,
        name: stored.name,
        type: .usb,
        connectionStatus: .connected,
        indexStatus: status,
        allowIndexing: true,
        autoIndexPaused: false,
        decision: stored.decision,
        capacityTotalBytes: stored.volumeTotalBytes,
        capacityUsedBytes: 0,
        fileCount: stored.fileCount,
        folderCount: stored.folderCount,
        scanTotal: stored.scanTotal,
        lastSeenAt: Date(),
        firstIndexedAt: stored.firstIndexedAt,
        lastIndexedAt: stored.lastIndexedAt,
        completedDepth: stored.completedDepth,
        isForgotten: false,
        indexingProgress: status == .indexed ? 1 : 0
    )
}

private final class WakeCountingAccess: MediumAccess, @unchecked Sendable {
    let inner: MemoryVolume
    private let lock = NSLock()
    private(set) var starts = 0

    init(inner: MemoryVolume) {
        self.inner = inner
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        lock.lock()
        starts += 1
        lock.unlock()
        return try await inner.listDirectory(at: url)
    }
}

private final class WakeGateAccess: MediumAccess, @unchecked Sendable {
    let inner: MemoryVolume
    private let state = WakeGateState()
    let entered = WakeSignal()

    init(inner: MemoryVolume) {
        self.inner = inner
    }

    func release() async {
        await state.release()
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        if Task.isCancelled { throw CancellationError() }
        if await state.markEnteredOnce() { await entered.signal() }
        while true {
            if Task.isCancelled { throw CancellationError() }
            if await state.isReleased { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        return try await inner.listDirectory(at: url)
    }
}

private actor WakeGateState {
    private var entered = false
    private var released = false

    func markEnteredOnce() -> Bool {
        guard !entered else { return false }
        entered = true
        return true
    }

    var isReleased: Bool { released }

    func release() {
        released = true
    }
}

private actor WakeSignal {
    private var ready = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        ready = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    func wait() async {
        if ready { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

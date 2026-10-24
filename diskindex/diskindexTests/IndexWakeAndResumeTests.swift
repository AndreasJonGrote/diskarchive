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

    /// Nacharbeit 3: echter Aufwach-Weg (Monitor-Auslöser → Coordinator → Service, dazu `handleWake` wie im
    /// `AppDelegate`) → bei verbundenem, indiziertem Medium genau ein zusätzlicher Start.
    @Test func wakeThroughMonitorStartsExactlyOneReconcile() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("only.txt")
        let volume = testVolume(path: "/Volumes/T", name: "TEST")
        _ = try await harness.run(access: inner, maxDepth: nil, fromScratch: true, volume: volume)
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)

        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: inner, app: app)
        let (wakes, wake) = AsyncStream<Void>.makeStream()
        let appearedAt = ContinuousClock.now
        MediumRecognitionStartup.bootstrap(
            appState: app,
            store: harness.store,
            coordinator: rig.coordinator,
            startChangeLoop: {},
            makeMonitor: { MediumMonitor(mountedVolumes: { [volume] }, wakeEvents: { wakes }) }
        )
        defer { rig.coordinator.stop() }
        let connected = await waitUntil { rig.starts(id) == [false] && !rig.service.isRunActive(id) }
        #expect(connected)
        // Entprellung des Monitors (1 s) abwarten, sonst verschluckt sie ein doppeltes `.appeared` schon vorher.
        try await Task.sleep(until: appearedAt + .milliseconds(1_200), clock: .continuous)

        wake.yield()
        app.handleWake()
        let woke = await waitUntil { rig.starts(id).count >= 2 }
        #expect(woke)
        await rig.service.waitUntilIdle(id)
        try await Task.sleep(for: .milliseconds(500))
        await rig.service.waitUntilIdle(id)
        #expect(rig.starts(id) == [false, false])
        try await Task.sleep(for: .milliseconds(300))
        #expect(rig.starts(id) == [false, false])
    }

    /// Nacharbeit 3: Lauf aktiv → `handleWake()` + `.appeared` desselben Volumes → DB bleibt `.indexing`,
    /// kein zweiter Lauf.
    @Test func activeRunKeepsIndexingStatusThroughWake() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("hold/x.txt")
        let volume = testVolume(path: "/Volumes/T", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)

        let access = RunGateAccess([inner]) { $0 == "/Volumes/T/hold" }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)
        await rig.coordinator.handle(.appeared(volume))
        let held = await waitUntil { await access.heldCount() >= 1 }
        try #require(held)
        #expect(rig.starts(id) == [false])

        app.handleWake()
        await rig.coordinator.handle(.appeared(volume))
        try await Task.sleep(for: .milliseconds(200))
        let during = try #require(try await harness.store.medium(uuid: id))
        #expect(during.indexStatus == .indexing)
        #expect(app.medium(with: id)?.indexStatus == .indexing)

        await access.open()
        await rig.service.waitUntilIdle(id)
        try await Task.sleep(for: .milliseconds(500))
        await rig.service.waitUntilIdle(id)
        #expect(rig.starts(id) == [false])
        let after = try #require(try await harness.store.medium(uuid: id))
        #expect(after.indexStatus == .indexed)
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

private final class WakeGateAccess: MediumAccess, @unchecked Sendable {
    /// bug.0.4.177: Testzugriff steht für ein eingehängtes Medium.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
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

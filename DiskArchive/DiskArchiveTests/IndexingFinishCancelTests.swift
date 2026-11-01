//
//  IndexingFinishCancelTests.swift
//  DiskArchiveTests
//
//  c.0.3.2.006 — finish token order, cancel detached task, background recount token.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite @MainActor struct IndexingFinishCancelTests {
    @Test func reindexKeepsMenuBarSpinner() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a/x.txt")
        _ = try await harness.run(access: inner, maxDepth: nil, fromScratch: true)
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(stored.indexStatus == .indexed)
        #expect(stored.completedDepth > 0)
        #expect(stored.scanTotal > 0)

        let access = GateUntilReleaseAccess(inner: inner)
        let appState = AppState()
        appState.media = [medium(from: stored)]
        let service = IndexingService(store: harness.store, access: access, appState: appState)
        let volume = harness.volume(at: "/Volumes/T")

        service.start(mediumUUID: harness.mediumID, volume: volume, fromScratch: false)
        await access.entered.wait()
        service.start(mediumUUID: harness.mediumID, volume: volume, fromScratch: true)
        var sawSpinner = false
        for _ in 0..<300 {
            if appState.menuBarIndexingSpinnerIDs.contains(harness.mediumID) {
                sawSpinner = true
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(sawSpinner)
        await access.release()
        await service.waitUntilIdle(harness.mediumID)
        let done = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(done.indexStatus == .indexed)
    }

    @Test func cancelStopsDetachedWork() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-finish-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "DEEP", type: .usb, decision: .index)
        try await store.upsertMedium(stored)
        let id = stored.uuid

        let inner = MemoryVolume(mountPath: "/Volumes/DEEP")
        for index in 0..<40 {
            inner.file("branch\(index)/leaf.txt")
        }
        let access = CountingHoldAccess(inner: inner)
        let appState = AppState()
        stored.indexStatus = .pending
        stored.completedDepth = 0
        try await store.upsertMedium(stored)
        appState.media = [medium(from: stored)]
        let service = IndexingService(store: store, access: access, appState: appState)
        let volume = VolumeInfo(
            mountPath: "/Volumes/DEEP",
            name: "DEEP",
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 100,
            diskSizeBytes: nil,
            volumeUUID: nil,
            createdAt: nil,
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: nil,
            isTimeMachineSnapshot: false
        )

        service.start(mediumUUID: id, volume: volume, fromScratch: true)
        await access.entered.wait()
        await service.cancel(mediumUUID: id)
        await access.releaseGate()
        await service.waitUntilIdle(id)
        #expect(await access.listCalls <= 4)
    }

    @Test func cancelDuringBackgroundRecountDoesNotBumpScanTotal() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a/x.txt")
        _ = try await harness.run(access: inner, maxDepth: nil, fromScratch: true)
        try await harness.store.setScanTotal(mediumUUID: harness.mediumID, total: 999)
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(stored.scanTotal == 999)

        let access = GateUntilReleaseAccess(inner: inner)
        let appState = AppState()
        appState.media = [medium(from: stored)]
        let service = IndexingService(store: harness.store, access: access, appState: appState)
        let volume = harness.volume(at: "/Volumes/T")

        service.start(mediumUUID: harness.mediumID, volume: volume, fromScratch: false)
        await access.entered.wait()
        await service.cancel(mediumUUID: harness.mediumID)
        await access.release()
        await service.waitUntilIdle(harness.mediumID)
        let after = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(after.scanTotal == 999)
    }

    private func medium(from stored: StoredMedium) -> Medium {
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
}

private final class GateUntilReleaseAccess: MediumAccess, @unchecked Sendable {
    /// bug.0.4.177: Testzugriff steht für ein eingehängtes Medium.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
    let inner: MemoryVolume
    private let state = FinishCancelGateState()
    let entered = FinishCancelSignal()

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

private final class CountingHoldAccess: MediumAccess, @unchecked Sendable {
    /// bug.0.4.177: Testzugriff steht für ein eingehängtes Medium.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
    let inner: MemoryVolume
    private let state = FinishCancelHoldState()
    let entered = FinishCancelSignal()

    init(inner: MemoryVolume) {
        self.inner = inner
    }

    var listCalls: Int {
        get async { await state.listCalls }
    }

    func releaseGate() async {
        await state.release()
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let waiting = await state.beginList()
        if waiting {
            await entered.signal()
            while true {
                if Task.isCancelled { throw CancellationError() }
                if await state.isReleased { break }
                try await Task.sleep(for: .milliseconds(5))
            }
            await state.clearHold()
        }
        return try await inner.listDirectory(at: url)
    }
}

private actor FinishCancelGateState {
    private var released = false
    private var enteredOnce = false

    func release() { released = true }
    var isReleased: Bool { released }

    /// true beim ersten Eintritt.
    func markEnteredOnce() -> Bool {
        if enteredOnce { return false }
        enteredOnce = true
        return true
    }
}

private actor FinishCancelHoldState {
    private var hold = true
    private var released = false
    private(set) var listCalls = 0

    func release() { released = true }
    var isReleased: Bool { released }

    func beginList() -> Bool {
        listCalls += 1
        return hold
    }

    func clearHold() { hold = false }
}

private actor FinishCancelSignal {
    private var ready = false

    func signal() {
        ready = true
    }

    func wait() async {
        while !ready {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

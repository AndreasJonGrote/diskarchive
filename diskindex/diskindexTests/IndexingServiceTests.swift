//
//  IndexingServiceTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor struct IndexingServiceTests {
    @Test func unplugDuringARunRestartsExactlyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-index-service-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = BlockingAccess()
        let appState = AppState()
        let service = IndexingService(store: store, access: access, appState: appState)
        let starts = StartLog()
        let coordinator = MediumCoordinator(store: store, access: access, appState: appState)
        service.attach(coordinator)
        coordinator.setIndexHandler { id, volume in
            starts.ids.append(id)
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
        }
        coordinator.onIndexingInterrupted = { id in
            await service.cancel(mediumUUID: id)
        }
        let volume = VolumeInfo(
            mountPath: "/Volumes/BLOCK",
            name: "BLOCK",
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 100,
            diskSizeBytes: nil,
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000099",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: nil,
            isTimeMachineSnapshot: false
        )
        await coordinator.handle(.appeared(volume))
        let id = try #require(appState.newMediumDialogMediumID)
        appState.onNewMediumChoice?(id, true, true)
        await coordinator.waitForChoice()
        await access.entered.wait()
        #expect(starts.ids == [id])
        await coordinator.handle(.disappeared(path: volume.mountPath))
        let paused = try #require(try await store.medium(uuid: id))
        #expect(paused.indexStatus == .pending)
        #expect(paused.completedDepth == 0)
        await access.release.signal()
        await service.waitUntilIdle(id)
        await coordinator.handle(.appeared(volume))
        await service.waitUntilIdle(id)
        #expect(starts.ids == [id, id])
        let done = try #require(try await store.medium(uuid: id))
        #expect(done.indexStatus == .indexed)
        #expect(done.decision == .index)
    }
}


private final class BlockingAccess: MediumAccess, @unchecked Sendable {
    let entered = Signal()
    let release = Signal()
    private let lock = NSLock()
    private var lists = 0

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let shouldBlock = consumeFirstList()
        if shouldBlock {
            await entered.signal()
            await release.wait()
        }
        return []
    }

    private func consumeFirstList() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        lists += 1
        return lists == 1
    }
}

private actor Signal {
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

private final class StartLog: @unchecked Sendable {
    var ids: [UUID] = []
}

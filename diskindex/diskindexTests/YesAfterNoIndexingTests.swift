//
//  YesAfterNoIndexingTests.swift
//  diskindexTests
//
//  bug.0.4.027 — Repro Nr. 60 aus audit-repro.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct YesAfterNoIndexingTests {
    @Test func nr60_yesAfterNoStartsANewRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-nr60-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let access = MapAccess()
        access.listings["/Volumes/NR60"] = [
            ListedDirectoryEntry(
                name: "root.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        let app = AppState()
        app.attach(store: store)
        let service = IndexingService(store: store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        let watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator, service: service, watcher: watcher, appState: app,
            startWatching: { _, _ in }
        )
        let volume = VolumeInfo(
            mountPath: "/Volumes/NR60", name: "NR60", fsType: "msdos",
            volumeTotalBytes: 1_000, volumeFreeBytes: 400, diskSizeBytes: 1_024, volumeUUID: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_102_804),
            isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: "USB", model: nil, isTimeMachineSnapshot: false
        )
        await coordinator.handle(.appeared(volume))
        let id = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(id, true, true)
        await coordinator.waitForChoice()
        let firstStarted = await waitUntil(timeout: 3) { access.listCount(for: "/Volumes/NR60") > 0 }
        #expect(firstStarted)
        await service.waitUntilIdle(id)
        let doneFirst = await waitUntil(timeout: 3) {
            (try? await store.medium(uuid: id))?.indexStatus == .indexed && !service.isRunActive(id)
        }
        #expect(doneFirst)
        let listsAfterFirst = access.listCount(for: "/Volumes/NR60")

        app.onMediumDecisionChanged?(id, .dontIndex, false)
        try await Task.sleep(for: .milliseconds(150))
        app.onMediumDecisionChanged?(id, .index, true)
        let rerun = await waitUntil(timeout: 3) { access.listCount(for: "/Volumes/NR60") > listsAfterFirst }
        #expect(rerun)
        await service.waitUntilIdle(id)
    }

    @Test func doubleIndexRequestDuringRunKeepsOneActiveRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-double-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let inner = MemoryVolume(mountPath: "/Volumes/DBL")
        inner.file("a/x.txt")
        inner.file("b/y.txt")
        let access = DoubleRequestGateAccess(inner: inner)
        let app = AppState()
        app.attach(store: store)
        let service = IndexingService(store: store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        let watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator, service: service, watcher: watcher, appState: app,
            startWatching: { _, _ in }
        )
        var stored = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "DBL", type: .usb, decision: .index, indexStatus: .pending
        )
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))
        app.media = [testMedium(from: stored)]
        let volume = VolumeInfo(
            mountPath: "/Volumes/DBL", name: "DBL", fsType: "apfs",
            volumeTotalBytes: 1_000, volumeFreeBytes: 400, diskSizeBytes: 1_024, volumeUUID: nil,
            createdAt: Date(), isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: "USB", model: nil, isTimeMachineSnapshot: false
        )
        service.start(mediumUUID: stored.uuid, volume: volume, fromScratch: true)
        await access.entered.wait()
        service.start(mediumUUID: stored.uuid, volume: volume, fromScratch: false)
        #expect(service.isRunActive(stored.uuid))
        #expect(await access.concurrentLists() <= 1)
        await access.release()
        await service.waitUntilIdle(stored.uuid)
    }

    @Test func sabotageWithoutClearIndexRequestBlocksNr60Rerun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-nr60-sabotage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let access = MapAccess()
        access.listings["/Volumes/SAB"] = [
            ListedDirectoryEntry(name: "root.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        let app = AppState()
        app.attach(store: store)
        let service = IndexingService(store: store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        let watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator, service: service, watcher: watcher, appState: app,
            startWatching: { _, _ in }
        )
        let volume = VolumeInfo(
            mountPath: "/Volumes/SAB", name: "SAB", fsType: "msdos",
            volumeTotalBytes: 1_000, volumeFreeBytes: 400, diskSizeBytes: 1_024, volumeUUID: nil,
            createdAt: Date(), isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: "USB", model: nil, isTimeMachineSnapshot: false
        )
        service.skipClearIndexRequestForTesting = true
        await coordinator.handle(.appeared(volume))
        let id = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(id, true, true)
        await coordinator.waitForChoice()
        await service.waitUntilIdle(id)
        let listsAfterFirst = access.listCount(for: "/Volumes/SAB")
        app.onMediumDecisionChanged?(id, .dontIndex, false)
        try await Task.sleep(for: .milliseconds(150))
        app.onMediumDecisionChanged?(id, .index, true)
        let rerun = await waitUntil(timeout: 2) { access.listCount(for: "/Volumes/SAB") > listsAfterFirst }
        #expect(rerun == false)
        service.skipClearIndexRequestForTesting = false
    }
}

private func testMedium(from stored: StoredMedium) -> Medium {
    Medium(
        id: stored.uuid,
        name: stored.name,
        type: .usb,
        connectionStatus: .connected,
        indexStatus: .pending,
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
        indexingProgress: 0
    )
}

private final class DoubleRequestGateAccess: MediumAccess, @unchecked Sendable {
    let inner: MemoryVolume
    private let gate = DoubleRequestGate()
    let entered = DoubleRequestSignal()

    init(inner: MemoryVolume) {
        self.inner = inner
    }

    func release() async {
        await gate.release()
    }

    func concurrentLists() async -> Int {
        await gate.concurrent
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        await gate.enter()
        defer { Task { await gate.leave() } }
        if await gate.shouldSignalEntered() {
            await entered.signal()
        }
        while !(await gate.isReleased) {
            try await Task.sleep(for: .milliseconds(5))
        }
        return try await inner.listDirectory(at: url)
    }
}

private actor DoubleRequestGate {
    private var holding = 0
    private var maxConcurrent = 0
    private var enteredOnce = false
    private var released = false

    func enter() {
        holding += 1
        maxConcurrent = max(maxConcurrent, holding)
    }

    func leave() {
        holding = max(0, holding - 1)
    }

    var concurrent: Int { maxConcurrent }

    func shouldSignalEntered() -> Bool {
        guard !enteredOnce else { return false }
        enteredOnce = true
        return true
    }

    var isReleased: Bool { released }

    func release() {
        released = true
    }
}

private actor DoubleRequestSignal {
    private var ready = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        ready = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func wait() async {
        if ready { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

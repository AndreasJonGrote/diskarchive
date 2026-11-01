//
//  WatcherFlushReproTests.swift
//  DiskArchiveTests
//
//  bug.0.4.019 — Repro Nr. 66, 99 (Regel 25).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct WatcherFlushReproTests {
    @Test func nr66_deferredFlushRunsAfterIndexingEnds() async throws {
        let rig = try await watchRig()
        let token = UUID()
        _ = try await rig.store.beginIndexing(mediumUUID: rig.medium.uuid, token: token)
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        var indexing = true
        rig.watcher.isIndexingActive = { _ in indexing }
        rig.watcher.quietInterval = .milliseconds(20)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 5))
        try await Task.sleep(for: .milliseconds(120))
        #expect(rig.access.listCountIsEmpty(), "Vorbedingung: während des Laufs wird nicht gelesen")
        _ = try await rig.store.finishIndexing(mediumUUID: rig.medium.uuid, token: token, status: .indexed, firstIndexedAt: nil)
        indexing = false
        let flushed = await waitUntil(timeout: 2) { rig.access.listCount(for: "/Volumes/DISK/A") > 0 }
        #expect(flushed, "Nr. 66: zurückgestellter Flush wird nach Laufende nie ausgeführt (listCount A=\(rig.access.listCount(for: "/Volumes/DISK/A")))")
        await rig.watcher.stop(mediumID: rig.medium.uuid)
    }

    @Test func nr99_concurrentDirectoryBatchesKeepCountsExact() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let store = harness.store
        let id = medium.uuid
        let folders = try await harness.addRoot(
            medium: medium,
            entries: (0..<40).map { ScannedEntry(name: "d\($0)", isFolder: true) }
        )
        try await withThrowingTaskGroup(of: Void.self) { group in
            for folder in folders {
                let parent = folder.id
                group.addTask {
                    try await store.applyDirectories(
                        mediumUUID: id,
                        batches: [(parentID: parent, path: nil, depth: nil,
                                   entries: (0..<5).map { ScannedEntry(name: "f\($0).txt", isFolder: false, sizeBytes: 1) },
                                   finalize: true)],
                        seenAt: Date()
                    )
                }
            }
            try await group.waitForAll()
        }
        let stored = try #require(try await store.medium(uuid: id))
        let truth = try await store.counts(mediumUUID: id)
        #expect(stored.fileCount == truth.files && stored.folderCount == truth.folders,
                "Nr. 99: Zähler weichen ab: gespeichert files=\(stored.fileCount) folders=\(stored.folderCount), echt files=\(truth.files) folders=\(truth.folders)")
    }

    @Test func serialFlushWhileBlockedReadsBothFolders() async throws {
        let rig = try await watchRig()
        rig.app.globalAutoIndexPaused = false
        let reconcile = ReconcileLog()
        rig.watcher.onFullReconcile = { id, _ in reconcile.ids.append(id) }
        let access = GatedMapAccess()
        access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "a.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        access.listings["/Volumes/DISK/B"] = [
            ListedDirectoryEntry(name: "b.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        let watcher = ChangeWatcher(store: rig.store, access: access, appState: rig.app)
        watcher.quietInterval = .milliseconds(25)
        watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/a.txt", eventID: 1))
        let blocked = await waitUntil(timeout: 10) { access.isBlockingFirstList() }
        #expect(blocked)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/B/b.txt", eventID: 2))
        try await Task.sleep(for: .milliseconds(80))
        #expect(access.listCount(for: "/Volumes/DISK/B") == 0)
        await access.release.signal()
        let both = await waitUntil(timeout: 10) {
            access.listCount(for: "/Volumes/DISK/A") > 0 && access.listCount(for: "/Volumes/DISK/B") > 0
        }
        #expect(both)
        #expect(reconcile.ids.isEmpty)
        await watcher.stop(mediumID: rig.medium.uuid)
    }

    @Test func pauseToggleWithPendingEventStillFlushes() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.app.globalAutoIndexPaused = true
        rig.watcher.pauseChanged()
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 7))
        rig.app.globalAutoIndexPaused = false
        rig.watcher.pauseChanged()
        let flushed = await waitUntil(timeout: 2) { rig.access.listCount(for: "/Volumes/DISK/A") > 0 }
        #expect(flushed)
        #expect(rig.watcher.isWatching(mediumID: rig.medium.uuid))
        await rig.watcher.stop(mediumID: rig.medium.uuid)
    }
}

private final class GatedMapAccess: MediumAccess, @unchecked Sendable {
    /// bug.0.4.177: Testzugriff steht für ein eingehängtes Medium.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
    var listings: [String: [ListedDirectoryEntry]] = [:]
    private var listCountStorage: [String: Int] = [:]
    private let lock = NSLock()
    let release = SurfaceAsyncSignal()
    private var calls = 0
    func isBlockingFirstList() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return blockingFirstList
    }

    private var blockingFirstList = false

    func listCount(for path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return listCountStorage[path] ?? 0
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let path = url.standardizedFileURL.path
        let blockFirst = lock.withLock { () -> Bool in
            calls += 1
            let block = calls == 1
            if block { blockingFirstList = true }
            return block
        }
        if blockFirst {
            await release.wait()
            lock.withLock { blockingFirstList = false }
        }
        lock.withLock { listCountStorage[path, default: 0] += 1 }
        return lock.withLock { listings[path] ?? [] }
    }
}

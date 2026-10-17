//
//  WatcherLifecycleTests.swift
//  diskindexTests
//
//  c.0.3.2.004 — Watcher vs Indexer, Stream-Ende, Cursor, LiveWiring.
//

import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct WatcherLifecycleTests {
    @Test func finishingChangeSourceReleasesWatchSlot() async throws {
        let rig = try await watchRig()
        let source = FinishingChangeSource()
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: source)
        #expect(rig.watcher.isWatching(mediumID: rig.medium.uuid))
        let released = await waitUntil(timeout: 2) {
            !rig.watcher.isWatching(mediumID: rig.medium.uuid)
        }
        #expect(released)
    }

    @Test func applyFailureDoesNotAdvanceCursor() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = []
        rig.watcher.quietInterval = .milliseconds(20)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/x", eventID: 10, fileSystemUUID: "UUID-1"))
        // bug.0.3.8.007: Vorbedingung abwarten (erster Flush gespeichert) statt fester 80 ms.
        let firstSaved = await waitUntil {
            (try? await rig.store.medium(uuid: rig.medium.uuid))?.lastEventID == 10
        }
        #expect(firstSaved)
        await rig.store.setDirectoryWritesFailing(true)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/y", eventID: 11, fileSystemUUID: "UUID-1"))
        // bug.0.3.8.007: erst warten, bis der zweite Flush A gelesen hat (Schreiben schlägt danach fehl), dann kurz
        // nachsehen — sonst wäre „Cursor nicht 11“ auch grün, wenn der Flush noch gar nicht lief.
        let secondRead = await waitUntil { rig.access.listCount(for: "/Volumes/DISK/A") >= 2 }
        #expect(secondRead)
        try await Task.sleep(for: .milliseconds(100))
        let row = try #require(try await rig.store.medium(uuid: rig.medium.uuid))
        #expect(row.lastEventID != 11)
        await rig.store.setDirectoryWritesFailing(false)
    }

    @Test func flushDeferredWhileIndexingSkipsApply() async throws {
        let rig = try await watchRig()
        let token = UUID()
        _ = try await rig.store.beginIndexing(mediumUUID: rig.medium.uuid, token: token)
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.isIndexingActive = { _ in true }
        rig.watcher.quietInterval = .milliseconds(20)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 5))
        try await Task.sleep(for: .milliseconds(120))
        #expect(rig.access.listCountIsEmpty())
        _ = try await rig.store.finishIndexing(mediumUUID: rig.medium.uuid, token: token, status: .indexed, firstIndexedAt: nil)
    }

    @Test func reconcileDoesNotWatchUntilRunIndexed() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-lw-reconcile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let access = BlockingListAccess()
        let app = AppState()
        let service = IndexingService(store: store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        let watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator,
            service: service,
            watcher: watcher,
            appState: app,
            startWatching: { id, volume in
                await LiveWiring.startWatching(
                    id: id, volume: volume, store: store, watcher: watcher, appState: app
                )
            }
        )

        let stored = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000D1",
            fsType: "apfs",
            volumeTotalBytes: 10,
            name: "Live",
            decision: .index,
            indexStatus: .indexed,
            completedDepth: 2
        )
        try await store.upsertMedium(stored)
        let volume = VolumeInfo(
            mountPath: "/Volumes/LIVE",
            name: "Live",
            fsType: "apfs",
            volumeTotalBytes: 10,
            volumeFreeBytes: 4,
            diskSizeBytes: nil,
            volumeUUID: stored.volumeUUID,
            createdAt: nil,
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: nil,
            model: nil,
            isTimeMachineSnapshot: false
        )
        await coordinator.handle(.appeared(volume))
        let runStarted = await waitUntil(timeout: 3) { service.isRunActive(stored.uuid) }
        #expect(runStarted)
        #expect(!watcher.isWatching(mediumID: stored.uuid))
        await access.entered.wait()
        await access.release.signal()
        await service.waitUntilIdle(stored.uuid)
        service.onRunIndexed?(stored.uuid, volume)
        // bug.0.3.8.007: auf das Starten warten statt fester 30 ms (Start läuft über einen Store-Zugriff).
        let watching = await waitUntil { watcher.isWatching(mediumID: stored.uuid) }
        #expect(watching)
    }
}
}

private final class FinishingChangeSource: ChangeSource, @unchecked Sendable {
    func changes() -> AsyncStream<VolumeChange> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

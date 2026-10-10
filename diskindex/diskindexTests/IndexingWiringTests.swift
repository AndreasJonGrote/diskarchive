//
//  IndexingWiringTests.swift
//  diskindexTests
//
//  Aufgabe 179 a–d — Indizierung, Pause, Vergessen.
//

import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct IndexingWiringTests {
    @Test func watchingStartsAfterPauseIndexedRun() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let root = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("a.txt"))

        let rig = try await LiveWatchRig.make(mountPath: volume.mountPath, volumeName: volume.volumeName)
        rig.app.globalAutoIndexPaused = true
        rig.app.startChangeLoop()
        await rig.coordinator.handle(.appeared(rig.volume))
        await rig.app.loadStoredMedia()
        let mediumID = try #require(rig.app.newMediumDialogMediumID)
        rig.app.onNewMediumChoice?(mediumID, true, true)
        await rig.coordinator.waitForChoice()
        rig.app.globalAutoIndexPaused = false
        rig.app.onAutoIndexPauseChanged?()
        await rig.service.waitUntilIdle(mediumID)
        let indexed = await waitUntil(timeout: 60) {
            (try? await rig.store.medium(uuid: mediumID))?.indexStatus == .indexed
        }
        #expect(indexed)
        try await Task.sleep(for: .seconds(2))
        #expect(rig.watcher.isWatching(mediumID: mediumID))

        let url = root.appendingPathComponent("a.txt")
        let renamed = root.appendingPathComponent("b.txt")
        try FileManager.default.moveItem(at: url, to: renamed)
        let seen = await waitUntil(timeout: 15) {
            (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "b.txt"))?.removedAt == nil
        }
        #expect(seen)
    }

    @Test func reconcileAfterPauseWhileConnected() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let root = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
        try Data("alt".utf8).write(to: root.appendingPathComponent("alt.txt"))

        let rig = try await LiveWatchRig.make(mountPath: volume.mountPath, volumeName: volume.volumeName)
        rig.app.startChangeLoop()
        await rig.coordinator.handle(.appeared(rig.volume))
        await rig.app.loadStoredMedia()
        let mediumID = try #require(rig.app.newMediumDialogMediumID)
        rig.app.onNewMediumChoice?(mediumID, true, true)
        await rig.coordinator.waitForChoice()
        await rig.service.waitUntilIdle(mediumID)

        rig.app.globalAutoIndexPaused = true
        rig.app.onAutoIndexPauseChanged?()
        let renamed = root.appendingPathComponent("neu.txt")
        try FileManager.default.moveItem(at: root.appendingPathComponent("alt.txt"), to: renamed)

        rig.app.globalAutoIndexPaused = false
        rig.app.onAutoIndexPauseChanged?()
        await rig.service.waitUntilIdle(mediumID)

        let ok = await waitUntil(timeout: 20) {
            (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "neu.txt"))?.removedAt == nil
        }
        #expect(ok)
    }

    @Test func forgetStopsWatcherAndCoordinatorMapping() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let rig = try await LiveWatchRig.make(mountPath: volume.mountPath, volumeName: volume.volumeName)
        rig.app.startChangeLoop()
        await rig.coordinator.handle(.appeared(rig.volume))
        await rig.app.loadStoredMedia()
        let mediumID = try #require(rig.app.newMediumDialogMediumID)
        rig.app.onNewMediumChoice?(mediumID, true, true)
        await rig.coordinator.waitForChoice()
        await rig.service.waitUntilIdle(mediumID)
        #expect(rig.watcher.isWatching(mediumID: mediumID))
        #expect(!rig.coordinator.connectedVolumes().isEmpty)

        rig.app.forgetMedium(id: mediumID)
        let stopped = await waitUntil(timeout: 10) {
            !rig.watcher.isWatching(mediumID: mediumID)
        }
        #expect(stopped)
        #expect(!rig.watcher.isWatching(mediumID: mediumID))
        #expect(rig.coordinator.connectedVolumes().isEmpty)
        await rig.coordinator.handle(.appeared(rig.volume))
        #expect(rig.app.newMediumDialogMediumID != nil)
    }
}
}

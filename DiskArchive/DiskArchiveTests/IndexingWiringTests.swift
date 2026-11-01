//
//  IndexingWiringTests.swift
//  DiskArchiveTests
//
//  Aufgabe 179 a–d — Indizierung, Pause, Vergessen.
//

import Foundation
import Testing
@testable import DiskArchive

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
        // bug.0.3.8.007: auf das Beobachten warten statt es nach fester Pause vorauszusetzen. Die 2 s danach bleiben:
        // Der echte FSEvents-Strom öffnet erst im Watch-Task, ein Umbenennen davor ginge verloren.
        let watching = await waitUntil { rig.watcher.isWatching(mediumID: mediumID) }
        #expect(watching)
        try await Task.sleep(for: .seconds(2))

        let url = root.appendingPathComponent("a.txt")
        let renamed = root.appendingPathComponent("b.txt")
        try FileManager.default.moveItem(at: url, to: renamed)
        let seen = await waitUntil(timeout: 15) {
            (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "b.txt")) != nil
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
            (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "neu.txt")) != nil
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
        // bug.0.4.204 K1: waitUntilIdle kommt mit dem Ende des Lebenszyklus zurück, die Überwachung startet danach
        // im Task aus onRunIndexed – auf sie warten statt sie vorauszusetzen.
        let watching = await waitUntil { rig.watcher.isWatching(mediumID: mediumID) }
        #expect(watching)
        #expect(!rig.coordinator.connectedVolumes().isEmpty)

        rig.app.forgetMedium(id: mediumID)
        // Beides kommt aus onMediaForgotten; erst nach beiden positiven Signalen die Negativprüfungen.
        let forgotten = await waitUntil(timeout: 10) {
            !rig.watcher.isWatching(mediumID: mediumID) && rig.coordinator.connectedVolumes().isEmpty
        }
        #expect(forgotten)
        #expect(!rig.watcher.isWatching(mediumID: mediumID))
        #expect(rig.coordinator.connectedVolumes().isEmpty)
        await rig.coordinator.handle(.appeared(rig.volume))
        #expect(rig.app.newMediumDialogMediumID != nil)
    }
}
}

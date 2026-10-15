//
//  PackageAndTrashesWatcherTests.swift
//  diskindexTests
//
//  bug.0.4.017 / bug.0.4.018 — Papierkorb und Paket-Inhalt.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct PackageAndTrashesWatcherTests {
    @Test func trashesPathDoesNotTriggerFullReconcile() async throws {
        let rig = try await watchRig()
        var reconciled = false
        rig.watcher.onFullReconcile = { _, _ in reconciled = true }
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/.Trashes/501/f.txt", eventID: 3, itemRemoved: true))
        try await Task.sleep(for: .milliseconds(200))
        #expect(!reconciled)
        #expect(rig.access.listCount.isEmpty)
    }

    @Test func packageInteriorEventRereadsVolumeRoot() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-pkg-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let app = mount.appendingPathComponent("X.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: contents.appendingPathComponent("Info.plist"))

        let rig = try await SurfaceRig.make()
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "PKG", decision: .index, indexStatus: .indexed, completedDepth: 2)
        try await rig.store.upsertMedium(medium)
        medium = try #require(try await rig.store.medium(uuid: medium.uuid))
        try await rig.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "X.app", isFolder: true, isPackage: true)],
            seenAt: Date()
        )
        let access = MapAccess()
        access.listings[mount.path] = [
            ListedDirectoryEntry(name: "X.app", isDirectory: true, isPackage: true, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
        ]
        let source = ScriptedChangeSource()
        let watcher = ChangeWatcher(store: rig.store, access: access, appState: rig.app)
        let volume = VolumeInfo(
            mountPath: mount.path,
            name: "PKG",
            fsType: "apfs",
            volumeTotalBytes: 10,
            volumeFreeBytes: 1,
            diskSizeBytes: nil,
            volumeUUID: nil,
            createdAt: nil,
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: nil,
            model: nil,
            isTimeMachineSnapshot: false
        )
        var reconciled = false
        watcher.onFullReconcile = { _, _ in reconciled = true }
        watcher.quietInterval = .milliseconds(50)
        watcher.start(mediumID: medium.uuid, volume: volume, source: source)
        let inner = app.appendingPathComponent("Contents/Info.plist").path
        source.emit(VolumeChange(path: inner, eventID: 9, itemCreated: true))
        let listed = try await waitForPackage(timeoutMs: 5_000) {
            access.listCount[mount.path] == 1 ? true : nil
        }
        #expect(listed == true)
        #expect(!reconciled)
    }

    private func waitForPackage(timeoutMs: Int, _ body: () async throws -> Bool?) async throws -> Bool? {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1_000)
        while Date() < deadline {
            if let value = try await body() { return value }
            try await Task.sleep(for: .milliseconds(25))
        }
        return try await body()
    }
}

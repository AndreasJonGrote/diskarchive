//
//  ChangeWatcherTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
/// Seriell: feste Quiet-Intervalle + gemeinsame Temp-/CPU-Last machen Parallel-Flakes (Aufgabe 140, bug.0.4.044).
@Suite(.serialized) @MainActor struct ChangeWatcherTests {
    @Test func newFileAppearsAfterQuiet() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = [ListedDirectoryEntry(name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 3, modifiedAt: Date())]
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 7))
        // bug.0.4.044: auf Bedingung warten, Obergrenze 10 s (feste 800 ms war unter Parallel-Last zu knapp).
        let parent = try await waitFor(timeoutMs: 10_000) {
            try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"])
        }
        let names = try await waitFor(timeoutMs: 10_000) {
            let n = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).map(\.name)
            return n == ["neu.txt"] ? n : nil
        }
        #expect(names == ["neu.txt"])
    }

    @Test func severalEventsInOneFolderReadOnce() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = [ListedDirectoryEntry(name: "a.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil)]
        rig.watcher.quietInterval = .milliseconds(80)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/a.txt", eventID: 1))
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/b.txt", eventID: 2))
        // bug.0.3.8.007: erst auf das Lesen warten, dann 3× Ruheintervall nachsehen, ob ein zweites Lesen folgt —
        // sonst beweist der Test „nur einmal“ nicht. Beide Ereignisse liegen vor dem ersten Flush im Puffer.
        let listed = await waitUntil { rig.access.listCount(for: "/Volumes/DISK/A") >= 1 }
        #expect(listed)
        try await Task.sleep(for: .milliseconds(240))
        #expect(rig.access.listCount(for: "/Volumes/DISK/A") == 1)
    }

    @Test func liveRenamePairKeepsFolderAndFavorite() async throws {
        let rig = try await watchRig()
        let parentA = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: parentA,
            entries: [ScannedEntry(name: "Alt", isFolder: true)],
            seenAt: Date()
        )
        let folder = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parentA).first { $0.name == "Alt" })
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: folder.id,
            entries: [ScannedEntry(name: "kind.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        let childBefore = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: folder.id).first)
        try await rig.store.setFavorite(itemID: folder.id, true)
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "Neu",
                isDirectory: true,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: nil,
                modifiedAt: nil
            ),
        ]
        rig.access.listings["/Volumes/DISK/A/Neu"] = [
            ListedDirectoryEntry(
                name: "kind.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        rig.watcher.pathExistsForLiveRename = { $0 == "/Volumes/DISK/A/Neu" }
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(
            VolumeChange(path: "/Volumes/DISK/A/Alt", eventID: 30, itemRemoved: true, itemRenamed: true)
        )
        rig.source.emit(
            VolumeChange(path: "/Volumes/DISK/A/Neu", eventID: 31, itemCreated: true, itemRenamed: true)
        )
        let back = try await waitFor(timeoutMs: 800) { () async throws -> StoredItem? in
            guard let row = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parentA).first(where: { $0.name == "Neu" }),
                  row.id == folder.id,
                  row.isFavorite,
                  row.isFolder else { return nil }
            let child = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: row.id).first
            guard child?.id == childBefore.id, child?.depth == childBefore.depth else { return nil }
            return row
        }
        #expect(back.id == folder.id)
    }

    @Test func liveRenamePairMovesFolderAndShiftsChildDepth() async throws {
        let rig = try await watchRig()
        let parentA = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: parentA,
            entries: [
                ScannedEntry(name: "Alt", isFolder: true),
                ScannedEntry(name: "Sub", isFolder: true),
            ],
            seenAt: Date()
        )
        let folder = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parentA).first { $0.name == "Alt" })
        let parentSub = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A", "Sub"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: folder.id,
            entries: [ScannedEntry(name: "kind.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        let childBefore = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: folder.id).first)
        let depthBefore = childBefore.depth
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "Sub",
                isDirectory: true,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: nil,
                modifiedAt: nil
            ),
        ]
        rig.access.listings["/Volumes/DISK/A/Sub"] = [
            ListedDirectoryEntry(
                name: "Alt",
                isDirectory: true,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: nil,
                modifiedAt: nil
            ),
        ]
        rig.access.listings["/Volumes/DISK/A/Sub/Alt"] = [
            ListedDirectoryEntry(
                name: "kind.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        rig.watcher.pathExistsForLiveRename = { $0 == "/Volumes/DISK/A/Sub/Alt" }
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(
            VolumeChange(path: "/Volumes/DISK/A/Alt", eventID: 32, itemRemoved: true, itemRenamed: true)
        )
        rig.source.emit(
            VolumeChange(path: "/Volumes/DISK/A/Sub/Alt", eventID: 33, itemCreated: true, itemRenamed: true)
        )
        let moved = try await waitFor(timeoutMs: 800) { () async throws -> StoredItem? in
            guard let row = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parentSub).first(where: { $0.name == "Alt" }),
                  row.id == folder.id else { return nil }
            let child = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: row.id).first
            guard child?.depth == depthBefore + 1 else { return nil }
            return row
        }
        #expect(moved.id == folder.id)
    }

    @Test func liveRenamePairKeepsRowAndFavoriteWithoutFileID() async throws {
        let rig = try await watchRig()
        let parent = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: parent,
            entries: [ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        let file = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).first)
        try await rig.store.setFavorite(itemID: file.id, true)
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "neu.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        rig.watcher.pathExistsForLiveRename = { $0 == "/Volumes/DISK/A/neu.txt" }
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(
            VolumeChange(path: "/Volumes/DISK/A/keep.txt", eventID: 20, itemRemoved: true, itemRenamed: true)
        )
        rig.source.emit(
            VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 21, itemCreated: true, itemRenamed: true)
        )
        let back = try await waitFor(timeoutMs: 800) { () async throws -> StoredItem? in
            guard let row = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).first,
                  row.name == "neu.txt",
                  row.id == file.id,
                  row.isFavorite else { return nil }
            return row
        }
        #expect(back.id == file.id)
    }

    /// Sabotage: Clash wieder `allowGone: false` → rot.
    @Test func liveRenameReplacesGoneTargetName() async throws {
        let rig = try await watchRig()
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "ghost.txt", isFolder: false, sizeBytes: 2),
            ],
            seenAt: Date()
        )
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        let keep = try #require(
            try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil).first { $0.name == "keep.txt" }
        )
        let ok = try await rig.store.applyLiveRename(
            mediumUUID: rig.medium.uuid,
            mountPath: "/Volumes/DISK",
            fromPath: "/Volumes/DISK/keep.txt",
            toPath: "/Volumes/DISK/ghost.txt"
        )
        #expect(ok)
        let rows = try await itemRowsNamed(
            store: rig.store,
            mediumUUID: rig.medium.uuid,
            parentID: nil,
            name: "ghost.txt"
        )
        #expect(rows.count == 1)
        #expect(rows[0].status == 0)
        #expect(rows[0].id == keep.id)
    }

    @Test func liveRenameFailsWhenActiveNameClashes() async throws {
        let rig = try await watchRig()
        let parent = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: parent,
            entries: [
                ScannedEntry(name: "first.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "second.txt", isFolder: false, sizeBytes: 2),
            ],
            seenAt: Date()
        )
        let ok = try await rig.store.applyLiveRename(
            mediumUUID: rig.medium.uuid,
            mountPath: "/Volumes/DISK",
            fromPath: "/Volumes/DISK/A/second.txt",
            toPath: "/Volumes/DISK/A/first.txt"
        )
        #expect(!ok)
    }

    @Test func deletedFileIsRemovedAndRestoredWithFavorite() async throws {
        let rig = try await watchRig()
        let parent = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: parent,
            entries: [ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1, fileID: "9001")],
            seenAt: Date()
        )
        let file = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).first)
        try await rig.store.setFavorite(itemID: file.id, true)
        rig.access.listings["/Volumes/DISK/A"] = []
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/keep.txt", eventID: 3, itemRemoved: true))
        let removed = await waitUntil(timeout: 3) {
            (try? await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent))?.isEmpty == true
        }
        #expect(removed)
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "keep.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil,
                fileID: 9001
            ),
        ]
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/keep.txt", eventID: 4, itemCreated: true))
        let restored = await waitUntil(timeout: 3) {
            guard let back = try? await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent),
                  let first = back.first else { return false }
            return first.id == file.id && first.isFavorite
        }
        #expect(restored)
    }

    @Test func appleDoubleAndExcludedNamesDoNothing() async throws {
        let rig = try await watchRig()
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/._Resource", eventID: 1))
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/node_modules/index.js", eventID: 2))
        try await Task.sleep(for: .milliseconds(150))
        #expect(rig.access.listCountIsEmpty())
    }

    @Test func eventPastScanDepthRereadsOnlyTheLastLevel() async throws {
        let rig = try await watchRig()
        rig.app.appSettings.scanDepth = 2
        rig.access.listings["/Volumes/DISK/A"] = [ListedDirectoryEntry(name: "B", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil)]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/B/deep/file.txt", eventID: 9))
        // bug.0.3.8.007: erst auf das Lesen von A warten; danach kurz (3× Ruheintervall) nachsehen, damit ein
        // fälschliches Lesen von B oder ein zweites Lesen von A noch auffallen kann. Ein Ereignis = ein Flush.
        let listed = await waitUntil { rig.access.listCount(for: "/Volumes/DISK/A") >= 1 }
        #expect(listed)
        try await Task.sleep(for: .milliseconds(90))
        #expect(rig.access.listCount(for: "/Volumes/DISK/A") == 1)
        #expect(rig.access.listCount(for: "/Volumes/DISK/A/B") == 0)
        let root = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        #expect(!root.contains { $0.name == "file.txt" })
    }

    @Test func overflowStartsAReconcile() async throws {
        let rig = try await watchRig()
        let log = ReconcileLog()
        let service = IndexingService(store: rig.store, access: rig.access, appState: rig.app)
        rig.watcher.onFullReconcile = { id, volume in
            log.ids.append(id)
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
        }
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK", eventID: 1, mustScanSubDirs: true))
        // bug.0.3.8.007: auf den Abgleich warten statt fester 80 ms; ein Ereignis löst höchstens einen aus.
        let reconciled = await waitUntil { !log.ids.isEmpty }
        #expect(reconciled)
        #expect(log.ids == [rig.medium.uuid])
    }

    @Test func mustScanSubDirsUnderMountStartsReconcile() async throws {
        let rig = try await watchRig()
        let log = ReconcileLog()
        rig.watcher.onFullReconcile = { id, _ in log.ids.append(id) }
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/B", eventID: 2, mustScanSubDirs: true))
        // bug.0.3.8.007: auf den Abgleich warten statt fester 80 ms; ein Ereignis löst höchstens einen aus.
        let reconciled = await waitUntil { !log.ids.isEmpty }
        #expect(reconciled)
        #expect(log.ids == [rig.medium.uuid])
        #expect(rig.access.listCountIsEmpty())
    }

    @Test func mustScanSubDirsOutsideMountIsIgnored() async throws {
        let rig = try await watchRig()
        let log = ReconcileLog()
        rig.watcher.onFullReconcile = { id, _ in log.ids.append(id) }
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/anderswo/X", eventID: 3, mustScanSubDirs: true))
        try await Task.sleep(for: .milliseconds(80))
        #expect(log.ids.isEmpty)
        #expect(rig.access.listCountIsEmpty())
    }

    @Test func indexedMediumReconcilesUnknownDoesNot() async throws {
        let rig = try await SurfaceRig.make()
        let log = ReconcileLog()
        rig.coordinator.onReconcileRequested = { id, _ in log.ids.append(id) }
        let known = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000B1",
            fsType: "apfs",
            volumeTotalBytes: 10,
            name: "Bekannt",
            decision: .index,
            indexStatus: .indexed
        )
        try await rig.store.upsertMedium(known)
        await rig.coordinator.handle(.appeared(rig.volume(name: "Bekannt", uuid: known.volumeUUID)))
        #expect(log.ids == [known.uuid])
        await rig.coordinator.handle(.appeared(rig.volume(name: "Fremd", path: "/Volumes/FREMD", uuid: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000B2")))
        #expect(log.ids == [known.uuid])
        #expect(rig.app.newMediumDialogMediumID != nil)
    }

    @Test func eventCursorSurvivesReopen() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = []
        rig.watcher.quietInterval = .milliseconds(20)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/x", eventID: 42, fileSystemUUID: "UUID-1"))
        let row = try await waitFor(timeoutMs: 800) {
            let m = try await rig.store.medium(uuid: rig.medium.uuid)
            return m?.lastEventID == 42 ? m : nil
        }
        #expect(row.lastEventID == 42)
        #expect(row.fsEventsUUID == "UUID-1")
        let reopened = IndexStoreV3(database: rig.database)
        let again = try #require(try await reopened.medium(uuid: rig.medium.uuid))
        #expect(again.lastEventID == 42)
    }

    @Test func eventCursorAdvancesAfterWatcherRestart() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = []
        rig.watcher.quietInterval = .milliseconds(25)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/a.txt", eventID: 10, fileSystemUUID: "UUID-1"))
        let stored = try await waitFor(timeoutMs: 800) {
            let m = try await rig.store.medium(uuid: rig.medium.uuid)
            return m?.lastEventID == 10 ? m : nil
        }
        await rig.watcher.stop(mediumID: rig.medium.uuid)
        #expect(stored.lastEventID == 10)
        let source2 = ScriptedChangeSource()
        rig.watcher.start(
            mediumID: rig.medium.uuid,
            volume: rig.volume,
            source: source2,
            resumeFSEventsUUID: stored.fsEventsUUID,
            resumeLastEventID: stored.lastEventID ?? 0
        )
        source2.emit(VolumeChange(path: "/Volumes/DISK/A/b.txt", eventID: 11, fileSystemUUID: "UUID-1"))
        let after = try await waitFor(timeoutMs: 800) {
            let m = try await rig.store.medium(uuid: rig.medium.uuid)
            return m?.lastEventID == 11 ? m : nil
        }
        #expect(after.lastEventID == 11)
    }

    @Test func newRootFolderWithoutMountEventIndexes() async throws {
        let rig = try await watchRig()
        let log = ReconcileLog()
        rig.watcher.onFullReconcile = { id, _ in log.ids.append(id) }
        rig.access.listings["/Volumes/DISK"] = [
            ListedDirectoryEntry(name: "Neu", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
        ]
        rig.access.listings["/Volumes/DISK/Neu"] = [
            ListedDirectoryEntry(name: "a.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.quietInterval = .milliseconds(25)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/Neu/a.txt", eventID: 5))
        // bug.0.3.8.007: Standard-Zeitgrenze (10 s) statt 1,2 s.
        let ok = await waitUntil {
            guard let neu = try? await rig.store.item(mediumUUID: rig.medium.uuid, path: [], name: "Neu"),
                  neu.isFolder else { return false }
            return (try? await rig.store.item(mediumUUID: rig.medium.uuid, path: ["Neu"], name: "a.txt")) != nil
        }
        #expect(ok)
        #expect(log.ids.isEmpty)
    }

    @Test func newFolderUnderKnownParentAppearsAfterQuiet() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "Neu", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
        ]
        rig.access.listings["/Volumes/DISK/A/Neu"] = [
            ListedDirectoryEntry(name: "eins.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/Neu/eins.txt", eventID: 8))
        let names: [String] = try await waitFor(timeoutMs: 1_200) {
            guard let parent = try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]) else {
                return nil as [String]?
            }
            let n = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).map(\.name)
            return n.contains("Neu") ? n : nil
        }
        #expect(names.contains("Neu"))
    }

    @Test func unplugCancelsReconcileAndReconnectResumes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diskindex-reconcile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = BlockingListAccess()
        let app = AppState()
        let service = IndexingService(store: store, access: access, appState: app)
        let resumes = ReconcileLog()
        let reconciles = ReconcileLog()
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        service.attach(coordinator)
        coordinator.onReconcileRequested = { id, volume in
            reconciles.ids.append(id)
            service.start(mediumUUID: id, volume: volume, fromScratch: true)
        }
        coordinator.setIndexHandler { id, volume in
            resumes.ids.append(id)
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
        }
        coordinator.onIndexingInterrupted = { id in
            await service.cancel(mediumUUID: id)
        }
        let stored = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000C1",
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
        await access.entered.wait()
        await coordinator.handle(.disappeared(path: volume.mountPath))
        await access.release.signal()
        await service.waitUntilIdle(stored.uuid)
        #expect(try await store.medium(uuid: stored.uuid)?.indexStatus == .pending)
        await coordinator.handle(.appeared(volume))
        #expect(reconciles.ids == [stored.uuid])
        #expect(resumes.ids == [stored.uuid])
    }

    @Test func newFolderWithFilesIsReadAfterQuiet() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK"] = [
            ListedDirectoryEntry(name: "A", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
            ListedDirectoryEntry(name: "B", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
            ListedDirectoryEntry(name: "Neu", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
        ]
        rig.access.listings["/Volumes/DISK/Neu"] = [
            ListedDirectoryEntry(name: "eins.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
            ListedDirectoryEntry(name: "zwei.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 2, modifiedAt: nil),
        ]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/Neu", eventID: 1))
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/Neu/eins.txt", eventID: 2))
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/Neu/zwei.txt", eventID: 3))
        let names: Set<String> = try await waitFor(timeoutMs: 1_200) {
            guard let parent = try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["Neu"]) else {
                return nil as Set<String>?
            }
            let set = Set(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).map(\.name))
            return set == ["eins.txt", "zwei.txt"] ? set : nil
        }
        #expect(names == ["eins.txt", "zwei.txt"])
    }

    @Test func failedReadDoesNotTombstone() async throws {
        let rig = try await watchRig()
        let parent = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: parent,
            entries: [ScannedEntry(name: "bleibt.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        rig.access.failing = ["/Volumes/DISK/A"]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/bleibt.txt", eventID: 1))
        try await Task.sleep(for: .milliseconds(160))
        let names = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).map(\.name)
        #expect(names == ["bleibt.txt"])
    }

    @Test func rootChangeDoesNotRereadSubfolders() async throws {
        let rig = try await watchRig()
        rig.access.listings["/Volumes/DISK"] = [
            ListedDirectoryEntry(name: "A", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
            ListedDirectoryEntry(name: "B", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
            ListedDirectoryEntry(name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/neu.txt", eventID: 1))
        // bug.0.3.8.007: gewöhnliches Ereignis im Wurzelordner (kein `rootChanged`-Flag). Erst auf das Lesen der
        // Wurzel warten, dann kurz (3× Ruheintervall) nachsehen, ob fälschlich A/B gelesen werden.
        let listed = await waitUntil { rig.access.listCount(for: "/Volumes/DISK") >= 1 }
        #expect(listed)
        try await Task.sleep(for: .milliseconds(90))
        #expect(rig.access.listCount(for: "/Volumes/DISK") == 1)
        #expect(rig.access.listCount(for: "/Volumes/DISK/A") == 0)
        #expect(rig.access.listCount(for: "/Volumes/DISK/B") == 0)
    }

    @Test func reappearedFolderIsReadWithItsSubtree() async throws {
        let rig = try await watchRig()
        let rootA = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: rootA,
            entries: [
                ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "Inner", isFolder: true),
            ],
            seenAt: Date()
        )
        let inner = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A", "Inner"]))
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: inner,
            entries: [ScannedEntry(name: "note.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        let root = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: nil,
            entries: root.filter { $0.name != "A" }.map {
                ScannedEntry(name: $0.name, isFolder: $0.isFolder, sizeBytes: $0.sizeBytes)
            },
            seenAt: Date()
        )
        #expect(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]) == nil)
        rig.access.listings["/Volumes/DISK"] = [
            ListedDirectoryEntry(name: "A", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
            ListedDirectoryEntry(name: "B", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
        ]
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "keep.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
            ListedDirectoryEntry(name: "Inner", isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil),
        ]
        rig.access.listings["/Volumes/DISK/A/Inner"] = [
            ListedDirectoryEntry(name: "note.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A", eventID: 8))
        let restored = try await waitFor(timeoutMs: 10_000) {
            try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"])
        }
        // bug.0.3.9.004: „A“ entsteht beim Lesen der Wurzel, sein Inhalt erst im nächsten Schritt (Lesen von „A“),
        // „note.txt“ noch einen Schritt später. Auf den Inhalt warten statt direkt nach „A“ zu lesen.
        let childNamesArrived = try await waitUntil(timeout: 10) {
            Set(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: restored).map(\.name)) == ["Inner", "keep.txt"]
        }
        let childNames = Set(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: restored).map(\.name))
        #expect(childNamesArrived)
        #expect(childNames == ["Inner", "keep.txt"])
        let innerListed = await waitUntil(timeout: 10) { rig.access.listCount(for: "/Volumes/DISK/A/Inner") >= 1 }
        #expect(innerListed)
        let notesArrived = try await waitUntil(timeout: 10) {
            guard let noteParent = try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A", "Inner"]) else { return false }
            return try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: noteParent).map(\.name) == ["note.txt"]
        }
        let noteParent = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A", "Inner"]))
        let notes = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: noteParent).map(\.name)
        #expect(notesArrived)
        #expect(notes == ["note.txt"])
    }

    /// Pollt statt fester Sleeps — unter Parallel-Last sonst zu knapp (Aufgabe 140f).
    private func itemRowsNamed(
        store: IndexStoreV3,
        mediumUUID: UUID,
        parentID: Int64?,
        name: String
    ) async throws -> [(id: Int64, status: Int)] {
        try await store.pool.read { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, status FROM items
                    WHERE storageID = ? AND parentID IS ? AND name = ?
                    """,
                arguments: [storageID, parentID, name]
            )
            return rows.map { (id: $0["id"], status: $0["status"]) }
        }
    }

    /// bug.0.4.010: Aufrufer mit 800 ms behalten die Signatur; Untergrenze 3 s gegen Wackeln.
    private func waitFor<T>(timeoutMs: Int, _ body: () async throws -> T?) async throws -> T {
        let effectiveMs = max(timeoutMs, 3_000)
        let deadline = Date().addingTimeInterval(Double(effectiveMs) / 1_000)
        while Date() < deadline {
            if let value = try await body() { return value }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("waitFor timeout \(effectiveMs)ms")
        return try #require(try await body())
    }

    @Test func prepareFlushInvokesFileExistsOffMainThread() async throws {
        let harness = try StoreHarness.make()
        let engine = ChangeWatcherEngine(store: harness.store, access: GrantedAccess())
        final class Flag: @unchecked Sendable {
            private let lock = NSLock()
            var offMain = false
            func noteOffMain() {
                lock.lock()
                offMain = true
                lock.unlock()
            }
            var sawOffMain: Bool {
                lock.lock()
                defer { lock.unlock() }
                return offMain
            }
        }
        let flag = Flag()
        _ = await engine.prepareFlush(
            rawPaths: [],
            itemEvents: [
                ItemPathEvent(path: "/Volumes/DISK/A/old.txt", itemCreated: false, itemRemoved: true, itemRenamed: true),
                ItemPathEvent(path: "/Volumes/DISK/A/new.txt", itemCreated: true, itemRemoved: false, itemRenamed: true),
            ],
            mount: "/Volumes/DISK",
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false),
            maxDepth: nil,
            fileExists: { path in
                #if DEBUG
                if !Thread.isMainThread { flag.noteOffMain() }
                #endif
                return path.hasSuffix("new.txt")
            }
        )
        #expect(flag.sawOffMain)
    }

    /// bug.0.3.8.007: Zeitgeber aus, Prüfung als Differenz (kein absoluter Zählvergleich).
    @Test func saveCursorWritesOnlyWhenEventIDChanges() async throws {
        let rig = try await watchRig()
        rig.watcher.quietInterval = .milliseconds(80)
        rig.watcher.cursorSaveInterval = nil
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "a.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/a.txt", eventID: 10, fileSystemUUID: "UUID-1"))
        // Der Flush sichert am Ende selbst; erst wenn Stand 10 gespeichert ist und ein eigenes Sichern durch ist,
        // gilt der Ausgangswert.
        let firstSaved = await waitUntil {
            await rig.watcher.saveCursor(mediumID: rig.medium.uuid)
            return (try? await rig.store.medium(uuid: rig.medium.uuid))?.lastEventID == 10
        }
        #expect(firstSaved)
        let afterFirstSave = await rig.store.recordEventCursorCallCountForTesting

        // Dreimal sichern ohne neues Ereignis erhöht nicht.
        await rig.watcher.saveCursor(mediumID: rig.medium.uuid)
        await rig.watcher.saveCursor(mediumID: rig.medium.uuid)
        await rig.watcher.saveCursor(mediumID: rig.medium.uuid)
        #expect(await rig.store.recordEventCursorCallCountForTesting - afterFirstSave == 0)

        // Neues Ereignis + sichern erhöht.
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/b.txt", eventID: 11, fileSystemUUID: "UUID-1"))
        let secondSaved = await waitUntil {
            await rig.watcher.saveCursor(mediumID: rig.medium.uuid)
            return (try? await rig.store.medium(uuid: rig.medium.uuid))?.lastEventID == 11
        }
        #expect(secondSaved)
        #expect(await rig.store.recordEventCursorCallCountForTesting - afterFirstSave >= 1)
        await rig.watcher.stop(mediumID: rig.medium.uuid)
    }
}
}

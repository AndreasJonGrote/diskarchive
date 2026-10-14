//
//  VersionLockReadOnlyTests.swift
//  diskindexTests
//
//  Read-only-Sperre schließen (c.0.3.3.002).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized)
struct VersionLockReadOnlyTests {
    @Test @MainActor func updateNoticeClearedWhenOfferMissing() {
        let appState = AppState()
        let offer = UpdateOffer(
            currentDisplay: "0.3",
            targetDisplay: "1.0",
            targetMajorMinor: AppVersion(major: 1, minor: 0, patch: 0),
            showSkipCheckbox: true,
            showBetaCountdown: false
        )
        appState.applyVersionLockEvaluation(
            VersionLockEvaluation(
                lockState: .unlocked,
                updateOffer: offer,
                showLockBanner: false,
                mutations: VersionLockSettingsMutations()
            )
        )
        #expect(appState.updateNotice != nil)
        appState.applyVersionLockEvaluation(
            VersionLockEvaluation(
                lockState: .unlocked,
                updateOffer: nil,
                showLockBanner: false,
                mutations: VersionLockSettingsMutations()
            )
        )
        #expect(appState.updateNotice == nil)
    }

    @Test @MainActor func versionLockCancelPreservesDeferredReconcileIntent() {
        let appState = AppState()
        appState.isRuleReconcileQueueActive = true
        appState.ruleReconcileNeedsRerun = true
        appState.cancelRuleReconcileForVersionLock()
        #expect(appState.ruleReconcileDeferredWhileLocked)
        #expect(!appState.ruleReconcileNeedsRerun)
        #expect(!appState.isRuleReconcileQueueActive)

        appState.ruleReconcileDeferredWhileLocked = false
        appState.cancelRuleReconcileForTermination()
        #expect(!appState.ruleReconcileDeferredWhileLocked)
    }

    @Test @MainActor func deferredRuleReconcileRunsAfterUnlock() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("version-lock-reconcile-\(UUID().uuidString).sqlite")
        let store = try IndexStoreV3.open(at: url)
        let appState = AppState(store: store)
        appState.versionLockState = .locked(.betaExpired)
        appState.enqueueRuleReconcile()
        #expect(appState.ruleReconcileDeferredWhileLocked)
        #expect(!appState.isRuleReconcileQueueActive)

        appState.applyVersionLockEvaluation(
            VersionLockEvaluation(
                lockState: .unlocked,
                updateOffer: nil,
                showLockBanner: false,
                mutations: VersionLockSettingsMutations()
            )
        )
        #expect(!appState.ruleReconcileDeferredWhileLocked)
        await appState.waitForRuleReconcileIdle()
    }

    @Test @MainActor func forgetMediumNoOpWhenLocked() async throws {
        let rig = try await RecognitionRigForLock.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        await rig.appState.loadStoredMedia()
        let countBefore = rig.appState.media.count
        rig.appState.versionLockState = .locked(.buildExpired)
        rig.appState.forgetMedium(id: id)
        #expect(rig.appState.media.count == countBefore)
        #expect(try await rig.store.medium(uuid: id) != nil)
    }

    @Test @MainActor func updateMediumPersistNoOpWhenLocked() async throws {
        let rig = try await RecognitionRigForLock.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        await rig.appState.loadStoredMedia()
        let storedBefore = try #require(try await rig.store.medium(uuid: id))
        rig.appState.versionLockState = .locked(.apiUnreachable)
        rig.appState.updateMedium(id: id, persist: true) {
            $0.allowIndexing = !storedBefore.allowIndexing
            $0.decision = storedBefore.allowIndexing ? .dontIndex : .index
        }
        let storedAfter = try #require(try await rig.store.medium(uuid: id))
        #expect(storedAfter.allowIndexing == storedBefore.allowIndexing)
        #expect(storedAfter.decision == storedBefore.decision)
    }

    @Test @MainActor func connectKnownDoesNotWriteWhenLocked() async throws {
        let rig = try await RecognitionRigForLock.make()
        let created = Date(timeIntervalSince1970: 1_718_102_804)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000099",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "STORED_NAME",
            type: .usb,
            decision: .index,
            indexStatus: .indexed,
            fileCount: 1,
            folderCount: 0,
            completedDepth: 1
        )
        try await rig.store.upsertMedium(existing)
        var reconciled: [UUID] = []
        rig.coordinator.onReconcileRequested = { id, _ in reconciled.append(id) }
        rig.appState.versionLockState = .locked(.betaExpired)
        await rig.coordinator.handle(.appeared(rig.volume(name: "LIVE_NAME", uuid: existing.volumeUUID, created: created)))
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.name == "STORED_NAME")
        #expect(reconciled.isEmpty)
        #expect(rig.appState.medium(with: existing.uuid)?.name == "LIVE_NAME")
    }

    @Test @MainActor func versionLockCancelClearsIndexingStatus() async throws {
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
        rig.service.start(mediumUUID: mediumID, volume: rig.volume, fromScratch: true)
        let started = await waitUntil(timeout: 3) {
            rig.app.medium(with: mediumID)?.indexStatus == .indexing || rig.service.isRunActive(mediumID)
        }
        #expect(started)
        rig.app.versionLockState = .locked(.buildExpired)
        await rig.service.cancelAllActiveForVersionLock()
        let cleared = await waitUntil(timeout: 3) {
            rig.app.medium(with: mediumID)?.indexStatus != .indexing
        }
        #expect(cleared)
    }

    @Test @MainActor func watcherFlushSkipsWritesWhenLocked() async throws {
        // Scripted source statt echter FSEvents/DMG — unter Parallel-Last sonst Wackeln.
        let rig = try await watchRig()
        let mediumID = rig.medium.uuid
        rig.access.listings["/Volumes/DISK"] = [
            ListedDirectoryEntry(
                name: "live.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: mediumID, volume: rig.volume, source: rig.source)
        rig.app.versionLockState = .locked(.betaExpired)
        #expect(!rig.app.featureAccess.canWriteIndex)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/live.txt", eventID: 7, itemCreated: true))
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await rig.store.item(mediumUUID: mediumID, path: [], name: "live.txt") == nil)
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await rig.store.item(mediumUUID: mediumID, path: [], name: "live.txt") == nil)
        #expect(rig.access.listCount["/Volumes/DISK"] == nil)
    }
}

@MainActor
private enum RecognitionRigForLock {
    static func make() async throws -> RecognitionRigForLockInstance {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-lock-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccessForLock()
        let appState = AppState(store: store)
        let coordinator = MediumCoordinator(store: store, access: access, appState: appState)
        return RecognitionRigForLockInstance(store: store, appState: appState, coordinator: coordinator, access: access)
    }
}

@MainActor
private struct RecognitionRigForLockInstance {
    let store: IndexStoreV3
    let appState: AppState
    let coordinator: MediumCoordinator
    let access: ScriptedAccessForLock

    func volume(
        name: String = "ZOOM_H4E",
        path: String = "/Volumes/ZOOM_H4E",
        uuid: String? = nil,
        created: Date? = Date(timeIntervalSince1970: 1_718_102_804)
    ) -> VolumeInfo {
        VolumeInfo(
            mountPath: path,
            name: name,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 400,
            diskSizeBytes: 1_024,
            volumeUUID: uuid,
            createdAt: created,
            isRemovable: true,
            isEjectable: true,
            isInternal: true,
            isLocal: true,
            deviceProtocol: "Secure Digital",
            model: "Built In SDXC Reader",
            isTimeMachineSnapshot: false
        )
    }
}

private final class ScriptedAccessForLock: MediumAccess, @unchecked Sendable {
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

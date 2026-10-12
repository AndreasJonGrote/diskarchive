//
//  MediumRecognitionTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

struct VolumeCandidateRuleTests {
    @Test func candidateTable() {
        #expect(VolumeCandidateRule.isCandidate(input(
            path: "/Volumes/ZOOM_H4E", removable: true, ejectable: true, internal: true, fileSystem: "msdos", protocol: "Secure Digital"
        )))
        #expect(VolumeCandidateRule.isCandidate(input(
            path: "/Volumes/NO NAME", removable: true, ejectable: true, internal: false, fileSystem: "msdos", protocol: "USB"
        )))
        #expect(!VolumeCandidateRule.isCandidate(input(path: "/", removable: false, ejectable: false, internal: true, fileSystem: "apfs")))
        #expect(!VolumeCandidateRule.isCandidate(input(
            path: "/System/Volumes/Update/mnt1", removable: false, ejectable: false, internal: true, fileSystem: "apfs"
        )))
        #expect(!VolumeCandidateRule.isCandidate(input(
            path: "/private/tmp/tmp-mount-x", removable: true, ejectable: true, internal: false, fileSystem: "msdos"
        )))
        #expect(!VolumeCandidateRule.isCandidate(input(
            path: "/System/Volumes/Data/home", removable: false, ejectable: false, internal: true, fileSystem: "autofs"
        )))
        #expect(!VolumeCandidateRule.isCandidate(input(
            path: "/Volumes/Server", local: false, removable: false, ejectable: false, internal: false, fileSystem: "smbfs"
        )))
        #expect(!VolumeCandidateRule.isCandidate(input(
            path: "/Volumes/Image", removable: true, ejectable: true, internal: false, fileSystem: "apfs", protocol: "Disk Image"
        )))
    }

    @Test func debouncerCollapsesSamePathWithinOneSecond() {
        var debouncer = MountEventDebouncer()
        let start = ContinuousClock.now
        let first = debouncer.shouldEmit(path: "/Volumes/A", kind: "appeared", now: start)
        let repeatSame = debouncer.shouldEmit(path: "/Volumes/A", kind: "appeared", now: start.advanced(by: .milliseconds(500)))
        let otherKind = debouncer.shouldEmit(path: "/Volumes/A", kind: "disappeared", now: start)
        let later = debouncer.shouldEmit(path: "/Volumes/A", kind: "appeared", now: start.advanced(by: .seconds(1)))
        #expect(first)
        #expect(!repeatSame)
        #expect(otherKind)
        #expect(later)
    }

    private func input(
        path: String,
        local: Bool = true,
        removable: Bool,
        ejectable: Bool,
        internal isInternal: Bool,
        fileSystem: String,
        protocol protocolName: String? = nil
    ) -> VolumeCandidateInput {
        VolumeCandidateInput(
            path: path,
            isLocal: local,
            isRemovable: removable,
            isEjectable: ejectable,
            isInternal: isInternal,
            fileSystem: fileSystem,
            deviceProtocol: protocolName,
            isTimeMachineSnapshot: false
        )
    }
}

@MainActor
struct MediumCoordinatorTests {
    @Test func secondUnknownMediumQueuesBehindFirstUndecided() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume(name: "PLATTE_A", path: "/Volumes/PLATTE_A")))
        let first = try #require(rig.appState.newMediumDialogMediumID)
        await rig.coordinator.handle(.appeared(rig.volume(
            name: "PLATTE_B",
            path: "/Volumes/PLATTE_B",
            uuid: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            created: Date(timeIntervalSince1970: 1_718_102_900)
        )))
        #expect(rig.appState.newMediumDialogMediumID == first)
        #expect(rig.appState.pendingNewMediumDecisionIDs.count == 2)
        rig.appState.onNewMediumChoice?(first, true, false)
        await rig.coordinator.waitForChoice()
        let second = try #require(rig.appState.newMediumDialogMediumID)
        #expect(second != first)
        #expect(rig.indexRequests == [first])
    }

    @Test func unknownGrantedStoresMediumAndRequestsDialog() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let stored = try #require(try await rig.store.media().first { $0.name == "ZOOM_H4E" })
        #expect(stored.decision == .undecided)
        #expect(stored.indexStatus == .pending)
        #expect(rig.appState.newMediumDialogMediumID == stored.uuid)
        #expect(rig.appState.medium(with: stored.uuid)?.connectionStatus == .connected)
    }

    @Test func knownMediumComesOnlineWithoutDialog() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_804)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000010",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "ALT",
            type: .usb,
            decision: .index,
            indexStatus: .indexed
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "NEU", uuid: existing.volumeUUID, created: created)))
        #expect(rig.appState.newMediumDialogMediumID == nil)
        let live = try #require(rig.appState.medium(with: existing.uuid))
        #expect(live.connectionStatus == .connected)
        #expect(live.name == "NEU")
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.name == "NEU")
        #expect(stored.lastSeenAt != nil)
    }

    @Test func deniedAccessRetriesWhenAppBecomesActive() async throws {
        let rig = try await RecognitionRig.make()
        rig.access.result = .denied(reason: "NSCocoaErrorDomain 257")
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.newMediumDialogMediumID == nil)
        let failed = try #require(rig.appState.media.first { $0.name == volume.name })
        #expect(failed.indexStatus == .error)
        rig.access.result = .granted
        await rig.coordinator.applicationDidBecomeActive()
        #expect(rig.appState.newMediumDialogMediumID == failed.id)
        #expect(rig.appState.medium(with: failed.id)?.indexStatus == .pending)
    }

    @Test func deniedKnownMediumStaysClosedUntilAccessIsGranted() async throws {
        let rig = try await RecognitionRig.make()
        rig.access.result = .denied(reason: "NSCocoaErrorDomain 257")
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.media.first { $0.name == volume.name }?.id)
        #expect(rig.appState.newMediumDialogMediumID == nil)
        #expect(rig.appState.medium(with: id)?.indexStatus == .error)

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.newMediumDialogMediumID == nil)
        #expect(rig.appState.medium(with: id)?.indexStatus == .error)
        #expect(rig.appState.medium(with: id)?.connectionStatus == .connected)
        let stillDenied = try #require(try await rig.store.medium(uuid: id))
        #expect(stillDenied.indexStatus == .error)

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.newMediumDialogMediumID == id)
        #expect(rig.appState.medium(with: id)?.indexStatus == .pending)
        let recovered = try #require(try await rig.store.medium(uuid: id))
        #expect(recovered.indexStatus == .pending)
        #expect(recovered.decision == .undecided)
    }

    @Test func disappearingGoesOfflineAndKeepsRows() async throws {
        let rig = try await RecognitionRig.make()
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        #expect(rig.appState.medium(with: id)?.connectionStatus == .offline)
        #expect(try await rig.store.medium(uuid: id) != nil)
    }

    @Test func ignoredMediumDoesNotOpenDialog() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_804)
        let existing = StoredMedium(
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "ZOOM_H4E",
            type: .usb,
            decision: .ignore,
            indexStatus: .indexed,
            allowIndexing: false
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(created: created)))
        #expect(rig.appState.newMediumDialogMediumID == nil)
        #expect(rig.appState.medium(with: existing.uuid)?.connectionStatus == .connected)
    }

    @Test func forgottenVolumeShowsDialogAsPending() async throws {
        let rig = try await RecognitionRig.make()
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.forgetMedium(id: id)
        try await rig.store.deleteMedium(uuid: id)
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.newMediumDialogMediumID != nil)
        let live = try #require(rig.appState.media.first { $0.name == volume.name })
        #expect(live.indexStatus == .pending)
        #expect(live.decision == .undecided)
    }

    @Test func pauseShowsDialogButDefersIndexRequestUntilChoice() async throws {
        let rig = try await RecognitionRig.make()
        rig.appState.globalAutoIndexPaused = true
        await rig.coordinator.handle(.appeared(rig.volume()))
        #expect(rig.appState.newMediumDialogMediumID != nil)
        #expect(rig.indexRequests.isEmpty)
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        #expect(rig.indexRequests == [id])
    }

    @Test func knownIndexedMediumConnectsAndReconciles() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_804)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000011",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "NO NAME",
            type: .usb,
            decision: .index,
            indexStatus: .indexed,
            fileCount: 40,
            folderCount: 2,
            completedDepth: 2
        )
        try await rig.store.upsertMedium(existing)
        var reconciled: [UUID] = []
        rig.coordinator.onReconcileRequested = { id, _ in reconciled.append(id) }
        await rig.coordinator.handle(.appeared(rig.volume(name: "NO NAME", uuid: existing.volumeUUID, created: created)))
        let live = try #require(rig.appState.medium(with: existing.uuid))
        #expect(live.connectionStatus == .connected)
        #expect(reconciled == [existing.uuid])
    }

    @Test func knownPendingMediumRequestsIndexOnMount() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_804)
        let existing = StoredMedium(
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "PENDING",
            type: .usb,
            decision: .index,
            indexStatus: .pending
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "PENDING", created: created)))
        #expect(rig.indexRequests == [existing.uuid])
        #expect(rig.appState.medium(with: existing.uuid)?.connectionStatus == .connected)
    }

    @Test func unknownMediumAtStartupIsUndecided() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume(name: "FRISCH")))
        let stored = try #require(try await rig.store.media().first { $0.name == "FRISCH" })
        #expect(stored.decision == .undecided)
        #expect(stored.indexStatus == .pending)
        #expect(rig.appState.newMediumDialogMediumID == stored.uuid)
    }

    @Test func indexChoiceIsStoredAndRequestsIndexingOnce() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, true)
        await rig.coordinator.waitForChoice()
        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(stored.decision == .index)
        #expect(stored.rememberDecision)
        #expect(stored.indexStatus == .pending)
        #expect(rig.indexRequests == [id])
        rig.appState.onNewMediumChoice?(id, true, true)
        await rig.coordinator.waitForChoice()
        #expect(rig.indexRequests == [id])
    }
}

@MainActor
private final class RecognitionRig {
    let store: IndexStoreV3
    let access: ScriptedAccess
    let appState: AppState
    let coordinator: MediumCoordinator
    private let requests: IndexRequestLog
    var indexRequests: [UUID] { requests.ids }

    static func make() async throws -> RecognitionRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-recognition-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccess()
        let appState = AppState()
        let requests = IndexRequestLog()
        let coordinator = MediumCoordinator(
            store: store,
            access: access,
            appState: appState,
            onIndexRequested: { id, _ in requests.ids.append(id) }
        )
        return RecognitionRig(store: store, access: access, appState: appState, coordinator: coordinator, requests: requests)
    }

    private init(
        store: IndexStoreV3,
        access: ScriptedAccess,
        appState: AppState,
        coordinator: MediumCoordinator,
        requests: IndexRequestLog
    ) {
        self.store = store
        self.access = access
        self.appState = appState
        self.coordinator = coordinator
        self.requests = requests
    }

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

private final class IndexRequestLog: @unchecked Sendable {
    var ids: [UUID] = []
}

private final class ScriptedAccess: MediumAccess, @unchecked Sendable {
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

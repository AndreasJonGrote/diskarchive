//
//  NewMediumStackTests.swift
//  diskindexTests
//
//  Aufgabe c.0.3.2.002
//

import AppKit
import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
struct NewMediumStackTests {
    @Test func undecidedConnectedMediaDoesNotRequestIndexAlone() async throws {
        let rig = try await StackRecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        #expect(rig.indexRequests.isEmpty)
    }

    @Test func settingsIndexYesInvokesDecisionHook() {
        let app = AppState()
        var seen = false
        app.onMediumDecisionChanged = { _, decision, allow in
            seen = decision == .index && allow
        }
        var medium = previewMedium(0)
        medium.decision = .undecided
        medium.allowIndexing = false
        app.media = [medium]
        app.updateMedium(id: medium.id, persist: true) {
            $0.decision = .index
            $0.allowIndexing = true
        }
        #expect(seen)
    }

    @Test func closingOnePanelLeavesOtherOpen() async throws {
        let rig = try await StackRecognitionRig.make()
        rig.appState.promptPanelPlacement = .offscreen
        await rig.coordinator.handle(.appeared(rig.volume(name: "A", path: "/Volumes/A")))
        let first = try #require(rig.appState.pendingNewMediumDecisionIDs.first)
        await rig.coordinator.handle(.appeared(rig.volume(
            name: "B",
            path: "/Volumes/B",
            uuid: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            created: Date(timeIntervalSince1970: 1_718_102_900)
        )))
        let ids = rig.appState.pendingNewMediumDecisionIDs
        defer {
            for id in ids {
                AppWindowPresenter.closeNewMediumPanel(mediumID: id, appState: rig.appState, userDismissed: false)
            }
        }
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 2)
        AppWindowPresenter.closeNewMediumPanel(mediumID: first, appState: rig.appState, userDismissed: true)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 1)
    }
}
}

@MainActor
private final class StackRecognitionRig {
    let coordinator: MediumCoordinator
    let appState: AppState
    private let requests: IndexRequestLog
    var indexRequests: [UUID] { requests.ids }

    static func make() async throws -> StackRecognitionRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-stack-\(UUID().uuidString)", isDirectory: true)
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
        return StackRecognitionRig(coordinator: coordinator, appState: appState, requests: requests)
    }

    private init(coordinator: MediumCoordinator, appState: AppState, requests: IndexRequestLog) {
        self.coordinator = coordinator
        self.appState = appState
        self.requests = requests
    }

    static func makeVolume(
        name: String,
        path: String,
        uuid: String,
        created: Date
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

    func volume(
        name: String = "ZOOM_H4E",
        path: String = "/Volumes/ZOOM_H4E",
        uuid: String = "AAAAAAAA-BBBB-CCCC-DDDD-000000000010",
        created: Date = Date(timeIntervalSince1970: 1_718_102_804)
    ) -> VolumeInfo {
        Self.makeVolume(name: name, path: path, uuid: uuid, created: created)
    }
}

private final class IndexRequestLog {
    var ids: [UUID] = []
}


private final class ScriptedAccess: MediumAccess, @unchecked Sendable {
    /// bug.0.4.177: Testzugriff steht für ein eingehängtes Medium.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

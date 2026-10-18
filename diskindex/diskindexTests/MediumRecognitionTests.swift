//
//  MediumRecognitionTests.swift
//  diskindexTests
//

import AppKit
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
@Suite(.serialized)
struct MediumCoordinatorTests {
    @Test func twoUnknownMediaEachStayUndecidedUntilChoice() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume(name: "PLATTE_A", path: "/Volumes/PLATTE_A")))
        let first = try #require(rig.appState.newMediumDialogMediumID)
        await rig.coordinator.handle(.appeared(rig.volume(
            name: "PLATTE_B",
            path: "/Volumes/PLATTE_B",
            uuid: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            created: Date(timeIntervalSince1970: 1_718_102_900)
        )))
        #expect(rig.appState.pendingNewMediumDecisionIDs.count == 2)
        #expect(rig.indexRequests.isEmpty)
        AppWindowPresenter.syncNewMediumPanels(appState: rig.appState)
        #expect(AppWindowPresenter.openNewMediumPanelCount == 2)
        rig.appState.onNewMediumChoice?(first, true, false)
        await rig.coordinator.waitForChoice()
        #expect(rig.indexRequests == [first])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.appState)
        #expect(AppWindowPresenter.openNewMediumPanelCount == 1)
    }

    @Test func dontIndexWithoutIndexKeepsPendingStatus() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, false, true)
        await rig.coordinator.waitForChoice()
        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(stored.decision == .dontIndex)
        #expect(stored.indexStatus == .pending)
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
            rememberDecision: true,
            indexStatus: .indexed
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "NEU", uuid: existing.volumeUUID, created: created)))
        #expect(rig.appState.newMediumDialogMediumID == nil)
        #expect(!rig.appState.needsNewMediumDialog(existing.uuid))
        let live = try #require(rig.appState.medium(with: existing.uuid))
        #expect(live.connectionStatus == .connected)
        #expect(live.name == "NEU")
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.name == "NEU")
        #expect(stored.lastSeenAt != nil)
    }

    @Test func reprobeKeepsIndexDecisionWithoutDialog() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_900)
        let uuid = "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"
        var existing = StoredMedium(
            volumeUUID: uuid,
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "STICK",
            type: .usb,
            decision: .index,
            rememberDecision: true,
            indexStatus: .indexed,
            lastIndexedAt: Date()
        )
        try await rig.store.upsertMedium(existing)
        existing = try #require(try await rig.store.medium(uuid: existing.uuid))
        let volume = rig.volume(name: "STICK", path: "/Volumes/STICK", uuid: uuid, created: created)
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(volume))
        existing.indexStatus = .error
        try await rig.store.updateMedium(uuid: existing.uuid, existing)
        rig.appState.updateMedium(id: existing.uuid) { $0.indexStatus = .error }
        await rig.coordinator.applicationDidBecomeActive()
        #expect(rig.appState.newMediumDialogMediumID == nil)
        #expect(rig.appState.medium(with: existing.uuid)?.decision == .index)
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.decision == .index)
    }

    @Test func reprobeKeepsDontIndexDecision() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_901)
        let uuid = "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"
        var existing = StoredMedium(
            volumeUUID: uuid,
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "NOIDX",
            type: .usb,
            decision: .dontIndex,
            rememberDecision: true,
            indexStatus: .indexed
        )
        try await rig.store.upsertMedium(existing)
        existing = try #require(try await rig.store.medium(uuid: existing.uuid))
        let volume = rig.volume(name: "NOIDX", path: "/Volumes/NOIDX", uuid: uuid, created: created)
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(volume))
        existing.indexStatus = .error
        try await rig.store.updateMedium(uuid: existing.uuid, existing)
        await rig.coordinator.applicationDidBecomeActive()
        #expect(rig.appState.newMediumDialogMediumID == nil)
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.decision == .dontIndex)
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
            // `.ignore` wird als „Nicht indizieren“ gespeichert; ohne „merken“ fragte der Dialog erneut (todo.0.4.026).
            rememberDecision: true,
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

    @Test func reprobeAfterErrorWithPriorIndexRequestsReconcile() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_103_000)
        let uuid = "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE"
        var existing = StoredMedium(
            volumeUUID: uuid,
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "RECON",
            type: .usb,
            decision: .index,
            indexStatus: .indexed,
            lastIndexedAt: Date()
        )
        try await rig.store.upsertMedium(existing)
        let volume = rig.volume(name: "RECON", path: "/Volumes/RECON", uuid: uuid, created: created)
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(volume))
        existing.indexStatus = .error
        try await rig.store.updateMedium(uuid: existing.uuid, existing)
        rig.appState.updateMedium(id: existing.uuid) { $0.indexStatus = .error }
        let reconcilesBefore = rig.reconcileRequests.count
        await rig.coordinator.applicationDidBecomeActive()
        #expect(rig.reconcileRequests.count == reconcilesBefore + 1)
        #expect(rig.indexRequests.isEmpty)
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .indexed)
    }

    @Test func choiceAfterDisappearIsOffline() async throws {
        let rig = try await RecognitionRig.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        await rig.coordinator.handle(.disappeared(path: rig.volume().mountPath))
        rig.appState.onNewMediumChoice?(id, true, true)
        await rig.coordinator.waitForChoice()
        #expect(rig.appState.medium(with: id)?.connectionStatus == .offline)
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

    // MARK: - todo.0.4.026 „Für dieses Medium merken“

    /// Ohne Haken: beim nächsten Anschließen erscheint der Dialog wieder, vorbelegt mit der letzten Entscheidung;
    /// bis zur Antwort gilt sie weiter. Gleiche Antwort mit Haken → gemerkt, danach kein Dialog mehr.
    @Test func decisionWithoutRememberAsksAgainOnNextConnect() async throws {
        let rig = try await RecognitionRig.make()
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)
        #expect(rig.indexRequests == [id])
        #expect(!rig.appState.needsNewMediumDialog(id))

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.pendingNewMediumDecisionIDs.contains(id), "Dialog ohne Haken nicht erneut angefordert")
        #expect(rig.appState.needsNewMediumDialog(id))
        let live = try #require(rig.appState.medium(with: id))
        #expect(live.decision == .index, "Vorbelegung = letzte Entscheidung")
        #expect(NewMediumDetectedDialog.isAskedAgain(live))
        #expect(!NewMediumDetectedDialog.defaultsToDontIndex(live))
        // Letzte Entscheidung gilt bis zur Antwort weiter (Lauf angefordert).
        #expect(rig.indexRequests == [id, id])

        // Gleiche Antwort, jetzt mit Haken: nur „merken“ ändert sich, kein weiterer Lauf.
        rig.appState.onNewMediumChoice?(id, true, true)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)
        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(stored.rememberDecision)
        #expect(stored.decision == .index)
        #expect(stored.indexStatus == .pending)
        #expect(rig.indexRequests == [id, id])

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "gemerkte Entscheidung fragt erneut")
        #expect(!rig.appState.needsNewMediumDialog(id))
    }

    /// Indiziertes Medium ohne Haken: Abgleich wie bisher und Dialog; „Indizieren“ erneut → Status bleibt
    /// „indiziert“, kein Erstlauf.
    @Test func askedAgainIndexedMediumKeepsIndexOnSameAnswer() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_805)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000026",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "MERKEN",
            type: .usb,
            decision: .index,
            indexStatus: .indexed,
            fileCount: 40,
            folderCount: 2,
            lastIndexedAt: Date(),
            completedDepth: 2
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "MERKEN", uuid: existing.volumeUUID, created: created)))
        #expect(rig.reconcileRequests == [existing.uuid])
        #expect(rig.appState.needsNewMediumDialog(existing.uuid))

        rig.appState.onNewMediumChoice?(existing.uuid, true, true)
        await rig.coordinator.waitForChoice()
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .indexed, "gleiche Antwort setzt den Index auf Erstlauf zurück")
        #expect(stored.rememberDecision)
        #expect(rig.indexRequests.isEmpty)
        #expect(rig.appState.medium(with: existing.uuid)?.indexStatus == .indexed)
    }

    /// Korrektur 1 (Regel 18): erneut gefragtes Medium bekommt über die echte Kette ein Panel (Warteschlange →
    /// `syncNewMediumPanels`), und die Menüleiste meldet eine offene Entscheidung.
    @Test func askedAgainMediumOpensPanel() async throws {
        let rig = try await RecognitionRig.make()
        let volume = rig.volume(name: "PANEL", path: "/Volumes/PANEL")
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)
        AppWindowPresenter.syncNewMediumPanels(appState: rig.appState)
        #expect(AppWindowPresenter.openNewMediumPanelCount == 0)
        defer {
            AppWindowPresenter.closeNewMediumPanel(mediumID: id, appState: rig.appState, userDismissed: false)
        }

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.newMediumDialogMediumID == id, "erneut gefragtes Medium nicht vorne in der Warteschlange")
        #expect(rig.appState.hasPendingNewMediumDecisions)
        AppWindowPresenter.syncNewMediumPanels(appState: rig.appState)
        #expect(AppWindowPresenter.openNewMediumPanelCount == 1, "kein Panel für das erneut gefragte Medium")
    }

    /// Korrektur 2: erneut gefragt, unvollständiger Index (`pending`, Ebene 2) → „Indizieren“ lässt den Status.
    @Test func askedAgainPendingIndexKeepsStatusOnIndex() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_806)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000126",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "HALB",
            type: .usb,
            decision: .index,
            indexStatus: .pending,
            fileCount: 10,
            folderCount: 2,
            completedDepth: 2
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "HALB", uuid: existing.volumeUUID, created: created)))
        #expect(rig.appState.needsNewMediumDialog(existing.uuid))
        rig.appState.onNewMediumChoice?(existing.uuid, true, true)
        await rig.coordinator.waitForChoice()
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .pending, "unvollständiger Index als „indiziert“ markiert")
        #expect(stored.rememberDecision)
    }

    /// Korrektur 3: Reprobe nach Fehler in derselben Sitzung fragt nicht noch einmal.
    @Test func reprobeDoesNotAskAgainInSameSession() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_807)
        let uuid = "AAAAAAAA-BBBB-CCCC-DDDD-000000000226"
        var existing = StoredMedium(
            volumeUUID: uuid,
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "REPROBE",
            type: .usb,
            decision: .index,
            indexStatus: .indexed,
            lastIndexedAt: Date()
        )
        try await rig.store.upsertMedium(existing)
        existing = try #require(try await rig.store.medium(uuid: existing.uuid))
        let volume = rig.volume(name: "REPROBE", path: "/Volumes/REPROBE", uuid: uuid, created: created)
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.needsNewMediumDialog(existing.uuid))
        rig.appState.onNewMediumChoice?(existing.uuid, true, false)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(existing.uuid)

        existing = try #require(try await rig.store.medium(uuid: existing.uuid))
        existing.indexStatus = .error
        try await rig.store.updateMedium(uuid: existing.uuid, existing)
        rig.appState.updateMedium(id: existing.uuid) { $0.indexStatus = .error }
        let reconcilesBefore = rig.reconcileRequests.count
        await rig.coordinator.applicationDidBecomeActive()
        #expect(rig.reconcileRequests.count == reconcilesBefore + 1)
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(existing.uuid), "Reprobe fragt erneut")
    }

    /// Mit Haken: beim nächsten Anschließen kein Dialog.
    @Test func decisionWithRememberDoesNotAskAgain() async throws {
        let rig = try await RecognitionRig.make()
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, false, true)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.medium(with: id)?.connectionStatus == .connected)
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "gemerkte Entscheidung fragt erneut")
        #expect(!rig.appState.needsNewMediumDialog(id))
        #expect(rig.indexRequests.isEmpty)
        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(stored.decision == .dontIndex)
        #expect(stored.rememberDecision)
    }

    /// Erneut gefragt nach „Nicht indizieren“: Vorbelegung Nein; Antwort „Indizieren“ fordert den Lauf an, eine
    /// spätere Antwort „Nicht indizieren“ stoppt wie die Änderung in 05/06.
    @Test func askedAgainDontIndexCanBeChangedInTheDialog() async throws {
        let rig = try await RecognitionRig.make()
        var changes: [(UUID, StoredIndexDecision, Bool)] = []
        rig.appState.onMediumDecisionChanged = { id, decision, allow in changes.append((id, decision, allow)) }
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, false, false)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.needsNewMediumDialog(id))
        let live = try #require(rig.appState.medium(with: id))
        #expect(NewMediumDetectedDialog.defaultsToDontIndex(live), "Vorbelegung nicht die letzte Entscheidung (Nein)")
        #expect(rig.indexRequests.isEmpty, "„Nicht indizieren“ gilt bis zur Antwort weiter")

        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)
        #expect(rig.indexRequests == [id])
        let indexed = try #require(try await rig.store.medium(uuid: id))
        #expect(indexed.decision == .index)
        #expect(!indexed.rememberDecision)

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.needsNewMediumDialog(id))
        rig.appState.onNewMediumChoice?(id, false, true)
        await rig.coordinator.waitForChoice()
        let refused = try #require(try await rig.store.medium(uuid: id))
        #expect(refused.decision == .dontIndex)
        #expect(refused.rememberDecision)
        let stop = try #require(changes.last)
        #expect(stop.0 == id && stop.1 == .dontIndex && stop.2 == false, "Nein im erneuten Dialog stoppt nicht")
    }

    /// Entscheidung in 05/06, während der erneute Dialog offen ist → Dialog beantwortet (aus der Warteschlange).
    @Test func settingsDecisionAnswersAskedAgainDialog() async throws {
        let rig = try await RecognitionRig.make()
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        rig.appState.completeNewMediumDecision(id)
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.needsNewMediumDialog(id))

        rig.appState.updateMedium(id: id, persist: true) {
            $0.decision = .dontIndex
            $0.allowIndexing = false
        }
        #expect(!rig.appState.needsNewMediumDialog(id))
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id))
    }
}

@MainActor
private final class RecognitionRig {
    let store: IndexStoreV3
    let access: ScriptedAccess
    let appState: AppState
    let coordinator: MediumCoordinator
    private let requests: IndexRequestLog
    private let reconciles: IndexRequestLog
    var indexRequests: [UUID] { requests.ids }
    var reconcileRequests: [UUID] { reconciles.ids }

    static func make() async throws -> RecognitionRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-recognition-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccess()
        let appState = AppState()
        let requests = IndexRequestLog()
        let reconciles = IndexRequestLog()
        let coordinator = MediumCoordinator(
            store: store,
            access: access,
            appState: appState,
            onIndexRequested: { id, _ in requests.ids.append(id) }
        )
        coordinator.onReconcileRequested = { id, _ in reconciles.ids.append(id) }
        coordinator.start(events: AsyncStream { _ in })
        return RecognitionRig(
            store: store,
            access: access,
            appState: appState,
            coordinator: coordinator,
            requests: requests,
            reconciles: reconciles
        )
    }

    private init(
        store: IndexStoreV3,
        access: ScriptedAccess,
        appState: AppState,
        coordinator: MediumCoordinator,
        requests: IndexRequestLog,
        reconciles: IndexRequestLog
    ) {
        self.store = store
        self.access = access
        self.appState = appState
        self.coordinator = coordinator
        self.requests = requests
        self.reconciles = reconciles
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

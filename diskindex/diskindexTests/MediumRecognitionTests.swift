//
//  MediumRecognitionTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import GRDB
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

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct MediumCoordinatorTests {
    @Test func twoUnknownMediaEachStayUndecidedUntilChoice() async throws {
        let rig = try await RecognitionRig.make()
        // Regel 18/119: Lage vor dem Ereignis; die Kette `requestDialog` → Panel läuft von allein.
        rig.appState.promptPanelPlacement = .offscreen
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
        let ids = rig.appState.pendingNewMediumDecisionIDs
        defer {
            for id in ids {
                AppWindowPresenter.closeNewMediumPanel(mediumID: id, appState: rig.appState, userDismissed: false)
            }
        }
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 2)
        // bug.0.4.119 (Regel 18): derselbe Einstieg wie der Knopf „Indizieren“ des Dialogs (Antwort, Panel, Stapel).
        NewMediumDetectedDialog.applyChoice(mediumID: first, allowIndexing: true, remember: false, appState: rig.appState)
        await rig.coordinator.waitForChoice()
        #expect(rig.indexRequests == [first])
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 1)
    }

    /// bug.0.4.117: Erkennungs-Panels aus Tests liegen außerhalb des Bildschirms, werden nicht Key, und ein
    /// zweiter `AppState` schließt die Panels des ersten nicht.
    @Test func newMediumPanelsStayOffscreenAndPerAppState() async throws {
        let rig = try await RecognitionRig.make()
        rig.appState.promptPanelPlacement = .offscreen
        await rig.coordinator.handle(.appeared(rig.volume(name: "PLATTE_A", path: "/Volumes/PLATTE_A")))
        await rig.coordinator.handle(.appeared(rig.volume(
            name: "PLATTE_B",
            path: "/Volumes/PLATTE_B",
            uuid: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            created: Date(timeIntervalSince1970: 1_718_102_900)
        )))
        let ids = rig.appState.pendingNewMediumDecisionIDs
        defer {
            for id in ids {
                AppWindowPresenter.closeNewMediumPanel(mediumID: id, appState: rig.appState, userDismissed: false)
            }
        }
        let panels = NSApp.windows.filter { $0 is KeyablePanel && $0.isVisible }
        #expect(panels.count >= 2)
        for panel in panels {
            let onScreen = NSScreen.screens.contains { $0.frame.intersects(panel.frame) }
            #expect(!onScreen, "Panel im sichtbaren Bereich: \(panel.frame)")
            #expect(!panel.isKeyWindow)
        }
        let other = AppState()
        other.promptPanelPlacement = .offscreen
        AppWindowPresenter.syncNewMediumPanels(appState: other)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 2, "fremder AppState schließt Panels")
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

    /// bug.0.4.126: Fehlerstatus nach abgebrochenem Erstlauf (Ebene 1 fertig, nie bis zum Ende) → beim Anschließen
    /// `.pending` und Erstlauf mit Fortschritt, kein bloßer Abgleich.
    @Test func errorAfterIncompleteFirstRunResumesAsPending() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_903)
        let uuid = "EEEEEEEE-1260-EEEE-EEEE-EEEEEEEEEEEE"
        let existing = StoredMedium(
            volumeUUID: uuid,
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "HALB",
            type: .usb,
            decision: .index,
            rememberDecision: true,
            indexStatus: .error
        )
        try await rig.store.upsertMedium(existing)
        try await rig.store.completeLayer(mediumUUID: existing.uuid, depth: 1)
        let before = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(before.lastIndexedAt != nil, "Voraussetzung: Ebene 1 setzt lastIndexedAt")
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(rig.volume(name: "HALB", path: "/Volumes/HALB", uuid: uuid, created: created)))
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .pending)
        #expect(rig.indexRequests.contains(existing.uuid), "kein Erstlauf mit Fortschritt")
        #expect(!rig.reconcileRequests.contains(existing.uuid))
    }

    /// bug.0.4.151: vollständig gewesen (`firstIndexedAt`), später Lücke → nach Fehlerstatus beim Anschließen `.pending`
    /// und Lauf mit Nachlesen der Lücke, kein bloßer Abgleich.
    @Test func errorAfterLaterGapResumesAsPending() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_904)
        let uuid = "EEEEEEEE-1510-EEEE-EEEE-EEEEEEEEEEEE"
        let existing = StoredMedium(
            volumeUUID: uuid, volumeCreatedAt: created, fsType: "apfs", volumeTotalBytes: 1_000, name: "LUECKE",
            type: .usb, decision: .index, rememberDecision: true, indexStatus: .error
        )
        try await rig.store.upsertMedium(existing)
        let token = UUID()
        #expect(try await rig.store.beginIndexing(mediumUUID: existing.uuid, token: token))
        #expect(try await rig.store.finishIndexing(
            mediumUUID: existing.uuid, token: token, status: .pending, firstIndexedAt: nil, ranToEnd: true
        ))
        try await rig.store.pool.write { db in
            try db.execute(sql: "UPDATE storages SET firstIndexedAt = 1700000000, indexStatus = ? WHERE uuid = ?",
                           arguments: [MediumCodecV3.code(.error), MediumCodecV3.data(existing.uuid)])
        }
        rig.access.result = .granted
        await rig.coordinator.handle(.appeared(rig.volume(name: "LUECKE", path: "/Volumes/LUECKE", uuid: uuid, created: created)))
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .pending, "Lücke durch Fehlerstatus verdeckt")
        #expect(rig.indexRequests.contains(existing.uuid))
        #expect(!rig.reconcileRequests.contains(existing.uuid))
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
            firstIndexedAt: Date(),
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
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "Koordinator beantwortet den Dialog nicht")
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
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "Koordinator beantwortet den Dialog nicht")
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
        rig.appState.promptPanelPlacement = .offscreen
        let volume = rig.volume(name: "PANEL", path: "/Volumes/PANEL")
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 1, "kein Panel beim ersten Anschließen")
        // bug.0.4.119 (Regel 18): derselbe Einstieg wie der Knopf „Indizieren“ des Dialogs (Antwort, Panel, Stapel).
        NewMediumDetectedDialog.applyChoice(mediumID: id, allowIndexing: true, remember: false, appState: rig.appState)
        await rig.coordinator.waitForChoice()
        #expect(rig.indexRequests == [id], "Koordinator beantwortet den Dialog nicht")
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 0)
        defer {
            AppWindowPresenter.closeNewMediumPanel(mediumID: id, appState: rig.appState, userDismissed: false)
        }

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.newMediumDialogMediumID == id, "erneut gefragtes Medium nicht vorne in der Warteschlange")
        #expect(rig.appState.hasPendingNewMediumDecisions)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.appState) == 1, "kein Panel für das erneut gefragte Medium")
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

    /// bug.0.4.128: Der Erkennungs-Dialog ändert den Index-Status nicht. Unvollständiger Index (Ebene 1, `.pending`),
    /// „Nicht indizieren“, nicht gemerkt → „Ja“ setzt fort (`.pending`, Lauf angefordert), kein „indiziert“.
    @Test func dialogYesKeepsIncompleteIndexPending() async throws {
        let rig = try await RecognitionRig.make()
        let created = Date(timeIntervalSince1970: 1_718_102_808)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000128",
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "TEIL",
            type: .usb,
            decision: .dontIndex,
            rememberDecision: false,
            indexStatus: .pending,
            fileCount: 10,
            folderCount: 2,
            completedDepth: 1
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "TEIL", uuid: existing.volumeUUID, created: created)))
        #expect(rig.appState.needsNewMediumDialog(existing.uuid))
        rig.appState.onNewMediumChoice?(existing.uuid, true, false)
        await rig.coordinator.waitForChoice()
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .pending, "unvollständiger Index als „indiziert“ markiert")
        #expect(rig.indexRequests.contains(existing.uuid), "kein Lauf angefordert")
    }

    /// bug.0.4.128: globale Pause, „Nein“ → der unvollständige Index bleibt `.pending` („x % indiziert“).
    @Test func dialogNoKeepsIncompleteIndexPending() async throws {
        let rig = try await RecognitionRig.make()
        rig.appState.globalAutoIndexPaused = true
        let created = Date(timeIntervalSince1970: 1_718_102_809)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000228",
            volumeCreatedAt: created,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: "TEIL2",
            type: .usb,
            decision: .dontIndex,
            rememberDecision: false,
            indexStatus: .pending,
            fileCount: 10,
            folderCount: 2,
            completedDepth: 1
        )
        try await rig.store.upsertMedium(existing)
        await rig.coordinator.handle(.appeared(rig.volume(name: "TEIL2", uuid: existing.volumeUUID, created: created)))
        #expect(rig.appState.needsNewMediumDialog(existing.uuid))
        rig.appState.onNewMediumChoice?(existing.uuid, false, false)
        await rig.coordinator.waitForChoice()
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.indexStatus == .pending, "„Nein“ markiert unvollständigen Index als „indiziert“")
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
            firstIndexedAt: Date(),
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
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(existing.uuid), "Koordinator beantwortet den Dialog nicht")

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
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "Koordinator beantwortet den Dialog nicht")

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
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "Koordinator beantwortet den Dialog nicht")

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.needsNewMediumDialog(id))
        let live = try #require(rig.appState.medium(with: id))
        #expect(NewMediumDetectedDialog.defaultsToDontIndex(live), "Vorbelegung nicht die letzte Entscheidung (Nein)")
        #expect(rig.indexRequests.isEmpty, "„Nicht indizieren“ gilt bis zur Antwort weiter")

        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "Koordinator beantwortet den Dialog nicht")
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
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "Koordinator beantwortet den Dialog nicht")
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

    // MARK: - bug.0.4.075 Änderung in 05/06 gilt als gemerkt

    /// Dialog ohne Haken, beim nächsten Anschließen erneut gefragt; der Nutzer ändert die Entscheidung in 05/06
    /// (gleicher Weg wie `RegistryTableRow`/`MediumDetailModalView`) → gemerkt, danach kein Dialog mehr.
    @Test func settingsDecisionIsRememberedAndNextConnectDoesNotAsk() async throws {
        let rig = try await RecognitionRig.make(attachStore: true)
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.needsNewMediumDialog(id), "ohne Haken nicht erneut gefragt")

        rig.appState.updateMedium(id: id, persist: true) {
            $0.decision = .dontIndex
            $0.allowIndexing = false
        }
        let written = try await waitUntil(timeout: 5) {
            guard rig.appState.pendingMediumWrites[id] == nil else { return false }
            return try await rig.store.medium(uuid: id)?.decision == .dontIndex
        }
        #expect(written, "Entscheidung aus 05/06 nicht geschrieben")
        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(stored.rememberDecision, "Änderung in 05/06 nicht als gemerkt gespeichert")

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(rig.appState.medium(with: id)?.connectionStatus == .connected)
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "nach Änderung in 05/06 erneut gefragt")
        #expect(!rig.appState.needsNewMediumDialog(id))
    }

    /// bug.0.4.080 d): Medium in 05/06 entschieden, aber nicht (mehr) in der Datenbank → `writeMedium` kehrt früh
    /// zurück und entfernt die Marke `userDecisionIDs`. Ebenso, wenn die Oberfläche das Medium nicht kennt.
    @Test func writeMediumForUnknownMediumDropsDecisionMark() async throws {
        let rig = try await RecognitionRig.make(attachStore: true)
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        try await rig.store.deleteMedium(uuid: id)
        try #require(try await rig.store.medium(uuid: id) == nil)

        rig.appState.updateMedium(id: id, persist: true) {
            $0.decision = .dontIndex
            $0.allowIndexing = false
        }
        let dropped = await waitUntil(timeout: 5) {
            rig.appState.pendingMediumWrites[id] == nil && rig.appState.userDecisionIDs[id] == nil
        }
        #expect(dropped, "Marke bleibt nach Write ohne Datenbankeintrag: \(String(describing: rig.appState.userDecisionIDs[id]))")

        let unknown = UUID()
        rig.appState.userDecisionIDs[unknown] = 1
        await rig.appState.writeMedium(unknown)
        #expect(rig.appState.userDecisionIDs[unknown] == nil, "Marke bleibt für ein unbekanntes Medium")
    }

    /// Neues Medium, Dialog offen; der Nutzer entscheidet in 05/06 statt im Dialog → gemerkt; der Dialog ist
    /// beantwortet und kommt beim nächsten Anschließen nicht wieder.
    @Test func settingsDecisionForUndecidedMediumIsRemembered() async throws {
        let rig = try await RecognitionRig.make(attachStore: true)
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)

        rig.appState.updateMedium(id: id, persist: true) {
            $0.decision = .index
            $0.allowIndexing = true
        }
        #expect(!rig.appState.needsNewMediumDialog(id))
        let written = try await waitUntil(timeout: 5) {
            guard rig.appState.pendingMediumWrites[id] == nil else { return false }
            return try await rig.store.medium(uuid: id)?.rememberDecision == true
        }
        #expect(written, "Entscheidung aus 05/06 nicht als gemerkt gespeichert")
        #expect(try await rig.store.medium(uuid: id)?.decision == .index)

        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        await rig.coordinator.handle(.appeared(volume))
        #expect(!rig.appState.pendingNewMediumDecisionIDs.contains(id), "nach Änderung in 05/06 erneut gefragt")
    }

    /// Beenden direkt nach der Änderung in 05/06: der Entscheidungs-Write wird abgelöst, das Ausschreiben beim
    /// Beenden merkt die Entscheidung trotzdem.
    @Test func settingsDecisionFlushedAtTerminationIsRemembered() async throws {
        let rig = try await RecognitionRig.make(attachStore: true)
        let volume = rig.volume()
        await rig.coordinator.handle(.appeared(volume))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        rig.appState.onNewMediumChoice?(id, true, false)
        await rig.coordinator.waitForChoice()

        rig.appState.updateMedium(id: id, persist: true) {
            $0.decision = .dontIndex
            $0.allowIndexing = false
        }
        await rig.appState.flushPendingWritesForTermination()
        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(stored.decision == .dontIndex)
        #expect(stored.rememberDecision, "beim Beenden ausgeschriebene Änderung aus 05/06 nicht gemerkt")
    }

    /// Korrektur (Prüfung 075): ein ausstehender Favoriten-Write vor der Dialog-Antwort ohne Haken macht die Antwort
    /// nicht zu „gemerkt“ und schreibt die alte Entscheidung der Oberfläche nicht zurück (Bereich bug.0.4.043).
    @Test func pendingFavoriteWriteDoesNotRememberDialogAnswer() async throws {
        let rig = try await RecognitionRig.make(attachStore: true)
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)

        rig.appState.updateMedium(id: id, persist: true) { $0.isFavorite.toggle() }
        #expect(rig.appState.pendingMediumWrites[id] != nil, "Favoriten-Write steht nicht aus")
        rig.appState.onNewMediumChoice?(id, false, false)
        await rig.coordinator.waitForChoice()
        await rig.appState.flushMediumEdits()

        let stored = try #require(try await rig.store.medium(uuid: id))
        #expect(!stored.rememberDecision, "Dialog ohne Haken durch fremden Write als gemerkt gespeichert")
        #expect(stored.decision == .dontIndex, "alte Entscheidung der Oberfläche zurückgeschrieben")
        #expect(stored.isFavorite)
    }
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

    /// `attachStore`: AppState schreibt Nutzerfelder (05/06) in den Store wie in der App (bug.0.4.075).
    static func make(attachStore: Bool = false) async throws -> RecognitionRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-recognition-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccess()
        let appState = attachStore ? AppState(store: store) : AppState()
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

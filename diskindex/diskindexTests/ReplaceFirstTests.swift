//
//  ReplaceFirstTests.swift
//  diskindexTests
//
//  bug.0.4.215 — „Ersetzt dieses Medium?“ zuerst und allein (Konzept `medien.md` Punkt 3, „Neu formatiert“, „Reihenfolge“):
//  genau ein Offline-Medium gleichen Namens → nur die Rückfrage, kein Erkennungspanel. „Altes vergessen“ übernimmt die
//  Entscheidung des alten (gemerkt → kein Erkennungsdialog), „Behalten“ → der Erkennungsdialog folgt. Echter Weg über den
//  `MediumCoordinator`, Panels außerhalb des Bildschirms (Regel 10).
//

import AppKit
import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct ReplaceFirstTests {
    @MainActor
    private struct Rig {
        let app: AppState
        let store: IndexStoreV3
        let wired: WiredRig
        let directory: URL

        var newMediumPanels: Int { AppWindowPresenter.openNewMediumPanelCount(for: app) }
        var replacePanelOpen: Bool { AppWindowPresenter.replaceMediumPromptPanel(for: app) != nil }

        @MainActor
        func close() {
            for medium in app.media {
                AppWindowPresenter.closeNewMediumPanel(mediumID: medium.id, appState: app, userDismissed: false)
            }
            AppWindowPresenter.closePromptPanels(for: app)
            app.prepareForTermination()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// Offline-Medien „USB“ mit der Entscheidung „Indizieren“ (je eigene Volume-UUID: kein Treffer für das neue Volume).
    private static func rig(offline: [Bool]) async throws -> (Rig, [UUID]) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-replace-first-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        var oldIDs: [UUID] = []
        for remember in offline {
            let medium = StoredMedium(
                volumeUUID: UUID().uuidString, fsType: "apfs", volumeTotalBytes: 1_000, name: "USB", type: .usb,
                decision: .index, rememberDecision: remember, indexStatus: .indexed
            )
            try await store.upsertMedium(medium)
            oldIDs.append(medium.uuid)
        }
        let app = AppState(store: store)
        app.promptPanelPlacement = .offscreen
        await app.loadStoredMedia()
        let wired = WiredRig(store: store, access: GrantedAccess(), app: app)
        return (Rig(app: app, store: store, wired: wired, directory: directory), oldIDs)
    }

    /// Das neue Medium „USB“ erscheint; seine ID (das einzige nicht offline).
    private static func plugNew(_ rig: Rig, name: String = "USB") async throws -> UUID {
        await rig.wired.coordinator.handle(.appeared(testVolume(path: "/Volumes/\(name)", name: name)))
        return try #require(rig.app.media.first { $0.connectionStatus == .connected }?.id, "neues Medium fehlt")
    }

    /// 1: gemerkt „Indizieren“ → nur die Rückfrage; „Altes vergessen“ → altes weg, Entscheidung übernommen, Lauf, kein Panel.
    @Test func rememberedDecisionIsAdoptedWithoutRecognitionDialog() async throws {
        let (rig, oldIDs) = try await Self.rig(offline: [true])
        defer { rig.close() }
        let newID = try await Self.plugNew(rig)
        #expect(rig.app.replaceMediumPrompt == ReplaceMediumPrompt(newID: newID, oldID: oldIDs[0], name: "USB"))
        #expect(rig.replacePanelOpen, "Rückfrage-Panel nicht offen")
        #expect(rig.newMediumPanels == 0, "Erkennungspanel vor der Rückfrage")
        #expect(rig.app.newMediumDialogMediumID == nil, "Erkennungsdialog wartet nicht auf die Rückfrage")

        rig.app.resolveReplaceMediumPrompt(forgetOld: true)
        await rig.wired.coordinator.waitForChoice()
        #expect(rig.app.medium(with: oldIDs[0]) == nil, "altes Medium nicht vergessen")
        let gone = await waitUntil { (try? await rig.store.medium(uuid: oldIDs[0])) == nil }
        #expect(gone)
        let stored = try #require(try await rig.store.medium(uuid: newID))
        #expect(stored.decision == .index && stored.rememberDecision, "Entscheidung nicht übernommen: \(stored.decision)")
        #expect(rig.app.medium(with: newID)?.decision == .index)
        let started = await waitUntil { !rig.wired.starts(newID).isEmpty }
        #expect(started, "kein Lauf angefordert")
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(rig.newMediumPanels == 0 && rig.app.newMediumDialogMediumID == nil, "Erkennungsdialog trotz gemerkter Entscheidung")
    }

    /// 2: nicht gemerkt → nach „Altes vergessen“ das Erkennungspanel.
    @Test func unrememberedDecisionStillAsks() async throws {
        let (rig, oldIDs) = try await Self.rig(offline: [false])
        defer { rig.close() }
        let newID = try await Self.plugNew(rig)
        #expect(rig.newMediumPanels == 0)
        rig.app.resolveReplaceMediumPrompt(forgetOld: true)
        await rig.wired.coordinator.waitForChoice()
        #expect(rig.app.medium(with: oldIDs[0]) == nil)
        #expect(rig.app.newMediumDialogMediumID == newID, "kein Erkennungsdialog nach „Altes vergessen“")
        #expect(rig.newMediumPanels == 1, "Erkennungspanel nicht offen")
        #expect(rig.app.medium(with: newID)?.decision == .index, "Vorbelegung nicht die alte Entscheidung")
    }

    /// 3: „Behalten“ → das Erkennungspanel, das alte bleibt.
    @Test func keepShowsTheRecognitionDialog() async throws {
        let (rig, oldIDs) = try await Self.rig(offline: [true])
        defer { rig.close() }
        let newID = try await Self.plugNew(rig)
        #expect(rig.newMediumPanels == 0)
        rig.app.resolveReplaceMediumPrompt(forgetOld: false)
        await rig.wired.coordinator.waitForChoice()
        #expect(rig.app.newMediumDialogMediumID == newID, "kein Erkennungsdialog nach „Behalten“")
        #expect(rig.newMediumPanels == 1)
        #expect(rig.app.medium(with: oldIDs[0]) != nil)
        #expect(try await rig.store.medium(uuid: oldIDs[0]) != nil)
        #expect(rig.app.medium(with: newID)?.decision == .undecided)
    }

    /// Selbstprüfung: dasselbe Medium bei offener Rückfrage umgesteckt → weiter nur die Rückfrage, kein Erkennungspanel.
    @Test func replugWhileAskingKeepsOnlyThePrompt() async throws {
        let (rig, oldIDs) = try await Self.rig(offline: [true])
        defer { rig.close() }
        let volume = testVolume(path: "/Volumes/USB", name: "USB")
        await rig.wired.coordinator.handle(.appeared(volume))
        let newID = try #require(rig.app.replaceMediumPrompt?.newID, "keine Rückfrage")
        let store = rig.store
        try #require(await waitUntil { (try? await store.medium(uuid: newID)) != nil })
        await rig.wired.coordinator.handle(.disappeared(path: "/Volumes/USB"))
        await rig.wired.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { rig.app.medium(with: newID)?.connectionStatus == .connected }, "nicht wieder angeschlossen")
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(rig.app.replaceMediumPrompt == ReplaceMediumPrompt(newID: newID, oldID: oldIDs[0], name: "USB"))
        #expect(rig.newMediumPanels == 0 && rig.app.newMediumDialogMediumID == nil, "Erkennungsdialog neben der Rückfrage")
    }

    /// 4: Gegenprobe – kein gleichnamiges Offline-Medium → sofort das Erkennungspanel.
    @Test func withoutNamesakeTheRecognitionDialogComesAtOnce() async throws {
        let (rig, _) = try await Self.rig(offline: [true])
        defer { rig.close() }
        let newID = try await Self.plugNew(rig, name: "STICK")
        #expect(rig.app.replaceMediumPrompt == nil)
        #expect(rig.app.newMediumDialogMediumID == newID)
        #expect(rig.newMediumPanels == 1)
    }

    /// 5: Gegenprobe – zwei Offline-Medien „USB“ → keine Rückfrage.
    @Test func twoNamesakesAskNothing() async throws {
        let (rig, _) = try await Self.rig(offline: [true, true])
        defer { rig.close() }
        let newID = try await Self.plugNew(rig)
        #expect(rig.app.replaceMediumPrompt == nil)
        #expect(!rig.replacePanelOpen)
        #expect(rig.app.newMediumDialogMediumID == newID)
        #expect(rig.newMediumPanels == 1)
    }
}
}

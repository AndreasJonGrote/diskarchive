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
    private static func rig(
        offline: [Bool],
        defaults: AppStateStore? = nil,
        access: any MediumAccess = GrantedAccess(),
        volumeUUIDs: [String]? = nil
    ) async throws -> (Rig, [UUID]) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-replace-first-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        var oldIDs: [UUID] = []
        for (index, remember) in offline.enumerated() {
            let medium = StoredMedium(
                volumeUUID: volumeUUIDs?[index] ?? UUID().uuidString, fsType: "apfs", volumeTotalBytes: 1_000, name: "USB",
                type: .usb, decision: .index, rememberDecision: remember, indexStatus: .indexed
            )
            try await store.upsertMedium(medium)
            oldIDs.append(medium.uuid)
        }
        let rig = await start(store: store, directory: directory, defaults: defaults, access: access)
        return (rig, oldIDs)
    }

    /// App-Start auf vorhandener Datenbank und vorhandenem App-Zustand (Neustart, bug.0.4.232).
    private static func start(store: IndexStoreV3, directory: URL, defaults: AppStateStore?, access: any MediumAccess) async -> Rig {
        let app = AppState(store: store, defaults: defaults)
        app.promptPanelPlacement = .offscreen
        await app.loadStoredMedia()
        let wired = WiredRig(store: store, access: access, app: app)
        return Rig(app: app, store: store, wired: wired, directory: directory)
    }

    /// Panels und Zustand der alten Instanz schließen, Datenbank und App-Zustand bleiben.
    private static func restart(_ rig: Rig, defaults: AppStateStore) async -> Rig {
        for medium in rig.app.media {
            AppWindowPresenter.closeNewMediumPanel(mediumID: medium.id, appState: rig.app, userDismissed: false)
        }
        AppWindowPresenter.closePromptPanels(for: rig.app)
        rig.app.prepareForTermination()
        return await start(store: rig.store, directory: rig.directory, defaults: defaults, access: GrantedAccess())
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

    /// bug.0.4.232: „Behalten“ gilt für dieses Paar dauerhaft – Erkennungsdialog offen gelassen, abgezogen, wieder
    /// angesteckt und nach einem Neustart: keine Rückfrage mehr, nur der Erkennungsdialog.
    @Test func keepIsRememberedForThisPair() async throws {
        let defaults = AppStateStore()
        let (first, _) = try await Self.rig(offline: [true], defaults: defaults)
        let volume = testVolume(path: "/Volumes/USB", name: "USB")
        await first.wired.coordinator.handle(.appeared(volume))
        let newID = try #require(first.app.replaceMediumPrompt?.newID, "keine Rückfrage beim ersten Anstecken")
        first.app.resolveReplaceMediumPrompt(forgetOld: false)
        await first.wired.coordinator.waitForChoice()
        #expect(first.app.newMediumDialogMediumID == newID)

        await first.wired.coordinator.handle(.disappeared(path: volume.mountPath))
        await first.wired.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { first.app.medium(with: newID)?.connectionStatus == .connected }, "nicht wieder angeschlossen")
        #expect(first.app.replaceMediumPrompt == nil, "Rückfrage nach „Behalten“ wieder da")
        #expect(first.app.newMediumDialogMediumID == newID, "kein Erkennungsdialog nach dem Wiederanstecken")

        let second = await Self.restart(first, defaults: defaults)
        defer { second.close() }
        await second.wired.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { second.app.medium(with: newID)?.connectionStatus == .connected }, "nach Neustart nicht angeschlossen")
        #expect(second.app.replaceMediumPrompt == nil, "Rückfrage nach Neustart wieder da")
        #expect(second.app.newMediumDialogMediumID == newID, "kein Erkennungsdialog nach Neustart")
    }

    /// bug.0.4.233: Start mit dem bekannten und einem neuen „USB“, das neue zuerst verarbeitet → keine Rückfrage zum
    /// eingehängten bekannten, Erkennungsdialog für das neue; das bekannte ist danach angeschlossen.
    @Test func startWithBothNamesakesMountedAsksNothing() async throws {
        let knownUUID = UUID().uuidString
        let access = MountedByUUIDAccess(["/Volumes/USB 1": knownUUID])
        let (rig, oldIDs) = try await Self.rig(offline: [true], access: access, volumeUUIDs: [knownUUID])
        defer { rig.close() }
        rig.wired.coordinator.mountedVolumePaths = { ["/Volumes/USB", "/Volumes/USB 1"] }
        let newVolume = testVolume(path: "/Volumes/USB", name: "USB")
        access.add(path: newVolume.mountPath, uuid: try #require(newVolume.volumeUUID))
        await rig.wired.coordinator.handle(.appeared(newVolume))
        let newID = try #require(rig.app.media.first { $0.connectionStatus == .connected }?.id, "neues Medium fehlt")
        #expect(rig.app.replaceMediumPrompt == nil, "Rückfrage zu einem eingehängten Medium")
        #expect(!rig.replacePanelOpen)
        #expect(rig.app.newMediumDialogMediumID == newID, "kein Erkennungsdialog für das neue")

        await rig.wired.coordinator.handle(.appeared(testVolume(path: "/Volumes/USB 1", name: "USB", uuid: knownUUID)))
        #expect(rig.app.medium(with: oldIDs[0])?.connectionStatus == .connected, "bekanntes Medium nicht angeschlossen")
        #expect(rig.app.replaceMediumPrompt == nil)
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

/// bug.0.4.233: Ein Medium gilt unter einem Pfad als eingehängt, wenn dort seine Volume-UUID liegt.
private final class MountedByUUIDAccess: MediumAccess, @unchecked Sendable {
    private let lock = NSLock()
    private var uuidByPath: [String: String]

    init(_ uuidByPath: [String: String]) {
        self.uuidByPath = uuidByPath
    }

    func add(path: String, uuid: String) {
        lock.withLock { uuidByPath[path] = uuid }
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool {
        let uuid = lock.withLock { uuidByPath[mountPath] }
        return uuid != nil && uuid?.uppercased() == medium.volumeUUID?.uppercased()
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

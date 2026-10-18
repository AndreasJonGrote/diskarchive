//
//  MediumIdentityTests.swift
//  diskindexTests
//
//  bug.0.4.031 — Klone (a), Volume-Umbenennung (b), Rückfrage „Ersetzt dieses Medium?“ (c, Logik über den echten Weg).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct MediumIdentityTests {
    /// a) Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, der erste bleibt unverändert.
    @Test func cloneWithSameVolumeUUIDGetsItsOwnMedium() async throws {
        let store = try freshStore()
        let shared = UUID().uuidString
        let first = testVolume(path: "/Volumes/USB", name: "USB", uuid: shared)
        let clone = testVolume(path: "/Volumes/USB 1", name: "USB", uuid: shared)
        let app = AppState(store: store)
        let rig = WiredRig(store: store, access: GrantedAccess(), app: app)

        await rig.coordinator.handle(.appeared(first))
        let firstID = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(firstID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(!app.pendingNewMediumDecisionIDs.contains(firstID), "Koordinator beantwortet den Dialog nicht")
        let firstBefore = try #require(try await store.medium(uuid: firstID))

        await rig.coordinator.handle(.appeared(clone))
        let cloneID = try #require(app.newMediumDialogMediumID)
        #expect(cloneID != firstID)
        #expect(rig.coordinator.volume(for: firstID)?.mountPath == "/Volumes/USB")
        #expect(rig.coordinator.volume(for: cloneID)?.mountPath == "/Volumes/USB 1")
        #expect(rig.coordinator.connectedVolumes().filter { $0.id == firstID }.count == 1)
        let firstAfter = try #require(try await store.medium(uuid: firstID))
        #expect(firstAfter.decision == firstBefore.decision)
        #expect(firstAfter.name == firstBefore.name)
        #expect(firstAfter.indexStatus == firstBefore.indexStatus)
        #expect(try await store.media().count == 2)

        // Klon ab- und wieder anstecken, während das Original steckt → er findet seine eigene Zeile, keine dritte.
        app.onNewMediumChoice?(cloneID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(!app.pendingNewMediumDecisionIDs.contains(cloneID), "Koordinator beantwortet den Dialog nicht")
        await rig.coordinator.handle(.disappeared(path: "/Volumes/USB 1"))
        await rig.coordinator.handle(.appeared(clone))
        #expect(rig.coordinator.volume(for: cloneID)?.mountPath == "/Volumes/USB 1")
        #expect(rig.coordinator.volume(for: firstID)?.mountPath == "/Volumes/USB")
        #expect(app.newMediumDialogMediumID == nil)
        #expect(try await store.media().count == 2)
    }

    /// b) Rename-Event → `volume(for:)` liefert den neuen Pfad, genau ein Abgleich unter dem neuen Pfad, danach Watcher
    /// mit dem neuen Volume; ein `rootChanged` aus der neuen Quelle startet nichts mehr; Unmount unter dem neuen Pfad
    /// setzt offline.
    @Test func renameRekeysPathReconcilesOnceAndUnmountSetsOffline() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let shared = UUID().uuidString
        let before = testVolume(path: "/Volumes/OLD", name: "TEST", uuid: shared)
        let oldMount = MemoryVolume(mountPath: "/Volumes/OLD")
        oldMount.file("a.txt")
        let newMount = MemoryVolume(mountPath: "/Volumes/NEU")
        newMount.file("a.txt")
        _ = try await harness.run(access: oldMount, maxDepth: nil, fromScratch: true, volume: before)
        try await harness.store.recordIdentity(mediumUUID: id, before.identity)

        let sources = WatchSources()
        let app = AppState(store: harness.store)
        var rigRef: WiredRig?
        let rig = WiredRig(store: harness.store, access: RunGateAccess([oldMount, newMount]) { _ in false }, app: app) { mediumID, volume in
            rigRef?.startScripted(mediumID, volume, sources: sources)
        }
        rigRef = rig
        await rig.coordinator.handle(.appeared(before))
        let settled = await waitUntil { sources.paths(for: id) == ["/Volumes/OLD"] && !rig.service.isRunActive(id) }
        #expect(settled)
        #expect(rig.starts(id) == [false])

        let after = testVolume(path: "/Volumes/NEU", name: "NEU", uuid: shared)
        await rig.coordinator.handle(.renamed(oldPath: "/Volumes/OLD", volume: after))
        #expect(rig.coordinator.volume(for: id)?.mountPath == "/Volumes/NEU")
        #expect(rig.coordinator.connectedVolumes().count == 1)
        #expect(app.medium(with: id)?.name == "NEU")
        #expect(try await harness.store.medium(uuid: id)?.name == "NEU")
        let rewatched = await waitUntil { sources.paths(for: id) == ["/Volumes/OLD", "/Volumes/NEU"] && !rig.service.isRunActive(id) }
        #expect(rewatched)
        #expect(rig.starts(id) == [false, false])
        #expect(newMount.listed.contains("/Volumes/NEU"))

        let source = try #require(sources.latest(for: id))
        source.emit(VolumeChange(path: "/Volumes/NEU", eventID: 50, rootChanged: true))
        // Positives Signal: der Watcher hat das Ereignis verarbeitet (Ereignisstand 50 gespeichert).
        let ingested = await waitUntil {
            await rig.watcher.saveCursor(mediumID: id)
            return (try? await harness.store.medium(uuid: id))?.lastEventID == 50
        }
        #expect(ingested)
        try await Task.sleep(for: .milliseconds(200))
        await rig.service.waitUntilIdle(id)
        #expect(rig.starts(id) == [false, false])

        await rig.coordinator.handle(.disappeared(path: "/Volumes/NEU"))
        #expect(app.medium(with: id)?.connectionStatus == .offline)
        #expect(rig.coordinator.volume(for: id) == nil)
        await rig.watcher.stop(mediumID: id)
    }

    /// Abziehen: `rootChanged` kommt, solange das Medium noch eingehängt ist (vor dem Aushängen) → kein Abgleich,
    /// Status nicht „Fehler“; danach `.disappeared` → offline.
    @Test func rootChangedWhilePullingStartsNoReconcile() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let volume = testVolume(path: "/Volumes/ZIEH", name: "TEST")
        let mount = MemoryVolume(mountPath: "/Volumes/ZIEH")
        mount.file("a.txt")
        _ = try await harness.run(access: mount, maxDepth: nil, fromScratch: true, volume: volume)
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)

        let sources = WatchSources()
        let app = AppState(store: harness.store)
        var rigRef: WiredRig?
        let rig = WiredRig(store: harness.store, access: mount, app: app) { mediumID, volume in
            rigRef?.startScripted(mediumID, volume, sources: sources)
        }
        rigRef = rig
        await rig.coordinator.handle(.appeared(volume))
        let settled = await waitUntil { sources.paths(for: id) == ["/Volumes/ZIEH"] && !rig.service.isRunActive(id) }
        #expect(settled)
        #expect(rig.starts(id) == [false])

        // Stick ist weg: Lesen schlägt fehl; FSEvents meldet die Wurzel, bevor macOS das Aushängen meldet.
        mount.failRoot(with: CocoaError(.fileReadNoSuchFile))
        let source = try #require(sources.latest(for: id))
        source.emit(VolumeChange(path: "/Volumes/ZIEH", eventID: 60, rootChanged: true))
        let ingested = await waitUntil {
            await rig.watcher.saveCursor(mediumID: id)
            return (try? await harness.store.medium(uuid: id))?.lastEventID == 60
        }
        #expect(ingested)
        try await Task.sleep(for: .milliseconds(200))
        await rig.service.waitUntilIdle(id)
        #expect(rig.starts(id) == [false])
        #expect(try await harness.store.medium(uuid: id)?.indexStatus == .indexed)

        await rig.coordinator.handle(.disappeared(path: "/Volumes/ZIEH"))
        #expect(app.medium(with: id)?.connectionStatus == .offline)
        #expect(app.medium(with: id)?.indexStatus != .error)
        #expect(rig.starts(id) == [false])
    }

    /// a) Klon allein gesteckt (Nutzer 17.10.): beide Medien bekannt, keiner eingehängt → das zuletzt gesehene verbindet
    /// sich, kein neues Medium; zweimal wiederholt bleibt die Zahl gleich.
    @Test func cloneAloneConnectsTheMostRecentlySeenMedium() async throws {
        let store = try freshStore()
        let shared = UUID().uuidString
        let original = testVolume(path: "/Volumes/USB", name: "USB", uuid: shared)
        let clone = testVolume(path: "/Volumes/USB 1", name: "USB", uuid: shared)
        let app = AppState(store: store)
        let rig = WiredRig(store: store, access: GrantedAccess(), app: app)

        await rig.coordinator.handle(.appeared(original))
        let originalID = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(originalID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(!app.pendingNewMediumDecisionIDs.contains(originalID), "Koordinator beantwortet den Dialog nicht")
        await rig.coordinator.handle(.appeared(clone))
        let cloneID = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(cloneID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(!app.pendingNewMediumDecisionIDs.contains(cloneID), "Koordinator beantwortet den Dialog nicht")
        #expect(try await store.media().count == 2)

        // Erst das Original ab, in der nächsten Sekunde der Klon: der Klon ist zuletzt gesehen (`lastSeenAt` in s).
        await rig.coordinator.handle(.disappeared(path: "/Volumes/USB"))
        try await sleepIntoNextSecond()
        await rig.coordinator.handle(.disappeared(path: "/Volumes/USB 1"))
        #expect(rig.coordinator.connectedVolumes().isEmpty)

        for _ in 0..<2 {
            await rig.coordinator.handle(.appeared(clone))
            #expect(rig.coordinator.volume(for: cloneID)?.mountPath == "/Volumes/USB 1")
            #expect(rig.coordinator.volume(for: originalID) == nil)
            #expect(app.newMediumDialogMediumID == nil)
            #expect(try await store.media().count == 2)
            #expect(app.media.count == 2)
            await rig.coordinator.handle(.disappeared(path: "/Volumes/USB 1"))
        }
    }

    private func sleepIntoNextSecond() async throws {
        let now = Date().timeIntervalSince1970
        try await Task.sleep(for: .milliseconds(Int((1 - (now - now.rounded(.down))) * 1_000) + 50))
    }

    /// b) Umbenennung während eines laufenden Laufs → Lauf abgebrochen, als Abgleich unter dem neuen Pfad neu gestartet.
    @Test func renameDuringRunRestartsTheRunUnderTheNewPath() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let shared = UUID().uuidString
        let before = testVolume(path: "/Volumes/OLD", name: "TEST", uuid: shared)
        let after = testVolume(path: "/Volumes/NEU", name: "TEST", uuid: shared)
        try await harness.store.recordIdentity(mediumUUID: id, before.identity)
        let oldMount = MemoryVolume(mountPath: "/Volumes/OLD")
        oldMount.file("x/a.txt")
        let newMount = MemoryVolume(mountPath: "/Volumes/NEU")
        newMount.file("x/a.txt")
        let access = RunGateAccess([oldMount, newMount]) { $0 == "/Volumes/OLD/x" }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)

        await rig.coordinator.handle(.appeared(before))
        let held = await waitUntil { await access.heldCount() >= 1 }
        try #require(held)
        #expect(rig.starts(id) == [false])

        await rig.coordinator.handle(.renamed(oldPath: "/Volumes/OLD", volume: after))
        let finished = await waitUntil { rig.starts(id).count == 2 && !rig.service.isRunActive(id) }
        #expect(finished)
        #expect(rig.starts(id) == [false, false])
        #expect(newMount.listed.contains("/Volumes/NEU/x"))
        let stored = try #require(try await harness.store.medium(uuid: id))
        #expect(stored.indexStatus == .indexed)
        await access.open()
    }

    /// c) Offline-Medium „USB“ + neues Medium „USB“ → nach der Entscheidung im Dialog die Rückfrage; „Behalten“ → beide bleiben.
    @Test func namesakeOfOfflineMediumAsksAndKeepLeavesBoth() async throws {
        let store = try freshStore()
        let old = try await offlineMedium(named: "USB", in: store)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        let rig = WiredRig(store: store, access: GrantedAccess(), app: app)

        await rig.coordinator.handle(.appeared(testVolume(path: "/Volumes/USB", name: "USB")))
        let newID = try #require(app.newMediumDialogMediumID)
        #expect(app.replaceMediumPrompt == nil)
        app.onNewMediumChoice?(newID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(app.replaceMediumPrompt == ReplaceMediumPrompt(newID: newID, oldID: old.uuid, name: "USB"))

        app.resolveReplaceMediumPrompt(forgetOld: false)
        #expect(app.replaceMediumPrompt == nil)
        try await Task.sleep(for: .milliseconds(200))
        #expect(app.medium(with: old.uuid) != nil)
        #expect(app.medium(with: newID) != nil)
        #expect(try await store.medium(uuid: old.uuid) != nil)
    }

    /// c) „Altes vergessen“ → altes Medium weg aus Liste und Store, das neue bleibt.
    @Test func namesakeForgetOldRemovesOnlyTheOldMedium() async throws {
        let store = try freshStore()
        let old = try await offlineMedium(named: "USB", in: store)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        let rig = WiredRig(store: store, access: GrantedAccess(), app: app)

        await rig.coordinator.handle(.appeared(testVolume(path: "/Volumes/USB", name: "USB")))
        let newID = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(newID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(app.replaceMediumPrompt?.oldID == old.uuid)

        app.resolveReplaceMediumPrompt(forgetOld: true)
        #expect(app.medium(with: old.uuid) == nil)
        let gone = await waitUntil { (try? await store.medium(uuid: old.uuid)) == nil }
        #expect(gone)
        #expect(app.medium(with: newID) != nil)
        #expect(try await store.medium(uuid: newID) != nil)
    }

    /// c) Zwei Offline-„USB“ → keine Rückfrage.
    @Test func twoOfflineNamesakesAskNothing() async throws {
        let store = try freshStore()
        _ = try await offlineMedium(named: "USB", in: store)
        _ = try await offlineMedium(named: "USB", in: store)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        let rig = WiredRig(store: store, access: GrantedAccess(), app: app)

        await rig.coordinator.handle(.appeared(testVolume(path: "/Volumes/USB", name: "USB")))
        let newID = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(newID, false, true)
        await rig.coordinator.waitForChoice()
        #expect(app.replaceMediumPrompt == nil)
        #expect(app.media.count == 3)
    }

    private func freshStore() throws -> IndexStoreV3 {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-identity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        return IndexStoreV3(database: database)
    }

    /// Bekanntes, nicht angeschlossenes Medium mit eigener Volume-UUID (kein Treffer für das neue Volume).
    private func offlineMedium(named name: String, in store: IndexStoreV3) async throws -> StoredMedium {
        let medium = StoredMedium(
            volumeUUID: UUID().uuidString,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            name: name,
            type: .usb,
            decision: .index,
            indexStatus: .indexed
        )
        try await store.upsertMedium(medium)
        return medium
    }
}

/// Watcher-Starts mit skriptbarer Quelle je Start (statt FSEvents), Reihenfolge der Pfade.
@MainActor
private final class WatchSources {
    private var starts: [(id: UUID, path: String, source: ScriptedChangeSource)] = []

    func add(_ id: UUID, _ path: String, _ source: ScriptedChangeSource) {
        starts.append((id, path, source))
    }

    func paths(for id: UUID) -> [String] {
        starts.filter { $0.id == id }.map(\.path)
    }

    func latest(for id: UUID) -> ScriptedChangeSource? {
        starts.last { $0.id == id }?.source
    }
}

private extension WiredRig {
    /// Wie `LiveWiring.startWatching`, nur mit Testquelle.
    func startScripted(_ id: UUID, _ volume: VolumeInfo, sources: WatchSources) {
        let source = ScriptedChangeSource()
        sources.add(id, volume.mountPath, source)
        watcher.start(mediumID: id, volume: volume, source: source)
    }
}

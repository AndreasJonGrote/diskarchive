//
//  GapMediumBehavesOnlineTests.swift
//  diskindexTests
//
//  bug.0.4.200 — Ein Medium mit Lücke (nicht lesbare Ordner) hat bis auf die Lücke einen vollständigen Index und
//  verhält sich überall wie Online; nur Chip, „!“, Modal und Mitteilung sagen „Fehler“. Erkennung, Indizierung und
//  Überwachung wie in der App verdrahtet (`WiredRig`), Medium im Speicher (`MemoryVolume`), nie echte Medien.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct GapMediumBehavesOnlineTests {
    /// Hält Läufe am Ordner „ok/sub“ an (Ebene 3, Ebenen 1 und 2 haben dann Fortschritt gemeldet), sobald eingeschaltet.
    final class HoldSwitch: @unchecked Sendable {
        private let lock = NSLock()
        private var on = false
        func set(_ value: Bool) { lock.withLock { on = value } }
        func holds(_ path: String) -> Bool { lock.withLock { on } && path.hasSuffix("/ok/sub") }
    }

    @MainActor
    final class Recorder {
        var withdrawn: [UUID] = []
        var finished = 0
    }

    @MainActor
    struct Setup {
        let harness: ScanHarness
        let volume: VolumeInfo
        let memory: MemoryVolume
        let gate: RunGateAccess
        let hold: HoldSwitch
        let app: AppState
        let rig: WiredRig
        let recorder: Recorder
        var id: UUID { harness.mediumID }

        func storedStatus() async throws -> StoredIndexStatus? {
            try await harness.store.medium(uuid: id)?.indexStatus
        }

        /// Lauf über den Dienst starten und auf sein Ende samt Entscheidung über Hinweis und Überwachung warten.
        func runToEnd(fromScratch: Bool = false) async -> Bool {
            let before = recorder.finished
            rig.service.start(mediumUUID: id, volume: volume, fromScratch: fromScratch)
            return await waitUntil { recorder.finished > before }
        }
    }

    private static var fastRetries: IndexingRunLimits {
        var limits = IndexingRunLimits.standard
        limits.readRetryDelays = [.milliseconds(1)]
        return limits
    }

    /// Angeschlossenes Medium (auch für `GapMediumRemainderTests`), erster Lauf endet mit Lücke („bad“ nicht lesbar) → `.error`, Hinweis steht.
    static func gapMedium(_ name: String) async throws -> Setup {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/\(name)", name: name)
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let memory = MemoryVolume(mountPath: volume.mountPath)
        memory.file("bad/keep.txt")
        memory.file("ok/a.txt")
        memory.file("ok/sub/tief.txt")
        memory.markUnreadable("bad")
        let hold = HoldSwitch()
        let gate = RunGateAccess([memory], holds: { hold.holds($0) })
        let app = AppState(store: harness.store, defaults: TestDefaults.make())
        let recorder = Recorder()
        app.withdrawIndexingFailureNotice = { recorder.withdrawn.append($0) }
        let rig = WiredRig(store: harness.store, access: gate, app: app)
        rig.service.runLimitsForTesting = fastRetries
        rig.service.finishDecisionHookForTesting = { _ in recorder.finished += 1 }
        let setup = Setup(harness: harness, volume: volume, memory: memory, gate: gate, hold: hold, app: app, rig: rig, recorder: recorder)
        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { recorder.finished > 0 }, "erster Lauf endet nicht")
        try #require(app.medium(with: setup.id)?.indexStatus == .error, "Voraussetzung: Lücke = Fehler")
        try #require(app.indexingFailure?.reason == .unreadableFolders, "Voraussetzung: Hinweis steht")
        return setup
    }

    /// (a) Dashboard und Menüleiste: bei Lücke die normalen Zeilen wie Online; anderer Grund bleibt „kein Zugriff“.
    @Test func gapMediumShowsTheOnlineLines() async throws {
        let setup = try await Self.gapMedium("ZEILEN")
        defer { setup.rig.coordinator.stop() }
        let medium = try #require(setup.app.medium(with: setup.id))
        #expect(medium.hasIndexGaps, "Merker nicht aus `indexGaps` geladen")
        #expect(try await setup.harness.store.medium(uuid: setup.id)?.hasIndexGaps == true)
        #expect(medium.hasCompleteIndexExceptGaps)
        #expect(MediumChip.presentation(medium).text == LayoutCopy.chipError, "Chip sagt weiter „Fehler“")
        #expect(medium.dashboardSpecLine == medium.specLine)
        #expect(medium.occupancyLabel(showAbsolute: false) != nil, "Belegung fehlt")
        #expect(medium.showsLastIndexedLine, "„Zuletzt indiziert“ fehlt")
        #expect(!medium.dashboardShowsRetryLine, "Karte zeigt „erneut versuchen“ statt der Belegung")
        #expect(medium.menuBarSecondaryLine == IndexedDateFormatting.lastIndexedLine(date: medium.lastIndexActivityAt ?? medium.lastIndexedAt))

        var denied = medium
        denied.hasIndexGaps = false
        #expect(denied.dashboardSpecLine == LayoutCopy.mediumNoAccess)
        #expect(denied.menuBarSecondaryLine == LayoutCopy.mediumNoAccess)
        #expect(denied.occupancyLabel(showAbsolute: false) == nil)
        #expect(!denied.showsLastIndexedLine)
        #expect(denied.dashboardShowsRetryLine)
    }

    /// (b) Nach Aufwachen und Pause-Ende wird das Medium mit Lücke überwacht wie ein `.indexed`-Medium.
    @Test func gapMediumIsWatchedAfterWakeAndPauseEnd() async throws {
        let setup = try await Self.gapMedium("WACHE")
        defer { setup.rig.coordinator.stop() }
        let watcher = setup.rig.watcher
        // `WiredRig` startet nach dem Lauf keine Überwachung (Standard-Haken leer).
        try #require(!watcher.isWatching(mediumID: setup.id), "Voraussetzung: noch nicht überwacht")
        await LiveWiring.restartWatchersAfterWake(
            coordinator: setup.rig.coordinator, watcher: watcher, store: setup.harness.store, appState: setup.app
        )
        #expect(watcher.isWatching(mediumID: setup.id), "nach dem Aufwachen nicht überwacht")
        await watcher.stop(mediumID: setup.id)
        try #require(!watcher.isWatching(mediumID: setup.id))
        watcher.pauseChanged()
        #expect(await waitUntil { watcher.isWatching(mediumID: setup.id) }, "nach Pause-Ende nicht überwacht")
    }

    /// (c) Ein Folgelauf (Abgleich) läuft still: Status bleibt „Fehler“, die Lücke wird nachgelesen, bleibt sie, kommt
    /// weder Hinweis noch Mitteilung neu.
    @Test func followUpRunStaysQuietWhileTheGapRemains() async throws {
        let setup = try await Self.gapMedium("STILL")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        let badReadsBefore = setup.memory.listed.filter { $0.hasSuffix("/bad") }.count
        var published: [IndexStatus] = []
        setup.rig.service.publishedStatusHookForTesting = { _, status in published.append(status) }
        setup.hold.set(true)
        let before = setup.recorder.finished
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.gate.entered.wait()
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status während des Abgleichs: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Abgleich endet nicht")
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error)
        #expect(!published.isEmpty, "Voraussetzung: Fortschritt gemeldet")
        #expect(!published.contains(.indexing), "Fortschritt zeigte „wird indiziert“: \(published)")
        #expect(setup.app.indexingFailure == nil, "Hinweis kam beim stillen Folgelauf neu")
        #expect(setup.recorder.withdrawn.isEmpty)
        #expect(setup.memory.listed.filter { $0.hasSuffix("/bad") }.count > badReadsBefore, "Lücke nicht nachgelesen")
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id))
    }

    /// (c) Pause während des stillen Abgleichs: der unterbrochene Lauf ist kein neuer Fehler (kein Hinweis), Status bleibt
    /// „Fehler“.
    @Test func pauseDuringTheQuietFollowUpRunIsNoNewFailure() async throws {
        let setup = try await Self.gapMedium("PAUSE")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        setup.hold.set(true)
        let before = setup.recorder.finished
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.gate.entered.wait()
        setup.app.globalAutoIndexPaused = true
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Abgleich endet nicht")
        #expect(setup.app.indexingFailure == nil, "Pause meldet einen Fehler: \(String(describing: setup.app.indexingFailure))")
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error)
        #expect(try await setup.storedStatus() == .error)
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id), "Merker nach Pause verloren")
    }

    /// (d) Merker steht, der letzte Fehler hat aber einen anderen Grund (Leserechte) → beim Aktivieren neu geprüft.
    @Test func laterFailureWithOtherReasonIsReprobedOnActivation() async throws {
        let setup = try await Self.gapMedium("RECHTE")
        defer { setup.rig.coordinator.stop() }
        setup.memory.markUnreadable("")
        try #require(await setup.runToEnd(), "Lauf mit gesperrtem Medium endet nicht")
        try #require(try await setup.storedStatus() == .error)
        #expect(setup.app.indexingFailure?.reason == .permission, "Grund: \(String(describing: setup.app.indexingFailure))")
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id) == false, "Merker der alten Lücke blieb stehen")
        // Medium war früher vollständig (`firstIndexedAt`): ohne Merker zählen die nicht lesbaren Ordner im Index als Lücke.
        let mediumData = MediumCodecV3.data(setup.id)
        try await setup.harness.store.pool.write { db in
            try db.execute(sql: "UPDATE storages SET firstIndexedAt = 1700000000 WHERE uuid = ?", arguments: [mediumData])
        }
        setup.memory.markReadable("")
        await setup.rig.coordinator.applicationDidBecomeActive()
        // Unmittelbar nach dem Aktivieren: `.pending` (bzw. schon `.indexing`, Lauf liest die Lücke nach), nie `.indexed`
        // (stiller Abgleich, der kurz „Online“ zeigt).
        let shown = setup.app.medium(with: setup.id)?.indexStatus
        #expect(shown == .pending || shown == .indexing, "Lücke im Index trotz fehlendem Merker: \(String(describing: shown))")
        #expect(try await setup.storedStatus() != .error, "nach der Freigabe beim Aktivieren nicht neu geprüft")
    }

    /// (e) Aushängen schließt den Hinweis und zieht die Mitteilung für jeden Grund zurück; endet ein Lauf, nachdem das
    /// Medium getrennt ist, kommt kein Hinweis.
    @Test func unmountEndsTheFailureForEveryReason() async throws {
        let setup = try await Self.gapMedium("AUSHANG")
        defer { setup.rig.coordinator.stop() }
        await setup.rig.coordinator.handle(.disappeared(path: setup.volume.mountPath))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .offline }, "Aushängen nicht verarbeitet")
        #expect(setup.app.indexingFailure == nil, "Hinweis blieb nach dem Aushängen")
        #expect(setup.recorder.withdrawn == [setup.id], "Zurückgezogen: \(setup.recorder.withdrawn)")

        // Lauf endet erst, als das Medium schon getrennt ist → kein Hinweis.
        let afterUnmount = setup.recorder.finished
        await setup.rig.coordinator.handle(.appeared(setup.volume))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .connected })
        // Das Anschließen liest die Lücke nach (Lauf wie heute); auf sein Ende warten.
        try #require(await waitUntil { setup.recorder.finished > afterUnmount }, "Lauf beim Anschließen endet nicht")
        setup.app.indexingFailure = nil
        setup.hold.set(true)
        let before = setup.recorder.finished
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: true)
        await setup.gate.entered.wait()
        setup.app.updateMedium(id: setup.id) { $0.connectionStatus = .offline }
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Lauf endet nicht")
        #expect(setup.app.indexingFailure == nil, "Hinweis für ein getrenntes Medium")
    }

    /// (f) „Nein“ beendet den Fehler: Status nach der Tabelle (unvollständiger Index → „x % indiziert“), Hinweis und
    /// Mitteilung weg.
    @Test func declineEndsTheFailure() async throws {
        let setup = try await Self.gapMedium("NEIN")
        defer { setup.rig.coordinator.stop() }
        setup.app.updateMedium(id: setup.id, persist: true) {
            $0.decision = .dontIndex
            $0.allowIndexing = false
        }
        let ended = await waitUntil { setup.app.medium(with: setup.id)?.indexStatus == .pending }
        #expect(ended, "Status nach „Nein“: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        #expect(setup.app.indexingFailure == nil, "Hinweis blieb nach „Nein“")
        #expect(setup.recorder.withdrawn == [setup.id], "Zurückgezogen: \(setup.recorder.withdrawn)")
        #expect(await waitUntil { (try? await setup.storedStatus()) == .pending }, "gespeicherter Status bleibt „Fehler“")
    }
}

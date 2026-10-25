//
//  GapMediumRemainderTests.swift
//  diskindexTests
//
//  bug.0.4.201 — Reste aus bug.0.4.200: Pause-Ende und Aufwachen gleichen ein Medium mit Lücke still ab, Aushängen
//  während des Laufendes zeigt keinen Hinweis, Abbruch und Anschließen in der Pause lassen „Fehler“ stehen, frühe
//  Fehler und verweigerter Zugriff löschen den Merker. Verdrahtet wie in der App (`WiredRig`), Medium im Speicher.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct GapMediumRemainderTests {
    private typealias Setup = GapMediumBehavesOnlineTests.Setup

    private static func gapMedium(_ name: String) async throws -> Setup {
        try await GapMediumBehavesOnlineTests.gapMedium(name)
    }

    /// Wartet auf einen stillen Abgleich, den Pause-Ende bzw. Aufwachen anstoßen: Start ohne „von vorn“, Status bleibt
    /// „Fehler“, kein Hinweis.
    private static func expectQuietReconcile(_ setup: Setup, startsBefore: Int, finishedBefore: Int) async throws {
        let started = await waitUntil { setup.rig.starts(setup.id).count > startsBefore }
        try #require(started, "kein Abgleich angestoßen")
        #expect(setup.rig.starts(setup.id).last == false, "Lauf von vorn statt Abgleich")
        try #require(await waitUntil { setup.recorder.finished > finishedBefore }, "Abgleich endet nicht")
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error)
        #expect(setup.app.indexingFailure == nil, "Hinweis kam beim stillen Abgleich neu")
    }

    /// (a) Pause-Ende gleicht ein Medium mit Lücke ab wie ein `.indexed`-Medium.
    @Test func pauseEndReconcilesTheGapMedium() async throws {
        let setup = try await Self.gapMedium("PAUSENENDE")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        setup.app.globalAutoIndexPaused = true
        let starts = setup.rig.starts(setup.id).count
        let finished = setup.recorder.finished
        setup.app.globalAutoIndexPaused = false
        try await Self.expectQuietReconcile(setup, startsBefore: starts, finishedBefore: finished)
    }

    /// (a) Aufwachen gleicht ein Medium mit Lücke ab wie ein `.indexed`-Medium.
    @Test func wakeReconcilesTheGapMedium() async throws {
        let setup = try await Self.gapMedium("AUFWACHEN")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        setup.app.heldForSleep = true
        let starts = setup.rig.starts(setup.id).count
        let finished = setup.recorder.finished
        await setup.app.handleWake().value
        try await Self.expectQuietReconcile(setup, startsBefore: starts, finishedBefore: finished)
    }

    /// (b) Aushängen, während ein Lauf in `finish` schon über die Token-Prüfung ist: kein Hinweis, keine Mitteilung für
    /// das getrennte Medium.
    @Test func unmountWhileTheRunFinishesShowsNoFailure() async throws {
        let setup = try await Self.gapMedium("RENNEN")
        let coordinator = setup.rig.coordinator
        defer { coordinator.stop() }
        setup.app.indexingFailure = nil
        // Aushängen bis nach dem Schließen des Hinweises laufen lassen, dann festhalten (vor `publish(…, .offline)`).
        let unmountReached = SurfaceAsyncSignal()
        let unmountRelease = SurfaceAsyncSignal()
        let disappeared = coordinator.onMediumDisappeared
        coordinator.onMediumDisappeared = { id in
            await unmountReached.signal()
            await unmountRelease.wait()
            await disappeared?(id)
        }
        let path = setup.volume.mountPath
        setup.rig.service.finishBeforeFailureHookForTesting = { _ in
            Task { await coordinator.handle(.disappeared(path: path)) }
            await unmountReached.wait()
        }
        let before = setup.recorder.finished
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: true)
        let ended = await waitUntil { setup.recorder.finished > before }
        setup.rig.service.finishBeforeFailureHookForTesting = nil
        await unmountRelease.signal()
        try #require(ended, "Lauf endet nicht")
        #expect(setup.app.indexingFailure == nil, "Hinweis für ein getrenntes Medium: \(String(describing: setup.app.indexingFailure))")
        #expect(!setup.app.failureNoticeMedia.contains(setup.id), "Mitteilung für ein getrenntes Medium")
        #expect(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .offline })
    }

    /// (c) `cancel()` direkt nach dem Start eines stillen Abgleichs (bevor der Lauf ihn sich merkt): Status bleibt
    /// „Fehler“ mit Lücke.
    @Test func cancelRightAfterTheQuietStartKeepsTheError() async throws {
        let setup = try await Self.gapMedium("ABBRUCH")
        defer { setup.rig.coordinator.stop() }
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.rig.service.cancel(mediumUUID: setup.id)
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status nach Abbruch: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        await setup.rig.service.waitUntilIdle(setup.id)
        #expect(try await setup.storedStatus() == .error)
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id), "Merker nach Abbruch verloren")
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error)
    }

    /// (d) Anschließen während der globalen Pause: kein Lauf startet, Status bleibt „Fehler“ mit Lücke.
    @Test func connectDuringPauseKeepsTheError() async throws {
        let setup = try await Self.gapMedium("PAUSEAN")
        defer { setup.rig.coordinator.stop() }
        await setup.rig.coordinator.handle(.disappeared(path: setup.volume.mountPath))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .offline })
        setup.app.globalAutoIndexPaused = true
        let starts = setup.rig.starts(setup.id).count
        await setup.rig.coordinator.handle(.appeared(setup.volume))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .connected })
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        #expect(try await setup.storedStatus() == .error)
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id))
        #expect(setup.rig.starts(setup.id).count == starts, "Lauf trotz Pause")
    }

    /// (d) Die Pause endet, während das Anschließen noch schreibt (Pfad noch nicht eingetragen): das Anschließen holt
    /// den stillen Abgleich selbst nach (`resumePausedRuns` fand das Medium noch nicht).
    @Test func pauseEndingDuringConnectStillReconciles() async throws {
        let setup = try await Self.gapMedium("PAUSEFENSTER")
        defer { setup.rig.coordinator.stop() }
        await setup.rig.coordinator.handle(.disappeared(path: setup.volume.mountPath))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .offline })
        setup.app.indexingFailure = nil
        setup.app.globalAutoIndexPaused = true
        let app = setup.app
        setup.rig.coordinator.connectStatusDecidedHookForTesting = { _ in app.globalAutoIndexPaused = false }
        let starts = setup.rig.starts(setup.id).count
        let finished = setup.recorder.finished
        await setup.rig.coordinator.handle(.appeared(setup.volume))
        setup.rig.coordinator.connectStatusDecidedHookForTesting = nil
        try await Self.expectQuietReconcile(setup, startsBefore: starts, finishedBefore: finished)
    }

    /// (e) `beginIndexing` wirft: der Merker fällt weg, das Aktivieren der App prüft das Medium wieder.
    @Test func earlyFailureClearsTheGapMarker() async throws {
        let setup = try await Self.gapMedium("FRUEH")
        defer { setup.rig.coordinator.stop() }
        await setup.harness.store.setBeginIndexingFailing(true)
        try #require(await setup.runToEnd(), "Lauf endet nicht")
        try #require(try await setup.storedStatus() == .error)
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id) == false, "Merker nach frühem Fehler")
        await setup.harness.store.setBeginIndexingFailing(false)
        await setup.rig.coordinator.applicationDidBecomeActive()
        #expect(try await setup.storedStatus() != .error, "beim Aktivieren nicht neu geprüft")
    }

    /// (f) Anschließen mit verweigertem Zugriff löscht den Merker (Fehler ist jetzt der Zugriff).
    @Test func deniedAccessOnConnectClearsTheGapMarker() async throws {
        let setup = try await Self.gapMedium("VERWEIGERT")
        defer { setup.rig.coordinator.stop() }
        await setup.rig.coordinator.handle(.disappeared(path: setup.volume.mountPath))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .offline })
        setup.gate.setProbeDenied(true)
        await setup.rig.coordinator.handle(.appeared(setup.volume))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .connected })
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id) == false, "Merker nach verweigertem Zugriff")
        #expect(setup.app.medium(with: setup.id)?.hasIndexGaps == false)
        #expect(try await setup.storedStatus() == .error)
    }
}

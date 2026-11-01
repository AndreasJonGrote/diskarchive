//
//  GapMediumRunWindowTests.swift
//  DiskArchiveTests
//
//  bug.0.4.202 — Zeitfenster am Laufende: Merker des Laufs gehören zu seinem Token, keine Überwachung und kein Hinweis
//  für ein beim Laufende ausgehängtes Medium, ein Abbruch vor dem Lesen des Speichers schreibt nur, was der Speicher
//  bestätigt, Pausen beim Anschließen. Verdrahtet wie in der App (`WiredRig`), Medium im Speicher (`MemoryVolume`).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct GapMediumRunWindowTests {
    private typealias Setup = GapMediumBehavesOnlineTests.Setup

    private static func gapMedium(_ name: String) async throws -> Setup {
        try await GapMediumBehavesOnlineTests.gapMedium(name)
    }

    /// Hält das Aushängen nach dem Austragen des Pfads fest (in `onMediumDisappeared`, vor `publish(…, .offline)`).
    @MainActor
    final class HeldUnmount {
        let reached = SurfaceAsyncSignal()
        let release = SurfaceAsyncSignal()

        init(_ coordinator: MediumCoordinator) {
            let disappeared = coordinator.onMediumDisappeared
            let reached = reached
            let release = release
            coordinator.onMediumDisappeared = { id in
                await reached.signal()
                await release.wait()
                await disappeared?(id)
            }
        }
    }

    private static func unmount(_ setup: Setup) async throws {
        await setup.rig.coordinator.handle(.disappeared(path: setup.volume.mountPath))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .offline })
    }

    /// (a) Wird zwischen der Freigabe in `finish` und seinem Ende ein neuer stiller Abgleich angefordert, bleiben dessen
    /// Merker: ein Abbruch stellt „Fehler“ mit Lücke her. bug.0.4.204: der neue Lauf wartet auf das Ende des alten.
    @Test func finishOfTheOldRunKeepsTheMarkersOfTheNewRun() async throws {
        let setup = try await Self.gapMedium("FENSTERALT")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        let service = setup.rig.service
        let id = setup.id
        let volume = setup.volume
        var startedNew = false
        service.finishBeforeFailureHookForTesting = { _ in
            guard !startedNew else { return }
            startedNew = true
            setup.hold.set(true)
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
        }
        try #require(await setup.runToEnd(), "alter Lauf endet nicht")
        service.finishBeforeFailureHookForTesting = nil
        try #require(await waitUntil { await setup.gate.heldCount() >= 1 }, "neuer Lauf hält nicht am Tor")
        try #require(startedNew && service.isRunActive(id), "neuer Lauf läuft nicht")
        await service.cancel(mediumUUID: id)
        await setup.gate.open()
        await service.waitUntilIdle(id)
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Status nach Abbruch: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        #expect(try await setup.storedStatus() == .error)
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: id), "Merker nach Abbruch verloren")
    }

    /// (b) Ausgehängt, während ein erfolgreicher Lauf endet: keine Überwachung für das getrennte Medium.
    @Test func unmountWhileTheRunFinishesStartsNoWatch() async throws {
        let setup = try await Self.gapMedium("FENSTERWACHE")
        let coordinator = setup.rig.coordinator
        defer { coordinator.stop() }
        setup.memory.markReadable("bad")
        let held = HeldUnmount(coordinator)
        var watched: [UUID] = []
        let runIndexed = setup.rig.service.onRunIndexed
        setup.rig.service.onRunIndexed = { id, volume in
            watched.append(id)
            runIndexed?(id, volume)
        }
        let path = setup.volume.mountPath
        setup.rig.service.finishBeforeFailureHookForTesting = { _ in
            Task { await coordinator.handle(.disappeared(path: path)) }
            await held.reached.wait()
        }
        let ended = await setup.runToEnd(fromScratch: true)
        setup.rig.service.finishBeforeFailureHookForTesting = nil
        await held.release.signal()
        try #require(ended, "Lauf endet nicht")
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .indexed, "Voraussetzung: Lauf erfolgreich")
        #expect(watched.isEmpty, "Überwachung für ein getrenntes Medium")
    }

    /// (c) Die Anzeige sagt `.indexed`, der Speicher nicht: ein Abbruch vor dem Lesen des Speichers schreibt kein
    /// `.indexed`, sondern fällt auf `.pending` zurück.
    @Test func cancelBeforeTheStoreReadWritesOnlyWhatTheStoreConfirms() async throws {
        let setup = try await Self.gapMedium("ABWEICHUNG")
        defer { setup.rig.coordinator.stop() }
        try await setup.harness.store.updateMediumIndexStatus(uuid: setup.id, .pending)
        setup.app.updateMedium(id: setup.id) {
            $0.indexStatus = .indexed
            $0.hasIndexGaps = false
        }
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.rig.service.cancel(mediumUUID: setup.id)
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .pending, "Status nach Abbruch: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        await setup.rig.service.waitUntilIdle(setup.id)
        #expect(try await setup.storedStatus() == .pending)
    }

    /// (c) Abbruch vor dem Lesen des Speichers, der Speicher ist dabei nicht lesbar: Rückfall `.pending`, nie der
    /// angezeigte Stand.
    @Test func cancelWithAnUnreadableStoreFallsBackToPending() async throws {
        let setup = try await Self.gapMedium("ABBRUCHLESEN")
        defer { setup.rig.coordinator.stop() }
        setup.app.updateMedium(id: setup.id) {
            $0.indexStatus = .indexed
            $0.hasIndexGaps = false
        }
        // bug.0.4.203 (d): nur das Lesen in `cancel` scheitert (je Instanz, kein Zähler, den andere Leser verbrauchen).
        let service = setup.rig.service
        service.failsNextCancelStoreReadForTesting = true
        defer { service.failsNextCancelStoreReadForTesting = false }
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.rig.service.cancel(mediumUUID: setup.id)
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .pending, "Status nach Abbruch: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        await setup.rig.service.waitUntilIdle(setup.id)
    }

    /// (c) Speicher vor dem Lauf nicht lesbar: Art des Laufs und Beginn der Anzeige aus derselben Quelle – der stille
    /// Abgleich zeigt kein „wird indiziert“.
    @Test func unreadableStoreBeforeTheRunKeepsTheQuietStart() async throws {
        let setup = try await Self.gapMedium("UNLESBAR")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        var published: [IndexStatus] = []
        setup.rig.service.publishedStatusHookForTesting = { _, status in published.append(status) }
        // bug.0.4.203 (d): nur das Lesen vor dem Lauf scheitert.
        let service = setup.rig.service
        service.failsNextStoreReadBeforeRunForTesting = true
        defer { service.failsNextStoreReadBeforeRunForTesting = false }
        setup.hold.set(true)
        let before = setup.recorder.finished
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.gate.entered.wait()
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status beim Beginn: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Abgleich endet nicht")
        #expect(!published.contains(.indexing), "Fortschritt zeigte „wird indiziert“: \(published)")
    }

    /// (d) Die Trennung ist sichtbar, bevor das Aushängen wartet (Überwachung stoppen, Lauf abbrechen).
    @Test func unmountShowsOfflineBeforeItsFirstAwait() async throws {
        let setup = try await Self.gapMedium("ZUERST")
        let coordinator = setup.rig.coordinator
        defer { coordinator.stop() }
        let held = HeldUnmount(coordinator)
        let path = setup.volume.mountPath
        let unmounting = Task { await coordinator.handle(.disappeared(path: path)) }
        await held.reached.wait()
        #expect(setup.app.medium(with: setup.id)?.connectionStatus == .offline, "Trennung erst nach den `await`s sichtbar")
        await held.release.signal()
        await unmounting.value
    }

    /// (d) Angezeigt bleibt `.connected`, der Pfad ist aber schon ausgetragen: `finish` fragt den Koordinator und zeigt
    /// keinen Hinweis.
    @Test func runEndAsksTheCoordinatorWhetherTheMediumIsMounted() async throws {
        let setup = try await Self.gapMedium("PFADWEG")
        let coordinator = setup.rig.coordinator
        defer { coordinator.stop() }
        setup.app.indexingFailure = nil
        let held = HeldUnmount(coordinator)
        let path = setup.volume.mountPath
        let app = setup.app
        let id = setup.id
        setup.rig.service.finishBeforeFailureHookForTesting = { _ in
            Task { await coordinator.handle(.disappeared(path: path)) }
            await held.reached.wait()
            app.updateMedium(id: id) { $0.connectionStatus = .connected }
        }
        let ended = await setup.runToEnd(fromScratch: true)
        setup.rig.service.finishBeforeFailureHookForTesting = nil
        await held.release.signal()
        try #require(ended, "Lauf endet nicht")
        #expect(setup.app.indexingFailure == nil, "Hinweis für ein ausgetragenes Medium: \(String(describing: setup.app.indexingFailure))")
        #expect(!setup.app.failureNoticeMedia.contains(id))
    }

    /// (e) Anschließen im Ruhezustand: kein Lauf, Status bleibt „Fehler“ mit Lücke.
    @Test func connectWhileHeldForSleepKeepsTheError() async throws {
        let setup = try await Self.gapMedium("SCHLAF")
        defer { setup.rig.coordinator.stop() }
        try await Self.unmount(setup)
        setup.app.heldForSleep = true
        await setup.rig.coordinator.handle(.appeared(setup.volume))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .connected })
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        #expect(try await setup.storedStatus() == .error)
    }

    /// (e) Anschließen mit automatischer Pause des Mediums: kein Lauf, Status bleibt „Fehler“ mit Lücke.
    @Test func connectWithAutoIndexPausedKeepsTheError() async throws {
        let setup = try await Self.gapMedium("AUTOPAUSE")
        defer { setup.rig.coordinator.stop() }
        try await Self.unmount(setup)
        setup.app.updateMedium(id: setup.id, persist: true) { $0.autoIndexPaused = true }
        let stored = await waitUntil { (try? await setup.harness.store.medium(uuid: setup.id))?.autoIndexPaused == true }
        try #require(stored, "Pause des Mediums nicht gespeichert")
        await setup.rig.coordinator.handle(.appeared(setup.volume))
        try #require(await waitUntil { setup.app.medium(with: setup.id)?.connectionStatus == .connected })
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        #expect(try await setup.storedStatus() == .error)
    }
}

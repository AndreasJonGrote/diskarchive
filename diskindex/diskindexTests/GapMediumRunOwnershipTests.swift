//
//  GapMediumRunOwnershipTests.swift
//  diskindexTests
//
//  bug.0.4.203 — Nach der Freigabe eines Laufs (`runs[id] = nil`) verändert sein altes `finish` nichts mehr, was einem
//  neuen Lauf desselben Mediums gehört (Sperre des Vollabgleichs, Anforderung, Anzeige); `cancel` prüft eine
//  unbestätigte Art immer gegen den Speicher; Überwachung nach gescheitertem Lauf nur für eingehängte Medien.
//  bug.0.4.204: der neue Lauf wartet auf das Ende des alten Abschlusses (`RunLifecycleTests`).
//  Verdrahtet wie in der App (`WiredRig`), Medium im Speicher (`MemoryVolume`).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct GapMediumRunOwnershipTests {
    private typealias Setup = GapMediumBehavesOnlineTests.Setup

    private static func gapMedium(_ name: String) async throws -> Setup {
        try await GapMediumBehavesOnlineTests.gapMedium(name)
    }

    /// Neuen Lauf anfordern, sobald das alte `finish` den Lauf freigegeben hat (bug.0.4.204: er startet nach dessen Ende
    /// und hält am Tor).
    private static func startNewRunAfterRelease(_ setup: Setup, start: @escaping @MainActor () -> Void) -> () -> Bool {
        var startedNew = false
        setup.rig.service.finishAfterReleaseHookForTesting = { _ in
            guard !startedNew else { return }
            startedNew = true
            setup.hold.set(true)
            start()
        }
        return { startedNew }
    }

    private static func newRunHeld(_ setup: Setup) async -> Bool {
        await waitUntil { await setup.gate.heldCount() >= 1 }
    }

    private static func finishNewRun(_ setup: Setup) async {
        setup.rig.service.finishAfterReleaseHookForTesting = nil
        await setup.gate.open()
        await setup.rig.service.waitUntilIdle(setup.id)
    }

    /// (a) Altes `finish`, ein neuer (stiller) Lauf wartet: Anzeige und Anforderung des neuen Laufs bleiben.
    @Test func oldFinishLeavesDisplayAndRequestOfTheNewRun() async throws {
        let setup = try await Self.gapMedium("ALTANZEIGE")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        let coordinator = setup.rig.coordinator
        let id = setup.id
        var watched: [UUID] = []
        let runIndexed = setup.rig.service.onRunIndexed
        setup.rig.service.onRunIndexed = { id, volume in
            watched.append(id)
            runIndexed?(id, volume)
        }
        let startedNew = Self.startNewRunAfterRelease(setup) { coordinator.requestIndexingAfterDecision(mediumID: id) }
        try #require(await setup.runToEnd(), "alter Lauf endet nicht")
        try #require(startedNew(), "neuer Lauf nicht angefordert")
        try #require(await Self.newRunHeld(setup), "neuer Lauf startet nicht")
        #expect(watched.isEmpty, "altes `finish` startet die Überwachung neben dem neuen Lauf")
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Anzeige des stillen Laufs überschrieben: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        #expect(coordinator.isIndexRequestedForTesting(id), "Anforderung des neuen Laufs gelöscht")
        await Self.finishNewRun(setup)
    }

    /// (a) Altes `finish` eines gescheiterten Laufs, ein neuer wartet: keine Sperre des Vollabgleichs für den neuen Lauf.
    /// (bug.0.4.204: der alte Lauf endet vor dem Start des neuen – sein Hinweis ist keiner „mitten im neuen“ mehr.)
    @Test func oldFailedFinishDoesNotSuppressTheNewRunsReconcile() async throws {
        let setup = try await Self.gapMedium("ALTSPERRE")
        defer { setup.rig.coordinator.stop() }
        setup.app.indexingFailure = nil
        let service = setup.rig.service
        let id = setup.id
        let volume = setup.volume
        setup.memory.markUnreadable("")
        let startedNew = Self.startNewRunAfterRelease(setup) {
            setup.memory.markReadable("")
            service.start(mediumUUID: id, volume: volume, fromScratch: true)
        }
        try #require(await setup.runToEnd(fromScratch: true), "alter Lauf endet nicht")
        try #require(startedNew(), "neuer Lauf nicht angefordert")
        try #require(await Self.newRunHeld(setup), "neuer Lauf startet nicht")
        #expect(!service.suppressesFullReconcile(id), "Sperre des alten Laufs gilt für den neuen")
        await Self.finishNewRun(setup)
    }

    /// (b) Die Anzeige sagt „wird indiziert“ (kein Abgleich), der Speicher „Fehler“ mit Lücke: ein sofortiger Abbruch
    /// stellt den Stand des Speichers her.
    @Test func cancelChecksAnUnconfirmedKindAgainstTheStore() async throws {
        let setup = try await Self.gapMedium("ANZEIGELAUF")
        defer { setup.rig.coordinator.stop() }
        setup.app.updateMedium(id: setup.id) { $0.indexStatus = .indexing }
        setup.rig.service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        await setup.rig.service.cancel(mediumUUID: setup.id)
        #expect(setup.app.medium(with: setup.id)?.indexStatus == .error, "Status nach Abbruch: \(String(describing: setup.app.medium(with: setup.id)?.indexStatus))")
        await setup.rig.service.waitUntilIdle(setup.id)
        #expect(try await setup.storedStatus() == .error)
        #expect(try await setup.harness.store.indexHasGaps(mediumUUID: setup.id))
    }

    /// (c) Gescheiterter Lauf, Pfad beim Laufende schon ausgetragen, Anzeige bleibt `.connected`: keine Überwachung.
    @Test func failedRunOfAnUnmountedMediumStartsNoWatch() async throws {
        let setup = try await Self.gapMedium("FEHLERWEG")
        let coordinator = setup.rig.coordinator
        defer { coordinator.stop() }
        setup.memory.markUnreadable("")
        let held = GapMediumRunWindowTests.HeldUnmount(coordinator)
        var watched: [UUID] = []
        let runIndexed = setup.rig.service.onRunIndexed
        setup.rig.service.onRunIndexed = { id, volume in
            watched.append(id)
            runIndexed?(id, volume)
        }
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
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Voraussetzung: Lauf gescheitert")
        #expect(watched.isEmpty, "Überwachung nach Fehler für ein ausgetragenes Medium")
    }
}

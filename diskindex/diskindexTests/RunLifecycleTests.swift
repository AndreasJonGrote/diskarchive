//
//  RunLifecycleTests.swift
//  diskindexTests
//
//  bug.0.4.204 — Je Medium höchstens ein Lebenszyklus „Start → Lauf → Abschluss bzw. Abbruch“: ein neuer `start` und
//  ein weiterer `cancel` warten, bis `finish` bzw. `cancel` des vorigen Laufs ganz fertig ist (Schlussmarker). Abbruch
//  während des Abschlusses (Aushängen, Sperre, Nein, Pause) überschreibt dessen Endstand nicht und streicht den
//  Nachhol-Abgleich; Aushängen und Beenden verwerfen einen wartenden Start. Verdrahtet wie in der App (`WiredRig`),
//  Medium im Speicher (`MemoryVolume`), Haken je Instanz, kein `sleep`.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct RunLifecycleTests {
    private typealias Setup = GapMediumBehavesOnlineTests.Setup

    private static func gapMedium(_ name: String) async throws -> Setup {
        try await GapMediumBehavesOnlineTests.gapMedium(name)
    }

    @MainActor
    final class WatchStarts {
        var count = 0
    }

    @MainActor
    final class Log {
        var watched: [UUID] = []
        var cancelArrived = false
        var cancelReturned = false
    }

    /// Überwachung (`onRunIndexed`) und Ankunft eines `cancel` während des Abschlusses mitschreiben.
    private static func log(_ setup: Setup) -> Log {
        let log = Log()
        let runIndexed = setup.rig.service.onRunIndexed
        setup.rig.service.onRunIndexed = { id, volume in
            log.watched.append(id)
            runIndexed?(id, volume)
        }
        setup.rig.service.cancelWhileClosingHookForTesting = { _ in log.cancelArrived = true }
        return log
    }

    private static func heldAtGate(_ setup: Setup) async -> Bool {
        await waitUntil { await setup.gate.heldCount() >= 1 }
    }

    /// Lauf am Tor festhalten, einen Nachhol-Abgleich vormerken, `during` einmal direkt nach der Freigabe im Abschluss
    /// ausführen und auf die Entscheidung über Hinweis und Überwachung warten.
    private static func finishWithPendingRerun(_ setup: Setup, during: @escaping @MainActor () async -> Void) async throws {
        let service = setup.rig.service
        setup.hold.set(true)
        service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        try #require(await heldAtGate(setup), "Lauf hält nicht am Tor")
        service.start(mediumUUID: setup.id, volume: setup.volume, fromScratch: false)
        try #require(service.hasPendingRerunForTesting(setup.id), "kein Nachhol-Abgleich vorgemerkt")
        var ran = false
        service.finishAfterReleaseHookForTesting = { _ in
            guard !ran else { return }
            ran = true
            await during()
        }
        let before = setup.recorder.finished
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Lauf endet nicht")
    }

    // MARK: - Ein Lebenszyklus je Medium

    /// (1) Im Abschluss des alten Laufs angefordert: der neue Lauf startet erst nach dessen Ende; Anzeige, Sperre,
    /// Anforderung und Überwachung gehören dann ihm.
    @Test func newRunStartsOnlyAfterTheOldFinish() async throws {
        let setup = try await Self.gapMedium("WARTEN")
        defer { setup.tearDown() }
        setup.app.indexingFailure = nil
        let service = setup.rig.service
        let coordinator = setup.rig.coordinator
        let id = setup.id
        let log = Self.log(setup)
        var startedInWindow: Bool?
        service.finishAfterReleaseHookForTesting = { _ in
            guard startedInWindow == nil else { return }
            setup.hold.set(true)
            let before = setup.rig.starts(id).count
            coordinator.requestIndexingAfterDecision(mediumID: id)
            _ = await waitUntil { service.hasWaitingStartForTesting(id) || setup.rig.starts(id).count > before }
            startedInWindow = setup.rig.starts(id).count > before
        }
        try #require(await setup.runToEnd(), "alter Lauf endet nicht")
        #expect(startedInWindow == false, "neuer Lauf startete im Abschluss des alten")
        try #require(await Self.heldAtGate(setup), "neuer Lauf startet nach dem Abschluss nicht")
        service.finishAfterReleaseHookForTesting = nil
        #expect(log.watched.isEmpty, "alter Abschluss startete die Überwachung vor dem wartenden Lauf")
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Anzeige: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        #expect(coordinator.isIndexRequestedForTesting(id), "Anforderung des neuen Laufs gelöscht")
        #expect(!service.suppressesFullReconcile(id), "Sperre des Vollabgleichs gilt für den neuen Lauf")
        let before = setup.recorder.finished
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "neuer Lauf endet nicht")
        await service.waitUntilIdle(id)
        #expect(log.watched == [id], "Überwachung nach dem neuen Lauf: \(log.watched)")
    }

    /// (2) Start und sofortiger Abbruch im Lesefenster des alten Abschlusses: der Abbruch wartet auf dessen Ende; der
    /// Abschluss schreibt den Stand aus dem Speicher, zeigt keinen Hinweis, startet keine Überwachung, und die
    /// Anforderung des wartenden Laufs bleibt.
    @Test func startAndCancelInTheReadWindowWaitForTheOldFinish() async throws {
        let setup = try await Self.gapMedium("LESEFENSTER")
        defer { setup.tearDown() }
        setup.app.indexingFailure = nil
        let service = setup.rig.service
        let coordinator = setup.rig.coordinator
        let id = setup.id
        let log = Self.log(setup)
        var triggered = false
        service.finishAfterReleaseHookForTesting = { _ in
            guard !triggered else { return }
            triggered = true
            setup.hold.set(true)
            coordinator.requestIndexingAfterDecision(mediumID: id)
            _ = await waitUntil { service.hasWaitingStartForTesting(id) || service.isRunActive(id) }
            Task {
                await service.cancel(mediumUUID: id)
                log.cancelReturned = true
            }
            _ = await waitUntil(timeout: 3) { log.cancelArrived || log.cancelReturned }
        }
        var returnedBeforeTheEnd: Bool?
        let decision = service.finishDecisionHookForTesting
        service.finishDecisionHookForTesting = { mediumID in
            if returnedBeforeTheEnd == nil { returnedBeforeTheEnd = log.cancelReturned }
            await decision?(mediumID)
        }
        try #require(await setup.runToEnd(), "alter Lauf endet nicht")
        #expect(returnedBeforeTheEnd == false, "Abbruch kehrte vor dem Ende des alten Abschlusses zurück")
        try #require(await waitUntil { log.cancelReturned }, "Abbruch kehrt nicht zurück")
        service.finishAfterReleaseHookForTesting = nil
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Anzeige: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        #expect(setup.app.indexingFailure == nil, "Hinweis: \(String(describing: setup.app.indexingFailure))")
        #expect(log.watched.isEmpty, "Überwachung nach dem Abbruch im Abschluss")
        #expect(coordinator.isIndexRequestedForTesting(id), "Anforderung gelöscht")
        await setup.gate.open()
        await service.waitUntilIdle(id)
        // Der wartende stille Abgleich lief danach; der Speicher bleibt „Fehler“ mit Lücke.
        #expect(try await setup.storedStatus() == .error)
    }

    /// (3) Zwei gleichzeitige Abbrüche: der zweite wartet auf das Ende des ersten; ein dabei angeforderter Lauf startet
    /// erst danach, seine Anforderung bleibt. (Aushängen bzw. Sperre als Quelle lehnten den neuen Lauf selbst ab – hier
    /// zwei `cancel` direkt.)
    @Test func secondCancelWaitsForTheFirst() async throws {
        let setup = try await Self.gapMedium("ZWEIABBRUCH")
        defer { setup.tearDown() }
        let service = setup.rig.service
        let coordinator = setup.rig.coordinator
        let id = setup.id
        let log = Self.log(setup)
        setup.hold.set(true)
        service.start(mediumUUID: id, volume: setup.volume, fromScratch: false)
        try #require(await Self.heldAtGate(setup), "Lauf hält nicht am Tor")
        var startedEarly: Bool?
        service.cancelBeforeAwaitHookForTesting = { _ in
            guard startedEarly == nil else { return }
            Task {
                await service.cancel(mediumUUID: id)
                log.cancelReturned = true
            }
            _ = await waitUntil(timeout: 3) { log.cancelArrived || log.cancelReturned }
            let before = setup.rig.starts(id).count
            coordinator.requestIndexingAfterDecision(mediumID: id)
            _ = await waitUntil { service.hasWaitingStartForTesting(id) || setup.rig.starts(id).count > before }
            startedEarly = setup.rig.starts(id).count > before
        }
        let firstCancelReturnedEarly = await Task {
            await service.cancel(mediumUUID: id)
            return log.cancelReturned
        }.value
        service.cancelBeforeAwaitHookForTesting = nil
        #expect(startedEarly == false, "neuer Lauf vor dem Ende des ersten Abbruchs")
        #expect(!firstCancelReturnedEarly, "zweiter Abbruch kehrte vor dem Ende des ersten zurück")
        #expect(await waitUntil { log.cancelReturned }, "zweiter Abbruch kehrt nicht zurück")
        #expect(coordinator.isIndexRequestedForTesting(id), "erster Abbruch löschte die Anforderung des neuen Laufs")
        #expect(await waitUntil { setup.rig.starts(id).count == 3 }, "neuer Lauf nach dem Abbruch nicht gestartet: \(setup.rig.starts(id))")
        await setup.gate.open()
        await service.waitUntilIdle(id)
    }

    /// (4) Stiller Abgleich hinter einem Lauf „von vorn“ (Anzeige „wird indiziert“): der Abschluss bestimmt die Anzeige
    /// neu, der Abgleich zeigt „Fehler“, nie „wird indiziert“.
    @Test func quietReconcileBehindARunNeverShowsIndexing() async throws {
        let setup = try await Self.gapMedium("STILLDAHINTER")
        defer { setup.tearDown() }
        setup.app.indexingFailure = nil
        let service = setup.rig.service
        let id = setup.id
        let volume = setup.volume
        var published: [IndexStatus] = []
        var recording = false
        service.publishedStatusHookForTesting = { _, status in
            if recording { published.append(status) }
        }
        var startedQuiet = false
        var displayAtTheEnd: IndexStatus?
        service.finishAfterReleaseHookForTesting = { mediumID in
            guard !startedQuiet else { return }
            startedQuiet = true
            displayAtTheEnd = setup.app.medium(with: mediumID)?.indexStatus
            setup.hold.set(true)
            recording = true
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
        }
        try #require(await setup.runToEnd(fromScratch: true), "Lauf von vorn endet nicht")
        try #require(displayAtTheEnd == .indexing, "Voraussetzung: der Lauf von vorn zeigt „wird indiziert“")
        try #require(await Self.heldAtGate(setup), "stiller Abgleich startet nicht")
        service.finishAfterReleaseHookForTesting = nil
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Anzeige während des Abgleichs: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        let before = setup.recorder.finished
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Abgleich endet nicht")
        #expect(!published.contains(.indexing), "Fortschritt zeigte „wird indiziert“: \(published)")
        await service.waitUntilIdle(id)
    }

    /// (5) Keine Verklemmung: ein im Lauf vorgemerkter Nachhol-Abgleich wartet am Marker und läuft nach dem Abschluss an.
    @Test func rerunAfterTheFinishStarts() async throws {
        let setup = try await Self.gapMedium("NACHHOLEN")
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        try await Self.finishWithPendingRerun(setup) {}
        #expect(await waitUntil { setup.rig.starts(id).count == 3 }, "Nachhol-Abgleich läuft nicht an: \(setup.rig.starts(id))")
        await service.waitUntilIdle(id)
        #expect(!service.hasPendingRerunForTesting(id))
        #expect(!service.isRunActive(id))
    }

    /// (5) Keine Verklemmung: „Neu indizieren“ während eines Laufs bricht ihn ab und startet danach von vorn.
    @Test func scratchRestartDuringARunStartsAfterTheCancel() async throws {
        let setup = try await Self.gapMedium("VONVORNNEU")
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        setup.hold.set(true)
        service.start(mediumUUID: id, volume: setup.volume, fromScratch: false)
        try #require(await Self.heldAtGate(setup), "Lauf hält nicht am Tor")
        service.start(mediumUUID: id, volume: setup.volume, fromScratch: true)
        #expect(await waitUntil { setup.rig.starts(id) == [false, false, true] }, "Neustart von vorn läuft nicht an: \(setup.rig.starts(id))")
        await setup.gate.open()
        await service.waitUntilIdle(id)
        #expect(!service.isRunActive(id))
    }

    /// Umbenennen im Abschluss: der Abschluss bricht ab, der neue Lauf startet danach – keine Überwachung neben ihm.
    @Test func renameDuringTheFinishStartsNoWatchBesideTheNextRun() async throws {
        let box = WatchStarts()
        let setup = try await GapMediumBehavesOnlineTests.gapMedium("UMBENENNEN") { _, _ in
            await MainActor.run { box.count += 1 }
        }
        let coordinator = setup.rig.coordinator
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        let log = Self.log(setup)
        var renamed = setup.volume
        renamed.name = "UMBENANNT"
        let renamedVolume = renamed
        let oldPath = setup.volume.mountPath
        var watchesBeforeTheNextRun: Int?
        var renaming: Task<Void, Never>?
        service.finishAfterReleaseHookForTesting = { _ in
            guard renaming == nil else { return }
            setup.hold.set(true)
            renaming = Task { await coordinator.handle(.renamed(oldPath: oldPath, volume: renamedVolume)) }
            _ = await waitUntil(timeout: 3) { log.cancelArrived || service.hasWaitingStartForTesting(id) }
        }
        // Der erste Lauf aus `gapMedium` startet seine Überwachung im Task aus `onRunIndexed` – erst danach zählen.
        try #require(await waitUntil { box.count >= 1 }, "Überwachung nach dem ersten Lauf startet nicht")
        let baseline = box.count
        try #require(await setup.runToEnd(), "Lauf endet nicht")
        await renaming?.value
        try #require(await Self.heldAtGate(setup), "neuer Lauf startet nicht")
        watchesBeforeTheNextRun = box.count - baseline
        service.finishAfterReleaseHookForTesting = nil
        #expect(watchesBeforeTheNextRun == 0, "Überwachung neben dem neuen Lauf gestartet")
        #expect(log.watched.isEmpty, "alter Abschluss startete die Überwachung")
        await setup.gate.open()
        await service.waitUntilIdle(id)
    }

    /// (b) Ein Start wartet auf den Abschluss, dann wird das Kabel gezogen (nur `disappeared`): kein Lauf mit dem alten
    /// Volume, der Endstand bleibt.
    @Test func disappearDiscardsTheWaitingStart() async throws {
        let setup = try await Self.gapMedium("KABELWEG")
        let coordinator = setup.rig.coordinator
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        let volume = setup.volume
        let log = Self.log(setup)
        var waited: Bool?
        var unmounting: Task<Void, Never>?
        service.finishAfterReleaseHookForTesting = { _ in
            guard waited == nil else { return }
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
            waited = service.hasWaitingStartForTesting(id)
            unmounting = Task { await coordinator.handle(.disappeared(path: volume.mountPath)) }
            _ = await waitUntil(timeout: 3) { log.cancelArrived }
        }
        try #require(await setup.runToEnd(), "Lauf endet nicht")
        try #require(waited == true, "Start wartete nicht auf den Abschluss")
        await unmounting?.value
        await service.waitUntilIdle(id)
        service.finishAfterReleaseHookForTesting = nil
        #expect(setup.rig.starts(id).count == 2, "Lauf nach dem Aushängen: \(setup.rig.starts(id))")
        #expect(setup.app.medium(with: id)?.indexStatus == .error, "Endstand überschrieben: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        #expect(try await setup.storedStatus() == .error)
    }

    // MARK: - (a) Abbruch während des Abschlusses

    /// (a) Aushängen im Abschluss: Endstand bleibt, kein Nachhol-Abgleich, keine Überwachung, kein neuer Lauf.
    @Test func unmountDuringTheFinishKeepsTheEndState() async throws {
        let setup = try await Self.gapMedium("ABSCHLUSSWEG")
        let coordinator = setup.rig.coordinator
        defer { setup.tearDown() }
        setup.memory.markReadable("bad")
        let service = setup.rig.service
        let id = setup.id
        let log = Self.log(setup)
        let path = setup.volume.mountPath
        var unmounting: Task<Void, Never>?
        var rerunKept: Bool?
        try await Self.finishWithPendingRerun(setup) {
            unmounting = Task { await coordinator.handle(.disappeared(path: path)) }
            _ = await waitUntil(timeout: 3) { log.cancelArrived }
            rerunKept = service.hasPendingRerunForTesting(id)
        }
        await unmounting?.value
        await service.waitUntilIdle(id)
        #expect(rerunKept == false, "Nachhol-Abgleich überlebte das Aushängen im Abschluss")
        #expect(try await setup.storedStatus() == .indexed, "Endstand im Speicher überschrieben")
        #expect(setup.app.medium(with: id)?.indexStatus == .indexed, "Anzeige: \(String(describing: setup.app.medium(with: id)?.indexStatus))")
        #expect(log.watched.isEmpty, "Überwachung für ein ausgehängtes Medium")
        #expect(setup.rig.starts(id).count == 2, "Läufe: \(setup.rig.starts(id))")
    }

    /// (a) Sperre im Abschluss: Endstand bleibt, kein Nachhol-Abgleich, keine Überwachung.
    @Test func versionLockDuringTheFinishKeepsTheEndState() async throws {
        let setup = try await Self.gapMedium("ABSCHLUSSSPERRE")
        defer { setup.tearDown() }
        setup.memory.markReadable("bad")
        let service = setup.rig.service
        let app = setup.app
        let id = setup.id
        let log = Self.log(setup)
        var rerunKept: Bool?
        try await Self.finishWithPendingRerun(setup) {
            app.versionLockState = .locked(.betaExpired)
            app.onVersionLockEngaged?()
            _ = await waitUntil(timeout: 3) { log.cancelArrived }
            rerunKept = service.hasPendingRerunForTesting(id)
        }
        await service.waitUntilIdle(id)
        #expect(rerunKept == false, "Nachhol-Abgleich überlebte die Sperre im Abschluss")
        #expect(try await setup.storedStatus() == .indexed, "Endstand im Speicher überschrieben")
        #expect(app.medium(with: id)?.indexStatus == .indexed, "Anzeige: \(String(describing: app.medium(with: id)?.indexStatus))")
        #expect(log.watched.isEmpty, "Überwachung trotz Sperre")
        #expect(setup.rig.starts(id).count == 2, "Läufe: \(setup.rig.starts(id))")
    }

    /// (a) „Nein“ im Abschluss: kein Nachhol-Abgleich, keine Überwachung; danach gilt die Nein-Tabelle (Lücke →
    /// „x % indiziert“), kein Hinweis.
    @Test func declineDuringTheFinishEndsLikeNo() async throws {
        let setup = try await Self.gapMedium("ABSCHLUSSNEIN")
        defer { setup.tearDown() }
        let service = setup.rig.service
        let app = setup.app
        let id = setup.id
        let log = Self.log(setup)
        var rerunKept: Bool?
        try await Self.finishWithPendingRerun(setup) {
            app.updateMedium(id: id, persist: true) {
                $0.decision = .dontIndex
                $0.allowIndexing = false
            }
            _ = await waitUntil(timeout: 3) { log.cancelArrived }
            rerunKept = service.hasPendingRerunForTesting(id)
        }
        await service.waitUntilIdle(id)
        #expect(rerunKept == false, "Nachhol-Abgleich überlebte „Nein“ im Abschluss")
        #expect(await waitUntil { app.medium(with: id)?.indexStatus == .pending }, "Status nach „Nein“: \(String(describing: app.medium(with: id)?.indexStatus))")
        #expect(await waitUntil { (try? await setup.storedStatus()) == .pending }, "gespeicherter Status nach „Nein“")
        #expect(app.indexingFailure == nil, "Hinweis nach „Nein“")
        #expect(log.watched.isEmpty, "Überwachung nach „Nein“")
        #expect(setup.rig.starts(id).count == 2, "Läufe: \(setup.rig.starts(id))")
    }

    /// K5: `LiveWiring.startWatching` für das angeschlossene Medium mit „Ja“; `event` tritt nach dem Lesen des Speichers
    /// ein (gemeinsame Liste mit `WatchStartCheckTests`, bug.0.4.205). Ergebnis: überwacht direkt nach dem Ende von
    /// `startWatching`, und ob der Haken lief.
    private static func watchingAfterTheRead(_ event: WatchStartEvent) async throws -> (watching: Bool, hookRan: Bool) {
        let setup = try await Self.gapMedium("LESEN\(event.rawValue.uppercased())")
        defer { setup.tearDown() }
        let app = setup.app
        let id = setup.id
        let watcher = setup.rig.watcher
        try #require(!watcher.isWatching(mediumID: id), "Voraussetzung: noch nicht überwacht")
        var hookRan = false
        watcher.startAfterReadHookForTesting = { _ in
            hookRan = true
            await event.apply(setup)
        }
        await LiveWiring.startWatching(id: id, volume: setup.volume, store: setup.harness.store, watcher: watcher, appState: app)
        let watching = watcher.isWatching(mediumID: id)
        watcher.startAfterReadHookForTesting = nil
        await watcher.stop(mediumID: id)
        return (watching, hookRan)
    }

    /// K5 (Supervisor 26.10.): Vergessen, „Nein“, Pause, Aushängen (bug.0.4.205) oder `stop` (bug.0.4.206), während
    /// `startWatching` den Speicher liest → keine Überwachung. Gegenprobe ohne Ereignis: sie läuft.
    @Test func startWatchingChecksTheStateAfterTheRead() async throws {
        let plain = try await Self.watchingAfterTheRead(.none)
        try #require(plain.hookRan, "Haken nach dem Lesen lief nicht")
        #expect(plain.watching, "Gegenprobe: ohne Ereignis keine Überwachung")
        for event in [WatchStartEvent.forget, .decline, .pause, .disconnect, .offline, .stop] {
            let result = try await Self.watchingAfterTheRead(event)
            try #require(result.hookRan, "Haken nach dem Lesen lief nicht (\(event))")
            #expect(!result.watching, "Überwachung trotz \(event) während des Lesens")
        }
    }

    /// K4 (204 b „`fromScratch` zusammenführen“): zwei Starts im Abschluss, der erste von vorn → genau ein Lauf danach,
    /// und zwar von vorn.
    @Test func twoStartsDuringTheFinishRunOnceFromScratch() async throws {
        let setup = try await Self.gapMedium("ZWEISTARTS")
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        var waiting: Bool?
        service.finishAfterReleaseHookForTesting = { _ in
            guard waiting == nil else { return }
            setup.hold.set(true)
            service.start(mediumUUID: id, volume: setup.volume, fromScratch: true)
            service.start(mediumUUID: id, volume: setup.volume, fromScratch: false)
            waiting = service.hasWaitingStartForTesting(id)
        }
        let before = setup.rig.starts(id).count
        try #require(await setup.runToEnd(), "alter Lauf endet nicht")
        #expect(waiting == true, "Starts im Abschluss warten nicht")
        try #require(await Self.heldAtGate(setup), "wartender Lauf startet nach dem Abschluss nicht")
        service.finishAfterReleaseHookForTesting = nil
        let finished = setup.recorder.finished
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > finished }, "wartender Lauf endet nicht")
        await service.waitUntilIdle(id)
        #expect(Array(setup.rig.starts(id).dropFirst(before)) == [false, true], "Läufe: \(setup.rig.starts(id))")
    }

    /// K2: Lauf von vorn mit nicht lesbarem Ordner (keine stille Lücke, also mit Hinweis); `decline`: „Nein“ direkt
    /// nach der Freigabe im Abschluss. Gemessen an der Entscheidung über die Überwachung, also nach der Hinweis-Stelle
    /// und vor `endFailureAfterDecline`.
    private static func hintedRunAtTheDecision(_ name: String, decline: Bool) async throws -> (hint: Bool, notice: Bool, shownBefore: Int, shownAfter: Int) {
        let setup = try await Self.gapMedium(name)
        defer { setup.tearDown() }
        let service = setup.rig.service
        let app = setup.app
        let id = setup.id
        app.indexingFailure = nil
        app.failureNoticeMedia.remove(id)
        let shownBefore = Self.failureShownCount(id)
        setup.hold.set(true)
        service.start(mediumUUID: id, volume: setup.volume, fromScratch: true)
        try #require(await heldAtGate(setup), "Lauf hält nicht am Tor")
        var declined = false
        service.finishAfterReleaseHookForTesting = { _ in
            guard decline, !declined else { return }
            declined = true
            app.updateMedium(id: id, persist: true) {
                $0.decision = .dontIndex
                $0.allowIndexing = false
            }
        }
        var measured: (hint: Bool, notice: Bool, shownAfter: Int)?
        let counted = service.finishDecisionHookForTesting
        service.finishDecisionHookForTesting = { finishedID in
            if measured == nil {
                measured = (app.indexingFailure?.id == id, app.failureNoticeMedia.contains(id), Self.failureShownCount(id))
            }
            await counted?(finishedID)
        }
        let before = setup.recorder.finished
        await setup.gate.open()
        try #require(await waitUntil { setup.recorder.finished > before }, "Lauf endet nicht")
        await service.waitUntilIdle(id)
        let result = try #require(measured, "Entscheidung nicht erreicht")
        try #require(declined == decline, "„Nein“ nicht im Abschluss")
        return (result.hint, result.notice, shownBefore, result.shownAfter)
    }

    private static func failureShownCount(_ id: UUID) -> Int {
        let data = AppStateStore.current.data(forKey: AppState.failureCountsKey) ?? Data()
        let counts = (try? JSONDecoder().decode([String: FailureCount].self, from: data)) ?? [:]
        return counts[id.uuidString]?.shown ?? 0
    }

    /// K2 (204 a „Nein → kein Hinweis, keine Mitteilung“): „Nein“ im Abschluss eines Laufs mit Hinweis zeigt weder
    /// Hinweis noch Mitteilung und zählt nicht in der Drossel; Gegenprobe ohne „Nein“: der Hinweis erscheint.
    @Test func declineDuringTheFinishShowsNoHint() async throws {
        let shown = try await Self.hintedRunAtTheDecision("HINWEISJA", decline: false)
        #expect(shown.hint, "Gegenprobe: kein Hinweis ohne „Nein“")
        #expect(shown.notice, "Gegenprobe: keine Mitteilung ohne „Nein“")
        #expect(shown.shownAfter == shown.shownBefore + 1, "Gegenprobe: Drossel zählte nicht")

        let declined = try await Self.hintedRunAtTheDecision("HINWEISNEIN", decline: true)
        #expect(!declined.hint, "Hinweis nach „Nein“ im Abschluss")
        #expect(!declined.notice, "Mitteilung nach „Nein“ im Abschluss")
        #expect(declined.shownAfter == declined.shownBefore, "Drossel zählte einen Hinweis nach „Nein“")
    }

    /// (a) Pause im Abschluss: Endstand bleibt, kein Nachhol-Abgleich, keine Überwachung.
    @Test func pauseDuringTheFinishKeepsTheEndState() async throws {
        let setup = try await Self.gapMedium("ABSCHLUSSPAUSE")
        defer { setup.tearDown() }
        setup.memory.markReadable("bad")
        let service = setup.rig.service
        let app = setup.app
        let id = setup.id
        let log = Self.log(setup)
        var rerunKept: Bool?
        try await Self.finishWithPendingRerun(setup) {
            app.globalAutoIndexPaused = true
            rerunKept = service.hasPendingRerunForTesting(id)
        }
        await service.waitUntilIdle(id)
        #expect(rerunKept == false, "Nachhol-Abgleich überlebte die Pause im Abschluss")
        #expect(try await setup.storedStatus() == .indexed, "Endstand im Speicher überschrieben")
        #expect(app.medium(with: id)?.indexStatus == .indexed, "Anzeige: \(String(describing: app.medium(with: id)?.indexStatus))")
        #expect(log.watched.isEmpty, "Überwachung trotz Pause")
        #expect(setup.rig.starts(id).count == 2, "Läufe: \(setup.rig.starts(id))")
    }

    // MARK: - (b) Wartender Start

    /// (b) Ein Start wartet auf den Abschluss, dann wird das Medium ausgehängt: kein Lauf, nichts bleibt hängen.
    @Test func unmountDiscardsTheWaitingStart() async throws {
        let setup = try await Self.gapMedium("WARTENDWEG")
        let coordinator = setup.rig.coordinator
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        let volume = setup.volume
        let log = Self.log(setup)
        var waited: Bool?
        var discarded: Bool?
        var unmounting: Task<Void, Never>?
        service.finishAfterReleaseHookForTesting = { _ in
            guard waited == nil else { return }
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
            waited = service.hasWaitingStartForTesting(id)
            unmounting = Task { await coordinator.handle(.willDisappear(path: volume.mountPath)) }
            _ = await waitUntil(timeout: 3) { log.cancelArrived }
            discarded = !service.hasWaitingStartForTesting(id)
        }
        try #require(await setup.runToEnd(), "Lauf endet nicht")
        try #require(waited == true, "Start wartete nicht auf den Abschluss")
        await unmounting?.value
        await service.waitUntilIdle(id)
        service.finishAfterReleaseHookForTesting = nil
        #expect(discarded == true, "Aushängen verwarf den wartenden Start nicht")
        #expect(!service.hasWaitingStartForTesting(id))
        #expect(setup.rig.starts(id).count == 2, "Lauf nach dem Aushängen: \(setup.rig.starts(id))")
        #expect(!service.isRunActive(id))
    }

    /// (b) Ein Start wartet auf den Abschluss, dann endet die App: kein Lauf, nichts bleibt hängen.
    @Test func terminationDiscardsTheWaitingStart() async throws {
        let setup = try await Self.gapMedium("WARTENDENDE")
        defer { setup.tearDown() }
        let service = setup.rig.service
        let id = setup.id
        let volume = setup.volume
        var waited: Bool?
        service.finishAfterReleaseHookForTesting = { _ in
            guard waited == nil else { return }
            service.start(mediumUUID: id, volume: volume, fromScratch: false)
            waited = service.hasWaitingStartForTesting(id)
            service.cancelAllForTermination()
        }
        try #require(await setup.runToEnd(), "Lauf endet nicht")
        try #require(waited == true, "Start wartete nicht auf den Abschluss")
        await service.waitUntilIdle(id)
        service.finishAfterReleaseHookForTesting = nil
        #expect(!service.hasWaitingStartForTesting(id))
        #expect(setup.rig.starts(id).count == 2, "Lauf nach dem Beenden: \(setup.rig.starts(id))")
        #expect(!service.isRunActive(id))
    }
}

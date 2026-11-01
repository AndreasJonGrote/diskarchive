//
//  LiveWatchAfterFailedRunTests.swift
//  DiskArchiveTests
//
//  bug.0.4.084 (README: beim Anschließen Lauf und sofort Live-Überwachung): Endet der Lauf mit Fehler, startet die
//  Überwachung trotzdem (angeschlossen, „Indizieren: Ja“, nicht pausiert, nicht gesperrt). Echte Kette (Regel 18):
//  Medium erscheint → Abgleich scheitert (Schreibfehler, vorhandener Testweg) → Überwachung läuft → eine Änderung auf dem
//  Testmedium kommt über die Überwachung im Index an. Der Test ruft keinen Kettenschritt selbst auf.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@MainActor
private final class FailedRunWatcherBox {
    weak var watcher: ChangeWatcher?
    /// Die Verdrahtung wollte die Überwachung starten (bug.0.4.166).
    var startRequested = false
    /// bug.0.4.194 (a): Der Dienst hat entschieden zu überwachen (`onRunIndexed`), synchron gesetzt.
    var runIndexedCalled = false
}

@MainActor
private final class FailedRunDecision {
    var reached = false
}

@Suite(.serialized) @MainActor
struct LiveWatchAfterFailedRunTests {
    @Test func watcherStartsAfterAFailedRunAndDeliversChanges() async throws {
        let harness = try await ScanHarness.make()
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "FEHLER", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let volume = testVolume(path: "/Volumes/FEHLER", name: "FEHLER")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/FEHLER")
        inner.file("alt.txt")
        // Lauf scheitert schnell über den vorhandenen Testweg (Schreibfehler der Datenbank, ohne Lese-Wiederholen).
        await harness.store.setDirectoryWritesFailing(true)
        let app = AppState(store: harness.store)
        let store = harness.store
        let box = FailedRunWatcherBox()
        let rig = WiredRig(store: store, access: inner, app: app) { [box] id, volume in
            guard let watcher = box.watcher else { return }
            await LiveWiring.startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: app)
        }
        box.watcher = rig.watcher
        let source = ScriptedChangeSource()
        rig.watcher.makeSourceForTesting = { _ in source }
        rig.watcher.quietInterval = .milliseconds(50)
        rig.watcher.cursorSaveInterval = nil
        let id = indexed.uuid
        defer { rig.coordinator.stop() }

        await rig.coordinator.handle(.appeared(volume))
        let ran = await waitUntil { !rig.starts(id).isEmpty && !rig.service.isRunActive(id) }
        try #require(ran, "Lauf startete bzw. endete nicht: \(rig.starts(id))")
        let failed = await waitUntil { app.medium(with: id)?.indexStatus == .error || app.indexingFailure != nil }
        #expect(failed, "Lauf endete nicht mit Fehler: \(String(describing: app.medium(with: id)?.indexStatus))")

        let watching = await waitUntil { rig.watcher.isWatching(mediumID: id) }
        #expect(watching, "Überwachung nach gescheitertem Lauf aus")

        await store.setDirectoryWritesFailing(false)
        inner.file("neu.txt")
        source.emit(VolumeChange(path: "/Volumes/FEHLER/neu.txt", eventID: 5, itemCreated: true))
        let arrived = await waitUntil {
            (try? await store.storedNames())?.contains("neu.txt") == true
        }
        let names = (try? await store.storedNames()) ?? []
        #expect(arrived, "Änderung kam nicht über die Überwachung an: \(names)")
        await rig.watcher.stop(mediumID: id)
    }

    /// bug.0.4.095: Schreibfehler bleiben → mehrere Änderungen lösen höchstens einen weiteren Start aus (nach einem
    /// gescheiterten Lauf kein Vollabgleich bis zum nächsten Lauf). Echte Kette, Skript-Quelle (Regel 18).
    @Test func persistentFailureDoesNotLoopFullReconciles() async throws {
        let harness = try await ScanHarness.make()
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "SCHLEIFE", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let volume = testVolume(path: "/Volumes/SCHLEIFE", name: "SCHLEIFE")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/SCHLEIFE")
        inner.file("alt.txt")
        await harness.store.setDirectoryWritesFailing(true)
        let app = AppState(store: harness.store)
        let store = harness.store
        let box = FailedRunWatcherBox()
        let rig = WiredRig(store: store, access: inner, app: app) { [box] id, volume in
            guard let watcher = box.watcher else { return }
            await LiveWiring.startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: app)
        }
        box.watcher = rig.watcher
        let source = ScriptedChangeSource()
        rig.watcher.makeSourceForTesting = { _ in source }
        rig.watcher.quietInterval = .milliseconds(30)
        rig.watcher.cursorSaveInterval = nil
        let id = indexed.uuid
        defer { rig.coordinator.stop() }

        await rig.coordinator.handle(.appeared(volume))
        let watching = await waitUntil { rig.watcher.isWatching(mediumID: id) && !rig.service.isRunActive(id) }
        try #require(watching, "Überwachung nach gescheitertem Lauf aus")
        let startsBefore = rig.starts(id).count
        for round in 1...3 {
            let listedBefore = inner.listed.filter { $0 == "/Volumes/SCHLEIFE" }.count
            inner.file("neu\(round).txt")
            source.emit(VolumeChange(path: "/Volumes/SCHLEIFE/neu\(round).txt", eventID: Int64(10 + round), itemCreated: true))
            // Positives Signal: die Überwachung hat den Ordner neu gelesen (Schreiben scheitert).
            let reread = await waitUntil {
                inner.listed.filter { $0 == "/Volumes/SCHLEIFE" }.count > listedBefore
                    && !rig.service.isRunActive(id)
            }
            #expect(reread, "Runde \(round): Änderung nicht gelesen")
        }
        let settled = await waitUntil { !rig.service.isRunActive(id) && rig.watcher.isWatching(mediumID: id) }
        #expect(settled)
        #expect(rig.starts(id).count <= startsBefore + 1, "Schleife: \(rig.starts(id).count - startsBefore) weitere Starts")
        await rig.watcher.stop(mediumID: id)
    }

    /// bug.0.4.095: Zeitüberschreitung (hängendes Medium) und Abbruch starten die Überwachung nach Fehler nicht.
    @Test func timeoutAndInterruptionDoNotWatchAfterFailure() {
        let failed = IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: nil, failureReason: .database)
        #expect(IndexingService.watchesAfterFailure(failed))
        var timeout = IndexRunOutcome(status: .pending, readErrors: 1, progress: [], completedDepths: [], firstIndexedAt: nil, failureReason: .timeout)
        #expect(!IndexingService.watchesAfterFailure(timeout))
        timeout.status = .error
        #expect(!IndexingService.watchesAfterFailure(timeout))
        var interrupted = failed
        interrupted.interrupted = true
        #expect(!IndexingService.watchesAfterFailure(interrupted))
    }

    /// bug.0.4.186: Endet der Lauf mit „Medium konnte nicht bestätigt werden“, startet keine Überwachung (unter dem Pfad
    /// kann ein anderes Medium liegen); jeder andere Fehlergrund startet sie wie bisher.
    @Test func unconfirmedRunDoesNotWatchButOtherFailuresDo() {
        let unconfirmed = IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: nil, failureReason: .unconfirmed)
        #expect(!IndexingService.watchesAfterFailure(unconfirmed))
        let unknown = IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: nil, failureReason: .unknown)
        #expect(IndexingService.watchesAfterFailure(unknown))
    }

    /// bug.0.4.186 (Regel 18): echte Kette – der Abgleich endet „nicht bestätigt“ (Prüfung vor dem Abschluss zweimal
    /// negativ, kein Aushängen-Ereignis) → die Überwachung bleibt aus, ein Ereignis unter dem Pfad schreibt nichts.
    @Test func unconfirmedRunLeavesTheWatcherOffAndWritesNothing() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/UNBESTAETIGT", name: "UNBESTAETIGT")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let inner = MemoryVolume(mountPath: volume.mountPath)
        inner.file("A/a.txt").file("C/c.txt").file("C/c2.txt")
        let first = try await harness.run(access: inner, maxDepth: nil, fromScratch: true, volume: harness.volume(at: volume.mountPath))
        try #require(first.status == .indexed, "Voraussetzung: erster Lauf vollständig")
        try await harness.store.updateMediumIndexStatus(uuid: harness.mediumID, .indexed)
        inner.remove("C/c.txt")
        inner.scriptMountChecks([false, false])
        inner.resetMountChecks()
        let app = AppState(store: harness.store)
        let store = harness.store
        let box = FailedRunWatcherBox()
        let rig = WiredRig(store: store, access: inner, app: app) { [box] id, volume in
            box.startRequested = true
            guard let watcher = box.watcher else { return }
            await LiveWiring.startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: app)
        }
        box.watcher = rig.watcher
        let source = ScriptedChangeSource()
        rig.watcher.makeSourceForTesting = { _ in source }
        rig.watcher.quietInterval = .milliseconds(50)
        rig.watcher.cursorSaveInterval = nil
        let id = harness.mediumID
        defer { rig.coordinator.stop() }

        // bug.0.4.191 (a): Die Entscheidung über die Überwachung folgt auf den Haken ohne weiteren Aufschub auf dem Main
        // Actor; ist der Haken beobachtet, steht sie fest – kein Warten auf eine Frist nötig.
        let decided = FailedRunDecision()
        rig.service.finishDecisionHookForTesting = { _ in decided.reached = true }
        // bug.0.4.194 (a): Die Verdrahtung startet die Überwachung erst in einem eigenen Task; die Entscheidung selbst
        // (Aufruf von `onRunIndexed`) fällt synchron direkt nach dem Haken – hier abgefangen, damit sie feststeht.
        let wired = rig.service.onRunIndexed
        rig.service.onRunIndexed = { [box] id, volume in
            box.runIndexedCalled = true
            wired?(id, volume)
        }
        await rig.coordinator.handle(.appeared(volume))
        // Positives Signal: der Lauf endete mit dem Fehler „nicht bestätigt“ und die Entscheidung ist gefallen.
        let failed = await waitUntil(timeout: 20) {
            decided.reached && !rig.service.isRunActive(id) && app.indexingFailure?.reason == .unconfirmed
        }
        try #require(failed, "Lauf endete nicht mit „nicht bestätigt“")
        #expect(!box.runIndexedCalled, "Überwachung nach „nicht bestätigt“ entschieden")
        #expect(!box.startRequested, "Überwachung nach „nicht bestätigt“ angefordert")
        #expect(!rig.watcher.isWatching(mediumID: id), "Überwachung nach „nicht bestätigt“ aktiv")
        #expect(!rig.service.suppressesFullReconcile(id))
        // Ein Ereignis unter dem Pfad erreicht niemanden (keine Überwachung) und schreibt nichts: die entfernte Datei bleibt
        // im Index, der Lauf bleibt als Fehler stehen.
        source.emit(VolumeChange(path: volume.mountPath + "/C/c.txt", eventID: 1, fileSystemUUID: nil, itemRemoved: true))
        await Task { @MainActor in }.value
        let rows: Int = try await harness.store.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE name = 'c.txt'") ?? 0 }
        #expect(rows == 1, "Ereignis ohne Überwachung hat den Index verändert")
        #expect(app.medium(with: id)?.indexStatus == .error)
        await rig.watcher.stop(mediumID: id)
    }

    /// bug.0.4.095: pausiert, „Indizieren“ aus oder gesperrt → keine Überwachung nach Fehler.
    @Test func pausedDisallowedOrLockedDoNotWatchAfterFailure() async throws {
        let harness = try await ScanHarness.make()
        let app = AppState(store: harness.store)
        let id = harness.mediumID
        var medium = try #require(try await harness.store.medium(uuid: id)).asMedium(connection: .connected)
        medium.decision = .index
        medium.allowIndexing = true
        app.media = [medium]
        let service = IndexingService(store: harness.store, access: MemoryVolume(mountPath: "/Volumes/T"), appState: app)
        #expect(service.watchesAfterFailedRun(id))
        app.globalAutoIndexPaused = true
        #expect(!service.watchesAfterFailedRun(id))
        app.globalAutoIndexPaused = false
        app.updateMedium(id: id) { $0.allowIndexing = false }
        #expect(!service.watchesAfterFailedRun(id))
        app.updateMedium(id: id) { $0.allowIndexing = true }
        app.versionLockState = .locked(.betaExpired)
        #expect(!service.watchesAfterFailedRun(id))
    }

    /// bug.0.4.166 (a): Der Lauf scheitert (Schreibfehler); zwischen Ende und Entscheidung wird pausiert bzw. die
    /// Versions-Sperre rastet ein → `watchesAfterFailedRun` muss Pause bzw. Sperre beachten, die Überwachung bleibt aus.
    /// (Ein Abbruch erreicht die Entscheidung nicht: `cancel` nimmt dem Lauf den Token, `finish` entscheidet nicht.)
    @Test(arguments: ["pause", "sperre"])
    func failedRunWithPauseOrLockAtTheEndDoesNotWatch(scenario: String) async throws {
        let harness = try await ScanHarness.make()
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "ENDE-\(scenario)", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let volume = testVolume(path: "/Volumes/ENDE-\(scenario)", name: "ENDE-\(scenario)")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
        let inner = MemoryVolume(mountPath: volume.mountPath)
        inner.file("alt.txt")
        await harness.store.setDirectoryWritesFailing(true)
        let app = AppState(store: harness.store)
        let store = harness.store
        let box = FailedRunWatcherBox()
        let rig = WiredRig(store: store, access: inner, app: app) { [box] id, volume in
            box.startRequested = true
            guard let watcher = box.watcher else { return }
            await LiveWiring.startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: app)
        }
        box.watcher = rig.watcher
        rig.watcher.makeSourceForTesting = { _ in ScriptedChangeSource() }
        let id = indexed.uuid
        defer { rig.coordinator.stop() }
        let decided = FailedRunDecision()
        rig.service.finishDecisionHookForTesting = { _ in
            if scenario == "pause" {
                app.globalAutoIndexPaused = true
            } else {
                app.versionLockState = .locked(.betaExpired)
            }
            decided.reached = true
        }
        await rig.coordinator.handle(.appeared(volume))
        // Positives Signal: Lauf gestartet, gescheitert, Entscheidung erreicht.
        let ended = await waitUntil {
            decided.reached && !rig.service.isRunActive(id) && app.medium(with: id)?.indexStatus != .indexing
        }
        try #require(ended, "Lauf endete nicht bzw. Entscheidung nicht erreicht")
        try #require(app.indexingFailure != nil || app.medium(with: id)?.indexStatus == .error, "Lauf scheiterte nicht")
        // Der Start der Überwachung liefe nach der Entscheidung asynchron: eine Zeit lang darauf achten, dass er nicht
        // kommt (weder angefordert noch aktiv).
        let started = await waitUntil(timeout: 1.5) { box.startRequested || rig.watcher.isWatching(mediumID: id) }
        #expect(!started, "Überwachung nach Fehler trotz \(scenario)")
        #expect(!rig.service.suppressesFullReconcile(id), "Entscheidung „Überwachung nach Fehler“ getroffen")
    }

    /// bug.0.4.155/160 (Regel 18): echte Kette – der Lauf läuft, wird pausiert, abgebrochen bzw. scheitert bei
    /// „Indizieren: Nein“ →
    /// die Überwachung bleibt aus (Gegenprobe: `watcherStartsAfterAFailedRunAndDeliversChanges`, gleicher Aufbau ohne Pause).
    @Test func pausedOrCancelledRunDoesNotStartTheWatcher() async throws {
        // „aus“: „Indizieren: Nein“ während des Laufs – der Lauf scheitert (Schreibfehler), die Überwachung nach Fehler
        // prüft `watchesAfterFailedRun` und bleibt aus. Pause und Abbruch enden unterbrochen (`watchesAfterFailure`).
        for scenario in ["pause", "cancel", "aus"] {
            let harness = try await ScanHarness.make()
            let indexed = StoredMedium(
                fsType: "apfs", volumeTotalBytes: 1_000, name: "AUS-\(scenario)", type: .usb,
                decision: .index, indexStatus: .indexed, completedDepth: 1
            )
            try await harness.store.upsertMedium(indexed)
            let volume = testVolume(path: "/Volumes/AUS-\(scenario)", name: "AUS-\(scenario)")
            try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
            let inner = MemoryVolume(mountPath: volume.mountPath)
            inner.file("hold/alt.txt")
            let gate = RunGateAccess([inner]) { $0 == "\(volume.mountPath)/hold" }
            let app = AppState(store: harness.store)
            let store = harness.store
            let box = FailedRunWatcherBox()
            let rig = WiredRig(store: store, access: gate, app: app) { [box] id, volume in
                guard let watcher = box.watcher else { return }
                await LiveWiring.startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: app)
            }
            box.watcher = rig.watcher
            rig.watcher.makeSourceForTesting = { _ in ScriptedChangeSource() }
            let id = indexed.uuid
            defer { rig.coordinator.stop() }
            // bug.0.4.160: in beiden Fällen läuft wirklich ein Lauf (am Tor angehalten), Schreiben scheitert.
            await rig.coordinator.handle(.appeared(volume))
            await gate.entered.wait()
            try #require(!rig.starts(id).isEmpty, "kein Lauf gestartet")
            await store.setDirectoryWritesFailing(true)
            switch scenario {
            case "pause": app.globalAutoIndexPaused = true
            case "cancel": await rig.service.cancel(mediumUUID: id)
            default: app.updateMedium(id: id) { $0.allowIndexing = false }
            }
            await gate.open()
            await rig.service.waitUntilIdle(id)
            // Positives Signal: Lauf beendet, Ergebnis gespeichert (nicht mehr „wird indiziert“).
            let saved = await waitUntil {
                guard !rig.service.isRunActive(id), app.medium(with: id)?.indexStatus != .indexing else { return false }
                let stored = try? await store.medium(uuid: id)
                return stored != nil && stored?.indexStatus != .indexing
            }
            try #require(saved, "Lauf endete nicht (\(scenario))")
            #expect(!rig.watcher.isWatching(mediumID: id), "Überwachung nach \(scenario) gestartet")
        }
    }
}

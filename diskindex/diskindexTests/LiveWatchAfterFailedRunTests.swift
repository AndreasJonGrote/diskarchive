//
//  LiveWatchAfterFailedRunTests.swift
//  diskindexTests
//
//  bug.0.4.084 (README: beim Anschließen Lauf und sofort Live-Überwachung): Endet der Lauf mit Fehler, startet die
//  Überwachung trotzdem (angeschlossen, „Indizieren: Ja“, nicht pausiert, nicht gesperrt). Echte Kette (Regel 18):
//  Medium erscheint → Abgleich scheitert (Schreibfehler, vorhandener Testweg) → Überwachung läuft → eine Änderung auf dem
//  Testmedium kommt über die Überwachung im Index an. Der Test ruft keinen Kettenschritt selbst auf.
//

import Foundation
import Testing
@testable import diskindex

@MainActor
private final class FailedRunWatcherBox {
    weak var watcher: ChangeWatcher?
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

    /// bug.0.4.155 (Regel 18): echte Kette – der Lauf scheitert, während das Medium pausiert ist bzw. wird abgebrochen →
    /// die Überwachung bleibt aus (Gegenprobe: `watcherStartsAfterAFailedRunAndDeliversChanges`, gleicher Aufbau ohne Pause).
    @Test func pausedOrCancelledRunDoesNotStartTheWatcher() async throws {
        for scenario in ["pause", "cancel"] {
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
            if scenario == "pause" {
                await store.setDirectoryWritesFailing(true)
                app.globalAutoIndexPaused = true
                await rig.coordinator.handle(.appeared(volume))
                // Positives Signal: der Abgleich wurde angefragt und vom Dienst abgelehnt (Pause), kein Lauf.
                try await Task.sleep(for: .milliseconds(500))
                #expect(rig.starts(id).isEmpty, "Lauf trotz Pause gestartet")
            } else {
                await rig.coordinator.handle(.appeared(volume))
                await gate.entered.wait()
                await rig.service.cancel(mediumUUID: id)
                await gate.open()
                await rig.service.waitUntilIdle(id)
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(!rig.watcher.isWatching(mediumID: id), "Überwachung nach \(scenario) gestartet")
        }
    }
}

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
}

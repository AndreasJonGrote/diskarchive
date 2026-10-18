//
//  VersionLockWatcherTests.swift
//  diskindexTests
//
//  bug.0.4.073 / bug.0.4.076 d: Überwachung beim Einrasten der Nur-Lesen-Sperre (`stopAllForVersionLock`).
//

import Foundation
import Testing
@testable import diskindex

@MainActor
private final class FlushHookProbe {
    let entered = SurfaceAsyncSignal()
    let gate = SurfaceAsyncSignal()
    var returned = false
}

/// Zwei Flushes nacheinander am selben Hook: der erste und der zweite halten je an einem eigenen Tor.
@MainActor
private final class TwoFlushProbe {
    let firstGate = SurfaceAsyncSignal()
    let secondGate = SurfaceAsyncSignal()
    var entries = 0
    var firstReturned = false
}

@Suite(.serialized) @MainActor
struct VersionLockWatcherTests {
    /// `stopAllForVersionLock`: Generationen erhöht, Ereignisstand und gepufferte Pfade verworfen, Überwachung aus.
    /// „Nichts geschrieben“ belegt `flushInFlightWritesNothingAfterQuickUnlock` (alter Flush nach schnellem Entsperren).
    @Test func stopAllForVersionLockDiscardsState() async throws {
        let rig = try await watchRig()
        let id = rig.medium.uuid
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false,
                isHidden: false, fileSize: 1, modifiedAt: nil
            ),
        ]
        rig.watcher.cursorSaveInterval = nil
        rig.watcher.quietInterval = .milliseconds(150)
        rig.watcher.start(mediumID: id, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 42, itemCreated: true))
        try #require(await waitUntil {
            rig.watcher.hasEventCursorForTesting(id) && !rig.watcher.pendingPathsForTesting(id).isEmpty
        })
        let generationBefore = rig.watcher.watchGenerationForTesting(id)
        let lockGenerationBefore = rig.watcher.versionLockGenerationForTesting

        rig.app.versionLockState = .locked(.betaExpired)
        rig.watcher.stopAllForVersionLock()

        #expect(rig.watcher.watchGenerationForTesting(id) == generationBefore + 1)
        #expect(rig.watcher.versionLockGenerationForTesting == lockGenerationBefore + 1)
        #expect(!rig.watcher.hasEventCursorForTesting(id))
        #expect(rig.watcher.pendingPathsForTesting(id).isEmpty)
        #expect(rig.watcher.pendingItemEventCountForTesting(id) == 0)
        #expect(!rig.watcher.isWatching(mediumID: id))
    }

    /// bug.0.4.076 d: Ein Flush hält nach dem Vorbereiten an (Hook je Instanz); dabei rastet die Sperre ein und
    /// `stopAllForVersionLock` leert die Puffer. Der Flush legt seine Pfade danach nicht zurück.
    @Test func flushInFlightDoesNotRequeueAfterVersionLockStop() async throws {
        let rig = try await watchRig()
        let id = rig.medium.uuid
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false,
                isHidden: false, fileSize: 1, modifiedAt: nil
            ),
        ]
        let probe = FlushHookProbe()
        rig.watcher.flushAfterPrepareHookForTesting = { [probe] in
            await probe.entered.signal()
            await probe.gate.wait()
            probe.returned = true
        }
        rig.watcher.cursorSaveInterval = nil
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: id, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 7, itemCreated: true))
        await probe.entered.wait()

        rig.app.versionLockState = .locked(.betaExpired)
        rig.watcher.stopAllForVersionLock()
        await probe.gate.signal()
        try #require(await waitUntil { probe.returned })
        // Nach dem Hook läuft der Flush ohne weitere Unterbrechung bis zur Rückkehr; trotzdem kurz Luft lassen.
        try await Task.sleep(for: .milliseconds(100))

        #expect(rig.watcher.pendingPathsForTesting(id).isEmpty)
        #expect(rig.watcher.pendingItemEventCountForTesting(id) == 0)
        rig.app.versionLockState = .unlocked
        try await Task.sleep(for: .milliseconds(300))
        #expect(rig.access.listCount(for: "/Volumes/DISK/A") == 0)
        #expect(rig.watcher.pendingPathsForTesting(id).isEmpty)
    }

    /// bug.0.4.076 d (Punkt 3 der Prüfung): Der Flush hält nach dem Vorbereiten an; Sperre, `stopAllForVersionLock`
    /// und sofortiges Entsperren, dann Hook frei. Der alte Flush liest und schreibt nichts mehr.
    @Test func flushInFlightWritesNothingAfterQuickUnlock() async throws {
        let rig = try await watchRig()
        let id = rig.medium.uuid
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(
                name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false,
                isHidden: false, fileSize: 1, modifiedAt: nil
            ),
        ]
        let probe = FlushHookProbe()
        rig.watcher.flushAfterPrepareHookForTesting = { [probe] in
            await probe.entered.signal()
            await probe.gate.wait()
            probe.returned = true
        }
        rig.watcher.cursorSaveInterval = nil
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: id, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 7, itemCreated: true))
        await probe.entered.wait()

        rig.app.versionLockState = .locked(.betaExpired)
        rig.watcher.stopAllForVersionLock()
        rig.app.versionLockState = .unlocked
        await probe.gate.signal()
        try #require(await waitUntil { probe.returned })
        try await Task.sleep(for: .milliseconds(300))

        #expect(rig.access.listCount(for: "/Volumes/DISK/A") == 0)
        #expect(rig.watcher.pendingPathsForTesting(id).isEmpty)
        let parent = try await rig.store.folderID(mediumUUID: id, path: ["A"])
        let children = try await rig.store.children(mediumUUID: id, parentID: parent).map(\.name)
        #expect(!children.contains("neu.txt"))
        #expect((try await rig.store.medium(uuid: id)?.lastEventID ?? 0) == 0)
    }
    /// bug.0.4.080 c): Flush A hält am Hook; Sperre, `stopAllForVersionLock`, schnelles Entsperren, Überwachung neu,
    /// Flush B hält ebenfalls. Endet A danach, bleibt die `flushInFlight`-Marke von B stehen.
    @Test func oldFlushDoesNotClearMarkOfNewFlushAfterQuickUnlock() async throws {
        let rig = try await watchRig()
        let id = rig.medium.uuid
        let probe = TwoFlushProbe()
        rig.watcher.flushAfterPrepareHookForTesting = { [probe] in
            probe.entries += 1
            if probe.entries == 1 {
                await probe.firstGate.wait()
                probe.firstReturned = true
            } else {
                await probe.secondGate.wait()
            }
        }
        rig.watcher.cursorSaveInterval = nil
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: id, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/eins.txt", eventID: 7, itemCreated: true))
        try #require(await waitUntil { probe.entries >= 1 })

        rig.app.versionLockState = .locked(.betaExpired)
        rig.watcher.stopAllForVersionLock()
        rig.app.versionLockState = .unlocked
        // Neue Überwachung mit neuer Quelle (ein AsyncStream endet mit dem Stopp seines Lesers).
        let second = ScriptedChangeSource()
        rig.watcher.start(mediumID: id, volume: rig.volume, source: second)
        second.emit(VolumeChange(path: "/Volumes/DISK/A/zwei.txt", eventID: 8, itemCreated: true))
        try #require(await waitUntil { probe.entries >= 2 })
        #expect(rig.watcher.isFlushInFlightForTesting(id))

        await probe.firstGate.signal()
        try #require(await waitUntil { probe.firstReturned })
        // A läuft nach dem Hook ohne weitere Unterbrechung bis zum `defer`; kurz Luft lassen.
        try await Task.sleep(for: .milliseconds(100))
        #expect(rig.watcher.isFlushInFlightForTesting(id), "Marke des neuen Flushes entfernt")

        await probe.secondGate.signal()
        #expect(await waitUntil { !rig.watcher.isFlushInFlightForTesting(id) })
        await rig.watcher.stop(mediumID: id)
    }
}

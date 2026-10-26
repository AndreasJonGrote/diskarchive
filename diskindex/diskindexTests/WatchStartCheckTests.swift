//
//  WatchStartCheckTests.swift
//  diskindexTests
//
//  bug.0.4.205 — Die Überwachung startet nur, wenn der aktuelle Zustand es erlaubt: Alle drei Startwege
//  (`LiveWiring.startWatching`, Pausenende `applyPause`, Neustart nach Stream-Unmount `restartWatchIfConnected`) prüfen
//  nach ihrem letzten `await` über `ChangeWatcher.mayStartWatching`. Ereignis im Lesefenster über den Haken
//  `startAfterReadHookForTesting` (je Instanz), Medium im Speicher (`MemoryVolume`), kein `sleep`.
//

import Foundation
import Testing
@testable import diskindex

/// Ereignis, das eintritt, nachdem ein Startweg der Überwachung den Speicher gelesen hat.
enum WatchStartEvent: String {
    case none, forget, decline, pause, disconnect
    /// Neuer Durchlauf des Pausenendes, der dieses Medium auslässt (wie nach dem Entsperren mit Abgleich).
    case pauseRoundSkipping
    /// `watcher.stop` wie in `stopWatcherAndStartIndex` (Umbenennen, Regeländerung, Voll-Abgleich), bug.0.4.206.
    case stop
    /// Nur die Anzeige „nicht angeschlossen“, ohne `stop` – belegt die Prüfung „angeschlossen“ allein (`.disconnect`
    /// stoppt über `onMediumDisappeared` auch die Überwachung, das fängt schon die Generation), bug.0.4.206.
    case offline

    @MainActor
    func apply(_ setup: GapMediumBehavesOnlineTests.Setup) async {
        let app = setup.app
        let id = setup.id
        switch self {
        case .none:
            break
        case .forget:
            app.forgetMedium(id: id)
        case .decline:
            app.updateMedium(id: id, persist: true) {
                $0.decision = .dontIndex
                $0.allowIndexing = false
            }
        case .pause:
            app.globalAutoIndexPaused = true
            app.onAutoIndexPauseChanged?()
        case .disconnect:
            await setup.rig.coordinator.handle(.disappeared(path: setup.volume.mountPath))
        case .pauseRoundSkipping:
            setup.rig.watcher.pauseChanged(skipping: [id])
        case .stop:
            await setup.rig.watcher.stop(mediumID: id)
        case .offline:
            app.updateMedium(id: id) { $0.connectionStatus = .offline }
        }
    }
}

@Suite(.serialized) @MainActor
struct WatchStartCheckTests {
    @MainActor
    final class Sources {
        var made: [ScriptedChangeSource] = []
    }

    /// Jeder Start der Überwachung legt eine Quelle an – gezählt, auch wenn danach etwas sie wieder stoppt.
    private static func countStarts(_ setup: GapMediumBehavesOnlineTests.Setup) -> Sources {
        let sources = Sources()
        setup.rig.watcher.makeSourceForTesting = { _ in
            let source = ScriptedChangeSource()
            sources.made.append(source)
            return source
        }
        return sources
    }

    /// Haken nach dem Lesen: `event` einmal für dieses Medium. `done` wird erst am Ende gesetzt; danach laufen die
    /// Prüfung und `start` ohne weiteres `await` im selben Schritt, ein `waitUntil { done }` sieht also ihr Ergebnis.
    @MainActor
    final class Hook {
        var ran = false
        var done = false
    }

    private static func hook(_ setup: GapMediumBehavesOnlineTests.Setup, _ event: WatchStartEvent) -> Hook {
        let hook = Hook()
        let id = setup.id
        setup.rig.watcher.startAfterReadHookForTesting = { readID in
            guard readID == id, !hook.ran else { return }
            hook.ran = true
            await event.apply(setup)
            hook.done = true
        }
        return hook
    }

    // MARK: - Pausenende (`applyPause`)

    private static func startsAfterPauseEnd(_ event: WatchStartEvent) async throws -> Int {
        let setup = try await GapMediumBehavesOnlineTests.gapMedium("PAUSE\(event.rawValue.uppercased())")
        defer { setup.tearDown() }
        let watcher = setup.rig.watcher
        try #require(!watcher.isWatching(mediumID: setup.id), "Voraussetzung: noch nicht überwacht")
        let sources = Self.countStarts(setup)
        let hook = Self.hook(setup, event)
        watcher.pauseChanged()
        try #require(await waitUntil { hook.done }, "Haken nach dem Lesen lief nicht (\(event))")
        let starts = sources.made.count
        watcher.startAfterReadHookForTesting = nil
        await watcher.stop(mediumID: setup.id)
        return starts
    }

    /// Pausenende liest den Speicher, dann Vergessen, „Nein“, erneute Pause, ein neuer Durchlauf ohne dieses Medium,
    /// Aushängen oder `stop` (bug.0.4.206) → keine Überwachung. Gegenprobe ohne Ereignis: sie startet.
    @Test func pauseEndChecksTheStateAfterTheRead() async throws {
        #expect(try await Self.startsAfterPauseEnd(.none) == 1, "Gegenprobe: Pausenende startet die Überwachung nicht")
        for event in [WatchStartEvent.forget, .decline, .pause, .pauseRoundSkipping, .disconnect, .offline, .stop] {
            #expect(try await Self.startsAfterPauseEnd(event) == 0, "Überwachung trotz \(event) während des Lesens")
        }
    }

    // MARK: - Neustart nach Stream-Unmount (`restartWatchIfConnected`)

    private static func startsAfterStreamUnmount(_ event: WatchStartEvent) async throws -> (starts: Int, watching: Bool) {
        let setup = try await GapMediumBehavesOnlineTests.gapMedium("NEUSTART\(event.rawValue.uppercased())")
        defer { setup.tearDown() }
        let watcher = setup.rig.watcher
        let id = setup.id
        let sources = Self.countStarts(setup)
        await LiveWiring.startWatching(id: id, volume: setup.volume, store: setup.harness.store, watcher: watcher, appState: setup.app)
        let first = try #require(sources.made.first, "Voraussetzung: Überwachung läuft")
        try #require(watcher.isWatching(mediumID: id))
        let hook = Self.hook(setup, event)
        first.emit(VolumeChange(path: setup.volume.mountPath, eventID: 1, unmounted: true))
        try #require(await waitUntil { hook.done }, "Haken nach dem Lesen lief nicht (\(event))")
        let result = (sources.made.count - 1, watcher.isWatching(mediumID: id))
        watcher.startAfterReadHookForTesting = nil
        await watcher.stop(mediumID: id)
        return result
    }

    /// Stream-Unmount, der Neustart liest den Speicher, dann Vergessen, „Nein“, Pause, Aushängen oder `stop`
    /// (bug.0.4.206) → keine Überwachung. Gegenprobe ohne Ereignis: sie läuft wieder an.
    /// Gegenprobe zugleich Beweis, dass der Neustart überhaupt ankommt (bug.0.4.205: lief vorher im abgebrochenen Task).
    @Test
    func restartAfterStreamUnmountChecksTheStateAfterTheRead() async throws {
        let plain = try await Self.startsAfterStreamUnmount(.none)
        #expect(plain.starts == 1, "Gegenprobe: kein Neustart nach dem Stream-Unmount")
        #expect(plain.watching, "Gegenprobe: Überwachung läuft nicht wieder")
        for event in [WatchStartEvent.forget, .decline, .pause, .disconnect, .offline, .stop] {
            let result = try await Self.startsAfterStreamUnmount(event)
            #expect(result.starts == 0, "Überwachung trotz \(event) während des Lesens")
        }
    }

    // MARK: - Stream-Unmount gilt nur für seinen Stream (bug.0.4.207)

    enum AfterSave: String {
        case none, stop
        /// `stop` und neuer Start wie beim Aufwachen (`LiveWiring.startWatching`).
        case stopAndStart
    }

    /// Stream-Unmount, im Haken nach `saveCursor` `event`; danach wird ein angestoßener Neustart abgewartet.
    private static func afterStreamUnmount(_ event: AfterSave) async throws -> (starts: Int, watching: Bool) {
        let setup = try await GapMediumBehavesOnlineTests.gapMedium("UNMOUNT\(event.rawValue.uppercased())")
        defer { setup.tearDown() }
        let watcher = setup.rig.watcher
        let id = setup.id
        let sources = Self.countStarts(setup)
        await LiveWiring.startWatching(id: id, volume: setup.volume, store: setup.harness.store, watcher: watcher, appState: setup.app)
        let first = try #require(sources.made.first, "Voraussetzung: Überwachung läuft")
        try #require(watcher.isWatching(mediumID: id))
        let hook = Hook()
        watcher.streamUnmountAfterSaveHookForTesting = { savedID in
            guard savedID == id, !hook.ran else { return }
            hook.ran = true
            // Eigener Task wie beim Aufwachen: Der Haken läuft im Überwachungs-Task, den `stop` abbricht.
            await Task { @MainActor in
                switch event {
                case .none:
                    break
                case .stop:
                    await watcher.stop(mediumID: id)
                case .stopAndStart:
                    await watcher.stop(mediumID: id)
                    await LiveWiring.startWatching(
                        id: id, volume: setup.volume, store: setup.harness.store, watcher: watcher, appState: setup.app
                    )
                }
            }.value
            hook.done = true
        }
        first.emit(VolumeChange(path: setup.volume.mountPath, eventID: 1, unmounted: true))
        // `done` am Ende des Hakens: danach läuft `handleStreamUnmount` ohne weiteres `await` zu Ende.
        try #require(await waitUntil { hook.done }, "Haken nach saveCursor lief nicht (\(event))")
        await watcher.streamRestartForTesting[id]?.value
        let result = (sources.made.count - 1, watcher.isWatching(mediumID: id))
        watcher.streamUnmountAfterSaveHookForTesting = nil
        await watcher.stop(mediumID: id)
        return result
    }

    /// Gegenprobe: ohne Ereignis nach `saveCursor` kommt der Neustart an und die Überwachung läuft wieder.
    @Test func streamUnmountRestartsTheWatch() async throws {
        let result = try await Self.afterStreamUnmount(.none)
        #expect(result.starts == 1, "Gegenprobe: kein Neustart nach dem Stream-Unmount")
        #expect(result.watching, "Gegenprobe: Überwachung läuft nicht wieder")
    }

    /// `stop` und neuer Start während `saveCursor` → der alte Stream-Unmount lässt die neue Überwachung stehen und
    /// startet nichts weiter.
    @Test func streamUnmountSparesANewerWatch() async throws {
        let result = try await Self.afterStreamUnmount(.stopAndStart)
        #expect(result.watching, "Neue Überwachung vom alten Stream-Unmount abgeräumt")
        #expect(result.starts == 1, "Genau ein Start (der neue), kein weiterer durch den Neustart")
    }

    /// Nur `stop` während `saveCursor` → kein Neustart.
    @Test func streamUnmountAfterStopRestartsNothing() async throws {
        let result = try await Self.afterStreamUnmount(.stop)
        #expect(result.starts == 0, "Neustart trotz stop während saveCursor")
        #expect(!result.watching, "Überwachung trotz stop während saveCursor")
    }
}

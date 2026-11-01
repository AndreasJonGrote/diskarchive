//
//  IndexProgressRuleTests.swift
//  DiskArchiveTests
//
//  bug.0.4.210 — eine Rechnung für jede Fortschrittsanzeige (Konzept „Fortschritt“, „Eine Rechnung“): Tabelle mit den
//  Fällen des Nutzers vom 26.10., dazu Gegenproben über den echten Indexer und die verdrahtete Kette (Medium im
//  Speicher, kein `sleep`).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct IndexProgressRuleTests {
    private struct Row {
        let label: String
        let status: IndexStatus
        var phase: IndexRunPhase = .indexing
        let entries: Int
        let total: Int
        /// Wert des laufenden Laufs (`indexingProgress`), nur bei `.indexing`.
        var run: Double = 0
        let percent: Int
    }

    private static func medium(_ row: Row) -> Medium {
        var medium = Medium(
            id: UUID(), name: "T", type: .usb, connectionStatus: .connected, indexStatus: row.status,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0,
            fileCount: row.entries, folderCount: 0, lastSeenAt: nil, firstIndexedAt: Date(), lastIndexedAt: nil,
            isForgotten: false, indexingProgress: row.run
        )
        medium.scanTotal = row.total
        medium.indexRunPhase = row.phase
        medium.completedDepth = 1
        return medium
    }

    /// Fälle 1–5 mit den Zahlen des Nutzers, „Fehler mit Lücke“ (gespeichert = Gesamtzahl), „indiziert“, Erstlauf.
    @Test func everyDisplayFollowsTheOneRule() {
        let rows: [Row] = [
            Row(label: "1 Abbruch: gespeicherter Stand", status: .pending, entries: 15_323, total: 45_920, percent: 33),
            Row(label: "2 offline wie online", status: .pending, entries: 19_617, total: 45_920, percent: 42),
            Row(label: "3 Zählphase mit gespeicherter Gesamtzahl", status: .indexing, phase: .counting,
                entries: 15_613, total: 45_920, run: 15_613.0 / 45_920.0, percent: 34),
            Row(label: "4 „Neu indizieren“, 256 alt, 0 neu", status: .indexing, entries: 256, total: 256, run: 0, percent: 0),
            Row(label: "5 Umbenennen mitten im Lauf", status: .pending, entries: 19_617, total: 45_920, percent: 42),
            Row(label: "Fehler mit Lücke, gespeichert = Gesamtzahl", status: .error, entries: 100, total: 100, percent: 99),
            Row(label: "indiziert", status: .indexed, entries: 100, total: 100, percent: 100),
            Row(label: "Erstlauf, Zählphase ohne Gesamtzahl", status: .indexing, phase: .counting, entries: 16, total: 0, percent: 0),
            Row(label: "Bestand über der Gesamtzahl", status: .pending, entries: 120, total: 100, percent: 99),
        ]
        for row in rows {
            let medium = Self.medium(row)
            #expect(medium.indexProgressPercent == row.percent, "\(row.label): \(medium.indexProgressPercent) statt \(row.percent)")
            var offline = medium
            offline.connectionStatus = .offline
            #expect(offline.indexProgressPercent == medium.indexProgressPercent, "\(row.label): offline anders als online")
        }
    }

    /// Fall 3: Ein fortgesetzter Lauf zeigt vom ersten Moment an den gespeicherten Stand – die Rampe „mindestens 1 s
    /// sichtbar“ beginnt dort, nicht bei 0 %. Gegenprobe: ein neuer Lauf ab 0 läuft weiter über die Rampe.
    @Test func resumedRunNeverDipsBelowTheStoredValue() throws {
        let app = AppState()
        let resumed = Self.medium(Row(label: "fortgesetzt", status: .indexing, entries: 15_323, total: 45_920,
                                      run: 15_323.0 / 45_920.0, percent: 33))
        var fresh = Self.medium(Row(label: "neu", status: .indexing, entries: 0, total: 100, run: 0, percent: 0))
        fresh.indexingProgress = 0.8
        app.media = [resumed, fresh]
        let start = Date(timeIntervalSince1970: 90_000)
        app.noteIndexSample(id: resumed.id, status: .indexing, fraction: resumed.indexProgressFraction, now: start)
        app.noteIndexSample(id: fresh.id, status: .indexing, fraction: 0, now: start)
        app.noteIndexSample(id: fresh.id, status: .indexing, fraction: 0.8, now: start.addingTimeInterval(0.1))
        let half = start.addingTimeInterval(0.3)
        #expect(app.displayedProgress(fresh.id, now: half).map { abs($0 - 0.5) < 0.01 } == true, "Gegenprobe: keine Rampe ab 0")
        for offset in [0.0, 0.05, 0.1, 0.3] {
            let value = try #require(app.displayedProgress(resumed.id, now: start.addingTimeInterval(offset)))
            #expect(IndexProgress.percent(value) == 33, "fortgesetzt zeigt \(IndexProgress.percent(value)) % bei \(offset) s")
        }
    }

    // MARK: - Fortsetzen über den echten Indexer

    /// Ein Lauf hält mitten in Ebene 3 an (Inhalt von `a` und `b` geschrieben, `c` nicht), der Folgelauf liest Ebene 3 neu:
    /// Der Zähler bleibt bei den wirklich gespeicherten Einträgen, nichts doppelt.
    @Test func resumingCountsNoEntryTwice() async throws {
        let harness = try await ScanHarness.make()
        defer { harness.closeDatabase() }
        let mount = "/Volumes/WEITER"
        let memory = MemoryVolume(mountPath: mount)
        for folder in ["a", "b", "c"] {
            for index in 0..<10 { memory.file("top/\(folder)/f\(index).txt") }
        }
        // Erst beim zweiten Lesen von `b` anhalten: das erste ist die Zählphase, das zweite das Schreiben von Ebene 3.
        let reads = ReadCount()
        let gate = RunGateAccess([memory], holds: { $0 == mount + "/top/b" && reads.next() == 2 })
        let halt = HaltFlag()
        let first = Task { @MainActor in
            try await harness.run(
                access: gate, maxDepth: nil, fromScratch: false, volume: harness.volume(at: mount),
                shouldHalt: { halt.value ? .pause : .none }
            )
        }
        await gate.entered.wait()
        halt.set()
        await gate.open()
        let stopped = try await first.value
        #expect(stopped.status == .pending, "Voraussetzung: der erste Lauf hält an")
        let between = try #require(try await harness.store.medium(uuid: harness.mediumID))
        try #require(between.completedDepth == 2, "Voraussetzung: Ebene 3 (a, b, c) unvollständig")

        let progress = ProgressLog()
        let resumed = try await harness.run(
            access: memory, maxDepth: nil, fromScratch: false, volume: harness.volume(at: mount),
            onProgress: { progress.append($0) }
        )
        #expect(resumed.status == .indexed)
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        // Auch die Schlussmeldung: Zwischenmeldungen sind auf 250 ms gedrosselt.
        let counted = progress.values.filter { $0.phase == .indexing }.map(\.entriesCompleted)
        try #require(!counted.isEmpty, "Gegenprobe: keine Fortschrittsmeldung")
        #expect(counted.max() ?? 0 <= stored.fileCount + stored.folderCount,
                "doppelt gezählt: \(counted.max() ?? 0) > \(stored.fileCount + stored.folderCount) gespeichert")
    }

    // MARK: - Verdrahtete Kette

    private struct Chain {
        let harness: ScanHarness
        let volume: VolumeInfo
        let memory: MemoryVolume
        let gate: RunGateAccess
        let hold: GateHold
        let app: AppState
        let rig: WiredRig
        let finished: FinishCount
        var id: UUID { harness.mediumID }

        @MainActor
        func tearDown() {
            rig.coordinator.stop()
            harness.closeDatabase()
        }
    }

    /// Medium mit einem tiefen Baum: Ebene 1 und 2 sind wenige Einträge, der Rest liegt darunter. `extra`: weitere
    /// Datenträger hinter demselben Tor (zweites Medium).
    private static func chain(_ name: String, extra: [MemoryVolume] = []) async throws -> Chain {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/\(name)", name: name)
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let memory = MemoryVolume(mountPath: volume.mountPath)
        for folder in ["a", "b", "c", "d"] {
            for index in 0..<25 { memory.file("top/mid/\(folder)/f\(index).txt") }
        }
        let hold = GateHold()
        let gate = RunGateAccess([memory] + extra, holds: { hold.holds($0) })
        let app = AppState(store: harness.store, defaults: TestDefaults.make())
        let rig = WiredRig(store: harness.store, access: gate, app: app)
        let finished = FinishCount()
        rig.service.finishDecisionHookForTesting = { _ in finished.count += 1 }
        return Chain(harness: harness, volume: volume, memory: memory, gate: gate, hold: hold, app: app, rig: rig, finished: finished)
    }

    /// Fall 1: Abziehen mitten im Lauf → kein kurzes 100 %, danach der gespeicherte Stand; offline wie online.
    @Test func abortNeverShowsHundred() async throws {
        let chain = try await Self.chain("ABBRUCH")
        defer { chain.tearDown() }
        chain.hold.path = chain.volume.mountPath + "/top/mid/c"
        await chain.rig.coordinator.handle(.appeared(chain.volume))
        await chain.gate.entered.wait()
        let running = try #require(chain.app.medium(with: chain.id))
        try #require(running.indexStatus == .indexing, "Gegenprobe: der Lauf zeigt „wird indiziert“")
        await chain.rig.coordinator.handle(.disappeared(path: chain.volume.mountPath))
        await chain.gate.open()
        await chain.rig.service.waitUntilIdle(chain.id)
        let ended = Date()
        let medium = try #require(chain.app.medium(with: chain.id))
        try #require(medium.indexStatus != .indexed, "Voraussetzung: abgebrochen")
        let stored = try #require(try await chain.harness.store.medium(uuid: chain.id))
        for step in 0...20 {
            let value = chain.app.displayedProgress(chain.id, now: ended.addingTimeInterval(Double(step) * 0.05))
            #expect(value != 1, "kurzes 100 % nach dem Abbruch bei \(Double(step) * 0.05) s")
        }
        let expected = IndexProgressRuleTests.percent(entries: stored.fileCount + stored.folderCount, total: stored.scanTotal)
        #expect(medium.indexProgressPercent == expected, "nicht der gespeicherte Stand")
        var offline = medium
        offline.connectionStatus = .offline
        #expect(offline.indexProgressPercent == medium.indexProgressPercent, "offline anders als online")
        let reloaded = stored.asMedium(connection: .offline)
        #expect(reloaded.indexProgressPercent == medium.indexProgressPercent, "aus dem Speicher geladen anders")
    }

    /// Fall 4: „Neu indizieren“ eines vollständig indizierten Mediums beginnt unten, nicht bei 99 % – im Indexer (erste
    /// Meldung des Laufs) und in der Anzeige des laufenden Laufs.
    @Test func reindexStartsLow() async throws {
        let chain = try await Self.chain("NEU")
        defer { chain.tearDown() }
        await chain.rig.coordinator.handle(.appeared(chain.volume))
        try #require(await waitUntil { chain.finished.count > 0 }, "erster Lauf endet nicht")
        try #require(chain.app.medium(with: chain.id)?.indexStatus == .indexed, "Gegenprobe: erster Lauf vollständig")

        let progress = ProgressLog()
        let outcome = try await chain.harness.run(
            access: chain.memory, maxDepth: nil, fromScratch: true, volume: chain.volume, onProgress: { progress.append($0) }
        )
        #expect(outcome.status == .indexed)
        let first = try #require(progress.values.first { $0.phase == .indexing && !$0.finished },
                                 "Gegenprobe: keine Meldung während des Laufs")
        #expect(first.ratio < 0.5, "„Neu indizieren“ beginnt im Indexer bei \(first.ratio)")

        chain.hold.path = chain.volume.mountPath + "/top/mid/a"
        chain.rig.service.start(mediumUUID: chain.id, volume: chain.volume, fromScratch: true)
        await chain.gate.entered.wait()
        let running = try #require(chain.app.medium(with: chain.id))
        try #require(running.indexStatus == .indexing, "Gegenprobe: „Neu indizieren“ läuft")
        #expect(running.indexProgressFraction < 0.5, "„Neu indizieren“ zeigt \(running.indexProgressFraction)")
        await chain.gate.open()
        try #require(await waitUntil { chain.finished.count > 1 }, "„Neu indizieren“ endet nicht")
        #expect(chain.app.medium(with: chain.id)?.indexProgressPercent == 100)
    }

    /// Ein zweites Medium indiziert gleichzeitig: Jedes zeigt seinen eigenen Wert.
    @Test func aSecondMediumKeepsItsOwnValue() async throws {
        let otherVolume = testVolume(path: "/Volumes/ZWEITES", name: "ZWEITES")
        let otherMemory = MemoryVolume(mountPath: otherVolume.mountPath)
        for index in 0..<10 { otherMemory.file("x/f\(index).txt") }
        let chain = try await Self.chain("ERSTES", extra: [otherMemory])
        defer { chain.tearDown() }
        let other = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ZWEITES", type: .usb, decision: .index)
        try await chain.harness.store.upsertMedium(other)
        try await chain.harness.store.recordIdentity(mediumUUID: other.uuid, otherVolume.identity)
        chain.hold.path = chain.volume.mountPath + "/top/mid/c"
        await chain.rig.coordinator.handle(.appeared(chain.volume))
        await chain.gate.entered.wait()
        let before = try #require(chain.app.medium(with: chain.id)?.indexProgressFraction)
        try #require(chain.app.medium(with: chain.id)?.indexStatus == .indexing, "Gegenprobe: das erste Medium läuft")

        await chain.rig.coordinator.handle(.appeared(otherVolume))
        try #require(await waitUntil { chain.app.medium(with: other.uuid)?.indexStatus == .indexed }, "zweites Medium endet nicht")
        #expect(chain.app.medium(with: other.uuid)?.indexProgressPercent == 100, "Gegenprobe: zweites Medium fertig")
        let after = try #require(chain.app.medium(with: chain.id)?.indexProgressFraction)
        #expect(after == before, "das zweite Medium ändert den Wert des ersten (\(before) → \(after))")
        await chain.gate.open()
    }

    /// bug.0.4.222: Abziehen mitten in einer Ebene (mehrere Stücke schon geschrieben, das nächste Schreiben trifft den
    /// Abbruch) und Wiedereinstecken: zuletzt online, offline und zu Beginn nach dem Wiedereinstecken derselbe ganze
    /// Prozentwert. Verdrahtete Kette, Medium im Speicher (Ebene 3: `a` und `b` mit je zwei Stücken bei Stückgröße 2000).
    /// Das zweite Stück von `a` hat einen Eintrag, kommt also Millisekunden nach dem ersten und hebt die Anzeige genau von
    /// 49 auf 50 % (2005 von 4010): Eine Drossel, die es verschluckt, zeigt beim Abziehen den älteren Wert.
    @Test func unplugMidLayerKeepsThePercent() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/STECKER", name: "STECKER")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let memory = MemoryVolume(mountPath: volume.mountPath)
        for (folder, count) in [("a", 2_001), ("b", 2_004), ("c", 1)] {
            for index in 0..<count { memory.file("top/\(folder)/f\(index).txt") }
        }
        let gate = ReplugGate(memory)
        let app = AppState(store: harness.store, defaults: TestDefaults.make())
        let rig = WiredRig(store: harness.store, access: gate, app: app)
        defer {
            rig.coordinator.stop()
            harness.closeDatabase()
        }
        let id = harness.mediumID

        // Ebene 3: `a` ist geschrieben (zwei Stücke), `b` wartet (der erste Lesevorgang von `b` ist die Zählphase).
        let held = gate.arm(path: volume.mountPath + "/top/b", skip: 1)
        await rig.coordinator.handle(.appeared(volume))
        await held.wait()
        try #require(app.medium(with: id)?.indexStatus == .indexing, "Gegenprobe: der Lauf zeigt „wird indiziert“")
        // Positives Signal: die Anzeige hat alles Geschriebene erreicht (Ebene 1–2: `top`, `a`, `b`, `c`; dazu `a` mit
        // 2001 Dateien, zusammen 2005 von 4010 Einträgen). Die Meldung kommt nach dem Schreiben über einen Sprung auf den
        // Haupt-Thread an.
        let online = Self.percent(entries: 4 + 2_001, total: 4_010)
        let shown = await waitUntil(timeout: 5) { app.medium(with: id)?.indexProgressPercent == online }
        #expect(shown, "der Lauf zeigt \(app.medium(with: id)?.indexProgressPercent ?? -1) % statt \(online) % für alles Geschriebene")

        // Abziehen: das nächste Schreiben (erstes Stück von `b`) trifft den Abbruch.
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        gate.release()
        await rig.service.waitUntilIdle(id)
        let offline = try #require(app.medium(with: id))
        try #require(offline.connectionStatus == .offline && offline.indexStatus != .indexed, "Voraussetzung: abgebrochen und offline")

        // Wiedereinstecken: der Folgelauf beginnt Ebene 3 mit `a` und wartet dort.
        let resumedHold = gate.arm(path: volume.mountPath + "/top/a", skip: 0)
        await rig.coordinator.handle(.appeared(volume))
        await resumedHold.wait()
        let resumed = try #require(app.medium(with: id))
        try #require(resumed.indexStatus == .indexing, "Gegenprobe: der Folgelauf läuft")

        #expect(offline.indexProgressPercent == online, "offline \(offline.indexProgressPercent) %, zuletzt online \(online) %")
        #expect(resumed.indexProgressPercent == online, "nach dem Wiedereinstecken \(resumed.indexProgressPercent) %, zuletzt online \(online) %")
        gate.release()
        await rig.service.waitUntilIdle(id)
    }

    private static func percent(entries: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(99, Int(floor(Double(entries) / Double(max(total, entries)) * 100)))
    }
}

/// Tor, das nach dem Öffnen erneut scharf gestellt werden kann (Abziehen und Wiedereinstecken desselben Mediums).
private final class ReplugGate: MediumAccess, @unchecked Sendable {
    private let volume: MemoryVolume
    private let lock = NSLock()
    private var rule: (path: String, skip: Int, signal: SurfaceAsyncSignal)?
    private var released = false

    init(_ volume: MemoryVolume) {
        self.volume = volume
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    /// Hält das `skip + 1`-te Lesen von `path` an; das Signal meldet das Anhalten.
    func arm(path: String, skip: Int) -> SurfaceAsyncSignal {
        let signal = SurfaceAsyncSignal()
        lock.withLock {
            rule = (path, skip, signal)
            released = false
        }
        return signal
    }

    func release() {
        lock.withLock { released = true }
    }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let path = url.standardizedFileURL.path
        let hit: SurfaceAsyncSignal? = lock.withLock {
            guard let current = rule, current.path == path else { return nil }
            if current.skip > 0 {
                rule = (current.path, current.skip - 1, current.signal)
                return nil
            }
            rule = nil
            return current.signal
        }
        if let hit {
            await hit.signal()
            // Auch nach dem Abbruch bis `release()`: das Lesen liefert, und erst das Schreiben trifft den Abbruch.
            while !lock.withLock({ released }) {
                if Task.isCancelled { await Task.yield() } else { try? await Task.sleep(for: .milliseconds(5)) }
            }
        }
        return try await volume.listDirectory(at: url)
    }
}

private final class HaltFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}

private final class ReadCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int { lock.withLock { count += 1; return count } }
}

private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [IndexProgress] = []
    var values: [IndexProgress] { lock.withLock { stored } }
    func append(_ progress: IndexProgress) { lock.withLock { stored.append(progress) } }
}

private final class GateHold: @unchecked Sendable {
    private let lock = NSLock()
    private var held: String?
    var path: String? {
        get { lock.withLock { held } }
        set { lock.withLock { held = newValue } }
    }
    func holds(_ candidate: String) -> Bool { path == candidate }
}

@MainActor
private final class FinishCount {
    var count = 0
}


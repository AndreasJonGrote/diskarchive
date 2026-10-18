//
//  SlowVolumeMountTests.swift
//  diskindexTests
//
//  bug.0.3.9.012 — Langsames Volume beim Einhängen nicht verlieren: erneut versuchen, höchstens eine laufende
//  Abfrage je Pfad, ausgehängt → nicht weiter versuchen, andere Volumes warten nicht.
//
//  Je Test ein eigenes NotificationCenter, eigene Abfrage, eigene Protokollsenke und kurze Zeiten je Instanz
//  (kein prozessweiter Schalter, Regel 20). Es wird nichts an NSWorkspace gemeldet.
//

import AppKit
import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct SlowVolumeMountTests {
    /// Erste Abfrage hängt über die Zeitgrenze hinaus (und kommt dann leer zurück), die zweite antwortet →
    /// genau ein `.appeared`, auch nach Ablauf aller weiteren Wartezeiten.
    @Test func hangingFirstLookupYieldsExactlyOneAppeared() async throws {
        let path = "/Volumes/Slow-\(UUID().uuidString)"
        let expected = Self.volume(path: path)
        let script = ScriptedLookup(byCall: { call in call == 1 ? .hold(returning: nil) : .answer(expected) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let monitor = Self.monitor(center: center, script: script, sink: sink, timeout: 0.3, delays: [0.5, 2, 2])
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: path, on: center)
        let held = await script.arrived()
        try #require(held == false, "erste Abfrage hat das Tor nicht erreicht oder lief auf main")
        let timedOut = await waitUntil(timeout: 8) { sink.count(of: "volume-lookup zeitgrenze") >= 1 }
        try #require(timedOut, "Zeitgrenze des ersten Versuchs nicht gemeldet")
        #expect(events.appeared.isEmpty, "vor der Antwort darf nichts erscheinen")
        script.open()

        let appeared = await waitUntil(timeout: 8) { !events.appeared.isEmpty }
        #expect(appeared, "langsames Volume ging verloren (kein neuer Versuch)")
        // Danach kommt kein zweites: länger warten als die nächste Wartezeit samt Zeitgrenze (2 s + 0,3 s).
        try await Task.sleep(for: .seconds(2.5))
        #expect(events.appeared == [expected])
        #expect(script.calls == 2)
        #expect(sink.count(of: "volume nicht erreichbar") == 0)
    }

    /// Hängt die Abfrage über mehrere Versuche, hängt sich jeder neue Versuch an die laufende an (höchstens ein
    /// belegter GCD-Thread je Pfad); antwortet sie schließlich, erscheint das Volume genau einmal.
    @Test func retriesJoinHangingLookupInsteadOfStartingAnother() async throws {
        let path = "/Volumes/Spinning-\(UUID().uuidString)"
        let expected = Self.volume(path: path)
        // Jede Abfrage hängt bis zum Öffnen: ein zweiter gestarteter Lookup bliebe ebenfalls hängen.
        let script = ScriptedLookup(byCall: { _ in .hold(returning: expected) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let flights = VolumeLookupFlights(lookup: { script.lookup($0) })
        let monitor = MediumMonitor(
            mountedVolumes: { [] },
            wakeEvents: { AsyncStream { _ in } },
            notificationCenter: center,
            lookupFlights: flights,
            lookupTimeout: 0.2,
            mountRetryDelays: Array(repeating: 0.1, count: 20),
            log: { sink.add($0, path: $1) }
        )
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: path, on: center)
        let held = await script.arrived()
        try #require(held == false, "erste Abfrage hat das Tor nicht erreicht oder lief auf main")
        let retried = await waitUntil(timeout: 8) { sink.count(of: "volume-lookup zeitgrenze") >= 3 }
        try #require(retried, "keine wiederholten Versuche")
        #expect(flights.startedLookups(path: path) == 1, "neuer Versuch startete eine zweite Abfrage neben der hängenden")
        #expect(script.calls == 1)
        script.open()

        let appeared = await waitUntil(timeout: 8) { !events.appeared.isEmpty }
        #expect(appeared)
        try await Task.sleep(for: .seconds(1.5))
        #expect(events.appeared == [expected])
    }

    /// Ausgehängt während der Wartezeit → kein `.appeared`, keine weiteren Abfragen, keine Protokollzeile.
    @Test func unmountDuringRetryWaitStopsLookups() async throws {
        let path = "/Volumes/Gone-\(UUID().uuidString)"
        let script = ScriptedLookup(byCall: { _ in .answer(nil) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let monitor = Self.monitor(center: center, script: script, sink: sink, timeout: 2, delays: [3, 3, 3])
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: path, on: center)
        let firstDone = await waitUntil(timeout: 8) { script.calls >= 1 }
        try #require(firstDone)
        Self.post(NSWorkspace.didUnmountNotification, path: path, on: center)
        let gone = await waitUntil(timeout: 8) { events.disappeared.contains(path) }
        try #require(gone)

        // Länger als die erste Wartezeit (3 s): ohne Abbruch käme es zu einer weiteren Abfrage.
        try await Task.sleep(for: .seconds(4))
        #expect(script.calls == 1, "nach dem Aushängen weiter versucht")
        #expect(events.appeared.isEmpty)
        #expect(sink.count(of: "volume nicht erreichbar") == 0)
    }

    /// Antwortet das Volume nie: nach allen Versuchen genau eine Protokollzeile „volume nicht erreichbar“.
    @Test func unreachableVolumeLogsAfterAllRetries() async throws {
        let path = "/Volumes/Never-\(UUID().uuidString)"
        let script = ScriptedLookup(byCall: { _ in .answer(nil) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let monitor = Self.monitor(center: center, script: script, sink: sink, timeout: 2, delays: [0.05, 0.05, 0.05])
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: path, on: center)
        let logged = await waitUntil(timeout: 8) { sink.count(of: "volume nicht erreichbar") >= 1 }
        #expect(logged)
        #expect(script.calls == 4, "erster Versuch plus drei Wiederholungen")
        #expect(sink.paths(of: "volume nicht erreichbar") == [path])
        #expect(events.appeared.isEmpty)
    }

    /// Ein hängendes Volume hält ein anderes, gleichzeitig eingehängtes nicht auf.
    @Test func hangingVolumeDoesNotDelayOtherMount() async throws {
        let slowPath = "/Volumes/SlowA-\(UUID().uuidString)"
        let fastPath = "/Volumes/FastB-\(UUID().uuidString)"
        let fast = Self.volume(path: fastPath)
        let script = ScriptedLookup(byPath: { url in
            url.path == slowPath ? .hold(returning: nil) : .answer(fast)
        })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let monitor = Self.monitor(center: center, script: script, sink: sink, timeout: 60, delays: [60])
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: slowPath, on: center)
        let held = await script.arrived()
        try #require(held == false)
        Self.post(NSWorkspace.didMountNotification, path: fastPath, on: center)
        let appeared = await waitUntil(timeout: 8) { !events.appeared.isEmpty }
        #expect(appeared, "zweites Volume wartet hinter dem hängenden")
        #expect(events.appeared == [fast])
    }

    /// Korrektur 1: Ein Volume, das beim Start-Scan hängt, wird wie beim Einhängen erneut versucht und erscheint
    /// genau einmal.
    @Test func volumeHangingDuringStartScanAppearsOnceAfterRetry() async throws {
        let path = "/Volumes/ScanSlow-\(UUID().uuidString)"
        let expected = Self.volume(path: path)
        let script = ScriptedLookup(byCall: { call in call == 1 ? .hold(returning: nil) : .answer(expected) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let monitor = Self.monitor(
            center: center, script: script, sink: sink, timeout: 0.3, delays: [0.5, 2, 2], scanPaths: [path]
        )
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        let held = await script.arrived()
        try #require(held == false, "Scan-Abfrage hat das Tor nicht erreicht oder lief auf main")
        let timedOut = await waitUntil(timeout: 8) { sink.count(of: "volume-lookup zeitgrenze") >= 1 }
        try #require(timedOut, "Zeitgrenze des Scans nicht gemeldet")
        #expect(events.appeared.isEmpty)
        script.open()

        let appeared = await waitUntil(timeout: 8) { !events.appeared.isEmpty }
        #expect(appeared, "beim Scan hängendes Volume ging verloren (kein neuer Versuch)")
        try await Task.sleep(for: .seconds(2.5))
        #expect(events.appeared == [expected])
        #expect(script.calls == 2)
    }

    /// Korrektur 2: Ein Flug, der nie zurückkehrt, blockiert den Pfad nicht dauerhaft: nach dem Aushängen startet ein
    /// neues Einhängen eine neue Abfrage, die antwortet.
    @Test func neverReturningLookupDoesNotBlockRemount() async throws {
        let path = "/Volumes/Stuck-\(UUID().uuidString)"
        let expected = Self.volume(path: path)
        let script = ScriptedLookup(byCall: { call in call == 1 ? .hold(returning: nil) : .answer(expected) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let flights = VolumeLookupFlights(lookup: { script.lookup($0) })
        let monitor = MediumMonitor(
            mountedVolumes: { [] },
            wakeEvents: { AsyncStream { _ in } },
            notificationCenter: center,
            lookupFlights: flights,
            lookupTimeout: 0.3,
            mountRetryDelays: [3, 3, 3],
            log: { sink.add($0, path: $1) }
        )
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: path, on: center)
        let held = await script.arrived()
        try #require(held == false)
        Self.post(NSWorkspace.didUnmountNotification, path: path, on: center)
        let gone = await waitUntil(timeout: 8) { events.disappeared.contains(path) }
        try #require(gone)

        // Erste Abfrage hängt weiter (Tor bleibt zu); neues Einhängen darf sich nicht an sie hängen.
        Self.post(NSWorkspace.didMountNotification, path: path, on: center)
        let appeared = await waitUntil(timeout: 8) { !events.appeared.isEmpty }
        #expect(appeared, "neues Einhängen hängt an der verlassenen Abfrage")
        #expect(events.appeared == [expected])
        #expect(flights.startedLookups(path: path) == 2)
    }

    /// Korrektur 3: Umbenannt, während das Einhängen noch wartet → unter dem neuen Pfad als Einhängen melden
    /// (kein `.renamed` für ein nie gemeldetes Volume), alter Pfad nicht weiter versuchen.
    @Test func renameWhileMountPendingResolvesNewPath() async throws {
        let oldPath = "/Volumes/Untitled-\(UUID().uuidString)"
        let newPath = "/Volumes/Renamed-\(UUID().uuidString)"
        let renamed = Self.volume(path: newPath)
        let script = ScriptedLookup(byPath: { url in url.path == newPath ? .answer(renamed) : .answer(nil) })
        defer { script.open() }
        let sink = MountLogSink()
        let center = NotificationCenter()
        let monitor = Self.monitor(center: center, script: script, sink: sink, timeout: 2, delays: [3, 3, 3])
        let events = MountEventCollector(monitor.events())
        defer { events.stop() }

        Self.post(NSWorkspace.didMountNotification, path: oldPath, on: center)
        let firstDone = await waitUntil(timeout: 8) { script.calls >= 1 }
        try #require(firstDone)
        center.post(name: NSWorkspace.didRenameVolumeNotification, object: nil, userInfo: [
            NSWorkspace.volumeURLUserInfoKey: URL(fileURLWithPath: newPath, isDirectory: true),
            NSWorkspace.oldVolumeURLUserInfoKey: URL(fileURLWithPath: oldPath, isDirectory: true),
        ])
        let appeared = await waitUntil(timeout: 8) { !events.appeared.isEmpty }
        #expect(appeared, "umbenanntes, noch wartendes Volume nicht gemeldet")
        #expect(events.appeared == [renamed])
        #expect(events.renamedCount == 0, ".renamed für ein nie gemeldetes Volume")
        // Länger als die erste Wartezeit (3 s): der alte Pfad darf nicht erneut abgefragt werden.
        try await Task.sleep(for: .seconds(4))
        #expect(script.calls == 2, "alter Pfad weiter versucht")
    }

    // MARK: - Hilfen

    private static func monitor(
        center: NotificationCenter,
        script: ScriptedLookup,
        sink: MountLogSink,
        timeout: TimeInterval,
        delays: [TimeInterval],
        scanPaths: [String]? = nil
    ) -> MediumMonitor {
        // Ohne Scan-Pfade feste leere Liste, sonst echter Scan über die Flights.
        var fixedList: (@MainActor () async -> [VolumeInfo])?
        if scanPaths == nil {
            fixedList = { [] }
        }
        return MediumMonitor(
            mountedVolumes: fixedList,
            candidateMountPaths: { scanPaths ?? [] },
            wakeEvents: { AsyncStream { _ in } },
            notificationCenter: center,
            lookupFlights: VolumeLookupFlights(lookup: { script.lookup($0) }),
            lookupTimeout: timeout,
            mountRetryDelays: delays,
            log: { sink.add($0, path: $1) }
        )
    }

    private static func post(_ name: Notification.Name, path: String, on center: NotificationCenter) {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        center.post(name: name, object: nil, userInfo: [NSWorkspace.volumeURLUserInfoKey: url])
    }

    private static func volume(path: String) -> VolumeInfo {
        VolumeInfo(
            mountPath: path, name: URL(fileURLWithPath: path).lastPathComponent, fsType: "apfs",
            volumeTotalBytes: 1_000, volumeFreeBytes: 500, diskSizeBytes: 1_000, volumeUUID: nil, createdAt: nil,
            isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: nil, model: nil, isTimeMachineSnapshot: false
        )
    }
}

/// Abfrage nach Drehbuch: zählt Aufrufe; `.hold` meldet sich am Tor und wartet, bis der Test öffnet (dauerhaft offen).
private final class ScriptedLookup: @unchecked Sendable {
    enum Step {
        case hold(returning: VolumeInfo?)
        case answer(VolumeInfo?)
    }

    private let lock = NSLock()
    private var callCount = 0
    private var isOpen = false
    private let semaphore = DispatchSemaphore(value: 0)
    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation
    private let step: (Int, URL) -> Step

    init(byCall step: @escaping (Int) -> Step) {
        self.step = { call, _ in step(call) }
        (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    init(byPath step: @escaping (URL) -> Step) {
        self.step = { _, url in step(url) }
        (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    var calls: Int { lock.withLock { callCount } }

    func lookup(_ url: URL) -> VolumeInfo? {
        let call: Int = lock.withLock {
            callCount += 1
            return callCount
        }
        switch step(call, url) {
        case .answer(let info):
            return info
        case .hold(let info):
            continuation.yield(Thread.isMainThread)
            let open = lock.withLock { isOpen }
            if !open {
                semaphore.wait()
            }
            return info
        }
    }

    /// Erste Meldung einer hängenden Abfrage (`true` = lief auf main).
    func arrived() async -> Bool? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    /// Öffnet das Tor dauerhaft (mehrfach aufrufbar, auch aus `defer`).
    func open() {
        let first: Bool = lock.withLock {
            let wasOpen = isOpen
            isOpen = true
            return !wasOpen
        }
        guard first else { return }
        // Großzügig freigeben: jede bereits wartende Abfrage kommt frei.
        for _ in 0..<16 { semaphore.signal() }
        continuation.finish()
    }
}

/// Eigene Protokollsenke je Test (statt `DiskIndexLog.shared`).
private final class MountLogSink: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [(message: String, path: String)] = []

    func add(_ message: String, path: String = "") {
        lock.withLock { lines.append((message, path)) }
    }

    func count(of message: String) -> Int {
        lock.withLock { lines.filter { $0.message == message }.count }
    }

    func paths(of message: String) -> [String] {
        lock.withLock { lines.filter { $0.message == message }.map(\.path) }
    }
}

/// Sammelt die Ereignisse des Monitors auf dem MainActor.
@MainActor
private final class MountEventCollector {
    private(set) var appeared: [VolumeInfo] = []
    private(set) var disappeared: [String] = []
    private(set) var renamedCount = 0
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<MediumEvent>) {
        task = Task { @MainActor [weak self] in
            for await event in stream {
                switch event {
                case .appeared(let info):
                    self?.appeared.append(info)
                case .disappeared(let path):
                    self?.disappeared.append(path)
                case .renamed:
                    self?.renamedCount += 1
                default:
                    break
                }
            }
        }
    }

    func stop() {
        task?.cancel()
    }
}

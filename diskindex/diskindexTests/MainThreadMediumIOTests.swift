//
//  MainThreadMediumIOTests.swift
//  diskindexTests
//
//  bug.0.4.021 — Medien-Probe und Volume-Lookup nicht auf dem Hauptfaden blockieren.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct MainThreadMediumIOTests {
    /// bug.0.3.8.004: ohne Zeitvergleich. Die Prüfung meldet ihren Thread und wartet auf ein Tor, das der Test erst
    /// nach einem gelungenen MainActor-Sprung öffnet. Liefe sie auf main, käme der Sprung nie an: Notfall-Zeitgrenze
    /// des Tors (10 s) → „Zeitgrenze“ → rot.
    @Test func directProbeKeepsMainActorResponsive() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-probe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let volume = VolumeInfo(
            mountPath: mount.path,
            name: "Probe",
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 500,
            diskSizeBytes: 1_000,
            volumeUUID: nil,
            createdAt: nil,
            isRemovable: false,
            isEjectable: false,
            isInternal: true,
            isLocal: true,
            deviceProtocol: nil,
            model: nil,
            isTimeMachineSnapshot: false
        )
        let gate = MainHopGate()
        let probing = DirectMediumAccess.$probeThreadObserverForTesting.withValue({ gate.arrive(onMain: $0) }) {
            // Große Zeitgrenze: hier zählt nur der Thread, die Zeitgrenze darf unter Last nicht greifen.
            Task { @MainActor in await DirectMediumAccess(probeTimeout: 60).probe(volume) }
        }
        // Endet die Prüfung, ohne das Tor zu erreichen, endet auch das Warten (rot statt Hängen).
        Task { _ = await probing.value; gate.finish() }
        let report = await gate.arrived()
        try #require(report != nil, "Arbeit endete ohne Meldung")
        #expect(report == false)

        await Task { @MainActor in }.value
        gate.open()

        let result = await probing.value
        #expect(result == .granted)
        #expect(gate.timedOut == false, "Prüfung blockierte den MainActor bis zur Notfall-Zeitgrenze")
    }

    /// bug.0.3.8.006: Die Prüfung hängt (am Tor, das erst nach dem Test öffnet) → `probe` kehrt nach der Zeitgrenze
    /// mit `.denied(reason: "timeout")` zurück und wartet nicht auf den blockierten Aufruf.
    @Test func hangingProbeReturnsTimeout() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-probe-hang-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let volume = VolumeInfo(
            mountPath: mount.path, name: "Hang", fsType: "apfs",
            volumeTotalBytes: 1_000, volumeFreeBytes: 500, diskSizeBytes: 1_000, volumeUUID: nil, createdAt: nil,
            isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: nil, model: nil, isTimeMachineSnapshot: false
        )
        let gate = MainHopGate()
        defer { gate.open() }
        let outcome = ProbeOutcome()
        DirectMediumAccess.$probeThreadObserverForTesting.withValue({ gate.arrive(onMain: $0) }) {
            Task { @MainActor in outcome.result = await DirectMediumAccess(probeTimeout: 0.3).probe(volume) }
        }
        // Notfall-Grenze großzügig; das Tor bleibt bis zum Testende zu.
        let returned = await waitUntil(timeout: 8) { outcome.result != nil }
        #expect(returned, "probe wartet auf den blockierten Aufruf")
        #expect(outcome.result == .denied(reason: "timeout"))
    }

    @Test func networkStyleMountPathSkipsVolumeLookup() async {
        // MediumMonitor prüft nur /Volumes/ in emitMount — kein Lookup für Netzwerk-Pfade.
        // bug.0.3.9.002: ohne den früheren prozessweiten Aufrufzähler (Regel 20).
        let paths = LocalVolumeMounts.candidateMountPaths()
        #expect(!paths.contains { $0.hasPrefix("/Network/") })
    }

    /// bug.0.3.9.002: Die Abfrage hängt (am Tor, das erst am Testende öffnet) → `VolumeLookup.info` kehrt nach der
    /// Zeitgrenze mit `nil` (kein Kandidat) zurück, wartet nicht auf die blockierte Abfrage und meldet die Zeitgrenze
    /// (eigene Senke statt des gemeinsamen Protokolls).
    @Test func hangingVolumeLookupReturnsNilAfterTimeout() async throws {
        let gate = LookupHoldGate()
        defer { gate.open() }
        let logged = LookupLogSink()
        let outcome = LookupOutcome()
        let url = URL(fileURLWithPath: "/Volumes/Hang-\(UUID().uuidString)", isDirectory: true)
        let late = Self.volume(name: "Spät")
        Task { @MainActor in
            outcome.result = await VolumeLookup.info(
                at: url,
                timeout: 0.3,
                lookup: { _ in
                    gate.hold(onMain: Thread.isMainThread)
                    return late
                },
                // bug.0.4.102 (c): Senke schreibt verzögert – meldete `info` erst nach dem Fortsetzen (alte Reihenfolge),
                // fände der Test sicher keine Meldung.
                logTimeout: { path in
                    Thread.sleep(forTimeInterval: 0.05)
                    logged.add(path)
                }
            )
            outcome.finished = true
            // bug.0.4.102 (c): erst schließen, wenn die Abfrage das Tor erreicht hat (unter Last startet sie evtl. erst
            // nach der Zeitgrenze); Notfall-Grenze großzügig, dann rot statt Hängen.
            await gate.finishAfterArrival(deadline: 10)
        }
        let report = await gate.arrived()
        try #require(report != nil, "Abfrage endete ohne Meldung")
        #expect(report == false, "Abfrage lief auf dem Hauptfaden")
        // Notfall-Grenze großzügig; das Tor bleibt bis zum Testende zu.
        let returned = await waitUntil(timeout: 8) { outcome.finished }
        #expect(returned, "info wartet auf die blockierte Abfrage")
        #expect(outcome.result == nil)
        #expect(logged.paths == [url.path], "Zeitgrenze nicht gemeldet")
    }

    /// bug.0.3.9.002: Ein hängendes Volume hält keine weitere Abfrage auf (vorher eine serielle Queue).
    @Test func secondLookupReturnsWhileFirstHangs() async throws {
        let gate = LookupHoldGate()
        defer { gate.open() }
        let logged = LookupLogSink()
        let first = LookupOutcome()
        let hangingURL = URL(fileURLWithPath: "/Volumes/Hang-\(UUID().uuidString)", isDirectory: true)
        Task { @MainActor in
            // Große Zeitgrenze: die erste Abfrage soll während des ganzen Tests hängen bleiben.
            first.result = await VolumeLookup.info(
                at: hangingURL,
                timeout: 60,
                lookup: { _ in
                    gate.hold(onMain: Thread.isMainThread)
                    return nil
                },
                logTimeout: { logged.add($0) }
            )
            first.finished = true
            gate.finish()
        }
        let report = await gate.arrived()
        try #require(report == false, "erste Abfrage hat das Tor nicht erreicht")

        let second = LookupOutcome()
        let expected = Self.volume(name: "Zweites")
        let secondURL = URL(fileURLWithPath: expected.mountPath, isDirectory: true)
        Task { @MainActor in
            second.result = await VolumeLookup.info(
                at: secondURL,
                timeout: 60,
                lookup: { _ in expected },
                logTimeout: { logged.add($0) }
            )
            second.finished = true
        }
        let returned = await waitUntil(timeout: 8) { second.finished }
        #expect(returned, "zweite Abfrage wartet hinter der hängenden ersten")
        #expect(second.result == expected)
        #expect(first.finished == false, "erste Abfrage hätte noch hängen müssen")
    }

    private static func volume(name: String) -> VolumeInfo {
        VolumeInfo(
            mountPath: "/Volumes/\(name)", name: name, fsType: "apfs",
            volumeTotalBytes: 1_000, volumeFreeBytes: 500, diskSizeBytes: 1_000, volumeUUID: nil, createdAt: nil,
            isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: nil, model: nil, isTimeMachineSnapshot: false
        )
    }
}

/// Tor ohne Selbstfreigabe (bug.0.3.9.002): die Abfrage meldet sich an und wartet, bis der Test öffnet (`defer`).
private final class LookupHoldGate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    private let lock = NSLock()
    private var reached = false

    /// Von der Abfrage aufgerufen (Hintergrund-Thread): melden, dann warten.
    func hold(onMain: Bool) {
        lock.withLock { reached = true }
        continuation.yield(onMain)
        semaphore.wait()
    }

    /// `finish` erst, wenn die Abfrage das Tor erreicht hat, oder nach der Notfall-Grenze (bug.0.4.102 c).
    func finishAfterArrival(deadline seconds: TimeInterval) async {
        let end = Date().addingTimeInterval(seconds)
        while !lock.withLock({ reached }), Date() < end {
            try? await Task.sleep(for: .milliseconds(5))
        }
        finish()
    }

    func arrived() async -> Bool? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    func open() {
        semaphore.signal()
    }

    /// Endet die Abfrage ohne Meldung, endet auch das Warten auf `arrived` (rot statt Hängen).
    func finish() {
        continuation.finish()
    }
}

/// Eigene Protokollsenke je Test (statt `DiskIndexLog.shared`).
private final class LookupLogSink: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    func add(_ path: String) {
        lock.withLock { stored.append(path) }
    }

    var paths: [String] {
        lock.withLock { stored }
    }
}

@MainActor
private final class LookupOutcome {
    var finished = false
    var result: VolumeInfo?
}

/// Tor für „läuft nicht auf main“ (bug.0.3.8.004): die Arbeit meldet sich an und wartet, bis der Test öffnet.
/// Notfall-Zeitgrenze nur für den roten Fall; im grünen Fall gibt es keine Uhrzeit-Erwartung.
final class MainHopGate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var didTimeOut = false
    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    /// Von der Arbeit aufgerufen (Hintergrund-Thread, im Fehlerfall main): melden, dann warten.
    func arrive(onMain: Bool) {
        continuation.yield(onMain)
        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            lock.withLock { didTimeOut = true }
        }
    }

    /// Erste Meldung der Arbeit; `nil`, wenn sie ohne Meldung endete.
    func arrived() async -> Bool? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    func open() {
        semaphore.signal()
    }

    func finish() {
        continuation.finish()
    }

    var timedOut: Bool {
        lock.withLock { didTimeOut }
    }
}

@MainActor
private final class ProbeOutcome {
    var result: MediumAccessResult?
}

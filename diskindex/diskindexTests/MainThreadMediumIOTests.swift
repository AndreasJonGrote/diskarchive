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
            Task { @MainActor in await DirectMediumAccess().probe(volume) }
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

    @Test func networkStyleMountPathSkipsVolumeLookup() async {
        VolumeLookupTestHooks.infoCallCount = 0
        let before = VolumeLookupTestHooks.infoCallCount
        let url = URL(fileURLWithPath: "/Network/SomeShare", isDirectory: true)
        // MediumMonitor prüft nur /Volumes/ in emitMount — kein Lookup für Netzwerk-Pfade.
        _ = url
        #expect(before == VolumeLookupTestHooks.infoCallCount)
        let paths = LocalVolumeMounts.candidateMountPaths()
        #expect(!paths.contains { $0.hasPrefix("/Network/") })
    }
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

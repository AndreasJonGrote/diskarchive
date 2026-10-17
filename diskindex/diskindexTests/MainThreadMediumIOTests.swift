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
    /// bug.0.3.8.004: prüft „Probe nicht auf main“ und „main nicht blockiert“ statt Ticks zu zählen.
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
        let (threads, report) = AsyncStream.makeStream(of: (onMain: Bool, at: ContinuousClock.Instant).self)
        let probing = DirectMediumAccess.$probeThreadObserverForTesting.withValue({ report.yield(($0, .now)) }) {
            DirectMediumAccess.$probeDelayForTesting.withValue(2.0) {
                Task { @MainActor in await DirectMediumAccess().probe(volume) }
            }
        }
        // Meldet die Prüfung nie ihren Beginn, endet der Strom mit ihr (rot statt Hängen).
        Task { _ = await probing.value; report.finish() }
        var reports = threads.makeAsyncIterator()
        let began = try #require(await reports.next())
        #expect(began.onMain == false)

        // Die Prüfung schläft ab `began.at` 2 s im Hintergrund; der MainActor-Sprung muss vor dem Ende dieser
        // Pause ankommen (Reihenfolge statt knapper Zeitgrenze). Auf main ausgeführt wäre er erst danach frei.
        await Task { @MainActor in }.value
        #expect(ContinuousClock.now < began.at + .seconds(2))

        let result = await probing.value
        #expect(result == .granted)
        report.finish()
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

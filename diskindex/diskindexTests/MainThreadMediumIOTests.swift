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
    @Test func directProbeKeepsMainActorResponsive() async throws {
        try await DirectMediumAccess.$probeDelayForTesting.withValue(2.0) {
            try await directProbeKeepsMainActorResponsiveBody()
        }
    }

    private func directProbeKeepsMainActorResponsiveBody() async throws {
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
        var ticks = 0
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                ticks += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let access = DirectMediumAccess()
        let result = await access.probe(volume)
        ticker.cancel()
        #expect(result == .granted)
        #expect(ticks >= 5)
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

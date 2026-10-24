//
//  MountedMediumCheckTests.swift
//  diskindexTests
//
//  bug.0.4.179: `MountedMediumCheck` bejaht ein echtes Volume nach dem Rundweg durch die Datenbank (gespeichert wie
//  bei der Erkennung, wieder geladen) – sonst würden echte Medien still nie wiederverbunden. Eine hängende Prüfung zählt
//  als hängender Zugriff des Mediums (wie 176 b).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct MountedMediumCheckTests {
    /// Gespeichert wie in `MediumCoordinator` beim ersten Anschließen; optional ohne Volume-UUID (dann zählt der
    /// Fingerabdruck aus Dateisystem, Erstelldatum und Größe).
    private func storedRoundTrip(of info: VolumeInfo, withUUID: Bool) async throws -> StoredMedium {
        let harness = try await ScanHarness.make()
        let identity = info.identity
        let medium = StoredMedium(
            volumeUUID: withUUID ? identity.volumeUUID : nil,
            volumeCreatedAt: identity.createdAt,
            fsType: info.fsType,
            volumeTotalBytes: info.volumeTotalBytes,
            diskSizeBytes: info.diskSizeBytes,
            name: info.name,
            type: info.mediumType,
            decision: .undecided,
            indexStatus: .pending,
            allowIndexing: true,
            lastSeenAt: Date()
        )
        try await harness.store.upsertMedium(medium)
        return try #require(try await harness.store.medium(uuid: medium.uuid))
    }

    @Test(arguments: [true, false])
    func realVolumeIsRecognisedAfterTheDatabaseRoundTrip(withUUID: Bool) async throws {
        let info = try #require(await VolumeLookup.info(at: URL(fileURLWithPath: "/", isDirectory: true)), "„/“ nicht lesbar")
        try #require(withUUID || info.identity.createdAt != nil, "Voraussetzung: Erstelldatum für den Fingerabdruck")
        let stored = try await storedRoundTrip(of: info, withUUID: withUUID)
        #expect(await MountedMediumCheck.isMounted(stored, at: "/"), "echtes Volume nach dem Rundweg nicht erkannt (UUID: \(withUUID))")
    }

    /// Hängt die Volume-Abfrage der Prüfung, zählt sie als hängender Zugriff: kein Lesen, Favorit bleibt; kehrt sie
    /// zurück, ist der Zähler wieder null.
    @Test func hangingMountCheckCountsAsHangingAccess() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-hanging-check-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = HangingLookupBlocker()
        defer { blocker.release() }
        await store.setMountLookupForTesting({ _ in
            blocker.block()
            return nil
        }, timeout: 0.3)
        let old = try await FatReconnectIndexerTests.runMovedFileFinish(
            store: store, id: harness.mediumID, root: root, finishMountPath: root.path
        )
        #expect(try await store.favoriteItemIDs().contains(old.id), "Favorit nach hängender Prüfung gelöscht")
        #expect(await store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 1, "hängende Prüfung nicht gezählt")
        blocker.release()
        #expect(await waitUntil { await store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 0 },
                "Rückkehr der Prüfung nicht gemeldet")
    }
}

/// Hält die Volume-Abfrage an (Notfall-Grenze 10 s).
private final class HangingLookupBlocker: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    func block() { _ = semaphore.wait(timeout: .now() + 10) }
    func release() { semaphore.signal() }
}

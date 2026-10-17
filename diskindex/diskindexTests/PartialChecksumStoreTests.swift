//
//  PartialChecksumStoreTests.swift
//  diskindexTests
//
//  bug.0.4.023 — Store-Actor blockiert nicht auf Teil-Prüfsumme.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) struct PartialChecksumStoreTests {
    @Test func slowPartialChecksumDoesNotBlockStoreReads() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-partial-latency-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let fileURL = mount.appendingPathComponent("big.bin")
        try Data(repeating: 0xAB, count: 128).write(to: fileURL)
        let harness = try StoreHarness.make()
        await harness.store.setPartialChecksumComputeDelayForTesting(8.0)
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "big.bin", isFolder: false, sizeBytes: 128)],
            seenAt: Date()
        )
        let item = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first)
        let checksumTask = Task {
            try await harness.store.storePartialChecksum(itemID: item.id, mountPath: mount.path)
        }
        // bug.0.3.8.007: Reihenfolge statt Millisekunden — Lesen und Suchen kommen zurück, solange die Prüfsumme
        // noch rechnet (8 s Verzögerung, Zeitgrenze 5 s).
        let done = ChecksumDone()
        Task { _ = try? await checksumTask.value; await done.mark() }
        try await Task.sleep(for: .milliseconds(300))
        _ = try await harness.store.childrenPage(mediumUUID: medium.uuid, parentID: nil, limit: 10)
        _ = try await harness.store.search(query: "big", filters: SearchFilters(), limit: 5)
        #expect(await done.isDone == false, "Lesen wartete auf die Prüfsumme")
        try await checksumTask.value
        await harness.store.setPartialChecksumComputeDelayForTesting(nil)
    }

    @Test func slowFileExistsProbeDoesNotBlockStoreReads() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-partial-exists-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let fileURL = mount.appendingPathComponent("probe.bin")
        try Data(repeating: 0xCD, count: 64).write(to: fileURL)
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "probe.bin", isFolder: false, sizeBytes: 64)],
            seenAt: Date()
        )
        let item = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first)
        try await PartialChecksum.$fileExistsDelayForTesting.withValue(2.0) {
            let checksumTask = Task {
                try await harness.store.storePartialChecksum(itemID: item.id, mountPath: mount.path)
            }
            // bug.0.3.8.007: Reihenfolge statt Millisekunden (Dateiprüfung schläft 2 s).
            let done = ChecksumDone()
            Task { _ = try? await checksumTask.value; await done.mark() }
            try await Task.sleep(for: .milliseconds(50))
            _ = try await harness.store.childrenPage(mediumUUID: medium.uuid, parentID: nil, limit: 10)
            _ = try await harness.store.search(query: "probe", filters: SearchFilters(), limit: 5)
            #expect(await done.isDone == false, "Lesen wartete auf die Dateiprüfung")
            try await checksumTask.value
        }
    }

    /// bug.0.3.8.006: Die Prüfsumme hängt länger als ihre Zeitgrenze → `computeOffActor` kehrt nach der Zeitgrenze mit
    /// `nil` zurück und wartet nicht auf das blockierte Lesen.
    @Test func hangingChecksumReturnsAfterTimeout() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-partial-hang-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let fileURL = mount.appendingPathComponent("hang.bin")
        try Data(repeating: 0xEF, count: 64).write(to: fileURL)
        let outcome = ChecksumDone()
        Task {
            let result = try? await PartialChecksum.computeOffActor(at: fileURL, timeout: .milliseconds(300), testComputeDelay: 8)
            await outcome.mark(gotValue: result != nil)
        }
        // Notfall-Grenze 6 s liegt deutlich unter der 8-s-Verzögerung.
        let returned = await waitUntil(timeout: 6) { await outcome.isDone }
        #expect(returned, "computeOffActor wartet auf das blockierte Lesen")
        #expect(await outcome.gotValue == false)
    }
}

private actor ChecksumDone {
    private(set) var isDone = false
    private(set) var gotValue = false

    func mark(gotValue: Bool = false) {
        isDone = true
        self.gotValue = gotValue
    }
}

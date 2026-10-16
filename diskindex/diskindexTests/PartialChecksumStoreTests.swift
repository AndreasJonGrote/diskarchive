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
        try await Task.sleep(for: .milliseconds(300))
        let childrenStarted = ContinuousClock.now
        _ = try await harness.store.childrenPage(mediumUUID: medium.uuid, parentID: nil, limit: 10)
        // 750 ms Reserve unter Parallel-Last (5-s-Timeout vs. 8-s-Verzögerung).
        #expect(childrenStarted.duration(to: ContinuousClock.now) < .milliseconds(750))
        let searchStarted = ContinuousClock.now
        _ = try await harness.store.search(query: "big", filters: SearchFilters(), limit: 5)
        #expect(searchStarted.duration(to: ContinuousClock.now) < .milliseconds(750))
        try await checksumTask.value
        await harness.store.setPartialChecksumComputeDelayForTesting(nil)
    }
}

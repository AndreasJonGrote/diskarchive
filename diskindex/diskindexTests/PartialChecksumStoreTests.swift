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
        defer { PartialChecksum.computeDelayForTesting = nil }
        PartialChecksum.computeDelayForTesting = 5.0
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-partial-latency-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let fileURL = mount.appendingPathComponent("big.bin")
        try Data(repeating: 0xAB, count: 128).write(to: fileURL)
        let harness = try StoreHarness.make()
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
        try await Task.sleep(for: .milliseconds(50))
        let childrenStarted = ContinuousClock.now
        _ = try await harness.store.childrenPage(mediumUUID: medium.uuid, parentID: nil, limit: 10)
        #expect(childrenStarted.duration(to: ContinuousClock.now) < .milliseconds(100))
        let searchStarted = ContinuousClock.now
        _ = try await harness.store.search(query: "big", filters: SearchFilters(), limit: 5)
        #expect(searchStarted.duration(to: ContinuousClock.now) < .milliseconds(100))
        try await checksumTask.value
    }
}

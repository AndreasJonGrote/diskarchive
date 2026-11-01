//
//  HardlinkIndexerTests.swift
//  DiskArchiveTests
//
//  bug.0.4.016: Hardlinks — zwei Zeilen, stabile IDs (Regel 18).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct HardlinkIndexerTests {
    @Test func twoHardlinksIndexedAsSeparateRows() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-hardlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("a.txt")
        try Data("hello".utf8).write(to: original)
        try FileManager.default.linkItem(at: original, to: root.appendingPathComponent("b.txt"))

        let harness = try await ScanHarness.make(fsType: "apfs")
        let volume = harness.volume(at: root.path)
        let access = DirectMediumAccess(mountCheck: { _, _ in true })
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true, volume: volume)
        let firstA = try #require(try await harness.item(named: "a.txt"))
        let firstB = try #require(try await harness.item(named: "b.txt"))
        #expect(firstA.id != firstB.id)
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: false, volume: volume)
        let secondA = try #require(try await harness.item(named: "a.txt"))
        let secondB = try #require(try await harness.item(named: "b.txt"))
        #expect(secondA.id == firstA.id)
        #expect(secondB.id == firstB.id)
    }
}

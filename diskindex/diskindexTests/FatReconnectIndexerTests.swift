//
//  FatReconnectIndexerTests.swift
//  diskindexTests
//
//  bug.0.4.015: FAT/exFAT reconnect über DirectoryIndexer + MemoryVolume (Regel 18).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct FatReconnectIndexerTests {
    private func fatHarness() async throws -> (ScanHarness, MemoryVolume) {
        let harness = try await ScanHarness.make(fsType: "msdos")
        let volume = MemoryVolume(mountPath: "/Volumes/FAT")
        return (harness, volume)
    }

    @Test func sameFolderRenameKeepsFavoriteID() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("alt.txt", size: 100)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "alt.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("alt.txt")
        _ = volume.file("neu.txt", size: 100)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "neu.txt"))
        #expect(after.id == before.id)
        #expect(after.isFavorite)
    }

    @Test func siblingFolderMoveKeepsFavoriteID() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("P/a.txt", size: 50)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "a.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("P/a.txt")
        _ = volume.file("Q/a.txt", size: 50)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "a.txt"))
        #expect(after.id == before.id)
        #expect(after.isFavorite)
    }

    @Test func moveUpToRootKeepsFavoriteID() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("A/B/x.txt", size: 77)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "x.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("A/B/x.txt")
        _ = volume.file("x.txt", size: 77)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "x.txt"))
        #expect(after.id == before.id)
        #expect(after.isFavorite)
    }

    @Test func ambiguousSameSizeDoesNotReconnect() async throws {
        let (harness, volume) = try await fatHarness()
        await harness.store.setPartialMatchingEnabled(false)
        _ = volume.file("a.bin", size: 64).file("b.bin", size: 64)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let favA = try #require(try await harness.item(named: "a.bin"))
        try await harness.store.setFavorite(itemID: favA.id, true)
        volume.remove("a.bin")
        volume.remove("b.bin")
        _ = volume.file("c.bin", size: 64).file("d.bin", size: 64)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let c = try #require(try await harness.item(named: "c.bin"))
        #expect(c.id != favA.id)
    }
}

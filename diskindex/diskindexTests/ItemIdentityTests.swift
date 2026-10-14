//
//  ItemIdentityTests.swift
//  diskindexTests
//
//  Umbenennen/Verschieben über fileID (235).
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct ItemIdentityTests {
    @Test func renameByFileIDKeepsRowAndFavorite() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "alt.txt", isFolder: false, sizeBytes: 4, fileID: "4242")],
            seenAt: Date()
        )
        let before = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first)
        try await harness.store.setFavorite(itemID: before.id, true)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 4, fileID: "4242")],
            seenAt: Date()
        )
        let after = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(after.count == 1)
        #expect(after.first?.id == before.id)
        #expect(after.first?.name == "neu.txt")
        #expect(after.first?.isFavorite == true)
    }

    @Test func fatTimestampToleranceMatchesGoneRow() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Stick", fsType: "msdos", bytes: 1_000)
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "dat.txt", isFolder: false, sizeBytes: 8, modifiedAt: seen)],
            seenAt: seen
        )
        let row = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [],
            seenAt: seen
        )
        let shifted = seen.addingTimeInterval(3600)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "dat.txt", isFolder: false, sizeBytes: 8, modifiedAt: shifted)],
            seenAt: shifted
        )
        let restored = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(restored.count == 1)
        #expect(restored.first?.id == row.id)
    }

    @Test func fatPartialDisambiguatesGoneCandidates() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-partial-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let payloadA = Data(repeating: 0xAA, count: 128)
        let payloadB = Data(repeating: 0xBB, count: 128)
        let seen = Date(timeIntervalSince1970: 1_700_000_100)
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Stick", fsType: "msdos", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "a.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen),
                ScannedEntry(name: "b.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen),
            ],
            seenAt: seen
        )
        let children = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        let favorite = try #require(children.first { $0.name == "a.bin" })
        let other = try #require(children.first { $0.name == "b.bin" })
        try payloadA.write(to: mount.appendingPathComponent("a.bin"))
        try payloadB.write(to: mount.appendingPathComponent("b.bin"))
        try await harness.store.setFavorite(itemID: favorite.id, true)
        try await harness.store.storePartialChecksum(itemID: favorite.id, mountPath: mount.path)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [],
            seenAt: seen
        )
        let reconnectURL = mount.appendingPathComponent("restored.bin")
        try payloadA.write(to: reconnectURL)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "restored.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen)],
            seenAt: seen,
            mountPath: mount.path
        )
        let restored = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(restored.count == 1)
        #expect(restored.first?.id == favorite.id)
        #expect(restored.first?.id != other.id)
    }

    @Test func fatSingleGoneFolderDoesNotReviveUnrelatedName() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Stick", fsType: "msdos", bytes: 1_000)
        let seen = Date(timeIntervalSince1970: 1_700_000_300)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "Archiv", isFolder: true, modifiedAt: seen)],
            seenAt: seen
        )
        let old = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first)
        try await harness.store.setFavorite(itemID: old.id, true)
        try await harness.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: [], seenAt: seen)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "NeuOrdner", isFolder: true, modifiedAt: seen)],
            seenAt: seen
        )
        let after = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(after.count == 1)
        #expect(after.first?.name == "NeuOrdner")
        #expect(after.first?.id != old.id)
        #expect(after.first?.isFavorite == false)
    }

    @Test func fatGoneFolderRevivesWhenNameAndParentMatch() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Stick", fsType: "msdos", bytes: 1_000)
        let seen = Date(timeIntervalSince1970: 1_700_000_350)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "Daten", isFolder: true, modifiedAt: seen)],
            seenAt: seen
        )
        let old = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first)
        try await harness.store.setFavorite(itemID: old.id, true)
        try await harness.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: [], seenAt: seen)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "Daten", isFolder: true, modifiedAt: seen)],
            seenAt: seen
        )
        let after = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(after.count == 1)
        #expect(after.first?.id == old.id)
        #expect(after.first?.isFavorite == true)
    }

    @Test func sabotagePartialDisabledDoesNotReconnectAmbiguous() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-partial-sabotage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let seen = Date(timeIntervalSince1970: 1_700_000_200)
        let harness = try StoreHarness.make()
        await harness.store.setPartialMatchingEnabled(false)
        let medium = try await harness.insert(name: "Stick", fsType: "msdos", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "a.bin", isFolder: false, sizeBytes: 64, modifiedAt: seen),
                ScannedEntry(name: "b.bin", isFolder: false, sizeBytes: 64, modifiedAt: seen),
            ],
            seenAt: seen
        )
        let favorite = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first { $0.name == "a.bin" })
        try Data(repeating: 0xAA, count: 64).write(to: mount.appendingPathComponent("a.bin"))
        try Data(repeating: 0xBB, count: 64).write(to: mount.appendingPathComponent("b.bin"))
        try await harness.store.setFavorite(itemID: favorite.id, true)
        try await harness.store.storePartialChecksum(itemID: favorite.id, mountPath: mount.path)
        try await harness.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: [], seenAt: seen)
        let fileURL = mount.appendingPathComponent("restored.bin")
        try Data(repeating: 0xAA, count: 64).write(to: fileURL)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "restored.bin", isFolder: false, sizeBytes: 64, modifiedAt: seen)],
            seenAt: seen,
            mountPath: mount.path
        )
        let restored = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(restored.first?.id != favorite.id)
    }
}

//
//  VolumeIdentityTests.swift
//  DiskArchiveTests
//

import Foundation
import Testing
@testable import DiskArchive

struct VolumeIdentityTests {
    private let created = Date(timeIntervalSince1970: 1_718_102_804)
    private let otherCreated = Date(timeIntervalSince1970: 1_700_000_000)
    private let fatEpoch = Date(timeIntervalSince1970: 315_532_800)

    @Test func sdCardNullUUIDMatchesByFingerprint() async throws {
        let harness = try StoreHarness.make()
        let card = StoredMedium(
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 31_902_433_280,
            name: "ZOOM_H4E",
            type: .usb
        )
        try await harness.store.upsertMedium(card)
        let matches = try await harness.store.candidates(for: VolumeIdentity(
            volumeUUID: "00000000-0000-0000-0000-000000000000",
            fsType: "msdos",
            volumeTotalBytes: 31_902_433_280,
            name: "ZOOM_H4E",
            createdAt: created.addingTimeInterval(0.4)
        ))
        #expect(matches.map(\.medium.uuid) == [card.uuid])
        #expect(matches.first?.strength == .fingerprint)
        let stored = try #require(try await harness.store.medium(uuid: card.uuid))
        #expect(stored.volumeUUID == nil)
    }

    @Test func sameSizeDifferentCreationDatesStaySeparate() async throws {
        let harness = try StoreHarness.make()
        let first = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 5_000, name: "EINS", type: .usb)
        let second = StoredMedium(volumeCreatedAt: otherCreated, fsType: "msdos", volumeTotalBytes: 5_000, name: "ZWEI", type: .usb)
        try await harness.store.upsertMedium(first)
        try await harness.store.upsertMedium(second)
        let matches = try await harness.store.candidates(for: VolumeIdentity(
            fsType: "msdos", volumeTotalBytes: 5_000, name: "EINS", createdAt: created
        ))
        #expect(matches.map(\.medium.uuid) == [first.uuid])
        #expect(matches.first?.strength == .fingerprint)
    }

    @Test func differentUUIDsStaySeparateDespiteSharedFingerprint() async throws {
        let harness = try StoreHarness.make()
        let left = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000001",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 8_000,
            name: "NO NAME",
            type: .usb
        )
        let right = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000002",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 8_000,
            name: "NO NAME",
            type: .usb
        )
        try await harness.store.upsertMedium(left)
        try await harness.store.upsertMedium(right)
        let matches = try await harness.store.candidates(for: VolumeIdentity(
            volumeUUID: "aaaaaaaa-bbbb-cccc-dddd-000000000001",
            fsType: "msdos",
            volumeTotalBytes: 8_000,
            name: "NO NAME",
            createdAt: created
        ))
        #expect(matches.map(\.medium.uuid) == [left.uuid])
        #expect(matches.first?.strength == .uuid)
    }

    @Test func sameUUIDMatchesAfterRename() async throws {
        let harness = try StoreHarness.make()
        let stick = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000010",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 8_000,
            name: "ALT",
            type: .usb
        )
        try await harness.store.upsertMedium(stick)
        let matches = try await harness.store.candidates(for: VolumeIdentity(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000010",
            fsType: "exfat",
            volumeTotalBytes: 1,
            name: "NEU"
        ))
        #expect(matches.map(\.strength) == [.uuid])
        #expect(matches.first?.medium.name == "ALT")
    }

    @Test func fingerprintFillsInUUIDLater() async throws {
        let harness = try StoreHarness.make()
        let stick = StoredMedium(
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 8_000,
            name: "NO NAME",
            type: .usb
        )
        try await harness.store.upsertMedium(stick)
        let identity = VolumeIdentity(
            volumeUUID: "BBBBBBBB-CCCC-DDDD-EEEE-000000000020",
            fsType: "msdos",
            volumeTotalBytes: 8_000,
            name: "NO NAME",
            createdAt: created
        )
        let matches = try await harness.store.candidates(for: identity)
        #expect(matches.map(\.strength) == [.fingerprint])
        try await harness.store.recordIdentity(mediumUUID: stick.uuid, identity)
        let stored = try #require(try await harness.store.medium(uuid: stick.uuid))
        #expect(stored.volumeUUID == "bbbbbbbb-cccc-dddd-eeee-000000000020")
        try await harness.store.recordIdentity(
            mediumUUID: stick.uuid,
            VolumeIdentity(volumeUUID: "CCCCCCCC-CCCC-CCCC-CCCC-000000000099", fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: otherCreated)
        )
        let unchanged = try #require(try await harness.store.medium(uuid: stick.uuid))
        #expect(unchanged.volumeUUID == stored.volumeUUID)
        #expect(VolumeIdentity.sameSecond(try #require(unchanged.volumeCreatedAt), created))
    }

    @Test func missingCreationDateIsOnlyWeak() async throws {
        let harness = try StoreHarness.make()
        let stick = StoredMedium(fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", type: .usb)
        try await harness.store.upsertMedium(stick)
        let missing = try await harness.store.candidates(for: VolumeIdentity(
            fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: nil
        ))
        #expect(missing.map(\.strength) == [.weak])
        let factory = try await harness.store.candidates(for: VolumeIdentity(
            fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: fatEpoch
        ))
        #expect(factory.map(\.strength) == [.weak])
        let otherName = try await harness.store.candidates(for: VolumeIdentity(
            fsType: "msdos", volumeTotalBytes: 8_000, name: "ANDERS", createdAt: fatEpoch
        ))
        #expect(otherName.isEmpty)
    }

    @Test func sharedFingerprintReturnsEveryCandidate() async throws {
        let harness = try StoreHarness.make()
        let first = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 5_000, name: "A", type: .usb)
        let second = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 5_000, name: "B", type: .usb)
        try await harness.store.upsertMedium(first)
        try await harness.store.upsertMedium(second)
        let matches = try await harness.store.candidates(for: VolumeIdentity(
            fsType: "msdos", volumeTotalBytes: 5_000, name: "egal", createdAt: created
        ))
        #expect(matches.map(\.strength) == [.fingerprint, .fingerprint])
        #expect(Set(matches.map(\.medium.uuid)) == [first.uuid, second.uuid])
    }
}

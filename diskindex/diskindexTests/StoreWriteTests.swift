//
//  StoreWriteTests.swift
//  diskindexTests
//
//  Aufgabe 231 f (1), seit 233 nur noch gegen `IndexStoreV3`: Schreib-Tests der früheren Schicht (IDs bleiben, Favorit,
//  Teilbaum, Reihenfolge, Zähler, Sondernamen, Meta-Stapel, Pfad-Meldung, Wiedererkennung von Medien) und
//  Medium-Rundreise, Löschen/Vergessen, Läufe (Token), Ordner-Abfragen.
//

import Foundation
import Testing
@testable import diskindex

struct StoreWriteTests {
    @Test func applyDirectoryKeepsIDs() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Platte")
        let entries = [ScannedEntry(name: "Projekte", isFolder: true), ScannedEntry(name: "liesmich.txt", isFolder: false)]
        let first = try await store.addRoot(medium: medium, entries: entries)
        let second = try await store.addRoot(medium: medium, entries: entries)
        #expect(Set(first.map(\.id)) == Set(second.map(\.id)))
        #expect(Set(first.map(\.name)) == ["Projekte", "liesmich.txt"])
    }

    @Test func favoriteSurvivesDisappearance() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Platte")
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        let file = ScannedEntry(name: "Urlaubsfoto.jpg", isFolder: false, sizeBytes: 10, modifiedAt: seen, fileID: "4711")
        let created = try await store.addRoot(medium: medium, entries: [file], seenAt: seen)
        let id = try #require(created.first?.id)
        try await store.writer.setFavorite(itemID: id, true)

        let removed = try await store.addRoot(medium: medium, entries: [], seenAt: seen.addingTimeInterval(60))
        #expect(removed.isEmpty)
        #expect(try await store.isGone(id))
        #expect(try await store.hasFavoriteRow(id))
        #expect(try await store.favoriteIDs().isEmpty)

        let restored = try await store.addRoot(medium: medium, entries: [file], seenAt: seen.addingTimeInterval(120))
        #expect(restored.map(\.id) == [id])
        #expect(restored.first?.isFavorite == true)
        #expect(try await store.favoriteIDs() == [id])
    }

    @Test func missingFolderMarksSubtreeUntilReread() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Platte")
        let root = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "bleibt.txt", isFolder: false),
        ])
        let projekte = try #require(root.first { $0.name == "Projekte" })
        let child = try await store.apply(medium: medium, parentID: projekte.id, entries: [
            ScannedEntry(name: "brief.txt", isFolder: false),
            ScannedEntry(name: "Kunde", isFolder: true),
        ])
        let kunde = try #require(child.first { $0.name == "Kunde" })
        let brief = try #require(child.first { $0.name == "brief.txt" })
        let note = try await store.apply(medium: medium, parentID: kunde.id, entries: [ScannedEntry(name: "notiz.txt", isFolder: false)])
        let noteID = try #require(note.first?.id)
        try await store.writer.setFavorite(itemID: noteID, true)

        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "bleibt.txt", isFolder: false)])
        for id in [projekte.id, brief.id, kunde.id, noteID] {
            #expect(try await store.isGone(id))
        }
        let stays = try #require(root.first { $0.name == "bleibt.txt" })
        #expect(try await store.item(id: stays.id) != nil)

        let back = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "bleibt.txt", isFolder: false),
        ])
        #expect(back.first { $0.name == "Projekte" }?.id == projekte.id)
        #expect(try await store.item(id: projekte.id) != nil)
        #expect(try await store.isGone(kunde.id))
        #expect(try await store.isGone(noteID))

        _ = try await store.apply(medium: medium, parentID: projekte.id, entries: [
            ScannedEntry(name: "brief.txt", isFolder: false),
            ScannedEntry(name: "Kunde", isFolder: true),
        ])
        #expect(try await store.item(id: kunde.id) != nil)
        #expect(try await store.isGone(noteID))

        let reread = try await store.apply(medium: medium, parentID: kunde.id, entries: [ScannedEntry(name: "notiz.txt", isFolder: false)])
        #expect(reread.map(\.id) == [noteID])
        #expect(reread.first?.isFavorite == true)
    }

    @Test func childrenOrderAndCompleteLayerNeverGoesBackward() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Platte")
        let children = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "zeta", isFolder: true),
            ScannedEntry(name: "beta.txt", isFolder: false),
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "alpha.txt", isFolder: false),
        ])
        #expect(children.map(\.name) == ["Alpha", "alpha.txt", "beta.txt", "zeta"])
        try await store.writer.completeLayer(mediumUUID: medium.uuid, depth: 2)
        try await store.writer.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let stored = try #require(try await store.writer.medium(uuid: medium.uuid))
        #expect(stored.completedDepth == 2)
        #expect(stored.fileCount == 2)
        #expect(stored.folderCount == 2)
        #expect(stored.lastIndexedAt != nil)
    }

    @Test func mediumCountsStayAccurateWithIncrementalMeta() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Zähler")
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        let root = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "liesmich.txt", isFolder: false),
        ], seenAt: seen)
        let folderID = try #require(root.first { $0.isFolder }?.id)
        _ = try await store.apply(medium: medium, parentID: folderID, entries: [
            ScannedEntry(name: "alt.txt", isFolder: false),
            ScannedEntry(name: "Unter", isFolder: true),
        ], seenAt: seen)
        _ = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "liesmich.txt", isFolder: false),
        ], seenAt: seen.addingTimeInterval(60))
        let stored = try #require(try await store.writer.medium(uuid: medium.uuid))
        let truth = try await store.counts(medium: medium)
        #expect(stored.fileCount == truth.files)
        #expect(stored.folderCount == truth.folders)
        #expect(truth.files == 2)
        #expect(truth.folders == 2)
    }

    @Test func specialNamesStayInsideTheirFolder() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Platte")
        let folders = ["100%", "a_b", "c\\d"]
        let root = try await store.addRoot(medium: medium, entries: folders.map { ScannedEntry(name: $0, isFolder: true) } + [
            ScannedEntry(name: "100%EXTRA", isFolder: false),
        ])
        var childIDs: [Int64] = []
        for folder in folders {
            let parent = try #require(root.first { $0.name == folder })
            let created = try await store.apply(medium: medium, parentID: parent.id, entries: [ScannedEntry(name: "innen.txt", isFolder: false)])
            childIDs.append(try #require(created.first?.id))
        }
        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "100%EXTRA", isFolder: false)])
        let extra = try #require(root.first { $0.name == "100%EXTRA" })
        #expect(try await store.item(id: extra.id) != nil)
        for folder in folders {
            let parent = try #require(root.first { $0.name == folder })
            #expect(try await store.isGone(parent.id))
        }
        for id in childIDs {
            #expect(try await store.isGone(id))
        }
    }

    @Test func metaCommitBatchesRapidChunksUntilFlush() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Batch", bytes: 100)
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.writer.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, [ScannedEntry(name: "a.txt", isFolder: false)], false)],
            seenAt: stamp
        )
        #expect(try await store.writer.medium(uuid: medium.uuid)?.fileCount == 1)
        try await store.writer.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, [ScannedEntry(name: "a.txt", isFolder: false), ScannedEntry(name: "b.txt", isFolder: false)], false)],
            seenAt: stamp
        )
        #expect(try await store.writer.medium(uuid: medium.uuid)?.fileCount == 1)
        try await store.writer.flushMediumMeta(mediumUUID: medium.uuid, force: true)
        #expect(try await store.writer.medium(uuid: medium.uuid)?.fileCount == 2)
    }

    @Test func applyDirectoriesEmitsResolvedParentPathWhenBatchPathNil() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Sub", bytes: 100)
        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "A", isFolder: true)])
        let folderA = try #require(try await store.writer.folderID(mediumUUID: medium.uuid, path: ["A"]))
        try await store.writer.applyDirectory(mediumUUID: medium.uuid, parentID: folderA, entries: [ScannedEntry(name: "B", isFolder: true)], seenAt: Date())
        let folderB = try #require(try await store.writer.folderID(mediumUUID: medium.uuid, path: ["A", "B"]))
        let changes = try await store.collectChanges {
            try await store.writer.applyDirectories(
                mediumUUID: medium.uuid,
                batches: [(folderB, nil, nil, [ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 1)], true)],
                seenAt: Date()
            )
        }
        let paths = changes.flatMap { change -> [[String]] in
            if case .items(_, let folderPaths) = change { return folderPaths }
            return []
        }
        #expect(paths.contains(["A", "B"]))
    }

    // MARK: Medien (aus VolumeIdentityTests)

    private let created = Date(timeIntervalSince1970: 1_718_102_804)
    private let otherCreated = Date(timeIntervalSince1970: 1_700_000_000)
    private let fatEpoch = Date(timeIntervalSince1970: 315_532_800)

    @Test func sdCardNullUUIDMatchesByFingerprint() async throws {
        let store = try TestStore.make()
        let card = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 31_902_433_280, name: "ZOOM_H4E", type: .usb)
        try await store.writer.upsertMedium(card)
        let matches = try await store.writer.candidates(for: VolumeIdentity(
            volumeUUID: "00000000-0000-0000-0000-000000000000", fsType: "msdos", volumeTotalBytes: 31_902_433_280,
            name: "ZOOM_H4E", createdAt: created.addingTimeInterval(0.4)
        ))
        #expect(matches.map(\.medium.uuid) == [card.uuid])
        #expect(matches.first?.strength == .fingerprint)
        #expect(try await store.writer.medium(uuid: card.uuid)?.volumeUUID == nil)
    }

    @Test func sameSizeDifferentCreationDatesStaySeparate() async throws {
        let store = try TestStore.make()
        let first = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 5_000, name: "EINS", type: .usb)
        let second = StoredMedium(volumeCreatedAt: otherCreated, fsType: "msdos", volumeTotalBytes: 5_000, name: "ZWEI", type: .usb)
        try await store.writer.upsertMedium(first)
        try await store.writer.upsertMedium(second)
        let matches = try await store.writer.candidates(for: VolumeIdentity(fsType: "msdos", volumeTotalBytes: 5_000, name: "EINS", createdAt: created))
        #expect(matches.map(\.medium.uuid) == [first.uuid])
        #expect(matches.first?.strength == .fingerprint)
    }

    @Test func differentUUIDsStaySeparateDespiteSharedFingerprint() async throws {
        let store = try TestStore.make()
        func stick(_ suffix: String) -> StoredMedium {
            StoredMedium(
                volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-\(suffix)", volumeCreatedAt: created, fsType: "msdos",
                volumeTotalBytes: 8_000, name: "NO NAME", type: .usb
            )
        }
        let left = stick("000000000001")
        let right = stick("000000000002")
        try await store.writer.upsertMedium(left)
        try await store.writer.upsertMedium(right)
        let matches = try await store.writer.candidates(for: VolumeIdentity(
            volumeUUID: "aaaaaaaa-bbbb-cccc-dddd-000000000001", fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: created
        ))
        #expect(matches.map(\.medium.uuid) == [left.uuid])
        #expect(matches.first?.strength == .uuid)
    }

    @Test func sameUUIDMatchesAfterRename() async throws {
        let store = try TestStore.make()
        let stick = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000010", volumeCreatedAt: created, fsType: "msdos",
            volumeTotalBytes: 8_000, name: "ALT", type: .usb
        )
        try await store.writer.upsertMedium(stick)
        let matches = try await store.writer.candidates(for: VolumeIdentity(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000010", fsType: "exfat", volumeTotalBytes: 1, name: "NEU"
        ))
        #expect(matches.map(\.strength) == [.uuid])
        #expect(matches.first?.medium.name == "ALT")
    }

    @Test func fingerprintFillsInUUIDLater() async throws {
        let store = try TestStore.make()
        let stick = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", type: .usb)
        try await store.writer.upsertMedium(stick)
        let identity = VolumeIdentity(
            volumeUUID: "BBBBBBBB-CCCC-DDDD-EEEE-000000000020", fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: created
        )
        #expect(try await store.writer.candidates(for: identity).map(\.strength) == [.fingerprint])
        try await store.writer.recordIdentity(mediumUUID: stick.uuid, identity)
        let stored = try #require(try await store.writer.medium(uuid: stick.uuid))
        #expect(stored.volumeUUID == "bbbbbbbb-cccc-dddd-eeee-000000000020")
        try await store.writer.recordIdentity(
            mediumUUID: stick.uuid,
            VolumeIdentity(volumeUUID: "CCCCCCCC-CCCC-CCCC-CCCC-000000000099", fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: otherCreated)
        )
        let unchanged = try #require(try await store.writer.medium(uuid: stick.uuid))
        #expect(unchanged.volumeUUID == stored.volumeUUID)
        let kept = try #require(unchanged.volumeCreatedAt)
        #expect(VolumeIdentity.sameSecond(kept, created))
    }

    @Test func missingCreationDateIsOnlyWeak() async throws {
        let store = try TestStore.make()
        try await store.writer.upsertMedium(StoredMedium(fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", type: .usb))
        let missing = try await store.writer.candidates(for: VolumeIdentity(fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: nil))
        #expect(missing.map(\.strength) == [.weak])
        let factory = try await store.writer.candidates(for: VolumeIdentity(fsType: "msdos", volumeTotalBytes: 8_000, name: "NO NAME", createdAt: fatEpoch))
        #expect(factory.map(\.strength) == [.weak])
        let otherName = try await store.writer.candidates(for: VolumeIdentity(fsType: "msdos", volumeTotalBytes: 8_000, name: "ANDERS", createdAt: fatEpoch))
        #expect(otherName.isEmpty)
    }

    @Test func sharedFingerprintReturnsEveryCandidate() async throws {
        let store = try TestStore.make()
        let first = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 5_000, name: "A", type: .usb)
        let second = StoredMedium(volumeCreatedAt: created, fsType: "msdos", volumeTotalBytes: 5_000, name: "B", type: .usb)
        try await store.writer.upsertMedium(first)
        try await store.writer.upsertMedium(second)
        let matches = try await store.writer.candidates(for: VolumeIdentity(fsType: "msdos", volumeTotalBytes: 5_000, name: "egal", createdAt: created))
        #expect(Set(matches.map(\.medium.uuid)) == [first.uuid, second.uuid])
        #expect(matches.allSatisfy { $0.strength == .fingerprint })
    }

    // MARK: Neu für beide Schichten

    @Test func mediumRoundTripsEveryField() async throws {
        let store = try TestStore.make()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let medium = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000AB", volumeCreatedAt: day, fsType: "exfat",
            volumeTotalBytes: 64_000_000_000, diskSizeBytes: 64_100_000_000, name: "Stick Ü", type: .usb,
            decision: .index, rememberDecision: true, indexStatus: .indexed, allowIndexing: false, autoIndexPaused: true,
            capacityUsedBytes: 123, fileCount: 7, folderCount: 3, lastSeenAt: day.addingTimeInterval(1),
            firstIndexedAt: day.addingTimeInterval(2), lastIndexedAt: day.addingTimeInterval(3),
            lastIndexActivityAt: day.addingTimeInterval(4), isForgotten: true, showAbsoluteCapacity: true,
            isFavorite: true, fsEventsUUID: "ABC-DEF", lastEventID: 99, completedDepth: 4, scanTotal: 0, createdAt: day.addingTimeInterval(5)
        )
        try await store.writer.upsertMedium(medium)
        #expect(try await store.writer.medium(uuid: medium.uuid) == medium)
        #expect(try await store.writer.media() == [medium])

        var changed = medium
        changed.name = "Anders"
        changed.completedDepth = 1
        changed.createdAt = day.addingTimeInterval(500)
        try await store.writer.updateMedium(uuid: medium.uuid, changed)
        var expected = changed
        expected.createdAt = medium.createdAt
        #expect(try await store.writer.medium(uuid: medium.uuid) == expected)

        var unknownFS = StoredMedium(fsType: "weirdfs", volumeTotalBytes: 1, name: "Fremd")
        unknownFS.createdAt = day
        try await store.writer.upsertMedium(unknownFS)
        #expect(try await store.writer.medium(uuid: unknownFS.uuid)?.fsType == "weirdfs")

        await #expect(throws: IndexStoreError.unknownMedium) {
            try await store.writer.updateMedium(uuid: UUID(), changed)
        }
    }

    @Test func deleteIsIdempotentAndForgetNeedsAKnownMedium() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Weg")
        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "a.txt", isFolder: false)])
        try await store.writer.forgetMedium(uuid: medium.uuid)
        #expect(try await store.writer.medium(uuid: medium.uuid)?.isForgotten == true)
        try await store.writer.deleteMedium(uuid: medium.uuid)
        try await store.writer.deleteMedium(uuid: medium.uuid)
        #expect(try await store.writer.medium(uuid: medium.uuid) == nil)
        #expect(try await store.writer.media().isEmpty)
        await #expect(throws: IndexStoreError.unknownMedium) { try await store.writer.forgetMedium(uuid: medium.uuid) }
    }

    @Test func indexingTokensFollowTheSameRules() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Lauf")
        let first = UUID()
        let second = UUID()
        #expect(try await store.writer.beginIndexing(mediumUUID: medium.uuid, token: first))
        #expect(await store.writer.indexingIsActive(mediumUUID: medium.uuid, token: first))
        #expect(try await store.writer.medium(uuid: medium.uuid)?.indexStatus == .indexing)
        #expect(try await store.writer.beginIndexing(mediumUUID: medium.uuid, token: second))
        #expect(!(await store.writer.indexingIsActive(mediumUUID: medium.uuid, token: first)))
        #expect(try await store.writer.finishIndexing(mediumUUID: medium.uuid, token: first, status: .indexed, firstIndexedAt: nil) == false)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(try await store.writer.finishIndexing(mediumUUID: medium.uuid, token: second, status: .indexed, firstIndexedAt: day))
        let done = try #require(try await store.writer.medium(uuid: medium.uuid))
        #expect(done.indexStatus == .indexed)
        #expect(done.firstIndexedAt == day)
        // Ein verworfener Token startet nie mehr.
        #expect(try await store.writer.beginIndexing(mediumUUID: medium.uuid, token: first) == false)
        await #expect(throws: IndexStoreError.unknownMedium) {
            _ = try await store.writer.beginIndexing(mediumUUID: UUID(), token: UUID())
        }
    }

    @Test func folderLookupsAndSmallMediumSettersWork() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Ordner")
        let root = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "z.txt", isFolder: false)])
        let a = try #require(root.first { $0.name == "A" })
        let inner = try await store.apply(medium: medium, parentID: a.id, entries: [ScannedEntry(name: "B", isFolder: true)])
        let b = try #require(inner.first)
        #expect(try await store.writer.folderID(mediumUUID: medium.uuid, path: ["A"]) == a.id)
        #expect(try await store.writer.folderID(mediumUUID: medium.uuid, path: ["A", "B"]) == b.id)
        #expect(try await store.writer.folderID(mediumUUID: medium.uuid, path: ["A", "X"]) == nil)
        #expect(try await store.writer.folderID(mediumUUID: medium.uuid, path: []) == nil)
        let level1 = try await store.writer.folders(mediumUUID: medium.uuid, depth: 1, limit: 100, offset: 0)
        #expect(level1.map(\.id) == [a.id])
        #expect(level1.map(\.path) == ["/A/"])
        let level2 = try await store.writer.folders(mediumUUID: medium.uuid, depth: 2, limit: 100, offset: 0)
        #expect(level2.map(\.path) == ["/A/B/"])
        #expect(try await store.writer.contentStamp(mediumUUID: medium.uuid, path: ["A"]) != nil)
        #expect(try await store.writer.contentStamp(mediumUUID: medium.uuid, path: ["Nope"]) == nil)

        try await store.writer.markFolderUnreadable(mediumUUID: medium.uuid, folderID: b.id)
        #expect(try await store.item(id: b.id)?.unreadable == true)
        try await store.writer.setScanTotal(mediumUUID: medium.uuid, total: 42)
        #expect(try await store.writer.medium(uuid: medium.uuid)?.scanTotal == 42)
        try await store.writer.recordEventCursor(mediumUUID: medium.uuid, fsEventsUUID: "E-1", lastEventID: 5)
        let cursor = try #require(try await store.writer.medium(uuid: medium.uuid))
        #expect(cursor.fsEventsUUID == "E-1")
        #expect(cursor.lastEventID == 5)
        try await store.writer.completeLayer(mediumUUID: medium.uuid, depth: 2)
        try await store.writer.resetCompletedDepth(mediumUUID: medium.uuid)
        #expect(try await store.writer.medium(uuid: medium.uuid)?.completedDepth == 0)
        await #expect(throws: IndexStoreError.unknownItem) { try await store.writer.setFavorite(itemID: 99_999, true) }
    }
}

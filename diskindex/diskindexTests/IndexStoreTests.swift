//
//  IndexStoreTests.swift
//  diskindexTests
//

import Foundation
import GRDB
import Testing
@testable import diskindex

struct IndexStoreTests {
    @Test func migrationCreatesTablesIndexesAndPragmas() async throws {
        let harness = try StoreHarness.make()
        let schema = try await harness.store.schemaSnapshot()
        let required = [
            "medium", "item", "item_fts",
            "item_identity", "item_parent", "item_removed", "item_path", "item_modified", "item_ext",
            "item_fts_delete", "item_fts_update",
        ]
        for name in required {
            #expect(schema.names.contains(name), "fehlt: \(name)")
        }
        #expect(schema.journalMode == "wal")
        #expect(schema.foreignKeys == 1)
        #expect(schema.synchronous == 1)
        #expect(schema.fullTextUpdateSQL.contains("UPDATE OF name"))

        let medium = try await harness.insert(name: "Karte", fsType: "msdos", bytes: 100)
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "liesmich.txt", isFolder: false),
        ])
        try await harness.store.deleteMedium(uuid: medium.uuid)
        let left = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(left.isEmpty)
        #expect(try await harness.store.medium(uuid: medium.uuid) == nil)
    }

    @Test func applyDirectoryKeepsIDs() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let entries = [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "liesmich.txt", isFolder: false),
        ]
        let first = try await harness.addRoot(medium: medium, entries: entries)
        let second = try await harness.addRoot(medium: medium, entries: entries)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.name) == ["Projekte", "liesmich.txt"])
    }

    @Test func favoriteSurvivesDisappearance() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        let gone = seen.addingTimeInterval(60)
        let back = seen.addingTimeInterval(120)
        let file = ScannedEntry(name: "Urlaubsfoto.jpg", isFolder: false, sizeBytes: 10, modifiedAt: seen, fileID: "abc")
        let created = try await harness.addRoot(medium: medium, entries: [file], seenAt: seen)
        let id = try #require(created.first?.id)
        try await harness.store.setFavorite(itemID: id, true)

        let removed = try await harness.addRoot(medium: medium, entries: [], seenAt: gone)
        #expect(removed.isEmpty)
        let whileGone = try #require(try await harness.store.item(id: id))
        #expect(whileGone.removedAt != nil)
        #expect(whileGone.isFavorite)
        #expect(try await harness.store.favorites().isEmpty)

        let restored = try await harness.addRoot(medium: medium, entries: [file], seenAt: back)
        #expect(restored.map(\.id) == [id])
        #expect(restored.first?.removedAt == nil)
        #expect(restored.first?.isFavorite == true)
        #expect(try await harness.store.favorites().map(\.id) == [id])
    }

    @Test func missingFolderMarksSubtreeUntilReread() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let root = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "bleibt.txt", isFolder: false),
        ])
        let projekte = try #require(root.first { $0.name == "Projekte" })
        let child = try await harness.store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: projekte.id,
            entries: [
                ScannedEntry(name: "brief.txt", isFolder: false),
                ScannedEntry(name: "Kunde", isFolder: true),
            ]
        )
        let kunde = try #require(child.first { $0.name == "Kunde" })
        let note = try await harness.store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: kunde.id,
            entries: [ScannedEntry(name: "notiz.txt", isFolder: false)]
        )
        let noteID = try #require(note.first?.id)
        try await harness.store.setFavorite(itemID: noteID, true)

        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "bleibt.txt", isFolder: false),
        ])
        for id in [projekte.id, child[0].id, kunde.id, noteID] {
            let item = try #require(try await harness.store.item(id: id))
            #expect(item.removedAt != nil)
        }
        let stays = try #require(root.first { $0.name == "bleibt.txt" })
        #expect(try await harness.store.item(id: stays.id)?.removedAt == nil)

        let back = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "bleibt.txt", isFolder: false),
        ])
        #expect(back.first { $0.name == "Projekte" }?.id == projekte.id)
        #expect(try await harness.store.item(id: projekte.id)?.removedAt == nil)
        #expect(try await harness.store.item(id: kunde.id)?.removedAt != nil)
        #expect(try await harness.store.item(id: noteID)?.removedAt != nil)

        _ = try await harness.store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: projekte.id,
            entries: [
                ScannedEntry(name: "brief.txt", isFolder: false),
                ScannedEntry(name: "Kunde", isFolder: true),
            ]
        )
        #expect(try await harness.store.item(id: kunde.id)?.removedAt == nil)
        #expect(try await harness.store.item(id: noteID)?.removedAt != nil)

        let reread = try await harness.store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: kunde.id,
            entries: [ScannedEntry(name: "notiz.txt", isFolder: false)]
        )
        #expect(reread.map(\.id) == [noteID])
        #expect(reread.first?.removedAt == nil)
        #expect(reread.first?.isFavorite == true)
    }

    @Test func childrenOrderAndCompleteLayerNeverGoesBackward() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let children = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "zeta", isFolder: true),
            ScannedEntry(name: "beta.txt", isFolder: false),
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "alpha.txt", isFolder: false),
        ])
        #expect(children.map(\.name) == ["Alpha", "zeta", "alpha.txt", "beta.txt"])

        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 2)
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(stored.completedDepth == 2)
        #expect(stored.fileCount == 2)
        #expect(stored.folderCount == 2)
        #expect(stored.lastIndexedAt != nil)
    }

    @Test func searchUsesFTSAndLikeAndSkipsRemoved() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let other = try await harness.insert(name: "Stick", fsType: "msdos", bytes: 2_000)
        let now = Date()
        let old = Calendar.current.date(byAdding: .year, value: -2, to: now) ?? now.addingTimeInterval(-60 * 60 * 24 * 800)
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Urlaubsfoto.jpg", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "FOTO_extra.png", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "AB.txt", isFolder: false, modifiedAt: old),
            ScannedEntry(name: "weg-foto.jpg", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "Notiz.txt", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "Fotos", isFolder: true, modifiedAt: now),
        ])
        let gone = try #require(try await harness.store.children(mediumUUID: medium.uuid, parentID: nil).first { $0.name == "weg-foto.jpg" })
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Urlaubsfoto.jpg", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "FOTO_extra.png", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "AB.txt", isFolder: false, modifiedAt: old),
            ScannedEntry(name: "Notiz.txt", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "Fotos", isFolder: true, modifiedAt: now),
        ])
        _ = try await harness.addRoot(medium: other, entries: [
            ScannedEntry(name: "anderes-foto.jpg", isFolder: false, modifiedAt: now),
        ])

        let foto = try await harness.store.search(query: "foto", filters: SearchFilters(), limit: 20)
        #expect(Set(foto.map(\.name)) == ["Urlaubsfoto.jpg", "FOTO_extra.png", "anderes-foto.jpg", "Fotos"])

        let upper = try await harness.store.search(query: "FOTO", filters: SearchFilters(), limit: 20)
        #expect(Set(upper.map(\.name)) == Set(foto.map(\.name)))

        let short = try await harness.store.search(query: "ab", filters: SearchFilters(), limit: 20)
        #expect(short.map(\.name) == ["AB.txt"])

        var images = SearchFilters()
        images.fileTypes = [.image]
        let imageHits = try await harness.store.search(query: "foto", filters: images, limit: 20)
        #expect(Set(imageHits.map(\.name)) == ["Urlaubsfoto.jpg", "FOTO_extra.png", "anderes-foto.jpg"])

        var onlyText = SearchFilters()
        onlyText.customExtensions = [".txt"]
        let textHits = try await harness.store.search(query: "", filters: onlyText, limit: 20)
        #expect(Set(textHits.map(\.name)) == ["AB.txt", "Notiz.txt"])

        var recent = SearchFilters()
        recent.age = .lastWeek
        let recentHits = try await harness.store.search(query: "ab", filters: recent, limit: 20)
        #expect(recentHits.isEmpty)

        var oneMedium = SearchFilters()
        oneMedium.selectAllMedia = false
        oneMedium.mediumIDs = [medium.uuid]
        let limited = try await harness.store.search(query: "foto", filters: oneMedium, limit: 20)
        #expect(Set(limited.map(\.name)) == ["Urlaubsfoto.jpg", "FOTO_extra.png", "Fotos"])
        #expect(try await harness.store.item(id: gone.id)?.removedAt != nil)
    }

    @Test func insertingTwoHundredThousandEntriesStaysFast() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Last", fsType: "apfs", bytes: 1_000_000_000)
        let parents = try await harness.addRoot(
            medium: medium,
            entries: (0..<40).map { ScannedEntry(name: "ordner-\($0)", isFolder: true) }
        )
        let seenAt = Date(timeIntervalSince1970: 1_700_000_000)
        let insertStarted = ContinuousClock.now
        for parent in parents {
            let batch = parent.name.split(separator: "-").last.flatMap { Int($0) } ?? 0
            let entries = (0..<5_000).map { index in
                let name = index % 1_000 == 0
                    ? "rechnung-\(batch)-\(index).pdf"
                    : "datei-\(batch)-\(index).bin"
                return ScannedEntry(name: name, isFolder: false, sizeBytes: 1)
            }
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid,
                parentID: parent.id,
                entries: entries,
                seenAt: seenAt
            )
        }
        let insertElapsed = ContinuousClock.now - insertStarted

        let searchStarted = ContinuousClock.now
        let hits = try await harness.store.search(query: "rechn", filters: SearchFilters(), limit: 20)
        let searchElapsed = ContinuousClock.now - searchStarted

        let report = "IndexStore Rauchtest: Einfügen \(smokeSeconds(insertElapsed)), Suche \(smokeSeconds(searchElapsed))"
        print(report)
        Attachment.record(report, named: "indexstore-smoke.txt")
        // Rauchtest auf Größenordnung, nicht auf eine lastabhängige Stoppuhr (K7).
        #expect(insertElapsed < .seconds(20))
        #expect(searchElapsed < .milliseconds(500))
        #expect(!hits.isEmpty)
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains("rechn") })
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        let truth = try await harness.store.counts(mediumUUID: medium.uuid)
        #expect(stored.fileCount == truth.files)
        #expect(stored.folderCount == truth.folders)
    }

    @Test func mediumCountsStayAccurateWithIncrementalMeta() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Zähler", fsType: "apfs", bytes: 1_000)
        let seen = Date(timeIntervalSince1970: 1_700_000_000)
        let root = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "liesmich.txt", isFolder: false),
        ], seenAt: seen)
        let folderID = try #require(root.first { $0.isFolder }?.id)
        _ = try await harness.store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: folderID,
            entries: [
                ScannedEntry(name: "alt.txt", isFolder: false),
                ScannedEntry(name: "Unter", isFolder: true),
            ],
            seenAt: seen
        )
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Projekte", isFolder: true),
            ScannedEntry(name: "liesmich.txt", isFolder: false),
        ], seenAt: seen.addingTimeInterval(60))
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        let truth = try await harness.store.counts(mediumUUID: medium.uuid)
        #expect(stored.fileCount == truth.files)
        #expect(stored.folderCount == truth.folders)
        #expect(truth.files == 2)
        #expect(truth.folders == 2)
    }

    @Test func databaseFilesArePrivateToTheUser() throws {
        let harness = try StoreHarness.make()
        #expect(permission(harness.directory) == 0o700)
        #expect(permission(harness.directory.appendingPathComponent("index.sqlite")) == 0o600)
        let loose = harness.directory.appendingPathComponent("index.sqlite-wal")
        if FileManager.default.fileExists(atPath: loose.path) {
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: loose.path)
            FilePrivacy.restrict(harness.directory)
            #expect(permission(loose) == 0o600)
        }
    }

    @Test func specialNamesStayInsideTheirFolder() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let folders = ["100%", "a_b", "c\\d"]
        let root = try await harness.addRoot(medium: medium, entries: folders.map { ScannedEntry(name: $0, isFolder: true) } + [
            ScannedEntry(name: "100%EXTRA", isFolder: false),
        ])
        var childIDs: [Int64] = []
        for folder in folders {
            let parent = try #require(root.first { $0.name == folder })
            let created = try await harness.store.applyDirectoryReturningChildren(
                mediumUUID: medium.uuid,
                parentID: parent.id,
                entries: [ScannedEntry(name: "innen.txt", isFolder: false)]
            )
            childIDs.append(try #require(created.first?.id))
        }
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "100%EXTRA", isFolder: false),
        ])
        let extra = try #require(root.first { $0.name == "100%EXTRA" })
        #expect(try await harness.store.item(id: extra.id)?.removedAt == nil)
        for folder in folders {
            let parent = try #require(root.first { $0.name == folder })
            #expect(try await harness.store.item(id: parent.id)?.removedAt != nil)
        }
        for id in childIDs {
            #expect(try await harness.store.item(id: id)?.removedAt != nil)
        }
    }

    @Test func secondPassLeavesTheFullTextIndex() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let entries = (0..<200_000).map { index in
            ScannedEntry(name: "datei-\(index).txt", isFolder: false, sizeBytes: 1)
        }
        let firstStart = ContinuousClock.now
        _ = try await harness.addRoot(medium: medium, entries: entries)
        let first = firstStart.duration(to: .now)
        let before = try await harness.store.fullTextByteLength()
        let secondStart = ContinuousClock.now
        _ = try await harness.addRoot(medium: medium, entries: entries)
        let second = secondStart.duration(to: .now)
        let after = try await harness.store.fullTextByteLength()
        #expect(before == after)
        #expect(second < first)
    }

    @Test func reopenDatabaseFileSupportsParallelReadsAndWrite() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-reopen-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("index.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try IndexDatabase(fileURL: fileURL)
        let store = IndexStore(database: database)
        let medium = StoredMedium(fsType: "msdos", volumeTotalBytes: 8_000_000_000, name: "NO NAME")
        try await store.upsertMedium(medium)
        try database.close()

        let reopened = try IndexDatabase(fileURL: fileURL)
        let store2 = IndexStore(database: reopened)
        try await withThrowingTaskGroup(of: [StoredMedium].self) { group in
            for _ in 0..<12 {
                group.addTask { try await store2.media() }
            }
            for try await rows in group {
                #expect(rows.count == 1)
            }
        }
        try await store2.upsertMedium(medium)
        #expect(try await store2.media().count == 1)
        try reopened.close()
    }

    @Test func reopenLegacyAutoVacuumZeroDatabase() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-legacy-vacuum-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("index.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        try IndexDatabase.installSchemaForTesting(at: fileURL, autoVacuumIncremental: false)
        let queue = try DatabaseQueue(path: fileURL.path)
        let modeBefore = try await queue.read { db in
            try Int.fetchOne(db, sql: "PRAGMA auto_vacuum") ?? 0
        }
        #expect(modeBefore == 0)

        let database = try IndexDatabase(fileURL: fileURL)
        let store = IndexStore(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "Platte")
        try await store.upsertMedium(medium)
        #expect(try await store.media().count == 1)
        try database.close()
    }

    @Test func reopenDatabaseWithMediumAndManyObjects() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-fixture-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("index.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        try IndexDatabase.installSchemaForTesting(at: fileURL, autoVacuumIncremental: true)
        let database = try IndexDatabase(fileURL: fileURL)
        let store = IndexStore(database: database)
        let medium = StoredMedium(
            fsType: "msdos",
            volumeTotalBytes: 8_000_000_000,
            name: "NO NAME",
            decision: .index,
            indexStatus: .indexed
        )
        try await store.upsertMedium(medium)
        let entries = (0..<40).map { index in
            ScannedEntry(name: "obj-\(index).txt", isFolder: false, sizeBytes: 100)
        }
        _ = try await store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: entries
        )
        try database.close()

        let reopened = try IndexDatabase(fileURL: fileURL)
        let store2 = IndexStore(database: reopened)
        #expect(try await store2.media().count == 1)
        let root = try await store2.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(root.count == 40)
        try reopened.close()
    }

    @Test func metaCommitBatchesRapidChunksUntilFlush() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Batch", fsType: "apfs", bytes: 100)
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        try await harness.store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, [ScannedEntry(name: "a.txt", isFolder: false)], false)],
            seenAt: stamp
        )
        let afterA = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(afterA.fileCount == 1)
        try await harness.store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, [
                ScannedEntry(name: "a.txt", isFolder: false),
                ScannedEntry(name: "b.txt", isFolder: false),
            ], false)],
            seenAt: stamp
        )
        let batched = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(batched.fileCount == 1)
        try await harness.store.flushMediumMeta(mediumUUID: medium.uuid, force: true)
        let flushed = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(flushed.fileCount == 2)
    }
}

private func permission(_ url: URL) -> Int? {
    let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
    return value?.intValue
}

private func smokeSeconds(_ duration: Duration) -> String {
    let parts = duration.components
    let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    return String(format: "%.3f s", seconds)
}

final class StoreHarness: @unchecked Sendable {
    let directory: URL
    let store: IndexStore
    private let closeDatabase: @Sendable () -> Void

    static func make() throws -> StoreHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-indexstore-\(UUID().uuidString)", isDirectory: true)
        let database = try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite"))
        return StoreHarness(directory: directory, store: IndexStore(database: database)) {
            try? database.close()
        }
    }

    private init(directory: URL, store: IndexStore, closeDatabase: @escaping @Sendable () -> Void) {
        self.directory = directory
        self.store = store
        self.closeDatabase = closeDatabase
    }

    deinit {
        closeDatabase()
        try? FileManager.default.removeItem(at: directory)
    }

    func insert(name: String, fsType: String, bytes: Int64) async throws -> StoredMedium {
        let medium = StoredMedium(fsType: fsType, volumeTotalBytes: bytes, name: name)
        try await store.upsertMedium(medium)
        return medium
    }

    func addRoot(medium: StoredMedium, entries: [ScannedEntry], seenAt: Date = Date()) async throws -> [StoredItem] {
        try await store.applyDirectoryReturningChildren(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: entries,
            seenAt: seenAt
        )
    }
}

extension IndexStore {
    fileprivate func collectItemFolderPathsDuring(
        mediumUUID: UUID,
        _ body: () async throws -> Void
    ) async throws -> [[String]] {
        var collected: [[String]] = []
        let listener = Task { @MainActor in
            for await event in self.changes {
                if case .items(let id, let folderPaths) = event.change, id == mediumUUID {
                    collected.append(contentsOf: folderPaths)
                }
            }
        }
        try await body()
        try await Task.sleep(for: .milliseconds(100))
        listener.cancel()
        return collected
    }
}

extension WindowTestGroup {
@Suite @MainActor
struct WindowTestGroupIndexStoreTests {
    @Test func applyDirectoriesEmitsResolvedParentPathWhenBatchPathNil() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Sub", fsType: "apfs", bytes: 100)
        _ = try await harness.addRoot(
            medium: medium,
            entries: [ScannedEntry(name: "A", isFolder: true)]
        )
        let folderA = try #require(try await harness.store.folderID(mediumUUID: medium.uuid, path: ["A"]))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: folderA,
            entries: [ScannedEntry(name: "B", isFolder: true)],
            seenAt: Date()
        )
        let folderB = try #require(try await harness.store.folderID(mediumUUID: medium.uuid, path: ["A", "B"]))

        let emitted = try await harness.store.collectItemFolderPathsDuring(mediumUUID: medium.uuid) {
            try await harness.store.applyDirectories(
                mediumUUID: medium.uuid,
                batches: [(folderB, nil, nil, [ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 1)], true)],
                seenAt: Date()
            )
        }
        #expect(emitted.contains(["A", "B"]))
    }
}
}

private extension IndexStore {
    func applyDirectoryReturningChildren(
        mediumUUID: UUID,
        parentID: Int64?,
        entries: [ScannedEntry],
        seenAt: Date = Date()
    ) async throws -> [StoredItem] {
        try await applyDirectory(mediumUUID: mediumUUID, parentID: parentID, entries: entries, seenAt: seenAt)
        return try await children(mediumUUID: mediumUUID, parentID: parentID)
    }
}

//
//  IndexStoreTests.swift
//  diskindexTests
//

import Foundation
import GRDB
import Testing
@testable import diskindex

struct IndexStoreTests {
    /// bug.0.4.044: deterministisch (200k Zeilen, Blockschreiben) — Zeitgrenzen nur unter `DA_BENCH=1`.
    @Test func insertingTwoHundredThousandEntriesInBlocks() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Last", fsType: "apfs", bytes: 1_000_000_000)
        let parents = try await harness.addRoot(
            medium: medium,
            entries: (0..<40).map { ScannedEntry(name: "ordner-\($0)", isFolder: true) }
        )
        let seenAt = Date(timeIntervalSince1970: 1_700_000_000)
        let expectedFiles = 40 * 5_000
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
        let truth = try await harness.store.counts(mediumUUID: medium.uuid)
        #expect(truth.files == expectedFiles)
        #expect(truth.folders == 40)
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(stored.fileCount == truth.files)
        #expect(stored.folderCount == truth.folders)
        let hits = try await harness.store.search(query: "rechn", filters: SearchFilters(), limit: 20)
        #expect(!hits.isEmpty)
        #expect(hits.allSatisfy { $0.name.localizedCaseInsensitiveContains("rechn") })
    }

    @Test func databaseFilesArePrivateToTheUser() throws {
        let harness = try StoreHarness.make()
        #expect(permission(harness.directory) == 0o700)
        #expect(permission(harness.directory.appendingPathComponent("archive.sqlite")) == 0o600)
        let loose = harness.directory.appendingPathComponent("archive.sqlite-wal")
        if FileManager.default.fileExists(atPath: loose.path) {
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: loose.path)
            FilePrivacy.restrict(harness.directory)
            #expect(permission(loose) == 0o600)
        }
    }

    @Test func reopenDatabaseFileSupportsParallelReadsAndWrite() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-reopen-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("archive.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try TestDatabase(fileURL: fileURL)
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "msdos", volumeTotalBytes: 8_000_000_000, name: "NO NAME")
        try await store.upsertMedium(medium)
        try database.close()

        let reopened = try TestDatabase(fileURL: fileURL)
        let store2 = IndexStoreV3(database: reopened)
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

    @Test func reopenDatabaseWithMediumAndManyObjects() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-fixture-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("archive.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try TestDatabase(fileURL: fileURL)
        let store = IndexStoreV3(database: database)
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

        let reopened = try TestDatabase(fileURL: fileURL)
        let store2 = IndexStoreV3(database: reopened)
        #expect(try await store2.media().count == 1)
        let root = try await store2.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(root.count == 40)
        try reopened.close()
    }
}

private func permission(_ url: URL) -> Int? {
    let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
    return value?.intValue
}

/// bug.0.4.044 — Zeitgrenzen nur unter `DA_BENCH=1` (Regel 8: Leistung nur Release/Messung).
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["DA_BENCH"] == "1"))
struct IndexStoreTimingBenchTests {
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
        let report = "IndexStoreV3 Rauchtest: Einfügen \(smokeSeconds(insertElapsed)), Suche \(smokeSeconds(searchElapsed))"
        print(report)
        Attachment.record(report, named: "indexstore-smoke.txt")
        #expect(insertElapsed < .seconds(20))
        #expect(searchElapsed < .milliseconds(500))
        #expect(!hits.isEmpty)
    }

    private func smokeSeconds(_ duration: Duration) -> String {
        let parts = duration.components
        let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        return String(format: "%.3f s", seconds)
    }
}

final class StoreHarness: @unchecked Sendable {
    let directory: URL
    let store: IndexStoreV3
    private let closeDatabase: @Sendable () -> Void

    static func make() throws -> StoreHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-indexstore-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        return StoreHarness(directory: directory, store: IndexStoreV3(database: database)) {
            try? database.close()
        }
    }

    private init(directory: URL, store: IndexStoreV3, closeDatabase: @escaping @Sendable () -> Void) {
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

private extension IndexStoreV3 {
    func applyDirectoryReturningChildren(
        mediumUUID: UUID,
        parentID: Int64?,
        entries: [ScannedEntry],
        seenAt: Date = Date()
    ) async throws -> [StoredItem] {
        try await applyDirectory(mediumUUID: mediumUUID, parentID: parentID, entries: entries, seenAt: seenAt)
        return try await children(mediumUUID: mediumUUID, parentID: parentID, limit: nil, offset: 0, scope: nil)
    }
}

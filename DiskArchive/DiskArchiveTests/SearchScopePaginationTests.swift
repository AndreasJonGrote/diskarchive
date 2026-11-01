//
//  SearchScopePaginationTests.swift
//  DiskArchiveTests
//
//  c.0.3.2.005 — Scope/Pagination nach SQL-LIMIT (REPORT 11, 12, 19, 20).
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct SearchScopePaginationTests {
    @Test func childrenPageSkipsHiddenPrefix() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-scope-page-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "Page", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        var entries: [ScannedEntry] = (0..<20).map {
            ScannedEntry(name: ".\($0).txt", isFolder: false, sizeBytes: 1)
        }
        entries += (1...12).map { ScannedEntry(name: "sicht-\($0).txt", isFolder: false, sizeBytes: 1) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, entries, true)],
            seenAt: Date()
        )

        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: false),
            checksNames: true
        )
        #expect(try await store.childCount(mediumUUID: medium.uuid, parentID: nil, scope: scope) == 12)

        var seen: [String] = []
        var cursor: ItemChildrenCursor?
        while true {
            let page = try await store.childrenPage(
                mediumUUID: medium.uuid,
                parentID: nil,
                limit: 5,
                after: cursor,
                scope: scope
            )
            seen += page.items.map(\.name)
            guard let next = page.nextCursor else { break }
            cursor = next
        }
        #expect(seen.count == 12)
        #expect(seen.allSatisfy { !$0.hasPrefix(".") })
    }

    @Test func searchFillsLimitDespiteHiddenSQLHits() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-scope-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "Suche", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        var entries: [ScannedEntry] = (0..<30).map {
            ScannedEntry(name: ".bericht-\($0).pdf", isFolder: false, sizeBytes: 1)
        }
        entries += (1...15).map { ScannedEntry(name: "bericht-\($0).pdf", isFolder: false, sizeBytes: 1) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, entries, true)],
            seenAt: Date()
        )

        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: false),
            checksNames: true
        )
        let hits = try await store.search(query: "bericht", filters: SearchFilters(), limit: 10, scope: scope)
        #expect(hits.count == 10)
        #expect(hits.allSatisfy { !$0.name.hasPrefix(".") })

        let count = try await store.searchCount(query: "bericht", filters: SearchFilters(), scope: scope)
        #expect(count == 15)
    }

    @Test func childCountRespectsScope() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-scope-count-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "Zahl", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        let entries: [ScannedEntry] = (0..<5).map {
            ScannedEntry(name: ".\($0).txt", isFolder: false, sizeBytes: 1)
        } + [ScannedEntry(name: "ok.txt", isFolder: false, sizeBytes: 1)]
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, "/", 1, entries, true)],
            seenAt: Date()
        )

        let scoped = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: false),
            checksNames: true
        )
        #expect(try await store.childCount(mediumUUID: medium.uuid, parentID: nil, scope: nil) == 6)
        #expect(try await store.childCount(mediumUUID: medium.uuid, parentID: nil, scope: scoped) == 1)
    }
}

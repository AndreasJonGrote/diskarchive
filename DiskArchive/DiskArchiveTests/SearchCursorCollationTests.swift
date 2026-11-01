//
//  SearchCursorCollationTests.swift
//  DiskArchiveTests
//
//  bug.0.4.057 (REPORT 100): Seite 1 der Suche sortiert `slug` binär, der Cursor der Folgeseiten muss
//  dieselbe Sortierfolge nutzen. Sonst fehlen bei „img10“ als letztem Treffer der Seite „img2“…„img9“.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct SearchCursorCollationTests {
    @Test func secondSearchPageHasNoGapsOrDuplicatesAroundImg9AndImg10() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-search-cursor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "Cursor", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        // 98 versteckte Treffer (binär vor „img…“) + „img1“, „img10“ füllen Seite 1 (100); Cursor steht auf „img10“.
        var entries: [ScannedEntry] = (0..<98).map {
            ScannedEntry(name: ".img-h-\($0)", isFolder: false, sizeBytes: 1)
        }
        entries += (1...20).map { ScannedEntry(name: "img\($0)", isFolder: false, sizeBytes: 1) }
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

        let hits = try await store.search(query: "img", filters: SearchFilters(), limit: 20, scope: scope)
        let names = hits.map(\.name)
        #expect(names.count == 20, "\(names)")
        #expect(Set(names).count == names.count, "Doppelte: \(names)")
        #expect(Set(names) == Set((1...20).map { "img\($0)" }), "Lücken: \(names)")
        #expect(names.allSatisfy { !$0.hasPrefix(".") })
    }
}

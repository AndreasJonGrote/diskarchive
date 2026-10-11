//
//  SearchCountTests.swift
//  diskindexTests
//
//  Aufgabe 211 a — die Trefferzahl hat keine Obergrenze (früher 50.000 mit `scope`).
//

import Foundation
import Testing
@testable import diskindex

@Suite struct SearchCountTests {
    @Test func countIsExactAboveFiftyThousandWithScope() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-count-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStore(database: try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ZAHL", type: .usb, decision: .index)
        try await store.upsertMedium(medium)

        var entries: [ScannedEntry] = []
        for index in 0..<60_000 {
            entries.append(ScannedEntry(name: "bericht-\(index).html", isFolder: false, sizeBytes: 1))
        }
        // Wird laut Bereich ausgeblendet: Muster, versteckt, ._-Datei, Artefakt.
        entries.append(ScannedEntry(name: "bericht-a.tmp", isFolder: false, sizeBytes: 1))
        entries.append(ScannedEntry(name: ".bericht-versteckt.html", isFolder: false, sizeBytes: 1))
        entries.append(ScannedEntry(name: "._bericht-apple.html", isFolder: false, sizeBytes: 1))
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: true)],
            seenAt: Date()
        )

        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: ["*.tmp"], artifactsIgnored: true)
        )
        let withScope = try await store.searchCount(query: "bericht", filters: SearchFilters(), scope: scope)
        #expect(withScope == 60_000)
        let withoutScope = try await store.searchCount(query: "bericht", filters: SearchFilters())
        #expect(withoutScope == 60_003)
    }
}

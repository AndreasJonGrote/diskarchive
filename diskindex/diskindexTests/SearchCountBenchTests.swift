//
//  SearchCountBenchTests.swift
//  diskindexTests
//
//  Aufgabe 211 a — Messung der Zählung bei über 1 Mio. Treffern. Nur mit DA_BENCH=1 (Release, Regel 8).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.enabled(if: ProcessInfo.processInfo.environment["DA_BENCH"] == "1"))
struct SearchCountBenchTests {
    @Test func countOverOneMillionHits() async throws {
        let free = (try? URL(fileURLWithPath: NSTemporaryDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        try #require(free > 4_000_000_000, "zu wenig freier Platz")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-countbench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "BENCH", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let total = 1_200_000
        let block = 20_000
        var written = 0
        let seenAt = Date()
        let buildStart = ContinuousClock.now
        while written < total {
            var entries: [ScannedEntry] = []
            for index in written..<(written + block) {
                entries.append(ScannedEntry(name: "seite-\(index).html", isFolder: false, sizeBytes: 1))
            }
            try await store.applyDirectories(
                mediumUUID: medium.uuid,
                batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
                seenAt: seenAt
            )
            written += block
        }
        print("BENCH aufbau \(buildStart.duration(to: .now))")
        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: ["*.tmp"], artifactsIgnored: true)
        )
        var pureScope = scope
        pureScope.checksNames = false
        let cases: [(String, String, IndexScope?)] = [
            ("mit ausstehender Bereinigung, 'seite'", "seite", scope),
            ("ohne ausstehende Bereinigung, 'seite'", "seite", pureScope),
            ("ohne Bereich, 'seite'", "seite", nil),
            ("mit ausstehender Bereinigung, 'html'", "html", scope),
            ("ohne ausstehende Bereinigung, 'html'", "html", pureScope),
        ]
        for (label, query, usedScope) in cases {
            var times: [Double] = []
            var count = 0
            for _ in 0..<5 {
                let start = ContinuousClock.now
                count = try await store.searchCount(query: query, filters: SearchFilters(), scope: usedScope)
                let d = start.duration(to: .now)
                times.append(Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18)
            }
            times.sort()
            print("BENCH \(label): Treffer \(count), Median \(times[2]) s, alle \(times)")
            #expect(count == total)
        }
    }
}

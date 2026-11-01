//
//  ColumnFilterBenchTests.swift
//  DiskArchiveTests
//
//  todo.0.4.2.003 (Gegenprobe 9): Tempo der Treffermenge auf einem erzeugten Medium mit 1 Mio. Einträgen und 50 000
//  Ordnern; Filter mit vielen (300 000) und mit wenigen (50) Treffern. Ziel unter 2 s je Rechnung. Nur mit DA_BENCH=1
//  (Release, Regel 8).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.enabled(if: ProcessInfo.processInfo.environment["DA_BENCH"] == "1"))
struct ColumnFilterBenchTests {
    @Test func hitsOnAMillionEntries() async throws {
        let free = (try? URL(fileURLWithPath: NSTemporaryDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        try #require(free > 4_000_000_000, "zu wenig freier Platz")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-columnfilter-bench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "BENCH", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let seenAt = Date()
        let buildStart = ContinuousClock.now
        // 250 Ordner in der Wurzel, je 199 Unterordner: 50 000 Ordner.
        _ = try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: nil, depth: 1, entries: (0..<250).map { ScannedEntry(name: "T\($0)", isFolder: true) }, finalize: false)],
            seenAt: seenAt
        )
        let tops = try await store.children(mediumUUID: medium.uuid, parentID: nil).map(\.id)
        for chunk in stride(from: 0, to: tops.count, by: 25) {
            let batches = tops[chunk..<min(chunk + 25, tops.count)].map { top in
                (parentID: Optional(top), path: String?.none, depth: Optional(2),
                 entries: (0..<199).map { ScannedEntry(name: "U\($0)", isFolder: true) }, finalize: false)
            }
            _ = try await store.applyDirectories(mediumUUID: medium.uuid, batches: batches, seenAt: seenAt)
        }
        var folders = tops
        for top in tops { folders += try await store.children(mediumUUID: medium.uuid, parentID: top).map(\.id) }
        #expect(folders.count == 50_000)
        // 950 000 Dateien, 19 je Ordner: 6 Bilder (zusammen 300 000), 50 PDFs im ganzen Medium, Rest Text.
        var images = 0
        var pdfs = 0
        for chunk in stride(from: 0, to: folders.count, by: 500) {
            let batches = folders[chunk..<min(chunk + 500, folders.count)].map { folder in
                var entries: [ScannedEntry] = []
                for index in 0..<19 {
                    let ext: String
                    if index < 6, images < 300_000 {
                        ext = "jpg"
                        images += 1
                    } else if index == 6, pdfs < 50, folder % 1_000 == 0 {
                        ext = "pdf"
                        pdfs += 1
                    } else {
                        ext = "txt"
                    }
                    entries.append(ScannedEntry(name: "d\(index).\(ext)", isFolder: false, sizeBytes: 1, modifiedAt: seenAt))
                }
                return (parentID: Optional(folder), path: String?.none, depth: Optional<Int>.none, entries: entries, finalize: false)
            }
            _ = try await store.applyDirectories(mediumUUID: medium.uuid, batches: batches, seenAt: seenAt)
        }
        var report = ["BENCH aufbau \(buildStart.duration(to: .now)), Bilder \(images), PDFs \(pdfs)"]
        for (label, type) in [("viele Treffer (Bild)", SearchFileTypeFilter.image), ("wenige Treffer (PDF)", .pdf)] {
            var filters = SearchFilters()
            filters.fileTypes = [type]
            var times: [Double] = []
            var count = 0
            for _ in 0..<3 {
                let start = ContinuousClock.now
                count = try await store.folderIDsWithHits(mediumUUID: medium.uuid, filters: filters, maxDepth: nil, scope: nil).count
                let duration = start.duration(to: .now)
                times.append(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
            }
            times.sort()
            let line = "BENCH \(label): Ordner mit Treffer \(count), Median \(times[1]) s, alle \(times)"
            print(line)
            report.append(line)
            #expect(times[1] < 2, "\(label): \(times[1]) s")
        }
        // Zahlen für den Status (Ausgabe des Testprozesses landet nicht im xcodebuild-Protokoll).
        try? report.joined(separator: "\n").write(
            to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("columnfilter-bench.txt"), atomically: true, encoding: .utf8
        )
    }
}

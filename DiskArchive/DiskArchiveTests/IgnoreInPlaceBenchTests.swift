//
//  IgnoreInPlaceBenchTests.swift
//  DiskArchiveTests
//
//  bug.0.4.099 (d): Messung – Ignorieren in einer geladenen Spalte mit 40.000 und 300.000 Einträgen, Dauer auf dem
//  Main Actor (Ausblenden an Ort und Stelle). Nur mit DA_BENCH=1 (Release, Regel 8); ohne Fenster (Regel 19).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized, .enabled(if: BenchGate.enabled)) @MainActor
struct IgnoreInPlaceBenchTests {
    @Test(arguments: [40_000, 300_000])
    func ignoreInLoadedColumn(count: Int) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-ignorebench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        defer { try? database.close() }
        let store = IndexStoreV3(database: database)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Bench", decision: .index, indexStatus: .indexed, completedDepth: 5)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        let block = 20_000
        var written = 0
        while written < count {
            let upper = min(count, written + block)
            let entries = (written..<upper).map { ScannedEntry(name: String(format: "datei-%06d.txt", $0), isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
            try await store.applyDirectories(
                mediumUUID: medium.uuid,
                batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
                seenAt: Date()
            )
            written = upper
        }
        let app = AppState()
        app.attach(store: store)
        defer { app.prepareForTermination() }
        await app.loadStoredMedia()
        app.columnBrowserState.selectedMediumID = medium.uuid
        let items = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: [])
        try #require(items.count == count)
        let target = String(format: "datei-%06d.txt", count / 2)
        let start = ContinuousClock.now
        app.toggleIgnoredPatterns([target])
        let elapsed = start.duration(to: .now)
        let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
        print("BENCH bug.0.4.099 ignore count=\(count) mainActorMs=\(String(format: "%.1f", ms))")
        #expect(app.indexRepository.children(mediumID: medium.uuid, path: []).count == count - 1)
        await app.waitForRuleReconcileIdle()
    }
}

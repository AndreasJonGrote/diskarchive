//
//  ColumnLoadMeasurementTests.swift
//  diskindexTests
//
//  Aufgabe 107 — Spalten-Ladezeiten / Speicher (nur mit Flag /tmp/diskindex-column-load.on).
//

import Darwin
import Foundation
import Testing
@testable import diskindex

@MainActor
@Suite(.serialized)
struct ColumnLoadMeasurementTests {
    @Test(.enabled(if: FileManager.default.fileExists(atPath: "/tmp/diskindex-column-load.on")))
    func measureColumnLoadsAndShapes() async throws {
        var lines: [String] = [
            "diskindex column-load bench \(ISO8601DateFormatter().string(from: Date()))",
            "batchSize=\(IndexRepository.loadBatchSize)",
        ]
        func keep(_ line: String) throws {
            lines.append(line)
            let body = lines.joined(separator: "\n") + "\n"
            try body.write(to: URL(fileURLWithPath: "/tmp/diskindex-column-load.txt"), atomically: true, encoding: .utf8)
            fputs(line + "\n", stderr)
            fflush(stderr)
        }

        let baselineRAM = ProcessMeter.residentBytes()
        try keep("baseline-ram-bytes=\(baselineRAM)")

        for count in [14_300, 100_000, 200_000] {
            try keep(try await measureWideFolderLoad(childCount: count, baselineRAM: baselineRAM))
        }

        try keep(try await measureFormA())
        try keep(try await measurePageQuery(childCount: 30_000))
        try keep(try await measureIndexerShape(
            label: "form-b",
            foldersPerDirectory: 18,
            filesPerDirectory: 5,
            maxDepth: 4
        ))
        try keep(try await measureIndexerShape(
            label: "form-c",
            foldersPerDirectory: 8,
            filesPerDirectory: 50,
            maxDepth: 5
        ))

        try keep("done")
    }

    /// Form (a): wenige Ordner, sehr viele Dateien (3 × 100.000).
    private func measureFormA() async throws -> String {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "FormA", fsType: "apfs", bytes: 1_000)
        let folders = try await harness.addRoot(
            medium: medium,
            entries: (0..<3).map { ScannedEntry(name: "bulk-\($0)", isFolder: true) }
        )
        let seen = Date()
        let seedStart = ContinuousClock.now
        for folder in folders {
            try await seedChildren(store: harness.store, mediumUUID: medium.uuid, parentID: folder.id, count: 100_000, seenAt: seen)
        }
        let seedSeconds = seconds(seedStart.duration(to: .now))
        let target = try #require(folders.first)
        let ramBefore = ProcessMeter.residentBytes()
        let repository = IndexRepository(store: harness.store)
        let loadStart = ContinuousClock.now
        let items = await repository.loadChildren(mediumID: medium.uuid, path: [target.name])
        let loadSeconds = seconds(loadStart.duration(to: .now))
        let ramAfter = ProcessMeter.residentBytes()
        let ramDeltaMB = Double(Int64(ramAfter) - Int64(ramBefore)) / 1_048_576
        return "form-a seed-s=\(fmt(seedSeconds)) load-s=\(fmt(loadSeconds)) count=\(items.count) ram-delta-mb=\(fmt(ramDeltaMB)) goal-load=<2.5s"
    }

    private func measureWideFolderLoad(childCount: Int, baselineRAM: UInt64) async throws -> String {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Wide-\(childCount)", fsType: "apfs", bytes: 1_000)
        _ = try await harness.addRoot(medium: medium, entries: [ScannedEntry(name: "Big", isFolder: true)])
        let folderID = try #require(try await harness.store.folderID(mediumUUID: medium.uuid, path: ["Big"]))
        let seedStart = ContinuousClock.now
        try await seedChildren(store: harness.store, mediumUUID: medium.uuid, parentID: folderID, count: childCount, seenAt: Date())
        let seedSeconds = seconds(seedStart.duration(to: .now))

        let ramBefore = ProcessMeter.residentBytes()
        let repository = IndexRepository(store: harness.store)
        var maxGapMs = 0.0
        let last = ContinuousClock.now
        // Erste Seite einzeln: Proxy für „erste Anzeige“ / Hauptfaden-Arbeit je Chunk.
        let pageStart = ContinuousClock.now
        let firstPage = try await harness.store.childrenPage(
            mediumUUID: medium.uuid,
            parentID: folderID,
            limit: IndexRepository.loadBatchSize,
            after: nil
        )
        let firstPageMs = seconds(pageStart.duration(to: .now)) * 1_000
        maxGapMs = max(maxGapMs, firstPageMs)

        let loadStart = ContinuousClock.now
        let items = await repository.loadChildren(mediumID: medium.uuid, path: ["Big"])
        let loadSeconds = seconds(loadStart.duration(to: .now))
        let ramAfter = ProcessMeter.residentBytes()
        let ramDeltaMB = Double(Int64(ramAfter) - Int64(ramBefore)) / 1_048_576
        let vsBaselineMB = Double(Int64(ramAfter) - Int64(baselineRAM)) / 1_048_576
        _ = last
        let goal: String = switch childCount {
        case 14_300: "<0.5s"
        case 100_000: "<2.5s"
        case 200_000: "<5s"
        default: "?"
        }
        let pass = switch childCount {
        case 14_300: loadSeconds < 0.5
        case 100_000: loadSeconds < 2.5
        case 200_000: loadSeconds < 5.0
        default: false
        }
        return [
            "wide-\(childCount)",
            "seed-s=\(fmt(seedSeconds))",
            "load-s=\(fmt(loadSeconds))",
            "first-page-ms=\(fmt(firstPageMs))",
            "first-page-count=\(firstPage.items.count)",
            "count=\(items.count)",
            "ram-delta-mb=\(fmt(ramDeltaMB))",
            "ram-vs-baseline-mb=\(fmt(vsBaselineMB))",
            "goal=\(goal)",
            "pass=\(pass ? "yes" : "no")",
        ].joined(separator: " ")
    }

    private func measurePageQuery(childCount: Int) async throws -> String {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Page", fsType: "apfs", bytes: 1_000)
        _ = try await harness.addRoot(medium: medium, entries: [ScannedEntry(name: "Big", isFolder: true)])
        let folderID = try #require(try await harness.store.folderID(mediumUUID: medium.uuid, path: ["Big"]))
        try await seedChildren(store: harness.store, mediumUUID: medium.uuid, parentID: folderID, count: childCount, seenAt: Date())
        var times: [Double] = []
        var cursor: ItemChildrenCursor?
        for _ in 0..<3 {
            let start = ContinuousClock.now
            let page = try await harness.store.childrenPage(
                mediumUUID: medium.uuid,
                parentID: folderID,
                limit: 500,
                after: cursor
            )
            times.append(seconds(start.duration(to: .now)) * 1_000)
            cursor = page.nextCursor
        }
        let avg = times.reduce(0, +) / Double(times.count)
        return "page-500-on-\(childCount) avg-ms=\(fmt(avg)) samples=\(times.map { fmt($0) }.joined(separator: ",")) goal=<30ms pass=\(avg < 30 ? "yes" : "no")"
    }

    private func measureIndexerShape(
        label: String,
        foldersPerDirectory: Int,
        filesPerDirectory: Int,
        maxDepth: Int
    ) async throws -> String {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: label, fsType: "apfs", bytes: 1_000)
        let access = SyntheticMediumAccess(
            foldersPerDirectory: foldersPerDirectory,
            filesPerDirectory: filesPerDirectory,
            maxDepth: maxDepth
        )
        let volume = VolumeInfo(
            mountPath: "/synthetic-\(label)",
            name: label,
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 100,
            diskSizeBytes: nil,
            volumeUUID: UUID().uuidString,
            createdAt: Date(timeIntervalSince1970: 10),
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: nil,
            isTimeMachineSnapshot: false
        )
        let ramBefore = ProcessMeter.residentBytes()
        let start = ContinuousClock.now
        let outcome = await DirectoryIndexer().run(
            store: harness.store,
            access: access,
            mediumUUID: medium.uuid,
            volume: volume,
            configuration: ScanConfiguration(
                maxDepth: maxDepth,
                ignoreHiddenFiles: true,
                excludedPatterns: [],
                limits: .standard
            ),
            fromScratch: true,
            token: UUID(),
            shouldHalt: { .none }
        )
        let elapsed = seconds(start.duration(to: .now))
        let ramAfter = ProcessMeter.residentBytes()
        let truth = try await harness.store.counts(mediumUUID: medium.uuid)
        let foldersPerSec = elapsed > 0 ? Double(truth.folders) / elapsed : 0
        let filesPerSec = elapsed > 0 ? Double(truth.files) / elapsed : 0
        return [
            label,
            "status=\(outcome.status)",
            "dauer-s=\(fmt(elapsed))",
            "folders=\(truth.folders)",
            "files=\(truth.files)",
            "folders-per-s=\(fmt(foldersPerSec))",
            "files-per-s=\(fmt(filesPerSec))",
            "ram-delta-mb=\(fmt(Double(Int64(ramAfter) - Int64(ramBefore)) / 1_048_576))",
        ].joined(separator: " ")
    }

    private func seedChildren(
        store: IndexStoreV3,
        mediumUUID: UUID,
        parentID: Int64,
        count: Int,
        seenAt: Date
    ) async throws {
        let entries = (0..<count).map { i in
            ScannedEntry(name: "file-\(i).txt", isFolder: false, sizeBytes: 1, modifiedAt: seenAt)
        }
        try await store.applyDirectory(
            mediumUUID: mediumUUID,
            parentID: parentID,
            entries: entries,
            seenAt: seenAt
        )
    }

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

//
//  BulkDirectoryReaderTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) struct BulkDirectoryReaderTests {
    private func bulkTestMedium(from stored: StoredMedium) -> Medium {
        Medium(
            id: stored.uuid,
            name: stored.name,
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .pending,
            allowIndexing: true,
            autoIndexPaused: false,
            decision: stored.decision,
            capacityTotalBytes: stored.volumeTotalBytes,
            capacityUsedBytes: 0,
            fileCount: stored.fileCount,
            folderCount: stored.folderCount,
            scanTotal: stored.scanTotal,
            lastSeenAt: Date(),
            firstIndexedAt: stored.firstIndexedAt,
            lastIndexedAt: stored.lastIndexedAt,
            completedDepth: stored.completedDepth,
            isForgotten: false,
            indexingProgress: 0
        )
    }

    @Test func deepTreeEmitsAtMostTenReadLogLines() throws {
        let tracker = BulkDirectoryReader.ReadLogEmitTracker()
        try BulkDirectoryReader.$readLogEmitTracker.withValue(tracker) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-log-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            for index in 0..<2_000 {
                let folder = root.appendingPathComponent("d-\(index)", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data("x".utf8).write(to: folder.appendingPathComponent("f.txt"))
            }
            _ = try BulkDirectoryReader.readResult(at: root)
            #expect(tracker.count <= 10)
        }
    }

    @Test @MainActor func indexRunOverTwoThousandFoldersEmitsAtMostTenReadLogLines() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-index-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<2_000 {
            let folder = root.appendingPathComponent("d-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: folder.appendingPathComponent("f.txt"))
        }
        let harness = try await ScanHarness.make()
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        stored.indexStatus = .pending
        try await harness.store.upsertMedium(stored)
        let app = AppState()
        app.media = [bulkTestMedium(from: stored)]
        let access = DirectMediumAccess()
        let service = IndexingService(store: harness.store, access: access, appState: app)
        let volume = harness.volume(at: root.path)
        DiskIndexLog.shared.record(.index, .info, "MARK bulk2000")
        service.start(mediumUUID: harness.mediumID, volume: volume, fromScratch: true)
        await service.waitUntilIdle(harness.mediumID)
        DiskIndexLog.shared.flushPendingWritesForTesting()
        let done = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(done.indexStatus == .indexed)
        #expect(done.fileCount >= 2_000)
        let crumbs = DiskIndexLog.shared.recentBreadcrumbs()
        let markIndex = crumbs.lastIndex { $0.contains("MARK bulk2000") } ?? 0
        let lesenLines = crumbs.dropFirst(markIndex).filter { $0.contains("lesen bulk=") }
        #expect(lesenLines.count <= 10)
    }

    @Test func bulkReadStreamsInChunks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-chunk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 0..<2_500 {
            let file = root.appendingPathComponent("n-\(index)")
            try Data().write(to: file)
        }

        var chunks = 0
        var total = 0
        for await result in BulkDirectoryReader.chunkedStream(at: root) {
            let chunk = try result.get()
            chunks += 1
            total += chunk.count
        }
        #expect(total == 2_500)
        #expect(chunks >= 2)
    }

    @Test func bulkUsedOnFAT32Volume() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-fat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let image = parent.appendingPathComponent("disk.dmg")
        let mountPoint = parent.appendingPathComponent("mnt")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let create = Process()
        create.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        create.arguments = ["create", "-size", "64m", "-fs", "MS-DOS FAT32", "-volname", "BULKTEST", image.path]
        let createOut = Pipe()
        let createErr = Pipe()
        create.standardOutput = createOut
        create.standardError = createErr
        try create.run()
        create.waitUntilExit()
        guard create.terminationStatus == 0 else {
            let out = String(data: createOut.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: createErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            Issue.record("hdiutil create fehlgeschlagen: \(out)\(err)")
            return
        }

        let attach = Process()
        attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attach.arguments = ["attach", "-nobrowse", "-mountpoint", mountPoint.path, image.path]
        let attachOut = Pipe()
        let attachErr = Pipe()
        attach.standardOutput = attachOut
        attach.standardError = attachErr
        try attach.run()
        attach.waitUntilExit()
        guard attach.terminationStatus == 0 else {
            let out = String(data: attachOut.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: attachErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            Issue.record("hdiutil attach fehlgeschlagen: \(out)\(err)")
            return
        }
        defer {
            let detach = Process()
            detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detach.arguments = ["detach", mountPoint.path, "-quiet"]
            try? detach.run()
            detach.waitUntilExit()
        }

        let root = mountPoint
        for index in 0..<200 {
            let file = root.appendingPathComponent("f-\(index).txt")
            try Data("z".utf8).write(to: file)
        }

        let result = try BulkDirectoryReader.readResult(at: root)
        #expect(result.stats.usedBulk)
        #expect(!result.stats.usedFallback)
        #expect(result.entries.count == 200)
    }
}

/// bug.0.3.9.008: Die 2-s-Grenze auf echtem Dateisystem misst bewusst Laufzeit, darum seriell in der Messgruppe.
extension MeasurementTestGroup {
@Suite(.serialized)
struct BulkDirectoryReaderMeasurementTests {
    @Test func bulkReadMatchesFileCountAndSkipsAppleDouble() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-read-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 0..<2_500 {
            let file = root.appendingPathComponent("file-\(index).txt")
            try Data("x".utf8).write(to: file)
            let dot = root.appendingPathComponent("._file-\(index).txt")
            try Data("y".utf8).write(to: dot)
        }

        let started = ContinuousClock.now
        let result = try BulkDirectoryReader.readResult(at: root)
        let elapsed = started.duration(to: .now)

        #expect(result.stats.usedBulk)
        #expect(!result.stats.usedFallback)
        #expect(result.entries.count == 2_500)
        #expect(elapsed < .seconds(2))
    }
}
}

//
//  BulkDirectoryReaderTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite struct BulkDirectoryReaderTests {
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

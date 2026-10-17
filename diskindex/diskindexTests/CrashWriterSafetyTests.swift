//
//  CrashWriterSafetyTests.swift
//  diskindexTests
//
//  bug.0.4.041 (REPORT 76, 128): Absturzschreiber signalsicher, Ringzeilen UTF-8-sicher.
//  Kein echtes Signal, kein raise/kill: die Handler-Körper werden direkt aufgerufen (Regel 19, 20).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) struct CrashWriterSafetyTests {
    private static let crashSignals: [(Int32, String)] = [
        (SIGABRT, "SIGABRT"), (SIGILL, "SIGILL"), (SIGTRAP, "SIGTRAP"), (SIGSEGV, "SIGSEGV"), (SIGBUS, "SIGBUS"),
    ]

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func crashFile(_ directory: URL) -> URL {
        directory.appendingPathComponent("crash-last.txt")
    }

    private func fileSize(_ url: URL) throws -> Int {
        let number = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)
        return number.intValue
    }

    @Test func startOpensTheCrashFileOutsideTheHandler() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        #expect(log.crashFDForTesting >= 0)
        #expect(log.logFDForTesting >= 0)
        #expect(try fileSize(crashFile(directory)) == 64 * 1024)
    }

    @Test func acknowledgeReopensAFreshCrashFile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("app info start\n".utf8).write(to: directory.appendingPathComponent("diskindex.log"))
        try Data("CRASH signal=SIGSEGV\nframe\n".utf8).write(to: crashFile(directory))
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        #expect(log.shouldShowCrashDialog)
        log.acknowledgeCrashDialog()
        #expect(FileManager.default.fileExists(atPath: crashFile(directory).path))
        #expect(try fileSize(crashFile(directory)) == 64 * 1024)
        #expect(log.crashFDForTesting >= 0)
        let handled = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("crash-handled", isDirectory: true),
            includingPropertiesForKeys: nil
        )
        let moved = try #require(handled.first)
        let movedText = try String(contentsOf: moved, encoding: .utf8)
        #expect(movedText.contains("CRASH signal=SIGSEGV"))
        // Der nächste Absturz landet in der frischen Datei, nicht in der verschobenen.
        log.writeCrashSnapshot(signal: SIGBUS)
        let fresh = try String(contentsOf: crashFile(directory), encoding: .utf8)
        #expect(fresh.hasPrefix("CRASH signal=SIGBUS\n"))
        #expect(try String(contentsOf: moved, encoding: .utf8) == movedText)
    }

    @Test func snapshotWritesThePreparedHeaderForEverySignal() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        log.ui("aktion-vor-absturz")
        for (number, name) in Self.crashSignals {
            log.writeCrashSnapshot(signal: number)
            let text = try String(contentsOf: crashFile(directory), encoding: .utf8)
            #expect(text.hasPrefix("CRASH signal=\(name)\n"), "\(name)")
            #expect(text.contains("aktion-vor-absturz"), "\(name)")
        }
        log.writeCrashSnapshot(signal: SIGUSR1)
        let unknown = try String(contentsOf: crashFile(directory), encoding: .utf8)
        #expect(unknown.hasPrefix("CRASH signal=unknown\n"))
        #expect(log.crashExcerpt().signal == "unknown")
    }

    @Test func writeRingNeverOpensTheFileItself() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DiskIndexLog(directory: directory)
        log.ui("ohne-start")
        log.writeCrashSnapshot(signal: SIGSEGV)
        #expect(log.crashFDForTesting < 0)
        #expect(!FileManager.default.fileExists(atPath: crashFile(directory).path))
    }

    @Test func umlautActionKeepsTheCrashFileValid() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        // 300 Bytes Umlaute, einmal mit gerader, einmal mit ungerader ASCII-Vorlänge:
        // eine der beiden Zeilen wird am Platzende mitten in einem „ä“ gekürzt.
        let umlauts = String(repeating: "ä", count: 150)
        log.ui(umlauts)
        log.ui("x" + umlauts)
        log.writeCrashSnapshot(signal: SIGSEGV)
        log.flushPendingWritesForTesting()
        let strict = try #require(String(data: Data(contentsOf: crashFile(directory)), encoding: .utf8))
        #expect(strict.hasPrefix("CRASH signal=SIGSEGV\n"))
        #expect(strict.contains("ääää"))
        let next = DiskIndexLog(directory: directory)
        next.start(installHandlers: false)
        #expect(next.shouldShowCrashDialog)
    }

    @Test func utf8PrefixEndsOnACharacterBoundary() throws {
        let samples = ["ä", "€", "🙂", "a"]
        for sample in samples {
            let bytes = Array(String(repeating: sample, count: 120).utf8)
            for limit in 0...12 {
                let cut = Array(DiskIndexLog.utf8Prefix(bytes, limit: limit))
                #expect(cut.count <= limit)
                #expect(String(bytes: cut, encoding: .utf8) != nil, "\(sample) limit=\(limit)")
                #expect(limit - cut.count < sample.utf8.count, "\(sample) limit=\(limit)")
            }
        }
        #expect(DiskIndexLog.utf8Prefix(Array("abc".utf8), limit: 239).count == 3)
    }

    @Test func brokenUTF8InTheCrashFileIsStillRecognized() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("app info start\n".utf8).write(to: directory.appendingPathComponent("diskindex.log"))
        var bytes = Array("CRASH signal=SIGSEGV\nui info ".utf8)
        bytes.append(contentsOf: [0xC3, 0x0A])
        bytes.append(contentsOf: Array("frame\n".utf8))
        try Data(bytes).write(to: crashFile(directory))
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        #expect(log.shouldShowCrashDialog)
        let excerpt = log.crashExcerpt()
        #expect(excerpt.signal == "SIGSEGV")
        #expect(excerpt.stack.contains("frame"))
    }

    @Test func freshCrashFileAddsNoCrashSectionToTheReport() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        log.flushPendingWritesForTesting()
        let report = log.report(includeCrash: true, logLineLimit: 50, actionLimit: 50)
        #expect(!report.contains("\u{0}"))
        #expect(!report.contains("CRASH signal="))
    }

    @Test func crashPathRecognizesTheWriteQueue() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = DiskIndexLog(directory: directory)
        #expect(log.isOnDiskWriteQueueForTesting(runOnQueue: true))
        #expect(!log.isOnDiskWriteQueueForTesting(runOnQueue: false))
    }
}

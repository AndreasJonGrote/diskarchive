//
//  AppDefaultsCleanupTests.swift
//  diskindexTests
//
//  Aufgabe 208 — Testläufe hinterlassen keine Einstellungsdateien fremder, beendeter Prozesse.
//

import Foundation
import Testing
@testable import diskindex

struct AppDefaultsCleanupTests {
    @Test func staleTestDomainsAreRemovedOwnAndRunningStay() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-prefs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let own = ProcessInfo.processInfo.processIdentifier
        func make(_ name: String) throws -> URL {
            let url = directory.appendingPathComponent("\(name).plist")
            try Data("x".utf8).write(to: url)
            return url
        }
        let dead = try make("\(AppDefaults.testDomainPrefix)99999999")
        let ownFile = try make("\(AppDefaults.testDomainPrefix)\(own)")
        let running = try make("\(AppDefaults.testDomainPrefix)1")
        let foreign = try make("app.diskarchive")
        let other = try make("\(AppDefaults.testDomainPrefix)abc")

        AppDefaults.removeStaleTestDomains(in: directory, ownPID: own)

        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: dead.path))
        #expect(fm.fileExists(atPath: ownFile.path))
        #expect(fm.fileExists(atPath: running.path))
        #expect(fm.fileExists(atPath: foreign.path))
        #expect(fm.fileExists(atPath: other.path))
    }

    /// bug.0.4.124: Suiten der Testhelfer (`<Präfix><pid>.<Name>`) und alte Namen ohne Prozesskennung werden aufgeräumt.
    @Test func helperSuitesAndLegacyNamesAreRemoved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-prefs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let own = ProcessInfo.processInfo.processIdentifier
        func make(_ name: String) throws -> URL {
            let url = directory.appendingPathComponent("\(name).plist")
            try Data("x".utf8).write(to: url)
            return url
        }
        let deadHelper = try make("\(AppDefaults.testDomainPrefix)99999999.lang-\(UUID().uuidString)")
        let ownHelper = try make("\(AppDefaults.testDomainPrefix)\(own).lang-\(UUID().uuidString)")
        let legacy = try AppDefaults.legacyTestPrefixes.map { try make("\($0)\(UUID().uuidString)") }
        let foreign = try make("com.apple.finder")
        // bug.0.4.162 (c): genaue Präfixe – eine fremde Domäne, die nur mit „autosend“ beginnt, bleibt; die alten
        // Testordner der Fehlerbericht- und Start-Tests werden geräumt.
        let lookalike = try make("autosendings.example")
        let realLog = try make("diskindex-real-log-\(UUID().uuidString)")
        let archiveStart = try make("diskindex-archive-start-\(UUID().uuidString)")
        AppDefaults.removeStaleTestDomains(in: directory, ownPID: own)
        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: deadHelper.path))
        #expect(fm.fileExists(atPath: ownHelper.path))
        #expect(legacy.allSatisfy { !fm.fileExists(atPath: $0.path) })
        #expect(fm.fileExists(atPath: foreign.path))
        #expect(fm.fileExists(atPath: lookalike.path), "zu allgemeines Präfix „autosend“")
        #expect(!fm.fileExists(atPath: realLog.path) && !fm.fileExists(atPath: archiveStart.path))
        // Der Helfer benennt seine Suiten nach dem Schema, das das Aufräumen versteht.
        #expect(TestDefaults.suiteName("x").hasPrefix("\(AppDefaults.testDomainPrefix)\(own)."))
    }

    @Test func runCheckKnowsOwnAndDeadProcesses() {
        #expect(AppDefaults.processIsRunning(ProcessInfo.processInfo.processIdentifier))
        #expect(!AppDefaults.processIsRunning(99_999_999))
    }
}

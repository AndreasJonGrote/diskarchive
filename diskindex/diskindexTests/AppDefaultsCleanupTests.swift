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

    @Test func runCheckKnowsOwnAndDeadProcesses() {
        #expect(AppDefaults.processIsRunning(ProcessInfo.processInfo.processIdentifier))
        #expect(!AppDefaults.processIsRunning(99_999_999))
    }
}

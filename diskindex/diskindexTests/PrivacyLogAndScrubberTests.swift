//
//  PrivacyLogAndScrubberTests.swift
//  diskindexTests
//
//  bug.0.4.011 / bug.0.4.012 — Protokoll ohne Namen, Scrubber, Leak-Wächter.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) struct PrivacyLogAndScrubberTests {
    @Test func scrubberRemovesPathsNamesAndQueries() {
        let samples = [
            "/Volumes/Jon's Passport/Clients/Acme Corp",
            #"/Volumes/A/My "Best" Photos"#,
            "/Volumes/A/‹Kunde Acme›/x",
            "file:///Volumes/O'Brien/x",
            "Die Datei „Präsentation.key“ konnte nicht gelesen werden.",
        ]
        for sample in samples {
            let scrubbed = ReportScrubber.text(sample)
            for leak in ["Passport", "Acme", "Photos", "O'Brien", "Präsentation", "Kunde"] {
                #expect(!scrubbed.contains(leak), "leak=\(leak) in \(scrubbed)")
            }
        }
    }

    @Test func scrubberKeepsTechnicalGermanLogLine() {
        let line = "2026-10-13T20:01:02Z medium info candidate=ja eingehängt id=1234 stärke=uuid"
        let scrubbed = ReportScrubber.text(line)
        #expect(scrubbed.contains("2026-10-13T20:01:02Z"))
        #expect(scrubbed.contains("id=1234"))
        #expect(scrubbed.contains("stärke=uuid"))
        #expect(scrubbed.contains("eingehängt"))
    }

    @Test func logFileOmitsPrivateDetailPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-log-privacy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let log = DiskIndexLog(directory: directory)
        log.record(.watcher, .error, "nicht lesbar \(DiskIndexLog.errorSummary(CocoaError(.fileReadNoPermission)))", privateDetail: "/Volumes/X/geheim")
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        #expect(!text.contains("geheim"))
        #expect(!text.contains("/Volumes/X"))
        #expect(text.contains("pathDepth="))
        #expect(text.contains("pathLen="))
        #expect(text.contains("domain="))
    }

    @Test func searchQueryUiDoesNotWriteQueryText() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-log-query-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let log = DiskIndexLog(directory: directory)
        log.ui("search query=geheimnis")
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        #expect(!text.contains("geheimnis"))
        #expect(text.contains("search query chars="))
    }

    @Test func extProfileHasNoAngleBracketsForOdd() {
        let scrubbed = ReportScrubber.text(#""datei.tar.gz""#)
        #expect(scrubbed.contains("ext="))
        #expect(!scrubbed.contains("ext=‹odd›"))
    }

    /// Sabotage: alter Pfad-Regex ohne file:// → file-URL bleibt ungescrubbt → rot.
    @Test func sabotageOldPathRegexLeavesFileURL() {
        defer { ReportScrubber.pathPatternForTesting = nil }
        ReportScrubber.pathPatternForTesting = #"(?:/Volumes|/Users|~)[^\n\"']*"#
        let scrubbed = ReportScrubber.text("file:///Volumes/O'Brien/x")
        #expect(scrubbed.contains("O'Brien") || scrubbed.contains("file://"), "Sabotage muss rot zeigen")
    }

    @Test func archiveMediumNameDoesNotBlockDiskArchiveBacktrace() {
        let json = #"{"crash":{"stack":["0 Disk Archive 0x1000 main"]}}"#
        #expect(ReportScrubber.leakCategory(in: json, names: ["Archive", "Disk Archive"]) == nil)
    }
}

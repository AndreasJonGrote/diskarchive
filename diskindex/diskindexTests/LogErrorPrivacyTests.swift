//
//  LogErrorPrivacyTests.swift
//  diskindexTests
//
//  bug.0.4.112: Fehler gehen nur als technische Kurzform ins Protokoll (`errorSummary`), nie mit Pfad und Benutzername.
//

import Foundation
import Testing
@testable import diskindex

struct LogErrorPrivacyTests {
    @Test func summaryOfAFileErrorHasNoPathOrUserName() {
        let error = CocoaError(.fileReadNoSuchFile, userInfo: [
            NSFilePathErrorKey: "/Users/tester/x",
            NSURLErrorKey: URL(fileURLWithPath: "/Users/tester/x"),
            NSLocalizedDescriptionKey: "Datei /Users/tester/x fehlt",
        ])
        let summary = DiskIndexLog.errorSummary(error)
        #expect(!summary.contains("/Users/"))
        #expect(!summary.contains("tester"))
        #expect(summary.contains("code="))
    }

    /// Kein Protokollaufruf der App druckt einen Fehler roh (`\(error)`): Datei- und Datenbankfehler tragen Pfade.
    @Test func noLogCallInterpolatesARawError() throws {
        let appDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("diskindex", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil))
        var hits: [String] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in source.components(separatedBy: "\n").enumerated()
            where line.contains("DiskIndexLog.shared.record(") && line.contains("\\(error)") {
                hits.append("\(file.lastPathComponent):\(index + 1)")
            }
        }
        #expect(hits.isEmpty, "Fehler roh im Protokoll: \(hits.joined(separator: ", "))")
    }
}

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

    /// Kein Protokollaufruf der App druckt einen Fehler roh (`\(error)`, `localizedDescription`): Datei- und
    /// Datenbankfehler tragen Pfade. bug.0.4.158: alle Protokollwege (`record(`, `log(`, `Logger`/`logger.…(`, `ui(`,
    /// `print(`, `NSLog(`), nur die Kurzform `DiskIndexLog.errorSummary(error)` ist erlaubt.
    @Test func noLogCallInterpolatesARawError() throws {
        let appDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("diskindex", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil))
        var hits: [String] = []
        var scanned = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in source.components(separatedBy: "\n").enumerated() where Self.isLogCall(line) {
                scanned += 1
                if Self.interpolatesRawError(line) { hits.append("\(file.lastPathComponent):\(index + 1)") }
            }
        }
        #expect(scanned > 50, "Wächter fand kaum Protokollaufrufe (\(scanned)) – Muster prüfen")
        #expect(hits.isEmpty, "Fehler roh im Protokoll: \(hits.joined(separator: ", "))")
    }

    /// Die Muster selbst: jede Form wird erkannt, die Kurzform nicht.
    @Test func guardPatternsCatchEveryForm() {
        let raw = [
            #"DiskIndexLog.shared.record(.app, .error, "x \(error)")"#,
            #"log("app report failed error=\(error.localizedDescription)")"#,
            #"recognitionLogger.error("x: \(error.localizedDescription, privacy: .public)")"#,
            #"logger.error("x: \(error, privacy: .public)")"#,
        ]
        for line in raw {
            #expect(Self.isLogCall(line) && Self.interpolatesRawError(line), "nicht erkannt: \(line)")
        }
        let clean = #"logger.error("x: \(DiskIndexLog.errorSummary(error), privacy: .public)")"#
        #expect(Self.isLogCall(clean) && !Self.interpolatesRawError(clean))
    }

    static func isLogCall(_ line: String) -> Bool {
        ["record(", "log(", "ogger.", ".ui(", "print(", "NSLog("].contains { line.contains($0) }
    }

    static func interpolatesRawError(_ line: String) -> Bool {
        line.contains("\\(error)") || line.contains("\\(error,") || line.contains("error.localizedDescription")
            || line.contains("\\(error.")
    }
}

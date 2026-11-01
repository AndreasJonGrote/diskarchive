//
//  LogErrorPrivacyTests.swift
//  DiskArchiveTests
//
//  bug.0.4.112: Fehler gehen nur als technische Kurzform ins Protokoll (`errorSummary`), nie mit Pfad und Benutzername.
//

import Foundation
import Testing
@testable import DiskArchive

struct LogErrorPrivacyTests {
    @Test func summaryOfAFileErrorHasNoPathOrUserName() {
        let error = CocoaError(.fileReadNoSuchFile, userInfo: [
            NSFilePathErrorKey: "/Users/tester/x",
            NSURLErrorKey: URL(fileURLWithPath: "/Users/tester/x"),
            NSLocalizedDescriptionKey: "Datei /Users/tester/x fehlt",
        ])
        let summary = DiskArchiveLog.errorSummary(error)
        #expect(!summary.contains("/Users/"))
        #expect(!summary.contains("tester"))
        #expect(summary.contains("code="))
    }

    /// Kein Protokollaufruf der App druckt einen Fehler roh (`\(error)`, `localizedDescription`): Datei- und
    /// Datenbankfehler tragen Pfade. bug.0.4.158: alle Protokollwege (`record(`, `log(`, `Logger`/`logger.…(`, `ui(`,
    /// `print(`, `NSLog(`), nur die Kurzform `DiskArchiveLog.errorSummary(error)` ist erlaubt.
    @Test func noLogCallInterpolatesARawError() throws {
        let appDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DiskArchive", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil))
        var hits: [String] = []
        var scanned = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (index, call) in Self.logCalls(in: source) {
                scanned += 1
                if Self.interpolatesRawError(call) { hits.append("\(file.lastPathComponent):\(index + 1)") }
            }
        }
        #expect(scanned > 50, "Wächter fand kaum Protokollaufrufe (\(scanned)) – Muster prüfen")
        #expect(hits.isEmpty, "Fehler roh im Protokoll: \(hits.joined(separator: ", "))")
    }

    /// Die Muster selbst: jede Form wird erkannt, die Kurzform nicht.
    @Test func guardPatternsCatchEveryForm() {
        let raw = [
            #"DiskArchiveLog.shared.record(.app, .error, "x \(error)")"#,
            #"log("app report failed error=\(error.localizedDescription)")"#,
            #"recognitionLogger.error("x: \(error.localizedDescription, privacy: .public)")"#,
            #"logger.error("x: \(error, privacy: .public)")"#,
            #"log("x \(err)")"#,
            #"DiskArchiveLog.shared.record(.app, .error, "x \(e.localizedDescription)")"#,
        ]
        for line in raw {
            #expect(Self.isLogCall(line) && Self.interpolatesRawError(line), "nicht erkannt: \(line)")
        }
        let clean = #"logger.error("x: \(DiskArchiveLog.errorSummary(error), privacy: .public)")"#
        #expect(Self.isLogCall(clean) && !Self.interpolatesRawError(clean))
        // Nur die Fehlernamen selbst, nicht Namen, die auf „e“ enden.
        let lookalike = #"log("x \(type.localizedDescription) \(name.localizedDescription)")"#
        #expect(!Self.interpolatesRawError(lookalike), "falsch erkannt: \(lookalike)")
    }

    /// bug.0.4.167 (d): mehrzeilige Aufrufe – vom Beginn des Protokollaufrufs bis zur schließenden Klammer zusammen.
    static func logCalls(in source: String) -> [(Int, String)] {
        let lines = source.components(separatedBy: "\n")
        var calls: [(Int, String)] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard isLogCall(line) else {
                index += 1
                continue
            }
            var text = line
            var depth = Self.parenBalance(line)
            var next = index + 1
            while depth > 0, next < lines.count, next - index < 12 {
                let more = lines[next]
                text += " " + more
                depth += Self.parenBalance(more)
                next += 1
            }
            calls.append((index, text))
            index += 1
        }
        return calls
    }

    /// bug.0.4.172 (c): Klammern einer Zeile ohne die in Zeichenketten; die Klammern einer Interpolation `\(…)` gleichen
    /// sich aus. (Zeichenketten über mehrere Zeilen und Zeichenketten in Interpolationen werden nicht gesondert erkannt.)
    static func parenBalance(_ line: String) -> Int {
        var balance = 0
        var inString = false
        var escaped = false
        var interpolation = 0
        for character in line {
            if inString, interpolation == 0 {
                if escaped {
                    escaped = false
                    if character == "(" { interpolation = 1 }
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }
            switch character {
            case "\"" where interpolation == 0: inString = true
            case "(": if interpolation > 0 { interpolation += 1 } else { balance += 1 }
            case ")": if interpolation > 0 { interpolation -= 1 } else { balance -= 1 }
            default: break
            }
        }
        return balance
    }

    /// bug.0.4.172 (c): Eine Klammer im Text zählt nicht – sonst hinge der Wächter die nächste (fremde) Zeile an.
    @Test func parenthesesInStringsAreNotCounted() {
        let source = """
            DiskArchiveLog.shared.record(.app, .info, "liste (gekürzt")
            let probe = "\\(error)"
            """
        let calls = Self.logCalls(in: source)
        #expect(calls.count == 1)
        #expect(!calls.contains { Self.interpolatesRawError($0.1) }, "fremde Zeile angehängt: \(calls)")
        #expect(Self.parenBalance(#"log("a \(b(c)) (")"#) == 0)
        #expect(Self.parenBalance(#"record(.app, "x \(error)""#) == 1)
    }

    @Test func multiLineCallsAreJoined() {
        let source = """
            DiskArchiveLog.shared.record(
                .app, .error,
                "x \\(error)"
            )
            """
        let calls = Self.logCalls(in: source)
        #expect(calls.contains { Self.interpolatesRawError($0.1) }, "\(calls)")
    }

    static func isLogCall(_ line: String) -> Bool {
        ["record(", "log(", "ogger.", ".ui(", "print(", "NSLog("].contains { line.contains($0) }
    }

    /// `\(error)`, `\(err, …)`, `\(e.…)` und `….localizedDescription` dieser Namen.
    static func interpolatesRawError(_ line: String) -> Bool {
        for name in ["error", "err", "e"] {
            if line.contains("\\(\(name))") || line.contains("\\(\(name),") || line.contains("\\(\(name).")
                || line.range(of: #"(?<![A-Za-z0-9_])"# + name + #"\.localizedDescription"#, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}

//
//  PreviousRunReportTests.swift
//  diskindexTests
//
//  bug.0.4.113 (Host-Entscheidung): Der Absturzbericht beschreibt den abgestürzten Lauf – Version, Build und Laufzeit
//  stammen aus dessen Startzeile im Protokoll, nie vom neuen Lauf; fehlen sie, bleibt das Feld leer.
//

import Darwin
import Foundation
import Testing
@testable import diskindex

struct PreviousRunReportTests {
    /// Erster Lauf über das echte Protokoll: Startzeile, Aktionen, Absturz über den Weg des Signal-Handlers
    /// (`writeCrashSnapshot` → nur `crash-last.txt`, keine „CRASH“-Zeile im Protokoll). Die Startzeile bekommt danach
    /// eine ältere Version (wie nach einem Update), damit sie sich von der des neuen Laufs unterscheidet.
    private func crashedRun(in directory: URL, keepLog: Bool = true) throws {
        let first = DiskIndexLog(directory: directory)
        first.start(installHandlers: false)
        first.ui("click row=7")
        first.ui("search query chars=20")
        first.flushPendingWritesForTesting()
        first.writeCrashSnapshot(signal: SIGSEGV)
        let url = directory.appendingPathComponent(DiskIndexLog.fileName)
        if keepLog {
            let text = try String(contentsOf: url, encoding: .utf8)
            let range = try #require(text.range(of: #" start version=\S+ build=\S+"#, options: .regularExpression))
            try text.replacingCharacters(in: range, with: " start version=0.3.1 build=40").write(to: url, atomically: true, encoding: .utf8)
        } else {
            try FileManager.default.removeItem(at: url)
        }
        #expect(!(try String(contentsOf: directory.appendingPathComponent("crash-last.txt"), encoding: .utf8)).isEmpty)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-prevrun-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// bug.0.4.113 (Nacharbeit): Signal-Absturz – Protokoll ohne „CRASH“-Zeile, die Startzeile des neuen Laufs ist
    /// schon geschrieben → Version, Build, Laufzeit und Aktionen kommen aus dem abgestürzten Lauf.
    @Test func signalCrashReportsTheCrashedRun() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try crashedRun(in: directory)
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        log.ui("crash dialog send")
        log.flushPendingWritesForTesting()
        let protocolText = try String(contentsOf: directory.appendingPathComponent(DiskIndexLog.fileName), encoding: .utf8)
        try #require(!protocolText.contains("CRASH signal="), "Voraussetzung: keine CRASH-Zeile im Protokoll")
        let info = log.previousRunInfo()
        #expect(info.version == "0.3.1")
        #expect(info.build == "40")
        #expect(info.runtimeSeconds != nil)
        let actions = log.crashBreadcrumbs()
        #expect(actions.contains { $0.hasSuffix("ui info click row=7") }, "Aktionen: \(actions)")
        #expect(actions.contains { $0.hasSuffix("ui info search query chars=20") })
        #expect(!actions.contains { $0.contains("crash dialog send") }, "Aktion des neuen Laufs im Bericht")
    }

    /// Fehlt die Startzeile des abgestürzten Laufs (Protokoll weg), bleiben die Felder leer – nie die des neuen Laufs.
    @Test func missingStartLineLeavesFieldsEmpty() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try crashedRun(in: directory, keepLog: false)
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        log.flushPendingWritesForTesting()
        let info = log.previousRunInfo()
        #expect(info == PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil))
        #expect(!log.crashBreadcrumbs().isEmpty, "Aktionen stehen in der Absturzdatei")
    }

    @Test func payloadUsesThePreviousRunInsteadOfTheBundle() throws {
        var draft = IssueDraft(
            kind: "crash", signature: "SIGSEGV", actions: [], logTail: [], crashSignal: "SIGSEGV", crashStack: [],
            media: 0, items: 0, dbBytes: 0
        )
        draft.previousRun = PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil)
        let data = IssuePayload.json(
            draft: draft, id: "A", version: draft.previousRun.map { $0.version ?? "" } ?? "neu",
            build: draft.previousRun.map { $0.build ?? "" } ?? "neu", config: "Debug", macOS: "x", model: "m",
            runtimeSeconds: draft.previousRun?.runtimeSeconds, createdAt: Date(timeIntervalSince1970: 0)
        )
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let app = try #require(object["app"] as? [String: Any])
        #expect(app["version"] as? String == "")
        #expect(app["build"] as? String == "")
        #expect(object["runtimeSeconds"] is NSNull)
    }
}

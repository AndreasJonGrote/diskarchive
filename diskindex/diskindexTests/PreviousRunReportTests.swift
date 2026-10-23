//
//  PreviousRunReportTests.swift
//  diskindexTests
//
//  bug.0.4.113 (Host-Entscheidung): Der Absturzbericht beschreibt den abgestürzten Lauf – Version, Build und Laufzeit
//  stammen aus dessen Startzeile im Protokoll, nie vom neuen Lauf; fehlen sie, bleibt das Feld leer.
//

import Foundation
import Testing
@testable import diskindex

struct PreviousRunReportTests {
    private func makeLog(_ text: String) throws -> (DiskIndexLog, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-prevrun-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: directory.appendingPathComponent(DiskIndexLog.fileName), atomically: true, encoding: .utf8)
        return (DiskIndexLog(directory: directory), directory)
    }

    @Test func readsVersionBuildAndRuntimeOfTheCrashedRun() throws {
        let text = """
        2026-10-01 09:00:00.000 app info start version=0.3.1 build=40 config=Release macOS=Version pid=11
        2026-10-01 10:00:00.000 app info start version=0.3.9 build=57 config=Release macOS=Version pid=12
        2026-10-01 10:02:30.500 index info lauf
        CRASH signal=SIGSEGV
        0 x 0x1 main
        """
        let (log, directory) = try makeLog(text)
        defer { try? FileManager.default.removeItem(at: directory) }
        let info = log.previousRunInfo()
        #expect(info.version == "0.3.9")
        #expect(info.build == "57")
        #expect(info.runtimeSeconds == 150)
    }

    @Test func missingStartLineLeavesFieldsEmpty() throws {
        let (log, directory) = try makeLog("CRASH signal=SIGSEGV\n0 x 0x1 main\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        let info = log.previousRunInfo()
        #expect(info == PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil))
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

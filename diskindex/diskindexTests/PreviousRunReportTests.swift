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

    // MARK: - bug.0.4.164: mehrere Läufe über die echten Wege

    /// Ersetzt Version und Build der `index`-ten Startzeile (wie ein älterer Lauf vor einem Update).
    private func setStartVersion(_ directory: URL, index: Int, version: String, build: String) throws {
        let url = directory.appendingPathComponent(DiskIndexLog.fileName)
        var lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
        let starts = lines.indices.filter { lines[$0].contains(" start version=") }
        try #require(starts.count > index, "Startzeile \(index) fehlt")
        let at = starts[index]
        let line = lines[at]
        let range = try #require(line.range(of: #" start version=\S+ build=\S+"#, options: .regularExpression))
        lines[at] = line.replacingCharacters(in: range, with: " start version=\(version) build=\(build)")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// (a) Absturz A ohne Signal (CRASH-Zeile im Protokoll), ein sauberer Lauf, dann Signal-Absturz B → der Bericht nach B
    /// trägt B, nicht A.
    @Test @MainActor func oldCrashLineDoesNotHideTheNewSignalCrash() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runA = DiskIndexLog(directory: directory)
        runA.start(installHandlers: false)
        runA.recordCrash(signal: "exception NSRangeException", symbols: ["0 diskindex 0x0000000100000000 main + 1"])
        runA.flushPendingWritesForTesting()
        try setStartVersion(directory, index: 0, version: "0.3.0", build: "30")
        let clean = DiskIndexLog(directory: directory)
        clean.start(installHandlers: false)
        await AppStartup.finishTermination(appState: AppState(), log: clean)
        clean.flushPendingWritesForTesting()
        let runB = DiskIndexLog(directory: directory)
        runB.start(installHandlers: false)
        runB.ui("click row=7")
        runB.flushPendingWritesForTesting()
        runB.writeCrashSnapshot(signal: SIGSEGV)
        try setStartVersion(directory, index: 2, version: "0.3.1", build: "31")
        let now = DiskIndexLog(directory: directory)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        let info = now.previousRunInfo()
        #expect(info.version == "0.3.1", "Version eines älteren Absturzes: \(String(describing: info.version))")
        #expect(info.build == "31")
    }

    /// (b) Ohne Absturzdatei kommt der Absturzteil aus dem Protokoll – er endet an der nächsten Startzeile, Zeilen des
    /// neuen Laufs gehören nicht dazu.
    @Test func crashSectionFromTheLogEndsAtTheNextStart() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let crashed = DiskIndexLog(directory: directory)
        crashed.start(installHandlers: false)
        crashed.ui("click row=7")
        crashed.recordCrash(signal: "exception NSRangeException", symbols: ["0 diskindex 0x0000000100000000 main + 1"])
        crashed.flushPendingWritesForTesting()
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        log.ui("crash dialog send")
        log.flushPendingWritesForTesting()
        let excerpt = log.crashExcerpt()
        #expect(excerpt.signal == "exception")
        #expect(!excerpt.stack.contains { $0.contains("crash dialog send") || $0.contains(" start version=") }, "\(excerpt.stack)")
        #expect(!log.crashBreadcrumbs().contains { $0.contains("crash dialog send") })
    }

    /// (c) Die Startzeile des abgestürzten Laufs fehlt (Protokoll gekürzt), davor liegt ein sauber beendeter Lauf → Felder
    /// leer statt der Werte des älteren Laufs.
    @Test @MainActor func missingCrashedStartDoesNotPickAnOlderRun() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let older = DiskIndexLog(directory: directory)
        older.start(installHandlers: false)
        await AppStartup.finishTermination(appState: AppState(), log: older)
        older.flushPendingWritesForTesting()
        let crashed = DiskIndexLog(directory: directory)
        crashed.start(installHandlers: false)
        crashed.ui("click row=7")
        crashed.flushPendingWritesForTesting()
        crashed.writeCrashSnapshot(signal: SIGSEGV)
        // Startzeile des abgestürzten Laufs entfernen (gekürztes Protokoll).
        let url = directory.appendingPathComponent(DiskIndexLog.fileName)
        var lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
        let starts = lines.indices.filter { lines[$0].contains(" start version=") }
        let crashedStart = try #require(starts.last)
        lines.remove(at: crashedStart)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        let now = DiskIndexLog(directory: directory)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        #expect(now.previousRunInfo() == PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil))
    }
}

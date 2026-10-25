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
    /// bug.0.4.196: Stempel ohne echte Uhr – Zeitzone `Europe/Berlin`, feste Zeiten (Umstellung CEST → CET am 25.10.2026
    /// um 03:00 Ortszeit = 01:00 UTC; 00:30 und 01:30 UTC sind beide „02:30“ Ortszeit).
    private static let berlin = TimeZone(identifier: "Europe/Berlin") ?? .current

    private static func utc(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text), "Zeit \(text)")
    }

    /// Uhr je Protokoll-Instanz (Parameter `now`), vom Test vorgestellt.
    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Date
        init(_ date: Date) { current = date }
        var date: Date {
            get { lock.withLock { current } }
            set { lock.withLock { current = newValue } }
        }
        var now: @Sendable () -> Date { { [self] in date } }
    }

    private func log(_ directory: URL, _ clock: TestClock) -> DiskIndexLog {
        DiskIndexLog(directory: directory, timeZone: Self.berlin, now: clock.now)
    }

    /// Absturzdatei mit der Zeit des Absturzes (der Signal-Handler schreibt sie; ihre Änderungszeit ist die Absturzzeit).
    private func setCrashFileDate(_ directory: URL, _ date: Date) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: date], ofItemAtPath: directory.appendingPathComponent("crash-last.txt").path
        )
    }

    /// Erster Lauf über das echte Protokoll: Startzeile, Aktionen, Absturz über den Weg des Signal-Handlers
    /// (`writeCrashSnapshot` → nur `crash-last.txt`, keine „CRASH“-Zeile im Protokoll). Die Startzeile bekommt danach
    /// eine ältere Version (wie nach einem Update), damit sie sich von der des neuen Laufs unterscheidet.
    /// bug.0.4.196: Start zur Zeit der Uhr, Aktionen 60 s später, Absturz `crashAfter` nach dem Start.
    private func crashedRun(in directory: URL, keepLog: Bool = true, clock: TestClock, crashAfter: TimeInterval = 300) throws {
        let began = clock.date
        let first = log(directory, clock)
        first.start(installHandlers: false)
        clock.date = began.addingTimeInterval(60)
        first.ui("click row=7")
        first.ui("search query chars=20")
        first.flushPendingWritesForTesting()
        clock.date = began.addingTimeInterval(crashAfter)
        first.writeCrashSnapshot(signal: SIGSEGV)
        try setCrashFileDate(directory, clock.date)
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
    /// bug.0.4.196: feste Zeiten in der doppelten Stunde (Absturz 02:35 Sommerzeit, neuer Lauf 02:30 Winterzeit).
    @Test func signalCrashReportsTheCrashedRun() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(try Self.utc("2026-10-25T00:30:00Z"))
        try crashedRun(in: directory, clock: clock)
        clock.date = try Self.utc("2026-10-25T01:30:00Z")
        let log = log(directory, clock)
        log.start(installHandlers: false)
        log.ui("crash dialog send")
        log.flushPendingWritesForTesting()
        let protocolText = try String(contentsOf: directory.appendingPathComponent(DiskIndexLog.fileName), encoding: .utf8)
        try #require(!protocolText.contains("CRASH signal="), "Voraussetzung: keine CRASH-Zeile im Protokoll")
        let info = log.previousRunInfo()
        #expect(info.version == "0.3.1")
        #expect(info.build == "40")
        #expect(info.runtimeSeconds == 60)
        let actions = log.crashBreadcrumbs()
        #expect(actions.contains { $0.hasSuffix("ui info click row=7") }, "Aktionen: \(actions)")
        #expect(actions.contains { $0.hasSuffix("ui info search query chars=20") })
        #expect(!actions.contains { $0.contains("crash dialog send") }, "Aktion des neuen Laufs im Bericht")
    }

    /// Fehlt die Startzeile des abgestürzten Laufs (Protokoll weg), bleiben die Felder leer – nie die des neuen Laufs.
    @Test func missingStartLineLeavesFieldsEmpty() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(try Self.utc("2026-10-25T00:30:00Z"))
        try crashedRun(in: directory, keepLog: false, clock: clock)
        clock.date = try Self.utc("2026-10-25T01:30:00Z")
        let log = log(directory, clock)
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
        // bug.0.4.196: feste Zeiten in der doppelten Stunde (B stürzt 02:35 Sommerzeit ab, neuer Lauf 02:30 Winterzeit).
        let clock = TestClock(try Self.utc("2026-10-25T00:10:00Z"))
        let runA = log(directory, clock)
        runA.start(installHandlers: false)
        runA.recordCrash(signal: "exception NSRangeException", symbols: ["0 diskindex 0x0000000100000000 main + 1"])
        runA.flushPendingWritesForTesting()
        try setStartVersion(directory, index: 0, version: "0.3.0", build: "30")
        clock.date = try Self.utc("2026-10-25T00:20:00Z")
        let clean = log(directory, clock)
        clean.start(installHandlers: false)
        await AppStartup.finishTermination(appState: AppState(), log: clean)
        clean.flushPendingWritesForTesting()
        clock.date = try Self.utc("2026-10-25T00:30:00Z")
        let runB = log(directory, clock)
        runB.start(installHandlers: false)
        clock.date = try Self.utc("2026-10-25T00:31:00Z")
        runB.ui("click row=7")
        runB.flushPendingWritesForTesting()
        clock.date = try Self.utc("2026-10-25T00:35:00Z")
        runB.writeCrashSnapshot(signal: SIGSEGV)
        try setCrashFileDate(directory, clock.date)
        try setStartVersion(directory, index: 2, version: "0.3.1", build: "31")
        clock.date = try Self.utc("2026-10-25T01:30:00Z")
        let now = log(directory, clock)
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

    /// (c) / bug.0.4.170: Vom abgestürzten Lauf B fehlt im Protokoll alles ab der Startzeile (Schreiben verloren); davor
    /// liegt Lauf A **ohne** „app terminate ok“. Die Absturzdatei entstand lange nach der letzten Zeile von A → sie gehört
    /// nicht zu A, die Felder bleiben leer (nicht Version und Laufzeit von A).
    @Test @MainActor func missingCrashedStartDoesNotPickAnOlderRun() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let older = DiskIndexLog(directory: directory)
        older.start(installHandlers: false)
        older.ui("click row=3")
        older.flushPendingWritesForTesting()
        let url = directory.appendingPathComponent(DiskIndexLog.fileName)
        let crashed = DiskIndexLog(directory: directory)
        crashed.start(installHandlers: false)
        crashed.ui("click row=7")
        crashed.flushPendingWritesForTesting()
        crashed.writeCrashSnapshot(signal: SIGSEGV)
        // Alles von B im Protokoll entfernen (ab seiner Startzeile).
        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
        let starts = lines.indices.filter { lines[$0].contains(" start version=") }
        try #require(starts.count == 2, "Startzeilen: \(starts.count)")
        let crashedStart = try #require(starts.last)
        try (lines[..<crashedStart].joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        // Der Absturz kam lange nach der letzten Zeile von A (B lief einen Tag; Grenze `crashAfterLastLineLimit`).
        let crashFile = directory.appendingPathComponent("crash-last.txt")
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(DiskIndexLog.crashAfterLastLineLimit + 18 * 3600)], ofItemAtPath: crashFile.path
        )
        let now = DiskIndexLog(directory: directory)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        #expect(now.previousRunInfo() == PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil))
    }

    /// bug.0.4.170: Ohne Absturzdatei zählt nur eine „CRASH“-Zeile des abgestürzten Laufs. Lauf A stürzte ab (Zeile im
    /// Protokoll) und wurde gemeldet; Lauf B endete ohne sauberes Ende und ohne Absturz → nach B kein Absturzteil von A.
    @Test @MainActor func crashSectionIgnoresACrashLineOfAnEarlierRun() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runA = DiskIndexLog(directory: directory)
        runA.start(installHandlers: false)
        runA.ui("click row=1")
        runA.recordCrash(signal: "exception NSRangeException", symbols: ["0 diskindex 0x0000000100000000 main + 1"])
        runA.acknowledgeCrashDialog()
        runA.flushPendingWritesForTesting()
        let runB = DiskIndexLog(directory: directory)
        runB.start(installHandlers: false)
        runB.ui("click row=9")
        runB.flushPendingWritesForTesting()
        let now = DiskIndexLog(directory: directory)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        let text = try String(contentsOf: directory.appendingPathComponent(DiskIndexLog.fileName), encoding: .utf8)
        try #require(text.contains("CRASH signal=exception"), "Voraussetzung: CRASH-Zeile von A im Protokoll")
        #expect(now.crashExcerpt().signal == "unknown", "Absturz von A im Bericht nach B: \(now.crashExcerpt().signal)")
        #expect(!now.crashBreadcrumbs().contains { $0.contains("click row=1") }, "Aktionen von A im Bericht nach B")
    }

    // MARK: - bug.0.4.196: Zeitumstellung

    /// Start, letzte Zeile und Absturz in der ersten „02:xx“-Stunde (Sommerzeit), der neue Lauf in der zweiten
    /// (Winterzeit) → Version, Build und die richtige Laufzeit (600 s), nicht eine Stunde verschoben.
    @Test func doubleHourStampsReadBackInOrder() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(try Self.utc("2026-10-25T00:30:00Z"))
        let crashed = log(directory, clock)
        crashed.start(installHandlers: false)
        clock.date = try Self.utc("2026-10-25T00:40:00Z")
        crashed.ui("click row=7")
        crashed.flushPendingWritesForTesting()
        clock.date = try Self.utc("2026-10-25T00:45:00Z")
        crashed.writeCrashSnapshot(signal: SIGSEGV)
        try setCrashFileDate(directory, clock.date)
        try setStartVersion(directory, index: 0, version: "0.3.1", build: "40")
        clock.date = try Self.utc("2026-10-25T01:35:00Z")
        let now = log(directory, clock)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        #expect(now.previousRunInfo() == PreviousRunInfo(version: "0.3.1", build: "40", runtimeSeconds: 600))
    }

    /// Start vor der Umstellung (02:50 Sommerzeit), letzte Zeile und Absturz danach (03:10 Winterzeit) → Laufzeit 80 min.
    @Test func runAcrossTheChangeHasTheRightRuntime() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = TestClock(try Self.utc("2026-10-25T00:50:00Z"))
        let crashed = log(directory, clock)
        crashed.start(installHandlers: false)
        clock.date = try Self.utc("2026-10-25T02:10:00Z")
        crashed.ui("click row=7")
        crashed.flushPendingWritesForTesting()
        clock.date = try Self.utc("2026-10-25T02:15:00Z")
        crashed.writeCrashSnapshot(signal: SIGSEGV)
        try setCrashFileDate(directory, clock.date)
        try setStartVersion(directory, index: 0, version: "0.3.1", build: "40")
        clock.date = try Self.utc("2026-10-25T02:20:00Z")
        let now = log(directory, clock)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        #expect(now.previousRunInfo() == PreviousRunInfo(version: "0.3.1", build: "40", runtimeSeconds: 4800))
    }

    /// Alte Zeilen ohne Versatz (vor bug.0.4.196) werden weiter als Ortszeit gelesen: Laufzeit aus Start und letzter Zeile.
    @Test func legacyStampsWithoutOffsetAreReadAsLocalTime() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = [
            "2026-10-20 12:00:00.000 app info start version=0.3.1 build=40 config=Debug macOS=15 pid=1",
            "2026-10-20 12:02:30.000 ui info click row=7",
            "",
        ].joined(separator: "\n")
        try legacy.write(to: directory.appendingPathComponent(DiskIndexLog.fileName), atomically: true, encoding: .utf8)
        try "CRASH signal=SIGSEGV\n".write(to: directory.appendingPathComponent("crash-last.txt"), atomically: true, encoding: .utf8)
        // 12:03 Ortszeit (Sommerzeit) = 10:03 UTC.
        try setCrashFileDate(directory, try Self.utc("2026-10-20T10:03:00Z"))
        let clock = TestClock(try Self.utc("2026-10-20T10:10:00Z"))
        let now = log(directory, clock)
        now.start(installHandlers: false)
        now.flushPendingWritesForTesting()
        #expect(now.previousRunInfo() == PreviousRunInfo(version: "0.3.1", build: "40", runtimeSeconds: 150))
    }
}

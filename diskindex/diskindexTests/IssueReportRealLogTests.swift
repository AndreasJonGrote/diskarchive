//
//  IssueReportRealLogTests.swift
//  diskindexTests
//
//  todo.0.4.023: Fehlerbericht aus echten Protokollzeilen. Die Zeilen entstehen über `DiskIndexLog` (eigene Instanz
//  je Testordner, keine von Hand formatierte Datei), der Bericht über den echten Weg `IssueReporter.enqueue(kind:)`
//  (wie der Absturz-Dialog „Senden“) bis in die Warteschlange und über `flush`/`start` an den Stub-Server.
//

import Darwin
import Foundation
import GRDB
import Testing
@testable import diskindex

/// Fängt gesendete Körper je Host ein (je Test ein eigener Host, kein prozessweiter Schalter).
final class RealLogReportStubURL: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var bodies: [String: [Data]] = [:]

    static func bodies(host: String) -> [Data] {
        lock.withLock { bodies[host] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".real-log.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = request.httpBody ?? Self.readStream(request.httpBodyStream)
        Self.lock.withLock { Self.bodies[host, default: []].append(body) }
        guard let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readStream(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

private final class LineSink: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func append(_ line: String) { lock.withLock { lines.append(line) } }
    var all: [String] { lock.withLock { lines } }
}

/// Testumgebung: eigener Ordner für Protokoll und Datenbank, eigener Server-Host.
private struct RealLogHarness {
    let root: URL
    let logDirectory: URL
    let pool: DatabasePool
    let host: String
    let defaultsSuite: String
    let sink = LineSink()

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-real-log-\(UUID().uuidString)", isDirectory: true)
        logDirectory = root.appendingPathComponent("Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        do {
            pool = try ApiQueuePersistence.openQueuePool(at: root.appendingPathComponent("archive.sqlite"))
        } catch {
            // bug.0.4.085 c): auch ohne Datenbank keinen Testordner zurücklassen.
            try? FileManager.default.removeItem(at: root)
            throw error
        }
        host = "r\(UUID().uuidString.prefix(8).lowercased()).real-log.test"
        defaultsSuite = "diskindex-real-log-\(UUID().uuidString)"
    }

    /// bug.0.4.080 e): Testordner und UserDefaults-Suite nach dem Test entfernen.
    func cleanUp() {
        UserDefaults(suiteName: defaultsSuite)?.removePersistentDomain(forName: defaultsSuite)
        try? FileManager.default.removeItem(at: root)
    }

    /// Erster Lauf: schreibt über das echte Protokoll, `body` erzeugt die Zeilen.
    func firstRun(_ body: (DiskIndexLog) -> Void) {
        let log = DiskIndexLog(directory: logDirectory)
        log.start(installHandlers: false)
        body(log)
        // Ende des abgestürzten Laufs: was er geschrieben hat, liegt auf der Platte.
        log.flushPendingWritesForTesting()
    }

    /// Nächster Start mit demselben Ordner (wie nach dem Absturz).
    func secondRun() -> DiskIndexLog {
        let log = DiskIndexLog(directory: logDirectory)
        log.start(installHandlers: false)
        return log
    }

    func reporter(log: DiskIndexLog) throws -> IssueReporter {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RealLogReportStubURL.self]
        let endpoint = try #require(URL(string: "https://\(host)/api/issues/"))
        let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
        let sink = self.sink
        let reporter = IssueReporter(
            endpoint: endpoint,
            directory: root.appendingPathComponent("outbox", isDirectory: true),
            queuePool: pool,
            defaults: defaults,
            session: URLSession(configuration: configuration),
            releaseBuild: false,
            log: { sink.append($0) },
            diskLog: log
        )
        reporter.sendsImmediately = false
        return reporter
    }
}

private func queuedObject(_ reporter: IssueReporter) throws -> (raw: String, object: [String: Any]) {
    reporter.waitForPendingEnqueuesForTesting()
    let data = try #require(try reporter.firstQueuedPayload())
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return (String(decoding: data, as: UTF8.self), object)
}

private func crash(_ object: [String: Any]) -> [String: Any] {
    object["crash"] as? [String: Any] ?? [:]
}

private func waitUntil(seconds: Double, _ condition: () throws -> Bool) async rethrows -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if try condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return try condition()
}

/// Private Bestandteile, die in den Zeilen vorkommen und nie im Bericht stehen dürfen.
private let secretWords = [
    "Urlaubsfotos", "Brief an Anna", "Kundenakte", "geheim", "Steuererklärung", "Geheimprojekt", "Tagebuch",
    "/Volumes/", "/Users/", "file://",
]

@Suite(.serialized)
struct IssueReportRealLogTests {
    /// Zeilen aus dem Protokoll landen in `logTail` (letzte 100, alte zuerst, ohne leere Endzeile), private
    /// Bestandteile sind geschwärzt, der Absturzteil kommt aus `crash-last.txt` mit Signal und letzten Aktionen.
    @Test func reportFromRealLogKeepsOrderLimitAndHidesNames() throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        harness.firstRun { log in
            for step in 1...130 {
                log.record(.index, .info, "scan step=\(step)")
            }
            log.record(.medium, .error, "open failed /Volumes/Urlaubsfotos/Privat/Brief an Anna.pdf")
            log.record(.index, .error, "read failed", privateDetail: "/Volumes/Kundenakte/geheim.txt")
            log.ui("search query=Steuererklärung 2024")
            log.record(.app, .info, "medium „Geheimprojekt“ mounted")
            log.record(.watcher, .info, "skipped 'Tagebuch.txt' kind=file")
            log.ui("click row=7")
            // Absturz über den Funktionsweg des Signal-Handlers (kein echtes Signal).
            log.writeCrashSnapshot(signal: SIGSEGV)
        }
        let log = harness.secondRun()
        #expect(log.shouldShowCrashDialog)
        log.ui("crash dialog send")
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)

        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)

        // Zeilen übernommen: genau die letzten 100, in Dateireihenfolge, keine leere Zeile.
        let tail = try #require(object["logTail"] as? [String])
        #expect(tail.count == 100)
        #expect(!tail.contains(""))
        let steps = tail.compactMap { line -> Int? in
            guard let range = line.range(of: "scan step=") else { return nil }
            return Int(line[range.upperBound...])
        }
        let lastStep = try #require(steps.last)
        #expect(lastStep == 130)
        #expect(steps.first != 1)
        #expect(steps == Array((lastStep - steps.count + 1)...lastStep))
        let lastLine = try #require(tail.last)
        #expect(lastLine.contains("ui info crash dialog send"))
        let scanIndex = try #require(tail.lastIndex { $0.contains("scan step=130") })
        let mediumIndex = try #require(tail.firstIndex { $0.contains("medium error open failed") })
        #expect(scanIndex < mediumIndex)

        // Datenschutz: Pfad, Suchbegriff, Namen in Anführungszeichen nur als Profil.
        for word in secretWords {
            #expect(!raw.contains(word), "Bericht enthält \(word)")
        }
        #expect(tail.contains { $0.contains("medium error open failed ‹path depth=") })
        #expect(tail.contains { $0.contains("index error read failed pathDepth=3 pathLen=") })
        #expect(tail.contains { $0.contains("search query chars=20") })
        #expect(tail.contains { $0.contains("medium ‹name chars=13 ") && $0.contains(" mounted") })
        #expect(tail.contains { $0.contains("skipped ‹name chars=8 ") && $0.contains("ext=.txt") })

        // Absturzteil: Signal, Aktionen des abgestürzten Laufs, Fehlerort (Stapel) lesbar.
        let crash = try #require(object["crash"] as? [String: Any])
        #expect(crash["signal"] as? String == "SIGSEGV")
        #expect(object["signature"] as? String == "SIGSEGV")
        let stack = try #require(crash["stack"] as? [String])
        #expect(stack.contains { $0.hasSuffix("ui info click row=7") })
        #expect(stack.contains { $0.hasSuffix("ui info search query chars=20") })
        #expect(stack.contains { $0.contains("writeCrashSnapshot") }, "Fehlerort fehlt: \(stack)")
        let actions = try #require(object["actions"] as? [String])
        #expect(actions.contains { $0.hasSuffix("ui info crash dialog send") })
        #expect(object["kind"] as? String == "crash")
        #expect(raw.utf8.count <= IssuePayload.bodyLimit)
    }

    /// Der echte Bericht passiert den Leak-Wächter und kommt unverändert beim Server an.
    @Test func realLogReportIsSentUnchanged() async throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        harness.firstRun { log in
            log.record(.medium, .error, "mount failed /Volumes/Urlaubsfotos")
            log.ui("search query=Geheimprojekt")
            log.writeCrashSnapshot(signal: SIGABRT)
        }
        let log = harness.secondRun()
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)
        reporter.enqueue(kind: "crash")
        let (raw, _) = try queuedObject(reporter)

        await reporter.flush()

        let sent = RealLogReportStubURL.bodies(host: harness.host)
        #expect(sent.count == 1)
        let body = try #require(sent.first)
        #expect(String(decoding: body, as: UTF8.self) == raw)
        #expect(try reporter.queuedReportCount() == 0)
        for word in secretWords {
            #expect(!raw.contains(word), "Bericht enthält \(word)")
        }
    }

    /// Ein Medienname ohne Anführungszeichen geht am Scrubber vorbei; der Leak-Wächter kennt die Namen beim ersten
    /// Senden nach `start()` schon und sperrt den Bericht.
    @Test func leakGuardBlocksMediumNameFromRealLogAtStart() async throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        let store = IndexStoreV3(pool: harness.pool)
        try await store.upsertMedium(
            StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "Urlaubsfotos", type: .usb, decision: .index)
        )
        harness.firstRun { log in
            log.record(.medium, .info, "medium Urlaubsfotos mounted")
            log.writeCrashSnapshot(signal: SIGBUS)
        }
        let log = harness.secondRun()
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)
        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)
        #expect(raw.contains("Urlaubsfotos"))
        let inventory = try #require(object["inventory"] as? [String: Any])
        #expect(inventory["media"] as? Int == 1)
        #expect((inventory["dbBytes"] as? Int ?? 0) > 0)

        reporter.start()

        let blocked = await waitUntil(seconds: 10) {
            harness.sink.all.contains("app report blocked:leak=name")
        }
        #expect(blocked, "Protokoll: \(harness.sink.all)")
        #expect(RealLogReportStubURL.bodies(host: harness.host).isEmpty)
    }

    /// Korrektur todo.0.4.023: „$“ schützt nur Swift-Symbole im Stapel. Ein Name mit „$“ im Protokoll wird zum
    /// Profil (mit U+0024), der Fehlerort `$s9diskindex…writeCrashSnapshot` bleibt im Stapel lesbar.
    @Test func dollarNameInLogIsHiddenButSwiftSymbolsInStackStayReadable() throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        harness.firstRun { log in
            log.record(.watcher, .info, "skipped Gehalt$Anna")
            log.writeCrashSnapshot(signal: SIGSEGV)
        }
        let log = harness.secondRun()
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)

        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)

        #expect(!raw.contains("Gehalt"))
        #expect(!raw.contains("Anna"))
        let tail = try #require(object["logTail"] as? [String])
        #expect(tail.contains { $0.contains("‹name ") && $0.contains("U+0024") }, "logTail: \(tail)")
        let crash = try #require(object["crash"] as? [String: Any])
        let stack = try #require(crash["stack"] as? [String])
        #expect(stack.contains { $0.contains("$s9diskindex") && $0.contains("writeCrashSnapshot") }, "Stapel: \(stack)")
    }

    /// bug.0.4.078: Ohne `crash-last.txt` besteht der Stapel aus allen Protokollzeilen nach „CRASH signal=“. Eine
    /// Protokollzeile mit „$S…“ im Dateinamen wird geschwärzt; nur echte Stapelrahmen behalten ihre Swift-Symbole.
    @Test func dollarSInLogLineAfterCrashIsScrubbedButFramesStayReadable() throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        let realFrames = Thread.callStackSymbols
        try #require(realFrames.contains { $0.contains("$s") })
        harness.firstRun { log in
            let frames = ["0   Disk Archive                        0x0000000100a1b2c3 $s9diskindex3FooV3baryyF + 12"] + realFrames
            log.recordCrash(signal: "exception NSRangeException", symbols: frames)
            // Nach der CRASH-Zeile: gehören über den Rückfallweg zum Stapel.
            log.record(.watcher, .info, "skipped Konto$Sparbuch.pdf")
            log.record(.medium, .error, "open failed /Volumes/Privat/Konto$Sparbuch.pdf")
        }
        let log = harness.secondRun()
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)

        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)

        #expect(!raw.contains("Sparbuch"), "Bericht enthält den Dateinamen")
        #expect(!raw.contains("Konto"), "Bericht enthält den Dateinamen")
        #expect(!raw.contains("/Volumes/"))
        let stack = try #require(crash(object)["stack"] as? [String])
        // Die Zeile mit „$“ wird wie im Protokoll ganz zum Namensprofil (mit U+0024).
        #expect(stack.contains { $0.hasPrefix("‹name ") && $0.contains("U+0024") }, "Stapel: \(stack)")
        #expect(stack.contains { $0.contains("medium error open failed ‹path depth=") }, "Stapel: \(stack)")
        #expect(stack.contains { $0.hasSuffix("0x0000000100a1b2c3 $s9diskindex3FooV3baryyF + 12") }, "Stapel: \(stack)")
        // Echte Rahmen aus diesem Prozess: mindestens ein Swift-Symbol bleibt lesbar.
        #expect(stack.contains { $0.contains("$s") && $0.contains("diskindexTests") }, "Stapel: \(stack)")
    }

    /// bug.0.4.082: (1) Eine Nachricht mit Zeilenumbruch erzeugt keine eigene, rahmenähnliche Zeile („12 x 0x1
    /// $Sgeheim.pdf“ hinter der CRASH-Zeile) – „geheim“ steht nicht im Bericht. (2) In einem echten Rahmen bleibt nur
    /// das Symbol direkt nach der Adresse lesbar, ein weiteres „$S…“ dahinter wird geschwärzt.
    @Test func newlineInMessageCannotForgeAStackFrame() throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        harness.firstRun { log in
            let frames = [
                "0   Disk Archive                        0x0000000100a1b2c3 $s9diskindex3FooV3baryyF + 12",
                "1   Disk Archive                        0x0000000100a1b2d4 $s9diskindex3BarV + 4 $Sparbuch",
            ]
            // Auch der Grund einer Ausnahme kann einen Zeilenumbruch tragen (Prüf-Agent).
            log.recordCrash(signal: "exception NSRangeException reason\n14 x 0x3 $Sgeheimakte.pdf", symbols: frames)
            log.record(.watcher, .info, "skipped\n12 x 0x1 $Sgeheim.pdf")
            log.record(.watcher, .info, "skipped\r13 x 0x2 $Sgeheimer.txt")
        }
        let log = harness.secondRun()
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)

        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)

        #expect(!raw.contains("geheim"), "Bericht enthält „geheim“")
        #expect(!raw.contains("Sparbuch") && !raw.contains("parbuch"), "zweites Symbol im Rahmen ungeschwärzt")
        let stack = try #require(crash(object)["stack"] as? [String])
        #expect(stack.contains { $0.hasSuffix("0x0000000100a1b2c3 $s9diskindex3FooV3baryyF + 12") }, "Stapel: \(stack)")
        #expect(stack.contains { $0.contains("0x0000000100a1b2d4 $s9diskindex3BarV‹name ") }, "Symbol nach der Adresse fehlt: \(stack)")
        #expect(!stack.contains { $0.hasPrefix("12 x 0x1") || $0.hasPrefix("13 x 0x2") }, "eigene Zeile aus dem Zeilenumbruch: \(stack)")
    }

    /// bug.0.4.083 (ersetzt die Reihenfolge aus bug.0.4.079): großer Stapel mit Brotkrumen. Zuerst fallen die
    /// Brotkrumen im Stapel weg, dann Rahmen von hinten; das reicht → `logTail` behält alle 100 Zeilen, Rahmen 0 bleibt.
    @Test func stackTrimKeepsAllLogLinesAndFrameZero() throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        let filler = String(repeating: "y", count: 480)
        harness.firstRun { log in
            for index in 0..<40 { log.ui("click row=\(index) \(String(repeating: "k", count: 120))") }
            let symbols = (0..<440).map { "\($0) diskindex 0x0000000100000000 frame\($0) \(filler)" }
            log.recordCrash(signal: "exception NSRangeException", symbols: symbols)
        }
        let log = harness.secondRun()
        log.record(.app, .info, "newest line marker")
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)

        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)

        #expect(raw.utf8.count <= IssuePayload.bodyLimit, "Körper \(raw.utf8.count) Bytes")
        let tail = try #require(object["logTail"] as? [String])
        #expect(tail.count == 100, "logTail gekürzt, obwohl der Stapel reichte: \(tail.count)")
        let newest = try #require(tail.last)
        #expect(newest.contains("app info newest line marker"))
        let stack = try #require(crash(object)["stack"] as? [String])
        let head = try #require(stack.first)
        #expect(head.hasPrefix("0 diskindex 0x0000000100000000 frame0 "), "Rahmen 0 fehlt: \(head.prefix(60))")
        #expect(!stack.contains { $0.contains("click row=") }, "Brotkrumen vor den Rahmen nicht gekürzt")
        #expect(stack.count < 440, "Stapel nicht gekürzt")
    }

    /// Signal und Signatur ohne Leerzeichen sind beliebig lang; der Bericht bleibt trotzdem unter 256 KB.
    @Test func hugeSignalAndSignatureStayUnderBodyLimit() throws {
        let huge = String(repeating: "S", count: 400_000)
        let draft = IssueDraft(
            kind: "crash", signature: huge, actions: [], logTail: [], crashSignal: huge, crashStack: [],
            media: 0, items: 0, dbBytes: 0
        )
        let data = IssuePayload.json(
            draft: draft, id: "X", version: "1", build: "1", config: "Debug", macOS: "15", model: "Mac",
            runtimeSeconds: 0, createdAt: Date(timeIntervalSince1970: 0)
        )
        #expect(data.count <= IssuePayload.bodyLimit, "Körper \(data.count) Bytes")
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let signal = try #require(crash(object)["signal"] as? String)
        #expect(!signal.isEmpty && signal.count <= IssuePayload.lineLimit)
    }

    /// Größenbegrenzung: auch ein sehr langer Absturzteil aus dem Protokoll (Ausnahme ohne `crash-last.txt`)
    /// bleibt unter 256 KB; Signal und Kopf des Stapels bleiben erhalten. bug.0.4.079: Der Stapel wird gekürzt, bevor
    /// das Protokoll unter `keptLogLines` (20) Zeilen fällt; die neueste Zeile bleibt.
    @Test func hugeCrashSectionFromRealLogStaysUnderBodyLimit() throws {
        let harness = try RealLogHarness()
        defer { harness.cleanUp() }
        let filler = String(repeating: "x", count: 480)
        harness.firstRun { log in
            for step in 1...150 {
                log.record(.index, .info, "line=\(step) \(filler)")
            }
            let symbols = (0..<700).map { "\($0) diskindex 0x0000000100000000 frame\($0) \(filler)" }
            log.recordCrash(signal: "exception NSRangeException", symbols: symbols)
        }
        let log = harness.secondRun()
        log.record(.app, .info, "newest line marker")
        log.flushPendingWritesForTesting()
        let reporter = try harness.reporter(log: log)

        reporter.enqueue(kind: "crash")
        let (raw, object) = try queuedObject(reporter)

        #expect(raw.utf8.count <= IssuePayload.bodyLimit, "Körper \(raw.utf8.count) Bytes")
        let crash = try #require(object["crash"] as? [String: Any])
        #expect(crash["signal"] as? String == "exception")
        let stack = try #require(crash["stack"] as? [String])
        let head = try #require(stack.first)
        #expect(head.hasPrefix("0 diskindex 0x0000000100000000 frame0 "))
        #expect(stack.allSatisfy { $0.count <= IssuePayload.lineLimit })
        // Der Stapel war zu groß und wurde von hinten gekürzt (älteste Rahmen weg), das Protokoll behält 20 Zeilen.
        #expect(stack.count < 700, "Stapel nicht gekürzt: \(stack.count)")
        let tail = try #require(object["logTail"] as? [String])
        #expect(tail.count >= IssuePayload.keptLogLines, "logTail: \(tail.count) Zeilen")
        let newest = try #require(tail.last)
        #expect(newest.contains("app info newest line marker"))
    }
}

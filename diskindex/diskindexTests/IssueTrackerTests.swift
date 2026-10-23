//
//  IssueTrackerTests.swift
//  diskindexTests
//

import Foundation
import GRDB
import Testing
@testable import diskindex

/// bug.0.4.125: Zustand des Test-Servers je Test (kein prozessweiter Schalter, Regel 20). `makeReporter` legt ihn an
/// und gibt ihn zurück; die Anfragen tragen seine Kennung als Kopfzeile.
final class IssueStub: @unchecked Sendable {
    private let lock = NSLock()
    private var _status = 201
    private var _body = Data(#"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890"}"#.utf8)
    private var _fail = false
    private var _failCode: URLError.Code = .notConnectedToInternet
    private var _hits = 0
    private var _lastRequestBody: Data?
    private var _responseDelayNanoseconds: UInt64 = 0

    var status: Int { get { lock.withLock { _status } } set { lock.withLock { _status = newValue } } }
    var body: Data { get { lock.withLock { _body } } set { lock.withLock { _body = newValue } } }
    var fail: Bool { get { lock.withLock { _fail } } set { lock.withLock { _fail = newValue } } }
    var failCode: URLError.Code { get { lock.withLock { _failCode } } set { lock.withLock { _failCode = newValue } } }
    var hits: Int { get { lock.withLock { _hits } } set { lock.withLock { _hits = newValue } } }
    var lastRequestBody: Data? { get { lock.withLock { _lastRequestBody } } set { lock.withLock { _lastRequestBody = newValue } } }
    var responseDelayNanoseconds: UInt64 {
        get { lock.withLock { _responseDelayNanoseconds } }
        set { lock.withLock { _responseDelayNanoseconds = newValue } }
    }
}

final class IssueStubURL: URLProtocol, @unchecked Sendable {
    static let header = "X-Issue-Stub"
    /// Register der Stubs je Kennung (nur Nachschlagen, kein Schalter; jeder Test hat seinen eigenen Eintrag).
    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [String: IssueStub] = [:]

    static func register(_ stub: IssueStub) -> String {
        let id = UUID().uuidString
        lock.withLock { stubs[id] = stub }
        return id
    }

    private static func stub(for request: URLRequest) -> IssueStub? {
        guard let id = request.value(forHTTPHeaderField: header) else { return nil }
        return lock.withLock { stubs[id] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let body = request.httpBody {
            stub(for: request)?.lastRequestBody = body
        }
        return request
    }

    override func startLoading() {
        guard let stub = Self.stub(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let delay = stub.responseDelayNanoseconds
        if delay > 0 {
            Thread.sleep(forTimeInterval: Double(delay) / 1_000_000_000)
        }
        stub.hits += 1
        if let body = request.httpBody { stub.lastRequestBody = body }
        if stub.fail {
            client?.urlProtocol(self, didFailWithError: URLError(stub.failCode))
            return
        }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct IssueTrackerTests {
    @Test func crashReportIsSentAndLeavesTheOutbox() async throws {
        let (reporter, stub) = try makeReporter()
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        #expect(stub.hits == 1)
        try expectQueued(reporter, 0)
    }

    @Test func serverErrorKeepsTheFileAndBacksOff() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let (reporter, stub) = try makeReporter(now: { clock.value })
        stub.status = 500
        stub.body = Data("no".utf8)
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        let id = try #require(try reporter.firstQueuedIssueID())
        await reporter.flush()
        try expectQueued(reporter, 1)
        #expect(stub.hits == 1)
        let first = try #require(reporter.nextRetry(id: id))
        #expect(first.attempts == 1)
        #expect(abs(first.next.timeIntervalSince(clock.value) - 3_600) < 1)
        await reporter.flush()
        #expect(stub.hits == 1)
        clock.value = first.next
        await reporter.flush()
        #expect(stub.hits == 2)
        let second = try #require(reporter.nextRetry(id: id))
        #expect(second.attempts == 2)
        #expect(abs(second.next.timeIntervalSince(clock.value) - 7_200) < 1)
    }

    @Test func clientErrorDropsTheFile() async throws {
        let (reporter, stub) = try makeReporter()
        stub.status = 400
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 0)
    }

    @Test func offlineKeepsTheFile() async throws {
        let (reporter, stub) = try makeReporter()
        stub.fail = true
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 1)
        #expect(stub.hits == 1)
    }

    /// bug.0.4.109: Zeitüberschreitung ist nicht „offline“ → Backoff: nach 61 s nicht fällig, zwei Flushes senden
    /// einmal (keine doppelten Berichte).
    @Test func timeoutBacksOffInsteadOfRetryingEveryMinute() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let (reporter, stub) = try makeReporter(now: { clock.value })
        stub.fail = true
        stub.failCode = .timedOut
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        await reporter.flush()
        #expect(stub.hits == 1)
        try expectQueued(reporter, 1)
        clock.value = clock.value.addingTimeInterval(61)
        let pool = try #require(reporter.queuePool)
        #expect(try ApiQueuePersistence.fetchDue(pool, now: clock.value).isEmpty)
        await reporter.flush()
        #expect(stub.hits == 1, "nach 61 s erneut gesendet")
    }

    /// bug.0.4.109: Nach 10 gescheiterten Versuchen (kein „offline“) wird der Eintrag verworfen.
    @Test func reportIsDroppedAfterTenFailedAttempts() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let (reporter, stub) = try makeReporter(now: { clock.value })
        stub.fail = true
        stub.failCode = .timedOut
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        for _ in 0..<10 {
            await reporter.flush()
            clock.value = clock.value.addingTimeInterval(25 * 3_600)
        }
        #expect(stub.hits == 10)
        try expectQueued(reporter, 0)
    }

    /// bug.0.4.109: Echt offline (`notConnectedToInternet`) zählt nicht gegen die Obergrenze.
    @Test func offlineDoesNotCountTowardsTheLimit() async throws {
        let (reporter, stub) = try makeReporter()
        stub.fail = true
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        for _ in 0..<12 {
            await reporter.flush()
        }
        try expectQueued(reporter, 1)
        #expect(stub.hits == 12)
        // Ältere Zeile mit hohem Zähler aus der Zeit, als „offline“ jede Minute zählte: bleibt erhalten.
        let pool = try #require(reporter.queuePool)
        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        try ApiQueuePersistence.recordFailure(pool, rowID: row.id, attempts: 50, lastTryAt: 0, info: "offline")
        await reporter.flush()
        try expectQueued(reporter, 1)
    }

    /// bug.0.4.110: Ist nur eine Zeile im Backoff (nichts fällig), steht ein Wecker auf ihren Fälligkeitstermin –
    /// kein Warten bis zum nächsten Ereignis (vorher bis zu 24 h statt 1/2/4 h).
    @Test func backoffDueDateArmsAWakeTimer() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let (reporter, stub) = try makeReporter(now: { clock.value })
        stub.status = 500
        stub.body = Data("no".utf8)
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        await reporter.flush()
        try expectQueued(reporter, 1)
        // bug.0.4.114: Fälligkeit wird im Hintergrund gelesen (keine Anweisung auf dem Hauptfaden).
        let poolURL = URL(fileURLWithPath: try #require(reporter.queuePool).path)
        let mainBefore = SchemaV3.OpenCounter.shared.mainThreadStatementCount(poolURL)
        reporter.syncReachabilityTimerForTesting()
        let armed = await waitUntil {
            await MainActor.run { reporter.reachabilityTimersForTesting.wakeFireDate != nil }
        }
        try #require(armed, "kein Wecker für den Fälligkeitstermin")
        let timers = await MainActor.run { reporter.reachabilityTimersForTesting }
        #expect(timers.periodic == false, "Minutentakt ohne fällige Arbeit")
        #expect(SchemaV3.OpenCounter.shared.mainThreadStatementCount(poolURL) == mainBefore, "Warteschlange auf dem Hauptfaden gelesen")
        let fire = try #require(timers.wakeFireDate)
        // Backoff nach dem ersten Fehlversuch: 1 h.
        #expect(abs(fire.timeIntervalSinceNow - 3_600) < 30, "Wecker in \(fire.timeIntervalSinceNow) s")
        // bug.0.4.162 (h): den 1-h-Wecker wieder abräumen (sonst feuert er später im Testprozess).
        reporter.stopReachabilityForTesting()
        let cleared = await waitUntil { await MainActor.run { reporter.reachabilityTimersForTesting.wakeFireDate == nil } }
        #expect(cleared, "Wecker nach dem Stopp nicht abgeräumt")
    }

    /// bug.0.4.162 (h): Kommt das Ergebnis des Lesens erst nach `stop()` an, legt `apply` keine Zeitgeber mehr an.
    @Test @MainActor func lateApplyAfterStopArmsNoTimer() async throws {
        let reachability = ApiQueueReachability()
        let due = Date().addingTimeInterval(3_600)
        reachability.queueSchedule = {
            Thread.sleep(forTimeInterval: 0.1)
            return (false, due)
        }
        reachability.syncPeriodicTimer()
        reachability.stop()
        let applied = await waitUntil { reachability.appliesForTesting >= 1 }
        try #require(applied, "spätes apply lief nicht")
        #expect(reachability.timersForTesting.wakeFireDate == nil, "Wecker nach stop() angelegt")
        #expect(reachability.timersForTesting.periodic == false)
    }

    /// bug.0.4.145: Auch der Versions-Check wird offline nie wegen der Obergrenze verworfen (20 Versuche ohne Netz).
    @Test func versionCheckOfflineDoesNotCountTowardsTheLimit() async throws {
        var lines: [String] = []
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let (reporter, stub) = try makeReporter(now: { clock.value }, log: { lines.append($0) })
        let pool = try #require(reporter.queuePool)
        try ApiQueuePersistence.enqueue(pool, kind: .versionCheck, payload: Data(), createdAt: 1)
        stub.fail = true
        for _ in 0..<20 {
            await reporter.flush()
            // Jedes Mal weit hinter den Backoff, damit die Zeile wirklich wieder fällig ist.
            clock.value = clock.value.addingTimeInterval(48 * 3_600)
        }
        #expect(try ApiQueuePersistence.count(pool, kind: .versionCheck) == 1, "Versions-Check-Zeile offline verworfen")
        #expect(lines.contains { $0.contains("version check offline") })
        #expect(!lines.contains { $0.contains("app report dropped") })
    }

    @Test func releaseRejectsPlainHTTP() async throws {
        var lines: [String] = []
        let (reporter, stub) = try makeReporter(release: true, log: { lines.append($0) })
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        #expect(stub.hits == 0)
        #expect(lines.contains { $0.contains("status=scheme") })
        #expect(!IssueEndpointPolicy.allows(ReportTarget.endpoint, release: true))
        #expect(IssueEndpointPolicy.allows(ReportTarget.endpoint, release: false))
        #expect(IssueEndpointPolicy.allows(try #require(URL(string: "https://example.com/issue-tracker/")), release: true))
        #expect(ReportTarget.endpoint.absoluteString == "http://localhost:8888/disk-archive/api/issues/")
    }

    /// todo.0.4.029: jedes 201 gilt als Erfolg, `id` optional (vorher: leere `id` → erneut senden).
    @Test func createdWithEmptyIDIsSuccess() async throws {
        let (reporter, stub) = try makeReporter()
        stub.status = 201
        stub.body = Data(#"{"id":""}"#.utf8)
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 0)
    }

    /// todo.0.4.029: 201 ohne Antwortkörper → Zeile gelöscht, kein erneutes Senden.
    @Test func createdWithoutBodyDeletesRowAndDoesNotResend() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        var lines: [String] = []
        let (reporter, stub) = try makeReporter(now: { clock.value }, log: { lines.append($0) })
        stub.status = 201
        stub.body = Data()
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        let id = try #require(try reporter.firstQueuedIssueID())
        await reporter.flush()
        #expect(stub.hits == 1)
        try expectQueued(reporter, 0)
        #expect(reporter.nextRetry(id: id) == nil)
        #expect(lines.contains { $0.contains("app report sent") && $0.contains("status=201") })
        clock.value = clock.value.addingTimeInterval(2 * 3_600)
        await reporter.flush()
        #expect(stub.hits == 1)
    }

    @Test func sentBodyHasRequiredAPIFields() async throws {
        let (reporter, stub) = try makeReporter()
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        let fileData = try #require(try reporter.firstQueuedPayload())
        await reporter.flush()
        #expect(stub.hits == 1)
        let data = try #require(stub.lastRequestBody ?? Optional(fileData))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["schema"] as? Int == 2)
        #expect(object["kind"] as? String == "crash")
        let app = try #require(object["app"] as? [String: Any])
        #expect((app["version"] as? String)?.isEmpty == false)
        let system = try #require(object["system"] as? [String: Any])
        #expect((system["macOS"] as? String)?.isEmpty == false)
    }

    @Test func legacyOKBodyRetries() async throws {
        let (reporter, stub) = try makeReporter()
        stub.status = 200
        stub.body = Data(#"{"ok":true}"#.utf8)
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 1)
    }

    @Test func unprocessableEntityDropsFile() async throws {
        let (reporter, stub) = try makeReporter()
        stub.status = 422
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 0)
    }

    @Test func successWithoutOKBodyStaysAndBacksOff() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        var lines: [String] = []
        let (reporter, stub) = try makeReporter(now: { clock.value }, log: { lines.append($0) })
        // todo.0.4.029: 201 ist immer Erfolg; „Erfolg ohne passenden Körper“ gilt nur noch für andere 2xx.
        stub.status = 200
        stub.body = Data("<html>tracker</html>".utf8)
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        let id = try #require(try reporter.firstQueuedIssueID())
        await reporter.flush()
        try expectQueued(reporter, 1)
        #expect(stub.hits == 1)
        #expect(lines.contains { $0.contains("status=200") && $0.contains("body=nicht-ok") })
        let first = try #require(reporter.nextRetry(id: id))
        #expect(first.attempts == 1)
        #expect(abs(first.next.timeIntervalSince(clock.value) - 3_600) < 1)
        await reporter.flush()
        #expect(stub.hits == 1)
        clock.value = first.next
        await reporter.flush()
        #expect(stub.hits == 2)
        let second = try #require(reporter.nextRetry(id: id))
        #expect(second.attempts == 2)
        #expect(abs(second.next.timeIntervalSince(clock.value) - 7_200) < 1)
    }

    @Test func errorsAreNotSentAsReports() throws {
        let (reporter, _) = try makeReporter()
        reporter.noteError(category: "store", message: "applyDirectories /tmp/a 12")
        try expectQueued(reporter, 0)
    }

    @Test func scrubberDropsNamesButKeepsTheProfile() throws {
        let nfc = "Müller – Übersicht 🎵 (final) .pdf"
        let nfd = nfc.decomposedStringWithCanonicalMapping
        let rtl = "\u{202E}secret"
        let control = "datei\u{0001}name.txt"
        let query = "Steuererklärung 2024"
        let path = "/Volumes/KUNDE/Rechnungen/\(nfc)"
        let lines = [
            "search query=\(query)",
            "search query=\(query.decomposedStringWithCanonicalMapping)",
            path,
            nfd,
            rtl,
            control,
        ]
        let scrubbed = lines.map(ReportScrubber.text).joined(separator: "\n")
        for name in [nfc, nfd, query, "KUNDE", "Rechnungen", "Müller", "Übersicht", "final"] {
            let stem = name.count >= 3 ? name : name
            if stem.count >= 3 {
                #expect(!scrubbed.contains(stem), "\(stem)")
                #expect(!scrubbed.contains(stem.decomposedStringWithCanonicalMapping))
            }
        }
        #expect(scrubbed.contains("nf=NFC") || scrubbed.contains("nf=NFD"))
        #expect(scrubbed.contains("flags=emoji") || scrubbed.contains("emoji"))
        #expect(scrubbed.contains("ext=.pdf"))
        #expect(scrubbed.contains("‹path depth="))
        #expect(scrubbed.contains("‹query chars="))
    }

    @Test func leakCheckBlocksAnInjectedPath() throws {
        let json = #"{"schema":2,"logTail":["/Volumes/KUNDE/geheim"]}"#
        #expect(ReportScrubber.leakCategory(in: json, names: []) == "path")
        #expect(ReportScrubber.leakCategory(in: #"{"ok":true}"#, names: ["Archiv"]) == nil)
        // Wortgrenzen (bug.0.4.012): Teilstring „Archiv“ in „Archivplatte“ zählt nicht.
        #expect(ReportScrubber.leakCategory(in: #"{"name":"Archivplatte"}"#, names: ["Archiv"]) == nil)
        #expect(ReportScrubber.leakCategory(in: #"{"name":"Archivplatte"}"#, names: ["Archivplatte"]) == "name")
        let encodedData = try JSONSerialization.data(withJSONObject: [
            "schema": 2,
            "logTail": ["/Volumes/KUNDE/geheim"],
        ])
        let encoded = try #require(String(data: encodedData, encoding: .utf8))
        #expect(ReportScrubber.leakCategory(in: encoded, names: []) == "path")
    }

    @Test func payloadHasTheContractFields() throws {
        let (reporter, _) = try makeReporter()
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        let data = try #require(try reporter.firstQueuedPayload())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(object.keys)
        #expect(keys == ["actions", "app", "crash", "createdAt", "id", "inventory", "kind", "logTail", "runtimeSeconds", "schema", "signature", "system"])
        #expect(object["schema"] as? Int == 2)
        #expect(object["kind"] as? String == "crash")
        let created = try #require(object["createdAt"] as? String)
        #expect(created.hasSuffix("Z"))
        let id = try #require(object["id"] as? String)
        #expect(UUID(uuidString: id) != nil)
        #expect(id == id.uppercased())
    }

    @Test func queueIsCapped() throws {
        let (reporter, _) = try makeReporter()
        for _ in 0..<51 {
            reporter.enqueue(kind: "crash")
        }
        try expectQueued(reporter, 50)
    }

    @Test func parallelFlushSendsOnce() async throws {
        let (reporter, stub) = try makeReporter()
        stub.responseDelayNanoseconds = 200_000_000
        defer { stub.responseDelayNanoseconds = 0 }
        reporter.enqueue(kind: "crash")
        async let first: Void = reporter.flush()
        async let second: Void = reporter.flush()
        _ = await (first, second)
        #expect(stub.hits == 1)
        try expectQueued(reporter, 0)
    }

    @Test func leakBlockedRowStaysOutOfDueAndSkipsResend() async throws {
        let (reporter, stub) = try makeReporter()
        let pool = try #require(reporter.queuePool)
        let id = UUID().uuidString
        let payload = Data(#"{"schema":2,"id":"\#(id)","kind":"crash","logTail":["/Volumes/KUNDE/geheim"]}"#.utf8)
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: payload, createdAt: 1)
        await reporter.flush()
        #expect(stub.hits == 0)
        try expectQueued(reporter, 1)
        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        #expect(row.info?.hasPrefix("blocked:leak=") == true)
        #expect(try ApiQueuePersistence.fetchDue(pool, now: Date()).isEmpty)
        stub.hits = 0
        await reporter.flush()
        #expect(stub.hits == 0)
    }

    /// bug.0.4.111: Ein nach dem Start angeschlossenes Medium gilt beim nächsten Senden für den Leak-Wächter.
    @Test func leakWatchReloadsMediumNamesBeforeSending() async throws {
        var logs: [String] = []
        let (reporter, stub) = try makeReporter(log: { logs.append($0) })
        let pool = try #require(reporter.queuePool)
        let store = IndexStoreV3(pool: pool)
        try await store.upsertMedium(StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Steuerunterlagen"))
        let body = try JSONSerialization.data(withJSONObject: [
            "schema": 2, "kind": "crash", "logTail": ["lese Steuerunterlagen"], "id": UUID().uuidString.uppercased(),
        ])
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: body, createdAt: Int(Date().timeIntervalSince1970))
        await reporter.flush()
        #expect(stub.hits == 0)
        #expect(logs.contains { $0.contains("blocked:leak=name") })
    }

    /// bug.0.4.164 (d): Absturzbericht ohne Version/Build/Laufzeit des abgestürzten Laufs (Startzeile fehlt) → „?“ statt
    /// des neuen Laufs bzw. eines leeren Felds, `runtimeSeconds` fehlt ganz (statt `null`). Echter Weg über `enqueue`.
    @Test func previousRunWithoutValuesSendsQuestionMarksAndNoRuntime() throws {
        let (reporter, _) = try makeReporter()
        var draft = IssueDraft(
            kind: "crash", signature: "SIGSEGV", actions: [], logTail: [], crashSignal: "SIGSEGV", crashStack: [],
            media: 0, items: 0, dbBytes: 0
        )
        draft.previousRun = PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil)
        reporter.enqueue(draft)
        reporter.waitForPendingEnqueuesForTesting()
        let data = try #require(try reporter.firstQueuedPayload())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let app = try #require(object["app"] as? [String: Any])
        #expect(app["version"] as? String == "?")
        #expect(app["build"] as? String == "?")
        #expect(object["runtimeSeconds"] == nil, "runtimeSeconds soll fehlen, nicht null sein")
    }

    /// bug.0.4.162 (a): Ein Lesefehler beim Nachladen der Mediennamen schaltet den Namens-Wächter nicht ab – die zuletzt
    /// geladenen Namen bleiben.
    @Test func knownNamesSurviveAReadError() async throws {
        let (reporter, _) = try makeReporter()
        let pool = try #require(reporter.queuePool)
        let store = IndexStoreV3(pool: pool)
        try await store.upsertMedium(StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Steuerunterlagen"))
        reporter.refreshKnownNamesInBackground()
        reporter.waitForPendingEnqueuesForTesting()
        try #require(reporter.knownNames().contains("Steuerunterlagen"), "Namen nicht geladen")
        // Lesen scheitert ab jetzt (Pool geschlossen).
        try pool.close()
        reporter.refreshKnownNamesInBackground()
        reporter.waitForPendingEnqueuesForTesting()
        #expect(reporter.knownNames().contains("Steuerunterlagen"), "Namens-Wächter nach Lesefehler leer")
    }

    /// bug.0.4.012: Payload mit Pfad direkt in die Queue → flush → blocked:leak=path, kein Request.
    @Test func leakWatchBlocksQueuedPathPayload() async throws {
        var logs: [String] = []
        let (reporter, stub) = try makeReporter(log: { logs.append($0) })
        reporter.knownNames = { [] }
        let leakBody = try JSONSerialization.data(withJSONObject: [
            "schema": 2,
            "kind": "crash",
            "logTail": ["/Volumes/X/geheim"],
            "id": UUID().uuidString.uppercased(),
        ])
        let pool = try #require(reporter.queuePool)
        try ApiQueuePersistence.enqueue(
            pool,
            kind: .issueReport,
            payload: leakBody,
            createdAt: Int(Date().timeIntervalSince1970)
        )
        await reporter.flush()
        #expect(logs.contains { $0.contains("blocked:leak=path") })
        #expect(stub.hits == 0)
    }

    @Test func enqueueSurvivesConcurrentExclusiveWrite() async throws {
        let (reporter, _) = try makeReporter()
        let pool = try #require(reporter.queuePool)
        let gate = ExclusiveWriteGate()
        let writer = Task {
            try pool.write { _ in
                gate.markEntered()
                gate.waitForRelease(timeoutSeconds: 5)
            }
        }
        let entered = await waitUntil(timeout: 2) { gate.hasEntered }
        #expect(entered)
        reporter.enqueue(kind: "crash")
        gate.release()
        try await writer.value
        try expectQueued(reporter, 1)
        #expect(reporter.reportFiles().isEmpty)
    }

    @Test func offlineFailureRetriesWithoutDelay() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let (reporter, stub) = try makeReporter(now: { clock.value })
        stub.fail = true
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        await reporter.flush()
        try expectQueued(reporter, 1)
        stub.fail = false
        await reporter.flush()
        try expectQueued(reporter, 0)
    }

    @Test @MainActor func enqueueReturnsQuicklyWhileDatabaseWriteBlocks() async throws {
        let poolTracker = ApiQueuePersistence.OpenQueuePoolCountTracker()
        try await ApiQueuePersistence.$openQueuePoolCountTracker.withValue(poolTracker) { () async throws -> Void in
            let (reporter, _) = try makeReporter()
            let opensAfterSetup = poolTracker.count
            let pool = try #require(reporter.queuePool)
            let gate = ExclusiveWriteGate()
            let writer = Task.detached {
                try pool.write { _ in
                    gate.markEntered()
                    // bug.0.3.8.007: Sperre hält bis `release()`; 30 s nur als Notausgang, falls der Test vorher abbricht.
                    gate.waitForRelease(timeoutSeconds: 30)
                }
            }
            let entered = await waitUntil { gate.hasEntered }
            #expect(entered)
            reporter.enqueue(kind: "crash")
            // bug.0.3.8.007: statt Zeitgrenze (< 100 ms) — `enqueue` ist zurück, während der Schreiber die
            // Datenbank noch hält. Wartete `enqueue` auf die Datenbank, käme es erst nach Ablauf der Sperre zurück.
            #expect(!gate.hasLeft, "enqueue hat auf die blockierte Datenbank gewartet")
            gate.release()
            try await writer.value
            reporter.waitForPendingEnqueuesForTesting()
            try expectQueued(reporter, 1)
            #expect(poolTracker.count == opensAfterSetup)
        }
    }

    @Test @MainActor func versionCheckEnqueueReturnsQuicklyWhileDatabaseWriteBlocks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close() }
        let gate = ExclusiveWriteGate()
        let writer = Task.detached {
            try store.pool.write { _ in
                gate.markEntered()
                // bug.0.3.8.007: Sperre hält bis `release()`; 30 s nur als Notausgang, falls der Test vorher abbricht.
                gate.waitForRelease(timeoutSeconds: 30)
            }
        }
        let entered = await waitUntil { gate.hasEntered }
        #expect(entered)
        // bug.0.4.074: der Weg des Produkts (`enqueueCheckIfDue` auf der seriellen Queue des Planers).
        let queue = DispatchQueue(label: "IssueTrackerTests.version-check")
        VersionCheckCoordinator.enqueueCheckIfDue(pool: store.pool, queue: queue, now: { Date() }, flush: {})
        // bug.0.3.8.007: statt Zeitgrenze (< 100 ms) — der Aufruf ist zurück, solange der Schreiber noch hält.
        #expect(!gate.hasLeft, "enqueueCheckIfDue hat auf die blockierte Datenbank gewartet")
        gate.release()
        try await writer.value
        queue.sync {}
        #expect(try ApiQueuePersistence.count(store.pool, kind: .versionCheck) == 1)
    }

    @Test func discardCrashDialogDoesNotRemoveQueuedReport() async throws {
        let (reporter, _) = try makeReporter()
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        try expectQueued(reporter, 1)
        let logDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: logDir) }
        let log = DiskIndexLog(directory: logDir)
        log.start(installHandlers: false)
        log.acknowledgeCrashDialog()
        try expectQueued(reporter, 1)
    }

    @Test func migratesLegacyOutboxFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyID = UUID().uuidString
        let legacyBody = Data(#"{"schema":2,"id":"\#(legacyID)","kind":"crash"}"#.utf8)
        FileManager.default.createFile(atPath: directory.appendingPathComponent("\(legacyID).json").path, contents: legacyBody)
        let (reporter, _) = try makeReporter(outboxDirectory: directory)
        reporter.migrateLegacyOutboxFiles()
        #expect(reporter.reportFiles().isEmpty)
        try expectQueued(reporter, 1)
        let payload = try #require(try reporter.firstQueuedPayload())
        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["id"] as? String == legacyID)
    }
}

private final class LockedDate: @unchecked Sendable {
    var value: Date
    init(_ value: Date) { self.value = value }
}

private func expectQueued(_ reporter: IssueReporter, _ expected: Int) throws {
    reporter.waitForPendingEnqueuesForTesting()
    let count = try reporter.queuedReportCount()
    #expect(count == expected)
}

private func makeReporter(
    release: Bool = false,
    now: @escaping () -> Date = { Date() },
    log: @escaping (String) -> Void = { _ in },
    outboxDirectory: URL? = nil
) throws -> (IssueReporter, IssueStub) {
    let stub = IssueStub()
    let directory = outboxDirectory ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    if outboxDirectory == nil {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let dbDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let pool = try ApiQueuePersistence.openQueuePool(at: dbDirectory.appendingPathComponent("archive.sqlite"))
    let defaults = TestDefaults.make()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [IssueStubURL.self]
    configuration.httpAdditionalHeaders = [IssueStubURL.header: IssueStubURL.register(stub)]
    let session = URLSession(configuration: configuration)
    let reporter = IssueReporter(
        directory: directory,
        queuePool: pool,
        defaults: defaults,
        session: session,
        releaseBuild: release,
        now: now,
        log: log,
        makeDraft: { kind in
            IssueDraft(
                kind: kind,
                signature: kind,
                actions: ["ui /Musik/Lied.mp3"],
                logTail: ["zeile"],
                crashSignal: "SIGSEGV",
                crashStack: ["/tmp/frame"],
                media: 3,
                items: 4,
                dbBytes: 5
            )
        }
    )
    reporter.sendsImmediately = false
    return (reporter, stub)
}

/// Sync-Gate für `pool.write` (kein `DispatchSemaphore.wait` im async-Testpfad, bug.0.4.010).
private final class ExclusiveWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private let releaseSem = DispatchSemaphore(value: 0)
    private var entered = false
    private var left = false

    var hasEntered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return entered
    }

    /// bug.0.3.8.007: Der Schreiber hat die Sperre verlassen (nach `release()` oder nach Ablauf der Wartezeit).
    var hasLeft: Bool {
        lock.lock()
        defer { lock.unlock() }
        return left
    }

    func markEntered() {
        lock.lock()
        entered = true
        lock.unlock()
    }

    func waitForRelease(timeoutSeconds: Double) {
        _ = releaseSem.wait(timeout: .now() + timeoutSeconds)
        lock.lock()
        left = true
        lock.unlock()
    }

    func release() {
        releaseSem.signal()
    }
}

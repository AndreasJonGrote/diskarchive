//
//  IssueTrackerTests.swift
//  diskindexTests
//

import Foundation
import GRDB
import Testing
@testable import diskindex

final class IssueStubURL: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 201
    nonisolated(unsafe) static var body = Data(#"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890"}"#.utf8)
    nonisolated(unsafe) static var fail = false
    nonisolated(unsafe) static var hits = 0
    nonisolated(unsafe) static var lastRequestBody: Data?
    nonisolated(unsafe) static var responseDelayNanoseconds: UInt64 = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let body = request.httpBody {
            Self.lastRequestBody = body
        }
        return request
    }

    override func startLoading() {
        if Self.responseDelayNanoseconds > 0 {
            Thread.sleep(forTimeInterval: Double(Self.responseDelayNanoseconds) / 1_000_000_000)
        }
        Self.hits += 1
        Self.lastRequestBody = request.httpBody
        if Self.fail {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct IssueTrackerTests {
    @Test func crashReportIsSentAndLeavesTheOutbox() async throws {
        let reporter = try makeReporter()
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        #expect(IssueStubURL.hits == 1)
        try expectQueued(reporter, 0)
    }

    @Test func serverErrorKeepsTheFileAndBacksOff() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        let reporter = try makeReporter(now: { clock.value })
        IssueStubURL.status = 500
        IssueStubURL.body = Data("no".utf8)
        reporter.enqueue(kind: "crash")
        let id = try #require(try reporter.firstQueuedIssueID())
        await reporter.flush()
        try expectQueued(reporter, 1)
        #expect(IssueStubURL.hits == 1)
        let first = try #require(reporter.nextRetry(id: id))
        #expect(first.attempts == 1)
        #expect(abs(first.next.timeIntervalSince(clock.value) - 3_600) < 1)
        await reporter.flush()
        #expect(IssueStubURL.hits == 1)
        clock.value = first.next
        await reporter.flush()
        #expect(IssueStubURL.hits == 2)
        let second = try #require(reporter.nextRetry(id: id))
        #expect(second.attempts == 2)
        #expect(abs(second.next.timeIntervalSince(clock.value) - 7_200) < 1)
    }

    @Test func clientErrorDropsTheFile() async throws {
        let reporter = try makeReporter()
        IssueStubURL.status = 400
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 0)
    }

    @Test func offlineKeepsTheFile() async throws {
        let reporter = try makeReporter()
        IssueStubURL.fail = true
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 1)
        #expect(IssueStubURL.hits == 1)
    }

    @Test func releaseRejectsPlainHTTP() async throws {
        var lines: [String] = []
        let reporter = try makeReporter(release: true, log: { lines.append($0) })
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        #expect(IssueStubURL.hits == 0)
        #expect(lines.contains { $0.contains("status=scheme") })
        #expect(!IssueEndpointPolicy.allows(ReportTarget.endpoint, release: true))
        #expect(IssueEndpointPolicy.allows(ReportTarget.endpoint, release: false))
        #expect(IssueEndpointPolicy.allows(URL(string: "https://example.com/issue-tracker/")!, release: true))
        #expect(ReportTarget.endpoint.absoluteString == "http://localhost:8888/disk-archive/api/issues/")
    }

    @Test func createdWithoutIDRetries() async throws {
        let reporter = try makeReporter()
        IssueStubURL.status = 201
        IssueStubURL.body = Data(#"{"id":""}"#.utf8)
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 1)
    }

    @Test func sentBodyHasRequiredAPIFields() async throws {
        let reporter = try makeReporter()
        reporter.enqueue(kind: "crash")
        let fileData = try #require(try reporter.firstQueuedPayload())
        await reporter.flush()
        #expect(IssueStubURL.hits == 1)
        let data = try #require(IssueStubURL.lastRequestBody ?? Optional(fileData))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["schema"] as? Int == 2)
        #expect(object["kind"] as? String == "crash")
        let app = try #require(object["app"] as? [String: Any])
        #expect((app["version"] as? String)?.isEmpty == false)
        let system = try #require(object["system"] as? [String: Any])
        #expect((system["macOS"] as? String)?.isEmpty == false)
    }

    @Test func legacyOKBodyRetries() async throws {
        let reporter = try makeReporter()
        IssueStubURL.status = 200
        IssueStubURL.body = Data(#"{"ok":true}"#.utf8)
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 1)
    }

    @Test func unprocessableEntityDropsFile() async throws {
        let reporter = try makeReporter()
        IssueStubURL.status = 422
        reporter.enqueue(kind: "crash")
        await reporter.flush()
        try expectQueued(reporter, 0)
    }

    @Test func successWithoutOKBodyStaysAndBacksOff() async throws {
        let clock = LockedDate(Date(timeIntervalSince1970: 1_700_000_000))
        var lines: [String] = []
        let reporter = try makeReporter(now: { clock.value }, log: { lines.append($0) })
        IssueStubURL.status = 201
        IssueStubURL.body = Data("<html>tracker</html>".utf8)
        reporter.enqueue(kind: "crash")
        let id = try #require(try reporter.firstQueuedIssueID())
        await reporter.flush()
        try expectQueued(reporter, 1)
        #expect(IssueStubURL.hits == 1)
        #expect(lines.contains { $0.contains("status=201") && $0.contains("body=nicht-ok") })
        let first = try #require(reporter.nextRetry(id: id))
        #expect(first.attempts == 1)
        #expect(abs(first.next.timeIntervalSince(clock.value) - 3_600) < 1)
        await reporter.flush()
        #expect(IssueStubURL.hits == 1)
        clock.value = first.next
        await reporter.flush()
        #expect(IssueStubURL.hits == 2)
        let second = try #require(reporter.nextRetry(id: id))
        #expect(second.attempts == 2)
        #expect(abs(second.next.timeIntervalSince(clock.value) - 7_200) < 1)
    }

    @Test func errorsAreNotSentAsReports() throws {
        let reporter = try makeReporter()
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

    @Test func leakCheckBlocksAnInjectedPath() {
        let json = #"{"schema":2,"logTail":["/Volumes/KUNDE/geheim"]}"#
        #expect(ReportScrubber.leakCategory(in: json, names: []) == "path")
        #expect(ReportScrubber.leakCategory(in: #"{"ok":true}"#, names: ["Archiv"]) == nil)
        #expect(ReportScrubber.leakCategory(in: #"{"name":"Archivplatte"}"#, names: ["Archiv"]) == "name")
    }

    @Test func payloadHasTheContractFields() throws {
        let reporter = try makeReporter()
        reporter.enqueue(kind: "crash")
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
        let reporter = try makeReporter()
        for _ in 0..<51 {
            reporter.enqueue(kind: "crash")
        }
        try expectQueued(reporter, 50)
    }

    @Test func parallelFlushSendsOnce() async throws {
        let reporter = try makeReporter()
        IssueStubURL.responseDelayNanoseconds = 200_000_000
        defer { IssueStubURL.responseDelayNanoseconds = 0 }
        reporter.enqueue(kind: "crash")
        async let first: Void = reporter.flush()
        async let second: Void = reporter.flush()
        _ = await (first, second)
        #expect(IssueStubURL.hits == 1)
        try expectQueued(reporter, 0)
    }

    @Test func leakBlockedRowStaysOutOfDueAndSkipsResend() async throws {
        let reporter = try makeReporter()
        let pool = try #require(reporter.queuePool)
        let id = UUID().uuidString
        let payload = Data(#"{"schema":2,"id":"\#(id)","kind":"crash","logTail":["/Volumes/KUNDE/geheim"]}"#.utf8)
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: payload, createdAt: 1)
        await reporter.flush()
        #expect(IssueStubURL.hits == 0)
        try expectQueued(reporter, 1)
        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        #expect(row.info?.hasPrefix("blocked:leak=") == true)
        #expect(try ApiQueuePersistence.fetchDue(pool, now: Date()).isEmpty)
        IssueStubURL.hits = 0
        await reporter.flush()
        #expect(IssueStubURL.hits == 0)
    }

    @Test func enqueueSurvivesConcurrentExclusiveWrite() async throws {
        let reporter = try makeReporter()
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

    @Test func migratesLegacyOutboxFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyID = UUID().uuidString
        let legacyBody = Data(#"{"schema":2,"id":"\#(legacyID)","kind":"crash"}"#.utf8)
        FileManager.default.createFile(atPath: directory.appendingPathComponent("\(legacyID).json").path, contents: legacyBody)
        let reporter = try makeReporter(outboxDirectory: directory)
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
    let count = try reporter.queuedReportCount()
    #expect(count == expected)
}

private func makeReporter(
    release: Bool = false,
    now: @escaping () -> Date = { Date() },
    log: @escaping (String) -> Void = { _ in },
    outboxDirectory: URL? = nil
) throws -> IssueReporter {
    IssueStubURL.status = 201
    IssueStubURL.body = Data(#"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890"}"#.utf8)
    IssueStubURL.fail = false
    IssueStubURL.hits = 0
    IssueStubURL.lastRequestBody = nil
    IssueStubURL.responseDelayNanoseconds = 0
    let directory = outboxDirectory ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    if outboxDirectory == nil {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let dbDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let pool = try ApiQueuePersistence.openQueuePool(at: dbDirectory.appendingPathComponent("archive.sqlite"))
    let defaults = UserDefaults(suiteName: "diskindex-issue-\(UUID().uuidString)")!
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [IssueStubURL.self]
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
    return reporter
}

/// Sync-Gate für `pool.write` (kein `DispatchSemaphore.wait` im async-Testpfad, bug.0.4.010).
private final class ExclusiveWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private let releaseSem = DispatchSemaphore(value: 0)
    private var entered = false

    var hasEntered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return entered
    }

    func markEntered() {
        lock.lock()
        entered = true
        lock.unlock()
    }

    func waitForRelease(timeoutSeconds: Double) {
        _ = releaseSem.wait(timeout: .now() + timeoutSeconds)
    }

    func release() {
        releaseSem.signal()
    }
}

//
//  IssueTracker.swift
//  diskindex
//
//  Berichte an den Issue-Tracker (Aufgabe 61). Warteschlange in `api_queue` (0.3.1).
//

import Darwin
import Foundation
import GRDB

nonisolated enum ReportTarget {
    #if DEBUG
    static let endpoint = URL(string: "http://localhost:8888/disk-archive/api/issues/")!
    #else
    static let endpoint = URL(string: "https://diskarchive.app/api/issues/")!
    #endif
}

nonisolated enum IssueConsent {
    static let legacyAutoSendKey = "diskindex.autoSendCrashReports"

    static func autoSendEnabled() -> Bool {
        AppSettingsRuntimeCache.autoSendEnabled()
    }

    static func setAutoSendEnabled(_ enabled: Bool) {
        AppSettingsRuntimeCache.setAutoSend(enabled)
        Task { @MainActor in
            AppDelegateBridge.appState.setAutoSendCrashReports(enabled)
        }
    }
}

nonisolated enum IssueEndpointPolicy {
    static func allows(_ url: URL, release: Bool) -> Bool {
        if url.scheme == "https" { return true }
        if release { return false }
        return url.scheme == "http" && url.host == "localhost"
    }
}

nonisolated struct IssueDraft: Equatable {
    var kind: String
    var signature: String
    var actions: [String]
    var logTail: [String]
    var crashSignal: String?
    var crashStack: [String]
    var media: Int
    var items: Int
    var dbBytes: Int
}

nonisolated enum IssuePayload {
    static let bodyLimit = 256 * 1024
    static let lineLimit = 500

    static func json(
        draft: IssueDraft,
        id: String,
        version: String,
        build: String,
        config: String,
        macOS: String,
        model: String,
        runtimeSeconds: Int,
        createdAt: Date
    ) -> Data {
        var actions = clipped(draft.actions, limit: 50)
        var logTail = clipped(draft.logTail, limit: 100)
        var data = encode(
            draft: draft, id: id, version: version, build: build, config: config,
            macOS: macOS, model: model, runtimeSeconds: runtimeSeconds, createdAt: createdAt,
            actions: actions, logTail: logTail
        )
        while data.count > bodyLimit, !logTail.isEmpty {
            logTail.removeLast()
            data = encode(
                draft: draft, id: id, version: version, build: build, config: config,
                macOS: macOS, model: model, runtimeSeconds: runtimeSeconds, createdAt: createdAt,
                actions: actions, logTail: logTail
            )
        }
        while data.count > bodyLimit, !actions.isEmpty {
            actions.removeLast()
            data = encode(
                draft: draft, id: id, version: version, build: build, config: config,
                macOS: macOS, model: model, runtimeSeconds: runtimeSeconds, createdAt: createdAt,
                actions: actions, logTail: logTail
            )
        }
        return data
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter.string(from: date)
    }

    private static func clipped(_ lines: [String], limit: Int) -> [String] {
        lines.suffix(limit).map { String($0.prefix(lineLimit)) }
    }

    private static func encode(
        draft: IssueDraft,
        id: String,
        version: String,
        build: String,
        config: String,
        macOS: String,
        model: String,
        runtimeSeconds: Int,
        createdAt: Date,
        actions: [String],
        logTail: [String]
    ) -> Data {
        let object: [String: Any] = [
            "schema": 2,
            "id": id,
            "kind": "crash",
            "createdAt": timestamp(createdAt),
            "app": ["version": version, "build": build, "config": config],
            "system": ["macOS": macOS, "model": model],
            "runtimeSeconds": runtimeSeconds,
            "signature": String(draft.signature.prefix(lineLimit)),
            "crash": [
                "signal": draft.crashSignal ?? "unknown",
                "stack": draft.crashStack.map { String($0.prefix(lineLimit)) },
            ],
            "actions": actions,
            "logTail": logTail,
            "inventory": ["media": draft.media, "items": draft.items, "dbBytes": draft.dbBytes],
        ]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }
}

nonisolated struct IssueRetry: Equatable, Codable {
    var attempts: Int
    var next: Date

    static func delay(afterAttempt attempts: Int) -> TimeInterval {
        let hours = min(24, pow(2, Double(max(0, attempts - 1))))
        return hours * 3_600
    }
}

nonisolated final class IssueReporter: @unchecked Sendable {
    static let shared = IssueReporter()

    var endpoint: URL
    /// Legacy-Outbox nur für Migration und Tests.
    var directory: URL
    var queuePool: DatabasePool?
    var defaults: UserDefaults
    var session: URLSession
    var releaseBuild: Bool
    var now: () -> Date
    var log: (String) -> Void
    var makeDraft: (String) -> IssueDraft
    var knownNames: () -> [String]

    var sendsImmediately = true
    private let reachability = ApiQueueReachability()
    private let flushGate = IssueReporterFlushGate()
    private var started = false
    private static let queuePersistAttempts = 3
    /// Mediennamen einmal beim Start geladen (bug.0.4.012 b) — nicht auf dem Main Thread.
    private let knownNamesLock = NSLock()
    private var cachedKnownNames: [String] = []

    init(
        endpoint: URL = ReportTarget.endpoint,
        directory: URL? = nil,
        queuePool: DatabasePool? = nil,
        defaults: UserDefaults = AppDefaults.current,
        session: URLSession? = nil,
        releaseBuild: Bool = false,
        now: @escaping () -> Date = { Date() },
        log: ((String) -> Void)? = nil,
        makeDraft: ((String) -> IssueDraft)? = nil
    ) {
        self.endpoint = endpoint
        self.queuePool = queuePool
        self.defaults = defaults
        self.releaseBuild = releaseBuild
        self.now = now
        self.log = log ?? { DiskIndexLog.shared.record(.app, .info, $0) }
        self.makeDraft = makeDraft ?? { kind in Self.liveDraft(kind: kind) }
        self.knownNames = { [] }
        if let directory {
            self.directory = directory
        } else if let base = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            self.directory = base.appendingPathComponent("Disk Archive/outbox", isDirectory: true)
        } else {
            self.directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("diskindex-outbox", isDirectory: true)
        }
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 10
            self.session = URLSession(configuration: configuration)
        }
        #if DEBUG
        if releaseBuild == false, session == nil {
            self.releaseBuild = false
        }
        #else
        if session == nil {
            self.releaseBuild = true
        }
        #endif
        reachability.onFlush = { [weak self] in
            self?.flushInBackground()
        }
        reachability.queueHasWork = { [weak self] in
            guard let self else { return false }
            guard let pool = try? self.resolvePool() else { return false }
            return (try? ApiQueuePersistence.hasDueWork(pool, kind: nil, now: self.now())) ?? false
        }
        knownNames = { [weak self] in
            guard let self else { return [] }
            self.knownNamesLock.lock()
            defer { self.knownNamesLock.unlock() }
            return self.cachedKnownNames
        }
    }

    func start() {
        guard !started else { return }
        started = true
        migrateLegacyOutboxFiles()
        refreshKnownNamesInBackground()
        reachability.start()
        syncReachabilityTimer()
        flushInBackground()
    }

    /// Mediennamen einmal im Hintergrund laden (bug.0.4.012 b).
    func refreshKnownNamesInBackground() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            var names: [String] = []
            if let url = try? IndexStoreV3.storeFileURL() {
                do {
                    let pool = try SchemaV3.openPool(at: url)
                    let store = IndexStoreV3(pool: pool)
                    let media = try await store.media()
                    names = media.map(\.name).filter { $0.count >= 4 }
                } catch {
                    names = []
                }
            }
            self.storeCachedKnownNames(names)
        }
    }

    private func storeCachedKnownNames(_ names: [String]) {
        knownNamesLock.lock()
        cachedKnownNames = names
        knownNamesLock.unlock()
    }

    #if DEBUG
    /// Tests: Cache sofort setzen (ohne Dateisystem).
    func setCachedKnownNamesForTesting(_ names: [String]) {
        storeCachedKnownNames(names)
    }
    #endif

    func noteError(category: String, message: String) {
        DiskIndexLog.shared.record(.app, .error, "index error category=\(category)")
    }

    func enqueue(kind: String) {
        guard kind == "crash" else { return }
        enqueue(makeDraft(kind))
    }

    func enqueue(_ draft: IssueDraft) {
        let id = UUID().uuidString
        let prepared = prepare(draft)
        let data = IssuePayload.json(
            draft: prepared,
            id: id,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            config: releaseBuild ? "Release" : "Debug",
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            model: Self.modelName(),
            runtimeSeconds: DiskIndexLog.shared.runtimeSeconds(),
            createdAt: now()
        )
        let createdAt = Int(now().timeIntervalSince1970)
        let persisted = persistReport(data: data, createdAt: createdAt, issueID: id)
        guard persisted else {
            fallbackOutboxReport(data: data, issueID: id)
            syncReachabilityTimer()
            if sendsImmediately { flushInBackground() }
            return
        }
        if let url = try? IndexStoreV3.storeFileURL() {
            FilePrivacy.restrict(url.deletingLastPathComponent())
        }
        log("app report queued kind=\(prepared.kind) id=\(id)")
        syncReachabilityTimer()
        if sendsImmediately { flushInBackground() }
    }

    func flushInBackground() {
        Task { await flushGate.run { await self.flushOnce() } }
    }

    func flush() async {
        await flushGate.run { await flushOnce() }
    }

    private func flushOnce() async {
        guard IssueEndpointPolicy.allows(endpoint, release: releaseBuild) else {
            log("app report failed kind=any id=- status=scheme")
            return
        }
        let pool: DatabasePool
        do {
            pool = try resolvePool()
        } catch {
            return
        }
        let moment = now()
        let due: [ApiQueueRow]
        do {
            due = try ApiQueuePersistence.fetchDue(pool, now: moment)
        } catch {
            return
        }
        for row in due {
            if let kind = ApiQueueKind(rawValue: row.kind), kind == .versionCheck {
                await sendVersionCheck(row: row, pool: pool)
                continue
            }
            guard let text = row.payload, let body = text.data(using: .utf8) else { continue }
            let issueID = ApiQueuePersistence.issueID(in: body) ?? "?"
            await send(row: row, body: body, issueID: issueID, pool: pool)
        }
        syncReachabilityTimer()
    }

    func discardPendingCrash() {
        guard let pool = try? resolvePool() else { return }
        try? ApiQueuePersistence.deleteAll(pool, kind: .issueReport)
        syncReachabilityTimer()
    }

    func nextRetry(id: String) -> IssueRetry? {
        guard let pool = try? resolvePool() else { return nil }
        return try? ApiQueuePersistence.nextRetry(pool, issueID: id)
    }

    func queuedReportCount() throws -> Int {
        try ApiQueuePersistence.count(try resolvePool(), kind: .issueReport)
    }

    func firstQueuedPayload() throws -> Data? {
        try ApiQueuePersistence.firstPayload(try resolvePool(), kind: .issueReport)
    }

    func firstQueuedIssueID() throws -> String? {
        guard let data = try firstQueuedPayload() else { return nil }
        return ApiQueuePersistence.issueID(in: data)
    }

    /// Tests: Datei-Outbox (Migration).
    func reportFiles() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return names.filter { $0.pathExtension == "json" }.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
    }

    private func resolvePool() throws -> DatabasePool {
        if let queuePool { return queuePool }
        return try ApiQueuePersistence.openQueuePool()
    }

    private func persistReport(data: Data, createdAt: Int, issueID: String) -> Bool {
        for attempt in 1...Self.queuePersistAttempts {
            do {
                let pool = try resolvePool()
                try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: data, createdAt: createdAt)
                return true
            } catch {
                if Self.isRetriableQueueError(error), attempt < Self.queuePersistAttempts {
                    Thread.sleep(forTimeInterval: 0.05 * Double(attempt))
                    continue
                }
                log("app report queue failed id=\(issueID) error=\(error.localizedDescription)")
                return false
            }
        }
        return false
    }

    private func fallbackOutboxReport(data: Data, issueID: String) {
        do {
            guard WriteGuard.permitsWrite(to: directory) else { return }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(issueID).json")
            guard WriteGuard.permitsWrite(to: url) else { return }
            try data.write(to: url, options: .atomic)
            log("app report queued kind=crash id=\(issueID) fallback=outbox")
        } catch {
            log("app report outbox failed id=\(issueID) error=\(error.localizedDescription)")
        }
    }

    private static func isRetriableQueueError(_ error: Error) -> Bool {
        guard let dbError = error as? DatabaseError else { return false }
        return dbError.resultCode == .SQLITE_BUSY || dbError.resultCode == .SQLITE_LOCKED
    }

    private func syncReachabilityTimer() {
        reachability.syncPeriodicTimer()
    }

    func migrateLegacyOutboxFiles() {
        let files = reportFiles()
        guard !files.isEmpty else { return }
        guard let pool = try? resolvePool() else { return }
        for url in files {
            guard let body = try? Data(contentsOf: url) else { continue }
            let created = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                .map { Int($0.timeIntervalSince1970) } ?? Int(now().timeIntervalSince1970)
            try? ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: body, createdAt: created)
            guard WriteGuard.permitsWrite(to: url) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
        try? ApiQueuePersistence.trim(pool)
    }

    private func sendVersionCheck(row: ApiQueueRow, pool: DatabasePool) async {
        let url = VersionCheckEndpoint.url
        guard IssueEndpointPolicy.allows(url, release: releaseBuild) else { return }
        let response = await VersionCheckClient.fetch(session: session, url: url)
        if response != nil {
            try? ApiQueuePersistence.delete(pool, rowID: row.id)
            log("version check ok")
            await MainActor.run {
                guard let store = AppDelegateBridge.appState.indexStore else { return }
                VersionCheckCoordinator.handleAPIResult(response, appState: AppDelegateBridge.appState, store: store, now: now())
            }
            return
        }
        scheduleRetry(row: row, pool: pool, info: "version-offline")
        log("version check failed")
    }

    private func send(row: ApiQueueRow, body: Data, issueID: String, pool: DatabasePool) async {
        let raw = String(decoding: body, as: UTF8.self)
        if let category = ReportScrubber.leakCategory(in: raw, names: knownNames()) {
            log("app report blocked:leak=\(category)")
            try? ApiQueuePersistence.markBlocked(pool, rowID: row.id, info: "blocked:leak=\(category)")
            syncReachabilityTimer()
            return
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10
        let kind = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["kind"] as? String ?? "?"
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 201 && Self.bodyAcceptsSuccess(data) {
                try? ApiQueuePersistence.delete(pool, rowID: row.id)
                log("app report sent kind=\(kind) id=\(issueID) status=\(status)")
                return
            }
            if (200...299).contains(status) {
                scheduleRetry(row: row, pool: pool, info: "status=\(status) body=nicht-ok")
                log("app report failed kind=\(kind) id=\(issueID) status=\(status) body=nicht-ok")
                return
            }
            if (400...499).contains(status), status != 408, status != 429 {
                try? ApiQueuePersistence.delete(pool, rowID: row.id)
                log("app report failed kind=\(kind) id=\(issueID) status=\(status)")
                return
            }
            scheduleRetry(row: row, pool: pool, info: "status=\(status)")
            log("app report failed kind=\(kind) id=\(issueID) status=\(status)")
        } catch {
            scheduleRetry(row: row, pool: pool, info: "offline")
            log("app report failed kind=\(kind) id=\(issueID) status=offline")
        }
    }

    private func scheduleRetry(row: ApiQueueRow, pool: DatabasePool, info: String) {
        let attempts = row.attempts + 1
        let lastTry = Int(now().timeIntervalSince1970)
        try? ApiQueuePersistence.recordFailure(pool, rowID: row.id, attempts: attempts, lastTryAt: lastTry, info: info)
    }

    private func prepare(_ draft: IssueDraft) -> IssueDraft {
        var copy = draft
        copy.kind = "crash"
        copy.signature = ReportScrubber.text(draft.signature)
        copy.actions = draft.actions.map(ReportScrubber.text)
        copy.logTail = draft.logTail.map(ReportScrubber.text)
        copy.crashStack = draft.crashStack.map(ReportScrubber.text)
        copy.crashSignal = draft.crashSignal.map(ReportScrubber.text)
        return copy
    }

    private static func liveDraft(kind: String) -> IssueDraft {
        let crash = DiskIndexLog.shared.crashExcerpt()
        let labels = IndexStoreV3.inventoryLabels()
        let bytes = ((try? IndexStoreV3.storeFileURL()).flatMap { url in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        })?.intValue ?? 0
        return IssueDraft(
            kind: kind,
            signature: kind == "crash" ? crash.signal : kind,
            actions: DiskIndexLog.shared.recentBreadcrumbs(),
            logTail: DiskIndexLog.shared.logTail(100),
            crashSignal: kind == "crash" ? crash.signal : nil,
            crashStack: kind == "crash" ? crash.stack : [],
            media: Int(labels.media) ?? 0,
            items: Int(labels.objects) ?? 0,
            dbBytes: bytes
        )
    }

    private static func modelName() -> String {
        var model = [CChar](repeating: 0, count: 128)
        var size = model.count
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private static func bodyAcceptsSuccess(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        guard let issueID = object["id"] as? String else { return false }
        return !issueID.isEmpty
    }
}

//
//  IssueTracker.swift
//  diskindex
//
//  Berichte an den Issue-Tracker (Aufgabe 61). Der JSON-Vertrag hat genau diese Felder.
//

import Darwin
import Foundation

nonisolated enum ReportTarget {
    #if DEBUG
    static let endpoint = URL(string: "http://localhost:8888/disk-archive/api/issues/")!
    #else
    static let endpoint = URL(string: "https://diskarchive.app/api/issues/")!
    #endif
}

nonisolated enum IssueConsent {
    static let autoSendKey = "diskindex.autoSendCrashReports"

    static func autoSendEnabled(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: autoSendKey)
    }

    static func setAutoSendEnabled(_ enabled: Bool, defaults: UserDefaults) {
        defaults.set(enabled, forKey: autoSendKey)
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
    var directory: URL
    var defaults: UserDefaults
    var session: URLSession
    var releaseBuild: Bool
    var now: () -> Date
    var log: (String) -> Void
    var makeDraft: (String) -> IssueDraft
    var knownNames: () -> [String]

    var sendsImmediately = true
    private var retries: [String: IssueRetry] = [:]
    private let lock = NSLock()
    private var timer: Timer?

    init(
        endpoint: URL = ReportTarget.endpoint,
        directory: URL? = nil,
        defaults: UserDefaults = AppDefaults.current,
        session: URLSession? = nil,
        releaseBuild: Bool = false,
        now: @escaping () -> Date = { Date() },
        log: ((String) -> Void)? = nil,
        makeDraft: ((String) -> IssueDraft)? = nil
    ) {
        self.endpoint = endpoint
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
    }

    func start() {
        flushInBackground()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3_600, repeats: true) { [weak self] _ in
            self?.flushInBackground()
        }
    }

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
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(id).json")
        FileManager.default.createFile(atPath: url.path, contents: data)
        FilePrivacy.restrict(directory)
        trimOutbox()
        log("app report queued kind=\(prepared.kind) id=\(id)")
        if sendsImmediately { flushInBackground() }
    }

    func flushInBackground() {
        Task { await flush() }
    }

    func flush() async {
        guard IssueEndpointPolicy.allows(endpoint, release: releaseBuild) else {
            log("app report failed kind=any id=- status=scheme")
            return
        }
        let files = reportFiles()
        let moment = now()
        for url in files {
            let id = url.deletingPathExtension().lastPathComponent
            if !isDue(id: id, moment: moment) { continue }
            await send(url: url, id: id)
        }
    }

    func discardPendingCrash() {
        for url in reportFiles() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func send(url: URL, id: String) async {
        guard let body = try? Data(contentsOf: url) else { return }
        let raw = String(decoding: body, as: UTF8.self)
        if let category = ReportScrubber.leakCategory(in: raw, names: knownNames()) {
            log("report blocked leak=\(category)")
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
                try? FileManager.default.removeItem(at: url)
                clearRetry(id)
                log("app report sent kind=\(kind) id=\(id) status=\(status)")
                return
            }
            if (200...299).contains(status) {
                scheduleRetry(id: id)
                log("app report failed kind=\(kind) id=\(id) status=\(status) body=nicht-ok")
                return
            }
            if (400...499).contains(status), status != 408, status != 429 {
                try? FileManager.default.removeItem(at: url)
                clearRetry(id)
                log("app report failed kind=\(kind) id=\(id) status=\(status)")
                return
            }
            scheduleRetry(id: id)
            log("app report failed kind=\(kind) id=\(id) status=\(status)")
        } catch {
            scheduleRetry(id: id)
            log("app report failed kind=\(kind) id=\(id) status=offline")
        }
    }

    private func isDue(id: String, moment: Date) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let retry = retries[id], moment < retry.next { return false }
        return true
    }

    private func clearRetry(_ id: String) {
        lock.lock()
        retries[id] = nil
        lock.unlock()
    }

    private func scheduleRetry(id: String) {
        lock.lock()
        let attempts = (retries[id]?.attempts ?? 0) + 1
        retries[id] = IssueRetry(attempts: attempts, next: now().addingTimeInterval(IssueRetry.delay(afterAttempt: attempts)))
        lock.unlock()
    }

    func nextRetry(id: String) -> IssueRetry? {
        lock.lock()
        defer { lock.unlock() }
        return retries[id]
    }

    func reportFiles() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return names.filter { $0.pathExtension == "json" }.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
    }

    private func trimOutbox() {
        var files = reportFiles()
        var total = files.reduce(0) { $0 + ((try? FileManager.default.attributesOfItem(atPath: $1.path)[.size] as? NSNumber)?.intValue ?? 0) }
        while files.count > 50 || total > 5 * 1024 * 1024, let oldest = files.first {
            let size = (try? FileManager.default.attributesOfItem(atPath: oldest.path)[.size] as? NSNumber)?.intValue ?? 0
            try? FileManager.default.removeItem(at: oldest)
            total -= size
            files.removeFirst()
        }
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
        let labels = IndexDatabase.inventoryLabels()
        let bytes = ((try? IndexDatabase.storeFileURL()).flatMap { url in
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

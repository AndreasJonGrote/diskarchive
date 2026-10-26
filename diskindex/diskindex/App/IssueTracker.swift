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

nonisolated enum IssueReporterError: Error {
    case noQueuePool
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
    /// bug.0.4.113: gesetzt, wenn der Bericht einen früheren Lauf beschreibt (Absturz beim Start des nächsten Laufs).
    var previousRun: PreviousRunInfo? = nil
}

nonisolated enum IssuePayload {
    static let bodyLimit = 256 * 1024
    static let lineLimit = 500
    /// So viele letzte Protokollzeilen bleiben beim Kürzen mindestens erhalten (bug.0.4.079).
    static let keptLogLines = 20

    static func json(
        draft: IssueDraft,
        id: String,
        version: String,
        build: String,
        config: String,
        macOS: String,
        model: String,
        runtimeSeconds: Int?,
        createdAt: Date
    ) -> Data {
        var actions = clipped(draft.actions, limit: 50)
        var logTail = clipped(draft.logTail, limit: 100)
        // todo.0.4.023: Der Stapel kommt aus dem Protokoll ab der letzten „CRASH“-Zeile und hat keine feste Länge;
        // er wird gekürzt, damit der Bericht nie über `bodyLimit` liegt (Reihenfolge unten, bug.0.4.083).
        var stack = draft.crashStack.map { String($0.prefix(lineLimit)) }
        var signature = String(draft.signature.prefix(lineLimit))
        var signal = String((draft.crashSignal ?? "unknown").prefix(lineLimit))
        func make() -> Data {
            encode(
                draft: draft, id: id, version: version, build: build, config: config,
                macOS: macOS, model: model, runtimeSeconds: runtimeSeconds, createdAt: createdAt,
                actions: actions, logTail: logTail, stack: stack,
                signature: signature, signal: signal
            )
        }
        var data = make()
        // bug.0.4.083 (Host-Entscheidung 18.10., ersetzt die Reihenfolge aus bug.0.4.079): (1) Brotkrumen im Stapel
        // (Zeilen ohne Rahmenform, älteste zuerst), (2) Rahmen von hinten bis auf Rahmen 0 (Signal und Kopf bleiben),
        // (3) `logTail` von vorn bis auf `keptLogLines`, (4) `actions`, (5) Sicherung: Rest von Protokoll und Stapel.
        let frame = try? NSRegularExpression(pattern: ReportScrubber.stackFramePattern)
        func isFrame(_ line: String) -> Bool {
            frame?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
        }
        while data.count > bodyLimit, let crumb = stack.firstIndex(where: { !isFrame($0) }) {
            stack.remove(at: crumb)
            data = make()
        }
        func trimStack(keeping minimum: Int) {
            while data.count > bodyLimit, stack.count > minimum {
                stack.removeLast(max(1, min(stack.count - minimum, (data.count - bodyLimit) / (lineLimit * 4))))
                data = make()
            }
        }
        trimStack(keeping: 1)
        while data.count > bodyLimit, logTail.count > keptLogLines {
            logTail.removeFirst()
            data = make()
        }
        while data.count > bodyLimit, !actions.isEmpty {
            actions.removeLast()
            data = make()
        }
        while data.count > bodyLimit, !logTail.isEmpty {
            logTail.removeFirst()
            data = make()
        }
        trimStack(keeping: 0)
        // Letzte Sicherung: Signatur und Signal sind schon auf `lineLimit` gekürzt; reicht das nicht, kürzer.
        if data.count > bodyLimit {
            signature = String(signature.prefix(64))
            signal = String(signal.prefix(64))
            data = make()
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
        runtimeSeconds: Int?,
        createdAt: Date,
        actions: [String],
        logTail: [String],
        stack: [String],
        signature: String,
        signal: String
    ) -> Data {
        var object: [String: Any] = [
            "schema": 2,
            "id": id,
            "kind": "crash",
            "createdAt": timestamp(createdAt),
            "app": ["version": version, "build": build, "config": config],
            "system": ["macOS": macOS, "model": model],
            "signature": signature,
            "crash": [
                "signal": signal,
                "stack": stack,
            ],
            "actions": actions,
            "logTail": logTail,
            "inventory": ["media": draft.media, "items": draft.items, "dbBytes": draft.dbBytes],
        ]
        // bug.0.4.164 (d): unbekannte Laufzeit weglassen statt `null`.
        if let runtimeSeconds { object["runtimeSeconds"] = runtimeSeconds }
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
    private let queuePoolLock = NSLock()
    private var _queuePool: DatabasePool?
    var queuePool: DatabasePool? {
        get {
            queuePoolLock.lock()
            defer { queuePoolLock.unlock() }
            return _queuePool
        }
        set {
            queuePoolLock.lock()
            _queuePool = newValue
            queuePoolLock.unlock()
            // bug.0.4.094: Namen erst laden, wenn verdrahtet ist (die Migration ist dann durch).
            if newValue != nil, started { refreshKnownNamesInBackground() }
        }
    }
    var session: URLSession
    var releaseBuild: Bool
    var now: () -> Date
    var log: (String) -> Void
    var makeDraft: (String) -> IssueDraft
    var knownNames: () -> [String]
    /// Die Datenbank des Prozesses (bug.0.4.086): vor dem Verdrahten (`queuePool`) nur über sie, nie ein eigener Pool.
    let archive: ArchiveDatabase
    /// Protokoll, aus dem der Bericht entsteht (todo.0.4.023): Standard `DiskIndexLog.shared`; Tests geben
    /// eine eigene Instanz mit eigenem Ordner mit, damit der echte Weg ohne Prozesszustand prüfbar ist.
    let diskLog: DiskIndexLog

    var sendsImmediately = true
    private let reachability = ApiQueueReachability()
    private let flushGate = IssueReporterFlushGate()
    private let dbQueue = DispatchQueue(label: "app.diskarchive.issue-reporter-db", qos: .utility)
    private var started = false
    private static let queuePersistAttempts = 3
    /// Mediennamen einmal beim Start geladen (bug.0.4.012 b) — nicht auf dem Main Thread.
    private let knownNamesLock = NSLock()
    private var cachedKnownNames: [String] = []

    init(
        endpoint: URL = ReportTarget.endpoint,
        directory: URL? = nil,
        queuePool: DatabasePool? = nil,
        session: URLSession? = nil,
        releaseBuild: Bool = false,
        now: @escaping () -> Date = { Date() },
        log: ((String) -> Void)? = nil,
        makeDraft: ((String) -> IssueDraft)? = nil,
        diskLog: DiskIndexLog? = nil,
        archive: ArchiveDatabase = .shared
    ) {
        self.archive = archive
        let diskLog = diskLog ?? DiskIndexLog.shared
        self.diskLog = diskLog
        self.endpoint = endpoint
        self._queuePool = queuePool
        self.releaseBuild = releaseBuild
        self.now = now
        self.log = log ?? { DiskIndexLog.shared.record(.app, .info, $0) }
        self.knownNames = { [] }
        if let directory {
            self.directory = directory
        } else if (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) != nil {
            self.directory = AppDataFolder.url.appendingPathComponent("outbox", isDirectory: true)
        } else {
            // bug.0.4.208: Ausweichweg nur, wenn der Datenordner nicht anzulegen ist.
            self.directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("diskindex-outbox", isDirectory: true)
            diskLog.record(.app, .error, "outbox im temporären ordner, datenordner nicht anlegbar")
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
        // Eigene Warteschlange, nicht die von `shared` (todo.0.4.023; in der App ist beides dieselbe Instanz).
        // Erst ohne `self` belegen, weil der Abschluss `self` erst nach voller Initialisierung fassen darf.
        self.makeDraft = makeDraft ?? { kind in Self.liveDraft(kind: kind, pool: nil, log: diskLog) }
        if makeDraft == nil {
            self.makeDraft = { [weak self] kind in Self.liveDraft(kind: kind, pool: self?.queuePool, log: diskLog) }
        }
        reachability.onFlush = { [weak self] in
            self?.flushInBackground()
        }
        reachability.now = { [weak self] in self?.now() ?? Date() }
        reachability.queueSchedule = { [weak self] in
            guard let self, let pool = try? self.resolvePool() else { return (false, nil) }
            return (try? ApiQueuePersistence.schedule(pool, now: self.now())) ?? (false, nil)
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
        refreshKnownNamesInBackground()
        reachability.start()
        syncReachabilityTimer()
        flushInBackground()
    }

    /// Mediennamen einmal im Hintergrund laden (bug.0.4.012 b). Auf `dbQueue` (todo.0.4.023): `flushOnce` wartet
    /// dort zuerst, so prüft der Leak-Wächter schon beim ersten Senden nach `start()` gegen die geladenen Namen
    /// (vorher eigener Task: in etwa 1 von 6 Läufen wurde vor dem Laden gesendet).
    func refreshKnownNamesInBackground() {
        dbQueue.async { [weak self] in
            guard let self else { return }
            var names: [String] = []
            do {
                if let pool = self.queuePool {
                    names = try pool.read { try MediumCodecV3.fetchAll($0) }.map(\.name)
                } else if let pool = self.archive.openedPool {
                    // bug.0.4.094: nur über den schon geöffneten Pool (derselbe wie der Index). Wer hier warten würde,
                    // hielte einen Faden die ganze Migration lang fest; die Namen kommen beim nächsten Senden nach.
                    names = try pool.read { try MediumCodecV3.fetchAll($0) }.map(\.name)
                } else {
                    return
                }
            } catch {
                // bug.0.4.162 (a): ein kurzer Lesefehler schaltet den Namens-Wächter nicht ab – alter Stand bleibt.
                return
            }
            self.storeCachedKnownNames(names.filter { $0.count >= 4 })
        }
    }

    private func storeCachedKnownNames(_ names: [String]) {
        knownNamesLock.lock()
        cachedKnownNames = names
        knownNamesLock.unlock()
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
            // bug.0.4.164 (d): fehlt der Wert des abgestürzten Laufs, „?“ (wie beim fehlenden Bundle-Wert).
            version: draft.previousRun.map { $0.version ?? "?" }
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: draft.previousRun.map { $0.build ?? "?" }
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            config: releaseBuild ? "Release" : "Debug",
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            model: Self.modelName(),
            runtimeSeconds: draft.previousRun != nil ? draft.previousRun?.runtimeSeconds : diskLog.runtimeSeconds(),
            createdAt: now()
        )
        let createdAt = Int(now().timeIntervalSince1970)
        let kind = prepared.kind
        dbQueue.async { [weak self] in
            guard let self else { return }
            let persisted = self.persistReport(data: data, createdAt: createdAt, issueID: id)
            if !persisted {
                self.fallbackOutboxReport(data: data, issueID: id)
            } else {
                self.log("app report queued kind=\(kind) id=\(id)")
            }
        }
        syncReachabilityTimer()
        if sendsImmediately { flushInBackground() }
    }

    #if DEBUG
    /// Tests (bug.0.4.110): Zeitgeber der Warteschlange nach dem Umstellen.
    var reachabilityTimersForTesting: (periodic: Bool, wakeFireDate: Date?) { reachability.timersForTesting }
    /// Tests (bug.0.4.162 h): Netzbeobachtung und Zeitgeber dieses Reporters beenden.
    func stopReachabilityForTesting() { reachability.stop() }
    func syncReachabilityTimerForTesting() { reachability.syncPeriodicTimer() }

    func waitForPendingEnqueuesForTesting() {
        dbQueue.sync { }
    }
    #endif

    func flushInBackground() {
        Task { await flushGate.run { await self.flushOnce() } }
    }

    func flush() async {
        await flushGate.run { await self.flushOnce() }
    }

    private func flushOnce() async {
        dbQueue.sync { }
        // bug.0.4.111: Namen vor dem Senden neu laden (ein später angeschlossenes Medium gilt sofort für den Leak-Wächter).
        refreshKnownNamesInBackground()
        dbQueue.sync { }
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

    func nextRetry(id: String) -> IssueRetry? {
        guard let pool = try? resolvePool() else { return nil }
        return try? ApiQueuePersistence.nextRetry(pool, issueID: id)
    }

    #if DEBUG
    func queuedReportCount() throws -> Int {
        try ApiQueuePersistence.count(try resolvePool(), kind: .issueReport)
    }
    #endif

    func firstQueuedPayload() throws -> Data? {
        try ApiQueuePersistence.firstPayload(try resolvePool(), kind: .issueReport)
    }

    #if DEBUG
    func firstQueuedIssueID() throws -> String? {
        guard let data = try firstQueuedPayload() else { return nil }
        return ApiQueuePersistence.issueID(in: data)
    }
    #endif

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
        guard let queuePool else { throw IssueReporterError.noQueuePool }
        return queuePool
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
                log("app report queue failed id=\(issueID) error=\(DiskIndexLog.errorSummary(error))")
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
            log("app report outbox failed id=\(issueID) error=\(DiskIndexLog.errorSummary(error))")
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
            do {
                try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: body, createdAt: created)
            } catch {
                continue
            }
            guard WriteGuard.permitsWrite(to: url) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
        try? ApiQueuePersistence.trim(pool)
    }

    /// bug.0.4.137: auf dem Main Actor nur Einstieg und Anwenden; Datenbank im Hintergrund (`handleAPIResult`).
    @MainActor
    private static func applyVersionCheck(_ response: VersionCheckResponse?, now: Date) async {
        guard let store = AppDelegateBridge.appState.indexStore else { return }
        await VersionCheckCoordinator.handleAPIResult(response, appState: AppDelegateBridge.appState, store: store, now: now)
    }

    private func sendVersionCheck(row: ApiQueueRow, pool: DatabasePool) async {
        let url = VersionCheckEndpoint.url
        guard IssueEndpointPolicy.allows(url, release: releaseBuild) else { return }
        let outcome = await VersionCheckClient.fetchOutcome(session: session, url: url)
        let response = outcome.response
        if response != nil {
            try? ApiQueuePersistence.delete(pool, rowID: row.id)
            log("version check ok")
            let checkedAt = now()
            await Self.applyVersionCheck(response, now: checkedAt)
            return
        }
        // bug.0.4.145: keine Verbindung zählt nicht gegen die Obergrenze (wie bei den Berichten), eigener Protokolltext.
        if outcome.offline {
            scheduleRetry(row: row, pool: pool, info: "offline")
            log("version check offline")
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
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // todo.0.4.029: jedes 201 gilt als Erfolg, `id` im Antwortkörper ist optional.
            if status == 201 {
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
            let info = Self.isOfflineNetworkError(error) ? "offline" : "error"
            scheduleRetry(row: row, pool: pool, info: info)
            log("app report failed kind=\(kind) id=\(issueID) status=\(info)")
        }
    }

    /// bug.0.4.109: Nur „keine Verbindung“ gilt als offline (immer fällig, sobald das Netz da ist). Zeitüberschreitung,
    /// Host nicht erreichbar oder Abbruch laufen über den Backoff – sonst ginge derselbe Bericht jede Minute raus
    /// (bei Zeitüberschreitung kam er oft schon an: doppelte Berichte).
    private static func isOfflineNetworkError(_ error: Error) -> Bool {
        (error as? URLError)?.code == .notConnectedToInternet
    }

    /// bug.0.4.109: Obergrenze der gescheiterten Versuche (Host: 10), danach wird der Eintrag verworfen.
    static let maxFailedAttempts = 10

    private func scheduleRetry(row: ApiQueueRow, pool: DatabasePool, info: String) {
        // „offline“ zählt nicht gegen die Obergrenze (kein Versuch beim Server).
        let attempts = info == "offline" ? row.attempts : row.attempts + 1
        // Ältere Zeilen zählten „offline“ jede Minute hoch: die Obergrenze gilt nur für echte Versuche beim Server.
        if info != "offline", attempts >= Self.maxFailedAttempts {
            try? ApiQueuePersistence.delete(pool, rowID: row.id)
            log("app report dropped attempts=\(attempts)")
            return
        }
        let lastTry = Int(now().timeIntervalSince1970)
        try? ApiQueuePersistence.recordFailure(pool, rowID: row.id, attempts: attempts, lastTryAt: lastTry, info: info)
    }

    private func prepare(_ draft: IssueDraft) -> IssueDraft {
        var copy = draft
        copy.kind = "crash"
        copy.signature = ReportScrubber.text(draft.signature)
        copy.actions = draft.actions.map(ReportScrubber.text)
        copy.logTail = draft.logTail.map(ReportScrubber.text)
        copy.crashStack = draft.crashStack.map(ReportScrubber.stackLine)
        copy.crashSignal = draft.crashSignal.map(ReportScrubber.text)
        return copy
    }

    private static func liveDraft(kind: String, pool: DatabasePool?, log: DiskIndexLog) -> IssueDraft {
        let crash = log.crashExcerpt()
        let labels = IndexStoreV3.inventoryLabels(using: pool)
        let databaseURL = pool.map { URL(fileURLWithPath: $0.path) } ?? (try? IndexStoreV3.storeFileURL())
        let bytes = (databaseURL.flatMap { url in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        })?.intValue ?? 0
        return IssueDraft(
            kind: kind,
            signature: kind == "crash" ? crash.signal : kind,
            // bug.0.4.113: Ein Absturzbericht beschreibt den abgestürzten Lauf – seine Aktionen aus dem Absturzteil
            // (fehlen sie: leer), nie die des neuen Laufs.
            actions: kind == "crash" ? log.crashBreadcrumbs() : log.recentBreadcrumbs(),
            logTail: log.logTail(100),
            crashSignal: kind == "crash" ? crash.signal : nil,
            crashStack: kind == "crash" ? crash.stack : [],
            media: Int(labels.media) ?? 0,
            items: Int(labels.objects) ?? 0,
            dbBytes: bytes,
            previousRun: kind == "crash" ? log.previousRunInfo() : nil
        )
    }

    private static func modelName() -> String {
        var model = [CChar](repeating: 0, count: 128)
        var size = model.count
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}

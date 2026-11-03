//
//  DiskArchiveLog.swift
//  DiskArchive
//
//  Protokoll auf der Platte (Aufgabe 53). Jede Zeile wird sofort geschrieben.
//

import AppKit
import Darwin
import Foundation
import OSLog

enum DiskLogCategory: String {
    case app, medium, index, watcher, store, ui, perf
}

enum DiskLogLevel: String {
    case info, error
}

nonisolated final class DiskArchiveLog: @unchecked Sendable {
    static let shared = DiskArchiveLog()

    static let fileName = "diskarchive.log"
    private static let breadcrumbLimit = 50
    private static let defaultByteLimit = 5 * 1024 * 1024

    private let directory: URL
    private let byteLimit: Int
    private let writesToDisk: Bool
    private let lock = NSLock()
    private var handle: FileHandle?
    private var breadcrumbs: [String] = []
    private var startedAt = Date()
    /// bug.0.4.113: Dieser Lauf hat seine Startzeile geschrieben (unter `lock`).
    private var wroteOwnStartLine = false
    private(set) var shouldShowCrashDialog = false
    /// Der Lauf davor endete ohne „app terminate ok“ (Aufgabe 219: dann `quick_check`).
    private(set) var previousRunUnclean = false
    /// Fehler aus Speicher, Index, Überwachung und Medien (Aufgabe 61). Nicht im Signal-Handler setzen.
    /// Gesetzt auf main, gelesen von allen Threads (bug.0.4.062, REPORT 132): eigene Sperre, Aufruf außerhalb davon.
    var onTrackedError: ((String, String) -> Void)? {
        get { trackedErrorLock.withLock { trackedErrorHandler } }
        set { trackedErrorLock.withLock { trackedErrorHandler = newValue } }
    }
    private let trackedErrorLock = NSLock()
    private var trackedErrorHandler: ((String, String) -> Void)?
    // bug.0.4.041: Alles, was der Signal-Handler liest, liegt in einmal angelegtem Rohspeicher
    // (`let`-Zeiger, kein Swift-Array, keine Exklusivitätsprüfung, keine Allokation im Handler).
    private static let crumbSlots = 50
    private static let crumbSlotBytes = 240
    private static let frameCapacity = 64
    private static let headerSlotBytes = 32
    private static let crashFileBytes: off_t = 64 * 1024
    /// Signale mit eigenem Kopf; der letzte Platz ist der Kopf für unbekannte Signale.
    private static let crashSignalNames: [(Int32, String)] = [
        (SIGABRT, "SIGABRT"), (SIGILL, "SIGILL"), (SIGTRAP, "SIGTRAP"), (SIGSEGV, "SIGSEGV"), (SIGBUS, "SIGBUS"),
    ]
    private let crumbs: UnsafeMutablePointer<UInt8>
    private let crumbLength: UnsafeMutablePointer<UInt16>
    /// [0] nächster Platz, [1] gefüllte Plätze.
    private let crumbCursor: UnsafeMutablePointer<Int>
    /// [0] `crash-last.txt`, [1] Protokoll (`O_APPEND`).
    private let descriptors: UnsafeMutablePointer<Int32>
    private let frames: UnsafeMutablePointer<UnsafeMutableRawPointer?>
    private let headerSignals: UnsafeMutablePointer<Int32>
    private let headerBytes: UnsafeMutablePointer<UInt8>
    private let headerLengths: UnsafeMutablePointer<Int>
    private let headerCount: Int
    private let altStack = UnsafeMutableRawPointer.allocate(byteCount: 32 * 1024, alignment: 16)
    private let diskQueueKey = DispatchSpecificKey<UInt8>()
    private var crashFD: Int32 {
        get { descriptors[0] }
        set { descriptors[0] = newValue }
    }
    private var logFD: Int32 {
        get { descriptors[1] }
        set { descriptors[1] = newValue }
    }
    private var handlersInstalled = false
    /// bug.0.4.196: Stempel mit Zeitzonen-Versatz („2026-10-25 02:30:00.000+02:00“) – eindeutig auch in der doppelten
    /// Stunde der Zeitumstellung; lesbar bleibt die Ortszeit. Schreiben und Lesen nur über `formatter`/`lineDate`.
    private let formatter: DateFormatter
    /// Alte Zeilen ohne Versatz (vor bug.0.4.196) werden weiter als Ortszeit gelesen.
    private let legacyFormatter: DateFormatter
    /// Namen archivierter Absturzdateien in UTC: sortierbar über die Umstellung hinweg.
    private let fileFormatter: DateFormatter
    private let loggers: [DiskLogCategory: Logger]
    private let diskWriteQueue = DispatchQueue(label: "app.diskarchive.log-disk", qos: .utility)

    /// Auto-Senden von Absturzberichten beim Start: je Instanz (bug.0.3.9.004/bug.0.4.041). Das gemeinsame Protokoll
    /// liest die Einstellung; Instanzen mit eigenem Ordner (Tests) senden nie und hängen so nicht am Prozesszustand.
    let crashAutoSendEnabled: () -> Bool
    /// Ziel für den automatisch gesendeten Absturzbericht (bug.0.3.9.010): Standard `IssueReporter.shared`,
    /// erst beim Senden aufgelöst; Tests geben eine eigene Instanz mit eigener Warteschlange mit.
    private let crashReporter: () -> IssueReporter
    /// bug.0.4.196: Uhr und Zeitzone der Stempel je Instanz (Tests: feste Zeit in der doppelten Stunde, ohne echte Uhr).
    private let now: @Sendable () -> Date

    init(
        directory: URL? = nil,
        byteLimit: Int = DiskArchiveLog.defaultByteLimit,
        crashAutoSend: (() -> Bool)? = nil,
        crashReporter: IssueReporter? = nil,
        timeZone: TimeZone = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.now = now
        self.crashAutoSendEnabled = crashAutoSend ?? (directory == nil ? { IssueConsent.autoSendEnabled() } : { false })
        if let crashReporter {
            self.crashReporter = { crashReporter }
        } else {
            self.crashReporter = { IssueReporter.shared }
        }
        self.writesToDisk = directory != nil || !RuntimeEnvironment.isRunningTests
        self.directory = directory ?? Self.defaultDirectory
        self.byteLimit = byteLimit
        func makeFormatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = format
            return formatter
        }
        self.formatter = makeFormatter("yyyy-MM-dd HH:mm:ss.SSSZZZZZ", timeZone)
        self.legacyFormatter = makeFormatter("yyyy-MM-dd HH:mm:ss.SSS", timeZone)
        self.fileFormatter = makeFormatter("yyyy-MM-dd_HH-mm-ss.SSS'Z'", TimeZone(identifier: "UTC") ?? timeZone)
        self.loggers = Dictionary(uniqueKeysWithValues: DiskLogCategory.allCases.map { category in
            (category, Logger(subsystem: "app.diskarchive", category: category.rawValue))
        })
        let slots = Self.crumbSlots
        crumbs = .allocate(capacity: slots * Self.crumbSlotBytes)
        crumbs.initialize(repeating: 0, count: slots * Self.crumbSlotBytes)
        crumbLength = .allocate(capacity: slots)
        crumbLength.initialize(repeating: 0, count: slots)
        crumbCursor = .allocate(capacity: 2)
        crumbCursor.initialize(repeating: 0, count: 2)
        descriptors = .allocate(capacity: 2)
        descriptors.initialize(repeating: -1, count: 2)
        frames = .allocate(capacity: Self.frameCapacity)
        frames.initialize(repeating: nil, count: Self.frameCapacity)
        let names = Self.crashSignalNames.map(\.1) + ["unknown"]
        headerCount = names.count
        headerSignals = .allocate(capacity: names.count)
        headerSignals.initialize(repeating: 0, count: names.count)
        headerBytes = .allocate(capacity: names.count * Self.headerSlotBytes)
        headerBytes.initialize(repeating: 0, count: names.count * Self.headerSlotBytes)
        headerLengths = .allocate(capacity: names.count)
        headerLengths.initialize(repeating: 0, count: names.count)
        for (slot, name) in names.enumerated() {
            if slot < Self.crashSignalNames.count {
                headerSignals[slot] = Self.crashSignalNames[slot].0
            }
            let bytes = Array("CRASH signal=\(name)\n".utf8.prefix(Self.headerSlotBytes))
            for (offset, byte) in bytes.enumerated() {
                headerBytes[slot * Self.headerSlotBytes + offset] = byte
            }
            headerLengths[slot] = bytes.count
        }
        diskWriteQueue.setSpecific(key: diskQueueKey, value: 1)
    }

    deinit {
        if descriptors[0] >= 0 { close(descriptors[0]) }
        if descriptors[1] >= 0 { close(descriptors[1]) }
        crumbs.deallocate()
        crumbLength.deallocate()
        crumbCursor.deallocate()
        descriptors.deallocate()
        frames.deallocate()
        headerSignals.deallocate()
        headerBytes.deallocate()
        headerLengths.deallocate()
        altStack.deallocate()
    }

    var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    func start(installHandlers: Bool = true) {
        FilePrivacy.restrict(directory)
        lock.lock()
        let existed = FileManager.default.fileExists(atPath: fileURL.path)
        let tail = existed ? lastLineUnlocked() : nil
        lock.unlock()
        let crashText = Self.readText(crashFileURL)
        if crashText.contains("CRASH") {
            if crashAutoSendEnabled() {
                crashReporter().enqueue(kind: "crash")
                consumeCrashMarker()
            } else {
                shouldShowCrashDialog = true
            }
        } else if existed {
            let resolved = tail?.contains("app terminate ok") == true || tail?.contains("app crash reported") == true
            if !resolved {
                previousRunUnclean = true
                record(.app, .info, "previous run ended without clean exit")
            }
        }
        startedAt = now()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        #if DEBUG
        let config = "Debug"
        #else
        let config = "Release"
        #endif
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        record(.app, .info, "start version=\(version) build=\(build) config=\(config) macOS=\(system) pid=\(ProcessInfo.processInfo.processIdentifier)")
        // bug.0.4.113: erst nach dem Schreiben der eigenen Startzeile gilt sie als „eigene“ (sonst hielte ein Bericht
        // in der Lücke die Startzeile des abgestürzten Laufs für die eigene).
        flushPendingWritesUnlessOnDiskQueue()
        lock.lock()
        wroteOwnStartLine = true
        lock.unlock()
        // bug.0.4.041: Deskriptoren hier öffnen (außerhalb des Signalkontexts); der Handler öffnet nie selbst.
        if crashFD < 0 { openCrashFile() }
        openLogFDIfNeeded()
        // bug.0.3.9.010: `backtrace` einmal außerhalb des Signalkontexts aufrufen. Der erste Aufruf initialisiert
        // libunwind/dyld (Sperren, Allokation); im Handler soll nur noch der schon vorbereitete Weg laufen. Ebenso
        // `backtrace_symbols_fd` (dladdr) einmal auf /dev/null. Gegen einen Absturz bei gehaltener dyld-Sperre hilft
        // das nicht, es nimmt nur die erste Initialisierung vorweg.
        let warmed = backtrace(frames, Int32(Self.frameCapacity))
        let devNull = open("/dev/null", O_WRONLY | O_CLOEXEC)
        if devNull >= 0 {
            backtrace_symbols_fd(frames, warmed, devNull)
            close(devNull)
        }
        guard installHandlers else { return }
        lock.lock()
        let already = handlersInstalled
        handlersInstalled = true
        lock.unlock()
        guard !already else { return }
        var stack = stack_t()
        stack.ss_sp = altStack
        stack.ss_size = 32 * 1024
        stack.ss_flags = 0
        sigaltstack(&stack, nil)
        NSSetUncaughtExceptionHandler { exception in
            DiskArchiveLog.shared.recordCrash(signal: "exception \(exception.name.rawValue) \(exception.reason ?? "")", symbols: exception.callStackSymbols)
        }
        var action = sigaction()
        sigemptyset(&action.sa_mask)
        action.sa_flags = SA_ONSTACK
        action.__sigaction_u.__sa_handler = Self.signalHandler
        // SIGTERM nicht hier: es läuft über `TerminationSignal` (DispatchSource → normales Beenden, bug.0.4.042).
        for signal in [SIGABRT, SIGILL, SIGTRAP, SIGSEGV, SIGBUS] {
            sigaction(signal, &action, nil)
        }
    }

    static func isOperationalFailure(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        return true
    }

    func record(_ category: DiskLogCategory, _ level: DiskLogLevel, _ message: String, privateDetail: String? = nil) {
        // Datei: kein privateDetail; nur pathDepth/pathLen (bug.0.4.011).
        let fileBody: String
        // bug.0.4.082: eine Nachricht bleibt eine Zeile. Ein Zeilenumbruch (z. B. in einem Dateinamen) erzeugte sonst
        // eine eigene Zeile, die im Absturzteil wie ein Stapelrahmen aussehen kann („12 x 0x1 $S…“).
        let oneLine = Self.singleLine(message)
        if let privateDetail {
            let depth = privateDetail.split(separator: "/").filter { !$0.isEmpty && $0 != "~" }.count
            let len = privateDetail.utf8.count
            fileBody = "\(oneLine) pathDepth=\(max(depth, 1)) pathLen=\(len)"
        } else {
            fileBody = oneLine
        }
        if level == .error, category == .store || category == .index || category == .watcher || category == .medium {
            if !fileBody.contains("CancellationError()") {
                onTrackedError?(category.rawValue, fileBody)
            }
        }
        guard writesToDisk else { return }
        let stamped = "\(timestamp()) \(category.rawValue) \(level.rawValue) \(fileBody)"
        if category == .ui {
            lock.lock()
            breadcrumbs.append(stamped)
            if breadcrumbs.count > Self.breadcrumbLimit {
                breadcrumbs.removeFirst(breadcrumbs.count - Self.breadcrumbLimit)
            }
            storeCrumb(stamped)
            lock.unlock()
        }
        let durable = level == .error
            || fileBody.contains("app terminate ok")
            || fileBody.hasPrefix("CRASH ")
        write(stamped, durable: durable)
        let logger = loggers[category]
        let privateText = privateDetail ?? ""
        // os_log: Nachricht .private; feste Präfixe bleiben technisch lesbar über getrennte Felder.
        if level == .error {
            logger?.error("\(message, privacy: .private) \(privateText, privacy: .private)")
        } else {
            logger?.info("\(message, privacy: .private) \(privateText, privacy: .private)")
        }
    }

    /// UI-Brotkrumen ohne Suchbegriff in Datei/os_log (bug.0.4.011 c).
    func ui(_ message: String) {
        if message.hasPrefix("search query=") {
            let query = String(message.dropFirst("search query=".count))
            record(.ui, .info, "search query chars=\(query.count)")
            return
        }
        record(.ui, .info, message)
    }

    /// `\n` und `\r` durch ein Leerzeichen ersetzen (bug.0.4.082).
    static func singleLine(_ message: String) -> String {
        guard message.contains(where: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }) else { return message }
        return String(message.map { $0 == "\n" || $0 == "\r" || $0 == "\r\n" ? " " : $0 })
    }

    /// Technische Kurzform für Datei-/Ordnerfehler — keine lokalisierten Texte mit Namen (bug.0.4.011 b).
    static func errorSummary(_ error: Error) -> String {
        let ns = error as NSError
        var parts = ["domain=\(ns.domain)", "code=\(ns.code)"]
        if let posix = ns.userInfo["NSPOSIXErrorKey"] as? NSNumber {
            parts.append("posix=\(posix.intValue)")
        } else if ns.domain == NSPOSIXErrorDomain {
            parts.append("posix=\(ns.code)")
        } else if let posix = error as? POSIXError {
            parts.append("posix=\(posix.code.rawValue)")
        }
        return parts.joined(separator: " ")
    }

    func perfIfSlow(_ name: String, since start: ContinuousClock.Instant) {
        let elapsed = ContinuousClock.now - start
        guard elapsed > .milliseconds(200) else { return }
        let parts = elapsed.components
        let milliseconds = parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000
        record(.perf, .info, "\(name) ms=\(milliseconds)")
    }

    /// Tests und der Absturzbericht lesen die letzten Aktionen.
    func recentBreadcrumbs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return breadcrumbs
    }

    /// Schreibt Signal, Stapel und die letzten 50 Aktionen. Tests rufen das ohne echtes Signal auf.
    /// Läuft im Handler für Ausnahmen; kommt die Ausnahme vom Schreiber selbst, kein `sync` auf dessen Queue
    /// und kein Warten auf dessen Sperre (bug.0.4.041).
    func recordCrash(signal: String, symbols: [String]) {
        var trail: [String] = []
        if isOnDiskWriteQueue {
            if lock.try() {
                trail = breadcrumbs
                lock.unlock()
            }
        } else {
            lock.lock()
            trail = breadcrumbs
            lock.unlock()
        }
        // bug.0.4.082: Grund und Rahmen bleiben je eine Zeile (z. B. ein Dateiname mit Zeilenumbruch in `reason`).
        var lines = ["CRASH signal=\(Self.singleLine(signal))"]
        lines.append(contentsOf: trail)
        lines.append(contentsOf: symbols.map(Self.singleLine))
        for line in lines {
            write(line, durable: true)
        }
    }

    func handleSignal(_ signal: Int32) {
        writeCrashSnapshot(signal: signal)
        Darwin.signal(signal, SIG_DFL)
        Darwin.raise(signal)
    }

    private func reopenLogFD() {
        let previous = logFD
        logFD = Darwin.open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0o600)
        if previous >= 0 { close(previous) }
    }

    /// Öffnet den Protokoll-Deskriptor (fsync, Absturzpfad) schon beim Start, außerhalb des Signalkontexts.
    private func openLogFDIfNeeded() {
        guard writesToDisk else { return }
        lock.lock()
        defer { lock.unlock() }
        guard logFD < 0 else { return }
        guard WriteGuard.permitsWrite(to: directory), WriteGuard.permitsWrite(to: fileURL) else { return }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        reopenLogFD()
    }

    /// Schreibt die vorbereitete Spur auch dann, wenn `lock` schon gehalten wird. Signalsicher:
    /// kein Öffnen, keine Allokation, kein `sync` auf die Schreib-Queue, keine Sperre (bug.0.3.9.010:
    /// `NSLock` ist nicht signalsicher, und `try()` schützte nichts, weil bei gehaltener Sperre trotzdem
    /// geschrieben wurde). Ohne Sperre sicher, weil der Ring nur aus Rohspeicher besteht, der in `init`
    /// einmal angelegt und nie neu zugeteilt wird, und `crashFD` einmal in eine lokale Variable gelesen
    /// und auf `>= 0` geprüft wird (`consumeCrashMarker` setzt ihn vor dem Schließen auf -1). Ein gleichzeitiges
    /// `storeCrumb` kann höchstens einen Platz halb geschrieben (mit Nullbytes) hinterlassen; das Lesen
    /// überspringt Nullbytes (`withoutNullBytes`).
    func writeCrashSnapshot(signal: Int32) {
        writeRing(signal: signal)
    }

    /// Wartet, bis die bisher eingereihten Zeilen auf der Platte stehen (nicht vom Schreiber selbst aus).
    private func flushPendingWritesUnlessOnDiskQueue() {
        guard !isOnDiskWriteQueue else { return }
        diskWriteQueue.sync { }
    }

    private var isOnDiskWriteQueue: Bool {
        DispatchQueue.getSpecific(key: diskQueueKey) != nil
    }

    #if DEBUG
    func holdLockForTest() { lock.lock() }
    func releaseLockForTest() { lock.unlock() }

    func flushPendingWritesForTesting() {
        diskWriteQueue.sync { }
    }

    var crashFDForTesting: Int32 { crashFD }
    var logFDForTesting: Int32 { logFD }

    /// Führt `body` auf der Schreib-Queue aus und meldet, ob der Absturzpfad sie dort erkennt.
    func isOnDiskWriteQueueForTesting(runOnQueue: Bool) -> Bool {
        guard runOnQueue else { return isOnDiskWriteQueue }
        var result = false
        diskWriteQueue.sync { result = isOnDiskWriteQueue }
        return result
    }
    #endif

    func acknowledgeCrashDialog() {
        shouldShowCrashDialog = false
        record(.app, .info, "app crash reported")
        consumeCrashMarker()
    }

    /// Verschiebt `crash-last.txt` und öffnet sofort eine frische Datei (außerhalb des Signalkontexts,
    /// bug.0.4.041), damit der nächste Absturz einen offenen Deskriptor vorfindet.
    func consumeCrashMarker() {
        // Erst vom alten Deskriptor lösen: misslingt das Neu-Öffnen, darf der nächste Absturz nicht in die schon
        // archivierte Datei schreiben (Review bug.0.4.041). Die kurze Lücke liegt auf dem Hauptthread.
        let archived = crashFD
        crashFD = -1
        moveCrashMarkerAside()
        openCrashFile()
        if archived >= 0 { close(archived) }
    }

    private func moveCrashMarkerAside() {
        shouldShowCrashDialog = false
        let source = crashFileURL
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let folder = directory.appendingPathComponent("crash-handled", isDirectory: true)
        guard WriteGuard.permitsWrite(to: folder) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        lock.lock()
        let stamp = fileFormatter.string(from: now())
        lock.unlock()
        let destination = folder.appendingPathComponent("\(stamp).txt")
        guard WriteGuard.permitsWrite(to: destination) else { return }
        try? FileManager.default.moveItem(at: source, to: destination)
        let kept = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for extra in kept.dropFirst(5) {
            guard WriteGuard.permitsWrite(to: extra) else { continue }
            try? FileManager.default.removeItem(at: extra)
        }
    }

    func runtimeSeconds() -> Int {
        max(0, Int(now().timeIntervalSince(startedAt)))
    }

    /// bug.0.4.113: Version, Build und Laufzeit des **abgestürzten** Laufs aus dem Protokoll: letzte Startzeile vor der
    /// „CRASH“-Zeile (ohne Absturzzeile: letzte Startzeile vor der des laufenden Protokolls), Laufzeit bis zur letzten
    /// Zeile mit Zeitstempel davor.
    /// Fehlt etwas, bleibt das Feld `nil` (nie der Wert des neuen Laufs).
    func previousRunInfo() -> PreviousRunInfo {
        let empty = PreviousRunInfo(version: nil, build: nil, runtimeSeconds: nil)
        let lines = Self.readText(fileURL).components(separatedBy: "\n")
        guard let run = crashedRunRange(lines) else { return empty }
        let startIndex = run.lowerBound
        let ownIndex = run.upperBound
        let beforeOwn = lines[..<ownIndex]
        // bug.0.4.164 (a): eine „CRASH“-Zeile zählt nur, wenn sie zu diesem Lauf gehört (nach seiner Startzeile); eine
        // alte aus einem früheren Absturz wird übergangen.
        let runLines = beforeOwn[startIndex...]
        let end = runLines.firstIndex { $0.hasPrefix("CRASH signal=") } ?? ownIndex
        let head = lines[startIndex..<end]
        // bug.0.4.164 (c): Endete dieser Lauf sauber, ist er nicht der abgestürzte (dessen Startzeile fehlt, z. B. durch
        // Kürzen des Protokolls) – dann Felder leer statt eines älteren Laufs.
        if head.contains(where: { $0.contains("app terminate ok") || $0.contains("app crash reported") }) { return empty }
        func value(_ key: String, in line: String) -> String? {
            guard let range = line.range(of: " \(key)=") else { return nil }
            return line[range.upperBound...].split(separator: " ").first.map(String.init)
        }
        func stamp(_ line: String) -> Date? { lineDate(line) }
        let startLine = lines[startIndex]
        // bug.0.4.164 (c): Die Absturzdatei (Signal-Absturz) entstand frühestens beim Start ihres Laufs; ist sie älter
        // als diese Startzeile, gehört die Startzeile zu einem späteren Lauf.
        if let began = stamp(startLine), let crashDate = crashFileContentDate(), crashDate < began.addingTimeInterval(-2) {
            return empty
        }
        var runtime: Int?
        if let began = stamp(startLine),
           let endLine = head.last(where: { stamp($0) != nil }),
           let ended = stamp(endLine) {
            runtime = max(0, Int(ended.timeIntervalSince(began)))
            // bug.0.4.170: Die Absturzdatei entstand lange nach der letzten Zeile dieses Laufs → ein späterer Lauf ist
            // abgestürzt, dessen Zeilen fehlen; dann Felder leer statt der Werte dieses Laufs.
            if let crashDate = crashFileContentDate(), crashDate > ended.addingTimeInterval(Self.crashAfterLastLineLimit) {
                return empty
            }
        }
        return PreviousRunInfo(version: value("version", in: startLine), build: value("build", in: startLine), runtimeSeconds: runtime)
    }

    /// bug.0.4.170: So lange darf ein Signal-Absturz nach der letzten Protokollzeile seines Laufs liegen (Leerlauf ohne
    /// Zeilen, z. B. über Nacht im Ruhezustand); liegt er später, gehört er zu einem anderen Lauf, dessen Zeilen fehlen.
    nonisolated static let crashAfterLastLineLimit: TimeInterval = 6 * 3600

    /// bug.0.4.170: Zeilen des abgestürzten Laufs – von der letzten Startzeile vor der eigenen bis vor die eigene (hat
    /// dieser Lauf seine Startzeile noch nicht geschrieben: bis zum Ende).
    private func crashedRunRange(_ lines: [String]) -> Range<Int>? {
        let isStart = { (line: String) in line.contains(" start version=") }
        lock.lock()
        let ownStart = wroteOwnStartLine
        lock.unlock()
        let ownIndex = ownStart ? (lines.lastIndex(where: isStart) ?? lines.count) : lines.count
        guard let startIndex = lines[..<ownIndex].lastIndex(where: isStart) else { return nil }
        return startIndex..<ownIndex
    }

    /// bug.0.4.196: Zeit einer Protokollzeile aus ihren ersten beiden Feldern (Datum, Uhrzeit mit Versatz); alte Zeilen ohne
    /// Versatz als Ortszeit. Keine feste Präfixlänge.
    func lineDate(_ line: String) -> Date? {
        let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard fields.count >= 2 else { return nil }
        let text = "\(fields[0]) \(fields[1])"
        lock.lock()
        defer { lock.unlock() }
        return formatter.date(from: text) ?? legacyFormatter.date(from: text)
    }

    /// Änderungszeit der Absturzdatei, wenn sie einen Absturz enthält.
    private func crashFileContentDate() -> Date? {
        guard Self.readText(crashFileURL).contains("CRASH") else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: crashFileURL.path))?[.modificationDate] as? Date
    }

    /// bug.0.4.113: Aktionen des abgestürzten Laufs – die Krumen nach der Kopfzeile des Absturzteils (`crash-last.txt`
    /// bzw. Protokoll), vor dem ersten Stapelrahmen. Ohne Absturzteil leer.
    func crashBreadcrumbs() -> [String] {
        guard let section = crashSection(in: Self.readText(fileURL), fallback: Self.readText(crashFileURL)) else { return [] }
        let lines = section.split(separator: "\n", omittingEmptySubsequences: true).map(String.init).dropFirst()
        let frame = try? NSRegularExpression(pattern: ReportScrubber.stackFramePattern)
        return Array(lines.prefix { line in
            frame?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) == nil
        })
    }

    /// Signal und Stapel aus dem Protokoll, für den Issue-Tracker nach dem Neustart.
    func crashExcerpt() -> (signal: String, stack: [String]) {
        let text = Self.readText(fileURL)
        let crashFile = Self.readText(crashFileURL)
        let section = crashSection(in: text, fallback: crashFile) ?? ""
        let lines = section.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let signal = lines.first.flatMap { line -> String? in
            guard let range = line.range(of: "signal=") else { return nil }
            let rest = line[range.upperBound...]
            return rest.split(separator: " ").first.map(String.init)
        } ?? "unknown"
        return (signal, Array(lines.dropFirst()))
    }

    func logTail(_ limit: Int) -> [String] {
        let text = Self.readText(fileURL)
        return CrashReportText.tail(text, limit: limit)
    }

    private func write(_ line: String, durable: Bool) {
        if durable, isOnDiskWriteQueue {
            // Absturz auf der Schreib-Queue selbst (Ausnahme im Schreiber): kein `sync` auf die eigene
            // Queue und keine Sperre, direkt auf den offenen Deskriptor (bug.0.4.041, Hinweis bug.0.4.025).
            let fd = logFD
            guard fd >= 0 else { return }
            let bytes = Array((line + "\n").utf8)
            _ = bytes.withUnsafeBufferPointer { Darwin.write(fd, $0.baseAddress, $0.count) }
            Darwin.fsync(fd)
        } else if durable {
            diskWriteQueue.sync { writeLineToFile(line, fsync: true) }
        } else {
            diskWriteQueue.async { [self] in
                self.writeLineToFile(line, fsync: false)
            }
        }
    }

    /// Schreib-Handle mit `O_APPEND` (bug.0.4.042): jede Zeile landet am Dateiende, auch wenn kurz eine zweite
    /// Instanz oder der Absturzpfad über `logFD` in dieselbe Datei schreibt.
    private static func appendingHandle(_ url: URL) throws -> FileHandle {
        let fd = Darwin.open(url.path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    private func writeLineToFile(_ line: String, fsync: Bool) {
        let data = Data((line + "\n").utf8)
        lock.lock()
        defer { lock.unlock() }
        do {
            guard WriteGuard.permitsWrite(to: directory), WriteGuard.permitsWrite(to: fileURL) else { return }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if handle == nil {
                rotateIfNeededUnlocked()
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                handle = try Self.appendingHandle(fileURL)
                try handle?.seekToEnd()
                reopenLogFD()
            }
            let used = try handle?.offset() ?? 0
            if used > 0, used + UInt64(data.count) > UInt64(byteLimit) {
                try handle?.close()
                handle = nil
                rotateClosedFileUnlocked()
                FilePrivacy.restrict(directory)
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                handle = try Self.appendingHandle(fileURL)
                reopenLogFD()
            }
            try handle?.write(contentsOf: data)
            if fsync {
                handle?.synchronizeFile()
                if logFD >= 0 { Darwin.fsync(self.logFD) }
            }
        } catch {
            handle = nil
        }
    }

    private func rotateIfNeededUnlocked() {
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        guard size >= byteLimit else { return }
        rotateClosedFileUnlocked()
    }

    private func rotateClosedFileUnlocked() {
        let previous = directory.appendingPathComponent("diskarchive.1.log")
        let oldest = directory.appendingPathComponent("diskarchive.2.log")
        guard WriteGuard.permitsWrite(to: oldest) else { return }
        try? FileManager.default.removeItem(at: oldest)
        if FileManager.default.fileExists(atPath: previous.path) {
            guard WriteGuard.permitsWrite(to: previous), WriteGuard.permitsWrite(to: oldest) else { return }
            try? FileManager.default.moveItem(at: previous, to: oldest)
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard WriteGuard.permitsWrite(to: fileURL), WriteGuard.permitsWrite(to: previous) else { return }
            try? FileManager.default.moveItem(at: fileURL, to: previous)
        }
    }

    private func lastLineUnlocked() -> String? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        let tail = data.suffix(8192)
        let text = String(decoding: tail, as: UTF8.self)
        return text.split(separator: "\n", omittingEmptySubsequences: true).last.map(String.init)
    }

    private func timestamp() -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: now())
    }

    /// bug.0.4.208: im Datenordner (`Disk Archive/Logs/`), mit `crash-last.txt` und Rotation.
    static var defaultDirectory: URL {
        AppDataFolder.url.appendingPathComponent("Logs", isDirectory: true)
    }

    private static let signalHandler: @convention(c) (Int32) -> Void = { signal in
        DiskArchiveLog.shared.handleSignal(signal)
    }

    /// Längstes Präfix mit höchstens `limit` Bytes, das auf einer UTF-8-Zeichengrenze endet (REPORT 128).
    static func utf8Prefix(_ bytes: [UInt8], limit: Int) -> ArraySlice<UInt8> {
        var cut = min(bytes.count, max(0, limit))
        if cut < bytes.count {
            // Folgebytes (10xxxxxx) gehören zum Zeichen davor: bis zu dessen Anfang zurück.
            while cut > 0, bytes.indices.contains(cut), bytes[cut] & 0xC0 == 0x80 {
                cut -= 1
            }
        }
        return bytes.prefix(cut)
    }

    private func storeCrumb(_ line: String) {
        let bytes = Self.utf8Prefix(Array(line.utf8), limit: Self.crumbSlotBytes - 1)
        let slot = crumbCursor[0]
        let start = crumbs + slot * Self.crumbSlotBytes
        start.update(repeating: 0, count: Self.crumbSlotBytes)
        for (offset, byte) in bytes.enumerated() {
            start[offset] = byte
        }
        crumbLength[slot] = UInt16(bytes.count)
        crumbCursor[0] = (slot + 1) % Self.crumbSlots
        crumbCursor[1] = min(crumbCursor[1] + 1, Self.crumbSlots)
    }

    /// Signalsicher: liest nur Rohspeicher aus `init`, schreibt per `write` auf den offenen Deskriptor.
    private func writeRing(signal: Int32) {
        let fd = crashFD
        guard fd >= 0 else { return }
        lseek(fd, 0, SEEK_SET)
        var header = headerCount - 1
        for slot in 0..<(headerCount - 1) where headerSignals[slot] == signal {
            header = slot
        }
        _ = Darwin.write(fd, headerBytes + header * Self.headerSlotBytes, headerLengths[header])
        let filled = min(max(crumbCursor[1], 0), Self.crumbSlots)
        let startSlot = filled < Self.crumbSlots ? 0 : crumbCursor[0]
        var newline: UInt8 = 10
        for step in 0..<filled {
            let slot = (startSlot + step) % Self.crumbSlots
            let length = Int(crumbLength[slot])
            guard length > 0 else { continue }
            _ = Darwin.write(fd, crumbs + slot * Self.crumbSlotBytes, length)
            _ = Darwin.write(fd, &newline, 1)
        }
        let count = backtrace(frames, Int32(Self.frameCapacity))
        backtrace_symbols_fd(frames, count, fd)
        ftruncate(fd, lseek(fd, 0, SEEK_CUR))
        fsync(fd)
    }

    /// Nur außerhalb des Signalkontexts (start, consumeCrashMarker). Erst neu öffnen, dann den alten
    /// Deskriptor schließen, damit der Handler nie eine Lücke sieht.
    private func openCrashFile() {
        guard writesToDisk else { return }
        let url = crashFileURL
        guard WriteGuard.permitsWrite(to: directory), WriteGuard.permitsWrite(to: url) else { return }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        let fresh = Darwin.open(url.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard fresh >= 0 else { return }
        if !Self.readText(url).contains("CRASH") {
            ftruncate(fresh, Self.crashFileBytes)
        }
        let previous = crashFD
        crashFD = fresh
        if previous >= 0 { close(previous) }
    }

    /// Liest Protokoll und Absturzdatei auch mit kaputten UTF-8-Folgen (REPORT 128).
    private static func readText(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private var crashFileURL: URL {
        directory.appendingPathComponent("crash-last.txt")
    }

    private func crashSection(in log: String, fallback: String) -> String? {
        // Die frische Absturzdatei ist 64 KB Nullbytes: die zählen nicht als Inhalt. Nullbytes mitten im Ring
        // (gleichzeitiges `storeCrumb` beim Absturz, bug.0.3.9.010) fallen ebenfalls weg.
        let trimmedFile = Self.withoutNullBytes(fallback).trimmingCharacters(in: Self.crashFileFiller)
        if !trimmedFile.isEmpty {
            if let range = trimmedFile.range(of: "CRASH signal=") {
                return String(trimmedFile[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return trimmedFile
        }
        // bug.0.4.164 (b) / 170: nur eine „CRASH“-Zeile des abgestürzten Laufs; der Absturzteil endet vor der Startzeile
        // des neuen Laufs (der gehört nicht dazu).
        let lines = log.components(separatedBy: "\n")
        guard let run = crashedRunRange(lines),
              let crashIndex = lines[run].lastIndex(where: { $0.hasPrefix("CRASH signal=") }) else { return nil }
        // Der Bereich endet vor der eigenen Startzeile; eine weitere Startzeile liegt darin nicht (bug.0.4.176 d).
        return lines[crashIndex..<run.upperBound].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Entfernt Nullbytes; Zeilen, die nur aus Nullbytes bestanden (halb gelöschter Ringplatz), fallen ganz weg.
    static func withoutNullBytes(_ text: String) -> String {
        guard text.contains("\u{0}") else { return text }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let kept = line.replacingOccurrences(of: "\u{0}", with: "")
                return kept.isEmpty && !line.isEmpty ? nil : kept
            }
            .joined(separator: "\n")
    }

    private static let crashFileFiller = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{0}"))
}

extension DiskLogCategory: CaseIterable {}

/// bug.0.4.113: Angaben des abgestürzten Laufs (Startzeile im Protokoll).
nonisolated struct PreviousRunInfo: Equatable, Sendable {
    var version: String?
    var build: String?
    var runtimeSeconds: Int?
}

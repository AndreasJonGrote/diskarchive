//
//  DiskIndexLog.swift
//  diskindex
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

nonisolated final class DiskIndexLog: @unchecked Sendable {
    static let shared = DiskIndexLog()

    static let fileName = "diskindex.log"
    private static let breadcrumbLimit = 50
    private static let defaultByteLimit = 5 * 1024 * 1024

    private let directory: URL
    private let byteLimit: Int
    private let writesToDisk: Bool
    private let lock = NSLock()
    private var handle: FileHandle?
    private var breadcrumbs: [String] = []
    private var crashFD: Int32 = -1
    private var logFD: Int32 = -1
    private var startedAt = Date()
    private(set) var shouldShowCrashDialog = false
    /// Der Lauf davor endete ohne „app terminate ok“ (Aufgabe 219: dann `quick_check`).
    private(set) var previousRunUnclean = false
    /// Fehler aus Speicher, Index, Überwachung und Medien (Aufgabe 61). Nicht im Signal-Handler setzen.
    var onTrackedError: ((String, String) -> Void)?
    private var crumbs = [UInt8](repeating: 0, count: 50 * 240)
    private var crumbLength = [UInt16](repeating: 0, count: 50)
    private var crumbNext = 0
    private var crumbFilled = 0
    private let altStack = UnsafeMutableRawPointer.allocate(byteCount: 32 * 1024, alignment: 16)
    private var handlersInstalled = false
    private let formatter: DateFormatter
    private let loggers: [DiskLogCategory: Logger]

    init(directory: URL? = nil, byteLimit: Int = DiskIndexLog.defaultByteLimit) {
        self.writesToDisk = directory != nil || !RuntimeEnvironment.isRunningTests
        self.directory = directory ?? Self.defaultDirectory
        self.byteLimit = byteLimit
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.formatter = formatter
        self.loggers = Dictionary(uniqueKeysWithValues: DiskLogCategory.allCases.map { category in
            (category, Logger(subsystem: "app.diskarchive", category: category.rawValue))
        })
    }

    var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    func start(installHandlers: Bool = true) {
        FilePrivacy.restrict(directory)
        lock.lock()
        let existed = FileManager.default.fileExists(atPath: fileURL.path)
        let tail = existed ? lastLineUnlocked() : nil
        lock.unlock()
        let crashText = (try? String(contentsOf: crashFileURL, encoding: .utf8)) ?? ""
        if crashText.contains("CRASH") {
            if IssueConsent.autoSendEnabled(defaults: AppDefaults.current) {
                IssueReporter.shared.enqueue(kind: "crash")
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
        startedAt = Date()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        #if DEBUG
        let config = "Debug"
        #else
        let config = "Release"
        #endif
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        record(.app, .info, "start version=\(version) build=\(build) config=\(config) macOS=\(system) pid=\(ProcessInfo.processInfo.processIdentifier)")
        guard installHandlers else { return }
        lock.lock()
        let already = handlersInstalled
        handlersInstalled = true
        lock.unlock()
        guard !already else { return }
        openCrashFile()
        var stack = stack_t()
        stack.ss_sp = altStack
        stack.ss_size = 32 * 1024
        stack.ss_flags = 0
        sigaltstack(&stack, nil)
        NSSetUncaughtExceptionHandler { exception in
            DiskIndexLog.shared.recordCrash(signal: "exception \(exception.name.rawValue) \(exception.reason ?? "")", symbols: exception.callStackSymbols)
        }
        var action = sigaction()
        sigemptyset(&action.sa_mask)
        action.sa_flags = SA_ONSTACK
        action.__sigaction_u.__sa_handler = Self.signalHandler
        for signal in [SIGABRT, SIGILL, SIGTRAP, SIGSEGV, SIGBUS, SIGTERM] {
            sigaction(signal, &action, nil)
        }
    }

    static func isOperationalFailure(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        return true
    }

    func record(_ category: DiskLogCategory, _ level: DiskLogLevel, _ message: String, privateDetail: String? = nil) {
        let lineBody = privateDetail.map { "\(message) \($0)" } ?? message
        if level == .error, category == .store || category == .index || category == .watcher || category == .medium {
            if !lineBody.contains("CancellationError()") {
                onTrackedError?(category.rawValue, lineBody)
            }
        }
        guard writesToDisk else { return }
        let stamped = "\(timestamp()) \(category.rawValue) \(level.rawValue) \(lineBody)"
        if category == .ui {
            lock.lock()
            breadcrumbs.append(stamped)
            if breadcrumbs.count > Self.breadcrumbLimit {
                breadcrumbs.removeFirst(breadcrumbs.count - Self.breadcrumbLimit)
            }
            storeCrumb(stamped)
            lock.unlock()
        }
        write(stamped)
        let logger = loggers[category]
        let privateText = privateDetail ?? ""
        if level == .error {
            logger?.error("\(message, privacy: .public) \(privateText, privacy: .private)")
        } else {
            logger?.info("\(message, privacy: .public) \(privateText, privacy: .private)")
        }
    }

    func ui(_ message: String) {
        record(.ui, .info, message)
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
    func recordCrash(signal: String, symbols: [String]) {
        lock.lock()
        let trail = breadcrumbs
        lock.unlock()
        var lines = ["CRASH signal=\(signal)"]
        lines.append(contentsOf: trail)
        lines.append(contentsOf: symbols)
        for line in lines {
            write(line)
        }
        lock.lock()
        handle?.synchronizeFile()
        lock.unlock()
    }

    func handleSignal(_ signal: Int32) {
        if signal == SIGTERM {
            writeCleanTermination()
            Darwin.signal(signal, SIG_DFL)
            Darwin.raise(signal)
            return
        }
        writeCrashSnapshot(signal: Self.name(for: signal))
        Darwin.signal(signal, SIG_DFL)
        Darwin.raise(signal)
    }

    /// Signalsicher: nur `write` auf den schon geöffneten Protokoll-Deskriptor.
    func writeCleanTermination() {
        if logFD < 0 { reopenLogFD() }
        guard logFD >= 0 else { return }
        let bytes = Array("app terminate ok\n".utf8)
        _ = bytes.withUnsafeBytes { Darwin.write(logFD, $0.baseAddress, bytes.count) }
        fsync(logFD)
    }

    private func reopenLogFD() {
        if logFD >= 0 { close(logFD) }
        logFD = Darwin.open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
    }

    /// Schreibt die vorbereitete Spur auch dann, wenn `lock` schon gehalten wird.
    func writeCrashSnapshot(signal: String) {
        let ownsLock = lock.try()
        writeRing(signal: signal)
        if ownsLock { lock.unlock() }
    }

    #if DEBUG
    func holdLockForTest() { lock.lock() }
    func releaseLockForTest() { lock.unlock() }
    #endif

    func acknowledgeCrashDialog() {
        shouldShowCrashDialog = false
        record(.app, .info, "app crash reported")
        consumeCrashMarker()
    }

    func consumeCrashMarker() {
        shouldShowCrashDialog = false
        let source = crashFileURL
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let folder = directory.appendingPathComponent("crash-handled", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ":", with: "-")
        let destination = folder.appendingPathComponent("\(stamp).txt")
        try? FileManager.default.moveItem(at: source, to: destination)
        let kept = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for extra in kept.dropFirst(5) {
            try? FileManager.default.removeItem(at: extra)
        }
        if crashFD >= 0 {
            close(crashFD)
            crashFD = -1
        }
    }

    func runtimeSeconds() -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }

    /// Signal und Stapel aus dem Protokoll, für den Issue-Tracker nach dem Neustart.
    func crashExcerpt() -> (signal: String, stack: [String]) {
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let crashFile = (try? String(contentsOf: directory.appendingPathComponent("crash-last.txt"), encoding: .utf8)) ?? ""
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
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        return CrashReportText.tail(text, limit: limit)
    }

    func report(includeCrash: Bool, logLineLimit: Int, actionLimit: Int) -> String {
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let crashFile = (try? String(contentsOf: directory.appendingPathComponent("crash-last.txt"), encoding: .utf8)) ?? ""
        let crash = includeCrash ? crashSection(in: text, fallback: crashFile) : nil
        let actions = Array(recentBreadcrumbs().suffix(actionLimit))
        #if DEBUG
        let config = "Debug"
        #else
        let config = "Release"
        #endif
        var model = [CChar](repeating: 0, count: 128)
        var size = model.count
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelName = String(cString: model)
        let databaseURL = try? IndexStoreV3.storeFileURL()
        let bytes = databaseURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? NSNumber }?.int64Value
        let inventory = IndexStoreV3.inventoryLabels()
        let runtime = String(format: "%.0f s", Date().timeIntervalSince(startedAt))
        return CrashReportText.make(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            config: config,
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            model: modelName,
            started: formatter.string(from: startedAt),
            runtime: runtime,
            crashSection: crash,
            actions: actions,
            logLines: CrashReportText.tail(text, limit: logLineLimit),
            databaseBytes: bytes,
            media: inventory.media,
            objects: inventory.objects,
            diagnosticHead: newestDiagnosticHead()
        )
    }

    @MainActor func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func write(_ line: String) {
        let data = Data((line + "\n").utf8)
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            FilePrivacy.restrict(directory)
            if handle == nil {
                rotateIfNeededUnlocked()
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                handle = try FileHandle(forWritingTo: fileURL)
                try handle?.seekToEnd()
                reopenLogFD()
            }
            let used = try handle?.offset() ?? 0
            if used > 0, used + UInt64(data.count) > UInt64(byteLimit) {
                try handle?.close()
                handle = nil
                rotateClosedFileUnlocked()
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                handle = try FileHandle(forWritingTo: fileURL)
                reopenLogFD()
            }
            try handle?.write(contentsOf: data)
            handle?.synchronizeFile()
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
        let previous = directory.appendingPathComponent("diskindex.1.log")
        let oldest = directory.appendingPathComponent("diskindex.2.log")
        try? FileManager.default.removeItem(at: oldest)
        if FileManager.default.fileExists(atPath: previous.path) {
            try? FileManager.default.moveItem(at: previous, to: oldest)
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
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
        return formatter.string(from: Date())
    }

    private static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Disk Archive", isDirectory: true)
    }

    private static let signalHandler: @convention(c) (Int32) -> Void = { signal in
        DiskIndexLog.shared.handleSignal(signal)
    }

    private func storeCrumb(_ line: String) {
        let bytes = Array(line.utf8.prefix(239))
        let slot = crumbNext
        let start = slot * 240
        for index in crumbs.indices.dropFirst(start).prefix(240) {
            crumbs[index] = 0
        }
        for (offset, byte) in bytes.enumerated() {
            crumbs[start + offset] = byte
        }
        crumbLength[slot] = UInt16(bytes.count)
        crumbNext = (crumbNext + 1) % 50
        crumbFilled = min(crumbFilled + 1, 50)
    }

    private func writeRing(signal: String) {
        if crashFD < 0 { openCrashFile() }
        guard crashFD >= 0 else { return }
        lseek(crashFD, 0, SEEK_SET)
        var header = Array("CRASH signal=\(signal)\n".utf8)
        header.append(0)
        _ = header.withUnsafeBytes { Darwin.write(crashFD, $0.baseAddress, header.count - 1) }
        let startSlot = crumbFilled < 50 ? 0 : crumbNext
        for step in 0..<crumbFilled {
            let slot = (startSlot + step) % 50
            let length = Int(crumbLength[slot])
            guard length > 0 else { continue }
            let offset = slot * 240
            _ = crumbs.withUnsafeBytes { raw in
                Darwin.write(crashFD, raw.baseAddress!.advanced(by: offset), length)
            }
            var newline: UInt8 = 10
            _ = Darwin.write(crashFD, &newline, 1)
        }
        var frames = Array(repeating: UnsafeMutableRawPointer?.none, count: 64)
        let count = backtrace(&frames, 64)
        backtrace_symbols_fd(&frames, count, crashFD)
        ftruncate(crashFD, lseek(crashFD, 0, SEEK_CUR))
        fsync(crashFD)
    }

    private func openCrashFile() {
        let url = crashFileURL
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FilePrivacy.restrict(directory)
        if crashFD >= 0 { close(crashFD) }
        crashFD = Darwin.open(url.path, O_RDWR | O_CREAT, 0o600)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if crashFD >= 0, !existing.contains("CRASH") {
            ftruncate(crashFD, 64 * 1024)
        }
    }

    private var crashFileURL: URL {
        directory.appendingPathComponent("crash-last.txt")
    }

    private func crashSection(in log: String, fallback: String) -> String? {
        let trimmedFile = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFile.isEmpty {
            if let range = trimmedFile.range(of: "CRASH signal=") {
                return String(trimmedFile[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return trimmedFile
        }
        if let range = log.range(of: "CRASH signal=", options: .backwards) {
            return String(log[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func newestDiagnosticHead() -> String? {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return nil }
        let match = names.filter { $0.hasPrefix("Disk Archive") && $0.hasSuffix(".ips") }.sorted().last
        guard let match else { return nil }
        guard let text = try? String(contentsOf: folder.appendingPathComponent(match), encoding: .utf8) else { return nil }
        return CrashReportText.tail(text, limit: 40).joined(separator: "\n")
    }

    private static func name(for signal: Int32) -> String {
        switch signal {
        case SIGABRT: "SIGABRT"
        case SIGILL: "SIGILL"
        case SIGTRAP: "SIGTRAP"
        case SIGSEGV: "SIGSEGV"
        case SIGBUS: "SIGBUS"
        default: "signal \(signal)"
        }
    }
}

extension DiskLogCategory: CaseIterable {}

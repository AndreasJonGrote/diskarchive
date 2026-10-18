//
//  WriteGuard.swift
//  diskindex
//
//  todo.0.4.014: Erlaubnisliste — Schreiben nur in App-eigene Wurzeln.
//

import Foundation
import OSLog

nonisolated enum WriteGuard {
    private static let logger = Logger(subsystem: "app.diskarchive", category: "WriteGuard")
    private static let lock = NSLock()
    /// Produktionszähler (Diagnose); Tests setzen ihn nie zurück (bug.0.3.9.013).
    private static var blockedWriteCountStorage = 0

    /// Anzahl blockierter Schreibversuche seit dem Start (prozessweit, wird nie zurückgesetzt).
    static var blockedWriteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return blockedWriteCountStorage
    }

    #if DEBUG
    /// Nur Tests (bug.0.3.9.013): zusätzliche erlaubte Wurzeln je Task statt prozessweit (Regel 20). Wirkt nur für
    /// Aufrufe im selben Task (z. B. `permits` direkt im Test), nicht auf Dispatch-Queues oder GRDB-Queues.
    @TaskLocal static var extraAllowedRootsForTesting: [String] = []

    /// Nur Tests: blockierte Pfade (zuletzt höchstens 1.000), damit ein Test nur seine eigenen, eindeutigen Pfade
    /// zählt — auch wenn das Schreiben auf einer Queue lief, die den Task-Wert nicht sieht. Wird nie zurückgesetzt.
    private static var blockedPathsForTesting: [String] = []

    /// Anzahl blockierter Schreibversuche auf `url` oder darunter (Tests mit eindeutigem Pfad).
    static func blockedWriteCount(under url: URL) -> Int {
        let root = normalizeRoot(url.path)
        let prefix = root.hasSuffix("/") ? root : root + "/"
        lock.lock()
        defer { lock.unlock() }
        return blockedPathsForTesting.filter { $0 == root || $0.hasPrefix(prefix) }.count
    }
    #endif

    /// `true`, wenn die App an diesem Pfad schreiben darf.
    static func permits(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        for root in allowedRoots() {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            if path == root || path.hasPrefix(prefix) { return true }
        }
        return false
    }

    /// Vor jedem Schreiben: bei `false` nicht schreiben (Release: Protokollzeile ohne Pfad).
    @discardableResult
    static func permitsWrite(to url: URL) -> Bool {
        guard permits(url) else {
            lock.lock()
            blockedWriteCountStorage += 1
            #if DEBUG
            blockedPathsForTesting.append(url.standardizedFileURL.path)
            if blockedPathsForTesting.count > 1_000 {
                blockedPathsForTesting.removeFirst(blockedPathsForTesting.count - 1_000)
            }
            #endif
            lock.unlock()
            logger.info("write blocked")
            return false
        }
        return true
    }

    private static func allowedRoots() -> [String] {
        var roots: [String] = []
        #if DEBUG
        roots.append(contentsOf: extraAllowedRootsForTesting.map(normalizeRoot))
        #endif
        if let data = try? IndexStoreV3.storeFileURL().deletingLastPathComponent() {
            roots.append(normalizeRoot(data.path))
        }
        roots.append(normalizeRoot(logsDirectoryPath()))
        roots.append(normalizeRoot(NSTemporaryDirectory()))
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            roots.append(normalizeRoot(caches.path))
        }
        let prefs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences", isDirectory: true)
        roots.append(normalizeRoot(prefs.path))
        return roots
    }

    private static func logsDirectoryPath() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Disk Archive", isDirectory: true).path
    }

    private static func normalizeRoot(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }
}

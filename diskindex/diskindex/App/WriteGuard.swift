//
//  WriteGuard.swift
//  diskindex
//
//  todo.0.4.014: Erlaubnisliste — Schreiben nur in App-eigene Wurzeln.
//

import Foundation

nonisolated enum WriteGuard {
    private static let lock = NSLock()
    private static var extraAllowedRoots: [String] = []
    private static var blockedWriteCountStorage = 0

    /// Anzahl blockierter Schreibversuche (Tests).
    static var blockedWriteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return blockedWriteCountStorage
    }

    /// Nur für Tests: zusätzliche erlaubte Wurzeln (z. B. simuliertes externes Home).
    static func setExtraAllowedRootsForTesting(_ paths: [String]) {
        lock.lock()
        defer { lock.unlock() }
        extraAllowedRoots = paths.map(normalizeRoot)
    }

    static func clearTestingOverrides() {
        lock.lock()
        defer { lock.unlock() }
        extraAllowedRoots = []
        blockedWriteCountStorage = 0
    }

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
            lock.unlock()
            DiskIndexLog.shared.record(.store, .info, "write blocked")
            return false
        }
        return true
    }

    private static func allowedRoots() -> [String] {
        lock.lock()
        let injected = extraAllowedRoots
        lock.unlock()
        var roots: [String] = injected
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

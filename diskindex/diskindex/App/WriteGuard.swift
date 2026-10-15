//
//  WriteGuard.swift
//  diskindex
//
//  todo.0.4.014: Laufzeit-Schreibschranke — keine Schreibzugriffe auf Speichermedien.
//

import Foundation

nonisolated enum WriteGuard {
    private static let lock = NSLock()
    private static var mediumMountPaths: [String] = []

    /// Bekannte Mount-Punkte indizierter Medien (Watcher, Monitor, Tests).
    static func setMediumMountPaths(_ paths: [String]) {
        lock.lock()
        defer { lock.unlock() }
        mediumMountPaths = paths.map(normalizeMount)
    }

    static func registerMediumMountPath(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        let norm = normalizeMount(path)
        if !mediumMountPaths.contains(norm) {
            mediumMountPaths.append(norm)
        }
    }

    static func clearMediumMountPathsForTesting() {
        lock.lock()
        defer { lock.unlock() }
        mediumMountPaths = []
    }

    static func wouldBlock(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        lock.lock()
        let mounts = mediumMountPaths
        lock.unlock()
        for mount in mounts {
            let prefix = mount.hasSuffix("/") ? mount : mount + "/"
            if path == mount || path.hasPrefix(prefix) { return true }
        }
        return false
    }

    /// Vor jedem Schreiben in erlaubten App-Dateien aufrufen.
    static func assertAppOwned(_ url: URL) {
        guard wouldBlock(url) else { return }
        #if DEBUG
        assertionFailure("WriteGuard: write blocked on medium mount")
        #endif
        DiskIndexLog.shared.record(.store, .info, "write blocked")
    }

    private static func normalizeMount(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }
}

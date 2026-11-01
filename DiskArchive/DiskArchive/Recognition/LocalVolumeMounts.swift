//
//  LocalVolumeMounts.swift
//  DiskArchive
//
//  bug.0.4.021 — Billige Vorfilterung lokaler /Volumes-Mounts.
//

import Darwin
import Foundation

nonisolated enum LocalVolumeMounts {
    /// Lokale Kandidaten unter `/Volumes/` (ohne Netzwerk), via `getmntinfo(MNT_NOWAIT)`.
    static func candidateMountPaths() -> [String] {
        var buffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&buffer, MNT_NOWAIT)
        guard count > 0, let buffer else { return [] }
        var paths: [String] = []
        for index in 0..<Int(count) {
            let entry = buffer[index]
            if Int32(entry.f_flags) & MNT_LOCAL == 0 { continue }
            let name = withUnsafeBytes(of: entry.f_mntonname) { bytes -> String in
                let trimmed = bytes.prefix { $0 != 0 }
                return String(decoding: trimmed, as: UTF8.self)
            }
            guard name.hasPrefix("/Volumes/"), name.count > "/Volumes/".count else { continue }
            paths.append(name)
        }
        return paths
    }
}

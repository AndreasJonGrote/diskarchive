//
//  DatabaseCare.swift
//  diskindex
//

import Foundation

nonisolated enum DatabaseCareError: Error {
    case unhealthy
}

nonisolated enum DatabaseCare {
    static func isHealthy(_ result: String?) -> Bool {
        result == "ok"
    }

    static func quarantine(_ fileURL: URL) throws {
        let stamp = Int(Date().timeIntervalSince1970)
        let aside = fileURL.deletingLastPathComponent()
            .appendingPathComponent("index-damaged-\(stamp).sqlite")
        let manager = FileManager.default
        WriteGuard.assertAppOwned(fileURL)
        WriteGuard.assertAppOwned(aside)
        if manager.fileExists(atPath: fileURL.path) {
            try manager.moveItem(at: fileURL, to: aside)
        }
        for suffix in ["-wal", "-shm"] {
            let side = URL(fileURLWithPath: fileURL.path + suffix)
            if manager.fileExists(atPath: side.path) {
                let dest = URL(fileURLWithPath: aside.path + suffix)
                WriteGuard.assertAppOwned(side)
                WriteGuard.assertAppOwned(dest)
                try? manager.moveItem(at: side, to: dest)
            }
        }
    }
}

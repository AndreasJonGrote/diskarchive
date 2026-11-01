//
//  IndexRunGuard.swift
//  DiskArchive
//

import Foundation

nonisolated enum IndexRunGuard {

    static func shouldPending(consecutiveTimeouts: Int, limit: Int = 3) -> Bool {
        consecutiveTimeouts >= limit
    }
}

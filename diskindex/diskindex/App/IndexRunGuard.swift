//
//  IndexRunGuard.swift
//  diskindex
//

import Foundation

nonisolated enum IndexRunGuard {
    static func capped(_ ratio: Double, finished: Bool) -> Double {
        if finished { return 1 }
        return min(0.99, max(0, ratio))
    }

    static func nextProgress(previous: Double, proposed: Double, finished: Bool) -> Double {
        capped(max(previous, proposed), finished: finished)
    }

    static func resumeDepth(completed: Int) -> Int {
        max(0, completed)
    }

    static func shouldPending(consecutiveTimeouts: Int, limit: Int = 3) -> Bool {
        consecutiveTimeouts >= limit
    }
}

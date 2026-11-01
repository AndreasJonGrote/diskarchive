//
//  IssueReporterFlushGate.swift
//  DiskArchive
//
//  Single-Flight für API-Queue-Flush (0.3.240).
//

import Foundation

actor IssueReporterFlushGate {
    private var running = false
    private var pending = false

    func run(_ body: @Sendable () async -> Void) async {
        if running {
            pending = true
            return
        }
        running = true
        repeat {
            pending = false
            await body()
        } while pending
        running = false
    }
}

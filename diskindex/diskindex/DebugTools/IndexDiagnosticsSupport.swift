#if DEBUG
//
//  IndexDiagnosticsSupport.swift
//  diskindex
//
//  Aufgabe 35: gemeinsamer Logger. Kein Produktcode.
//

import Foundation
import os

let indexDiagnosticsLogger = Logger(subsystem: "app.diskarchive", category: "IndexDiagnostics")

nonisolated func indexDiagnosticsSeconds(_ duration: Duration) -> Double {
    let parts = duration.components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
}

nonisolated func indexDiagnosticsFormat(seconds: Double) -> String {
    String(format: "%.3f s", seconds)
}

final class IndexDiagnosticsCancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var cancelled = false

    nonisolated func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}
#endif

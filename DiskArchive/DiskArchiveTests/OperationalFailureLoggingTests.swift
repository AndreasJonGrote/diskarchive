//
//  OperationalFailureLoggingTests.swift
//  DiskArchiveTests
//
//  Aufgabe 109 — CancellationError nie als .error / onTrackedError.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite struct OperationalFailureLoggingTests {
    @Test func cancellationIsNotOperationalFailure() {
        #expect(!DiskArchiveLog.isOperationalFailure(CancellationError()))
        #expect(DiskArchiveLog.isOperationalFailure(NSError(domain: "test", code: 1)))
    }

    @Test func trackedErrorSkipsCancellationMessage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let log = DiskArchiveLog(directory: directory)
        var tracked: [String] = []
        log.onTrackedError = { _, message in
            tracked.append(message)
        }
        log.record(.index, .error, "favorites CancellationError()")
        log.record(.index, .error, "favorites disk full")
        #expect(!tracked.contains(where: { $0.contains("CancellationError") }))
        #expect(tracked.contains(where: { $0.contains("disk full") }))
    }
}

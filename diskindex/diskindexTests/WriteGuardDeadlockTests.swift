//
//  WriteGuardDeadlockTests.swift
//  diskindexTests
//
//  bug.0.4.045 — WriteGuard darf nicht über DiskIndexLog reentrancy deadlocken.
//

import Foundation
import Testing
@testable import diskindex

@Suite struct WriteGuardDeadlockTests {
    @Test func blockedLogDirectoryDoesNotHangWithinTwoSeconds() async throws {
        WriteGuard.clearTestingOverrides()
        let blockedDir = URL(fileURLWithPath: "/Volumes/BLOCKEDWRITEGUARD/deep", isDirectory: true)
        let log = DiskIndexLog(directory: blockedDir)
        let finished = await waitUntil(timeout: 2) {
            log.record(.app, .info, "probe line")
            return true
        }
        #expect(finished)
        #expect(WriteGuard.blockedWriteCount >= 1)
        #expect(!FileManager.default.fileExists(atPath: blockedDir.appendingPathComponent("diskindex.log").path))
    }
}

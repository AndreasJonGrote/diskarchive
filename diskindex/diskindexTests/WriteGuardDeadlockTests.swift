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
        // bug.0.3.9.013: eindeutiger Pfad, Zähler je Pfad statt globalem Zurücksetzen (Regel 20).
        let blockedDir = URL(fileURLWithPath: "/Volumes/BLOCKEDWRITEGUARD-\(UUID().uuidString)/deep", isDirectory: true)
        let log = DiskIndexLog(directory: blockedDir)
        log.record(.app, .info, "probe line")
        let finished = await waitUntil(timeout: 2) {
            WriteGuard.blockedWriteCount(under: blockedDir) >= 1
        }
        #expect(finished)
        #expect(!FileManager.default.fileExists(atPath: blockedDir.appendingPathComponent("diskindex.log").path))
    }
}

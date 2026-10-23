//
//  ApiQueuePersistenceTests.swift
//  diskindexTests
//
//  API-Warteschlange in `api_queue` (0.3.1).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

private func makeQueuePool() throws -> (pool: DatabasePool, directory: URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-api-queue-\(UUID().uuidString)", isDirectory: true)
    let pool = try ApiQueuePersistence.openQueuePool(at: directory.appendingPathComponent("archive.sqlite"))
    return (pool, directory)
}

struct ApiQueuePersistenceTests {
    @Test func enqueueAndFetchDue() throws {
        let (pool, directory) = try makeQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data(#"{"id":"A","kind":"crash"}"#.utf8)
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: payload, createdAt: 1)
        let due = try ApiQueuePersistence.fetchDue(pool, now: Date())
        #expect(due.count == 1)
        #expect(try #require(due.first).attempts == 0)
    }

    @Test func backoffBlocksUntilDue() throws {
        let (pool, directory) = try makeQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data(#"{"id":"B","kind":"crash"}"#.utf8)
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: payload, createdAt: 1)
        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        let moment = Date(timeIntervalSince1970: 1_700_000_000)
        try ApiQueuePersistence.recordFailure(pool, rowID: row.id, attempts: 1, lastTryAt: Int(moment.timeIntervalSince1970), info: "status=500")
        let tooSoon = try ApiQueuePersistence.fetchDue(pool, now: moment.addingTimeInterval(100))
        #expect(tooSoon.isEmpty)
        let later = try ApiQueuePersistence.fetchDue(pool, now: moment.addingTimeInterval(3_601))
        #expect(later.count == 1)
        try ApiQueuePersistence.recordFailure(pool, rowID: row.id, attempts: 2, lastTryAt: Int(moment.timeIntervalSince1970), info: "offline")
        let offlineDue = try ApiQueuePersistence.fetchDue(pool, now: moment.addingTimeInterval(1))
        #expect(offlineDue.count == 1)
    }

    @Test func trimCapsRowCount() throws {
        let (pool, directory) = try makeQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        let small = Data(#"{"id":"x"}"#.utf8)
        for index in 0..<51 {
            try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: small, createdAt: index)
        }
        #expect(try ApiQueuePersistence.count(pool) == 50)
    }

    @Test func deleteAllByKind() throws {
        let (pool, directory) = try makeQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: Data("{}".utf8), createdAt: 1)
        try ApiQueuePersistence.deleteAll(pool, kind: .issueReport)
        #expect(try ApiQueuePersistence.count(pool) == 0)
    }

    @Test func blockedRowIsNotDue() throws {
        let (pool, directory) = try makeQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: Data(#"{"id":"x"}"#.utf8), createdAt: 1)
        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        try ApiQueuePersistence.markBlocked(pool, rowID: row.id, info: "blocked:leak=path")
        #expect(try ApiQueuePersistence.fetchDue(pool, now: Date()).isEmpty)
        #expect(try ApiQueuePersistence.hasDueWork(pool, now: Date()) == false)
        #expect(try ApiQueuePersistence.count(pool) == 1)
    }

    @Test func nextRetryFindsIssueID() throws {
        let (pool, directory) = try makeQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        try ApiQueuePersistence.enqueue(pool, kind: .issueReport, payload: Data(#"{"id":"\#(id)"}"#.utf8), createdAt: 1)
        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        let moment = Date(timeIntervalSince1970: 1_700_000_000)
        try ApiQueuePersistence.recordFailure(pool, rowID: row.id, attempts: 1, lastTryAt: Int(moment.timeIntervalSince1970), info: nil)
        let retry = try #require(try ApiQueuePersistence.nextRetry(pool, issueID: id))
        #expect(retry.attempts == 1)
        #expect(abs(retry.next.timeIntervalSince(moment) - 3_600) < 1)
    }
}

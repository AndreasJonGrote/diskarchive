//
//  ApiQueuePersistence.swift
//  diskindex
//
//  Persistenz für `api_queue` (0.3.1).
//

import Foundation
import GRDB

nonisolated struct ApiQueueRow: Equatable, Sendable {
    var id: Int64
    var kind: Int
    var payload: String?
    var createdAt: Int
    var attempts: Int
    var lastTryAt: Int?
    var info: String?
}

nonisolated enum ApiQueuePersistence {
    static let maxRows = 50
    static let maxPayloadBytes = 5 * 1_024 * 1_024

    static func openQueuePool() throws -> DatabasePool {
        try SchemaV3.openPool(at: IndexStoreV3.storeFileURL())
    }

    static func openQueuePool(at fileURL: URL) throws -> DatabasePool {
        try SchemaV3.openPool(at: fileURL)
    }

    static func enqueue(_ pool: DatabasePool, kind: ApiQueueKind, payload: Data, createdAt: Int) throws {
        guard let text = String(data: payload, encoding: .utf8) else { return }
        try pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO api_queue (kind, payload, createdAt, attempts, lastTryAt, info)
                    VALUES (?, ?, ?, 0, NULL, NULL)
                    """,
                arguments: [kind.rawValue, text, createdAt]
            )
        }
        try trim(pool)
    }

    static func trim(_ pool: DatabasePool) throws {
        try pool.write { db in
            while true {
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue") ?? 0
                let total = try Int.fetchOne(
                    db,
                    sql: "SELECT COALESCE(SUM(length(payload)), 0) FROM api_queue"
                ) ?? 0
                if count <= maxRows, total <= maxPayloadBytes { break }
                guard let oldest = try Int64.fetchOne(db, sql: "SELECT id FROM api_queue ORDER BY id ASC LIMIT 1") else { break }
                try db.execute(sql: "DELETE FROM api_queue WHERE id = ?", arguments: [oldest])
            }
        }
    }

    static func fetchAllOrdered(_ pool: DatabasePool) throws -> [ApiQueueRow] {
        try pool.read { db in
            try rows(from: db, sql: "SELECT * FROM api_queue ORDER BY id ASC")
        }
    }

    static func fetchDue(_ pool: DatabasePool, now: Date) throws -> [ApiQueueRow] {
        let all = try fetchAllOrdered(pool)
        return all.filter { isDue($0, now: now) }
    }

    static func isBlocked(_ row: ApiQueueRow) -> Bool {
        row.info?.hasPrefix("blocked:") == true
    }

    static func isDue(_ row: ApiQueueRow, now: Date) -> Bool {
        if isBlocked(row) { return false }
        guard let last = row.lastTryAt else { return true }
        let delay = IssueRetry.delay(afterAttempt: row.attempts)
        return now.timeIntervalSince1970 >= Double(last) + delay
    }

    static func hasDueWork(_ pool: DatabasePool, kind: ApiQueueKind = .issueReport, now: Date) throws -> Bool {
        try pool.read { db in
            let rows = try rows(from: db, sql: "SELECT * FROM api_queue WHERE kind = ? ORDER BY id ASC", arguments: [kind.rawValue])
            return rows.contains { isDue($0, now: now) }
        }
    }

    static func markBlocked(_ pool: DatabasePool, rowID: Int64, info: String) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE api_queue SET info = ? WHERE id = ?",
                arguments: [info, rowID]
            )
        }
    }

    static func delete(_ pool: DatabasePool, rowID: Int64) throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM api_queue WHERE id = ?", arguments: [rowID])
        }
    }

    static func recordFailure(_ pool: DatabasePool, rowID: Int64, attempts: Int, lastTryAt: Int, info: String?) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                    UPDATE api_queue SET attempts = ?, lastTryAt = ?, info = ?
                    WHERE id = ?
                    """,
                arguments: [attempts, lastTryAt, info, rowID]
            )
        }
    }

    static func deleteAll(_ pool: DatabasePool, kind: ApiQueueKind) throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM api_queue WHERE kind = ?", arguments: [kind.rawValue])
        }
    }

    static func count(_ pool: DatabasePool, kind: ApiQueueKind? = nil) throws -> Int {
        try pool.read { db in
            if let kind {
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue WHERE kind = ?", arguments: [kind.rawValue]) ?? 0
            }
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue") ?? 0
        }
    }

    static func nextRetry(_ pool: DatabasePool, issueID: String) throws -> IssueRetry? {
        let rows = try fetchAllOrdered(pool)
        for row in rows {
            guard let payload = row.payload?.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  object["id"] as? String == issueID else { continue }
            guard let last = row.lastTryAt else {
                return IssueRetry(attempts: row.attempts, next: Date())
            }
            let delay = IssueRetry.delay(afterAttempt: row.attempts)
            return IssueRetry(
                attempts: row.attempts,
                next: Date(timeIntervalSince1970: Double(last) + delay)
            )
        }
        return nil
    }

    static func issueID(in payload: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return nil }
        return object["id"] as? String
    }

    static func firstPayload(_ pool: DatabasePool, kind: ApiQueueKind = .issueReport) throws -> Data? {
        try pool.read { db in
            guard let text = try String.fetchOne(
                db,
                sql: "SELECT payload FROM api_queue WHERE kind = ? ORDER BY id ASC LIMIT 1",
                arguments: [kind.rawValue]
            ) else { return nil }
            return text.data(using: .utf8)
        }
    }

    private static func rows(from db: Database, sql: String, arguments: StatementArguments = []) throws -> [ApiQueueRow] {
        try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
            ApiQueueRow(
                id: row["id"],
                kind: row["kind"],
                payload: row["payload"],
                createdAt: row["createdAt"],
                attempts: row["attempts"],
                lastTryAt: row["lastTryAt"],
                info: row["info"]
            )
        }
    }
}

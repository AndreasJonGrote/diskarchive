//
//  DatabaseMaintenance.swift
//  diskindex
//
//  Leerlauf-Wartung: Zähler gelöschter Zeilen, incremental_vacuum, WAL (236).
//

import Foundation
import GRDB

nonisolated enum MaintenancePolicy {
    static let changeThreshold = 10_000
    static let maxPagesPerVacuumPass = 100
    static let maxVacuumPasses = 100

    static let debtKey = "maintenanceChangeDebt"
    static let lastCompactionKey = "lastCompactionAt"
}

nonisolated enum DatabaseMaintenance {
    /// Tests: Sabotage — ohne incremental_vacuum bleibt freelist hoch.
    nonisolated(unsafe) static var incrementalVacuumEnabled = true

    static func readDebt(_ db: Database) throws -> Int {
        guard let raw = try String.fetchOne(
            db,
            sql: "SELECT value FROM settings WHERE key = ?",
            arguments: [MaintenancePolicy.debtKey]
        ), let value = Int(raw) else { return 0 }
        return max(0, value)
    }

    static func addDebt(_ db: Database, rows: Int) throws {
        guard rows > 0 else { return }
        let next = try readDebt(db) + rows
        try db.execute(
            sql: """
                INSERT INTO settings (key, value, date) VALUES (?, ?, NULL)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
            arguments: [MaintenancePolicy.debtKey, String(next)]
        )
    }

    static func setDebt(_ db: Database, _ debt: Int) throws {
        try db.execute(
            sql: """
                INSERT INTO settings (key, value, date) VALUES (?, ?, NULL)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
            arguments: [MaintenancePolicy.debtKey, String(max(0, debt))]
        )
    }

    static func setLastCompaction(_ db: Database, atSeconds: Int64) throws {
        try db.execute(
            sql: """
                INSERT INTO settings (key, value, date) VALUES (?, NULL, ?)
                ON CONFLICT(key) DO UPDATE SET date = excluded.date
                """,
            arguments: [MaintenancePolicy.lastCompactionKey, atSeconds]
        )
    }

    static func freelistCount(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "PRAGMA freelist_count") ?? 0
    }

    static func runIncrementalVacuum(_ db: Database) throws {
        guard incrementalVacuumEnabled else { return }
        for _ in 0..<MaintenancePolicy.maxVacuumPasses {
            let free = try freelistCount(db)
            if free == 0 { break }
            try db.execute(sql: "PRAGMA incremental_vacuum(\(MaintenancePolicy.maxPagesPerVacuumPass))")
        }
    }

    static func truncateWriteAheadLog(_ db: Database) throws {
        try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
    }

    static func compactAfterLargeDelete(_ db: Database) throws {
        try runIncrementalVacuum(db)
        try truncateWriteAheadLog(db)
    }
}

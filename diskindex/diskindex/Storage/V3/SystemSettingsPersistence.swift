//
//  SystemSettingsPersistence.swift
//  diskindex
//
//  Systemzustand in `settings` (Versions-Check / Sperre, c.0.3.3.001).
//

import Foundation
import GRDB

nonisolated enum SystemSettingsKey {
    static let betaExpiryNoticedAt = "betaExpiryNoticedAt"
    static let apiLastSeen = "apiLastSeen"
    static let lockedVersion = "lockedVersion"
    static let skippedUpdateVersion = "skippedUpdateVersion"
}

nonisolated struct SystemSettingsSnapshot: Equatable, Sendable {
    var betaExpiryNoticedAt: Date?
    var apiLastSeen: Date?
    var lockedVersion: String?
    var skippedUpdateVersion: String?
}

nonisolated enum SystemSettingsPersistence {
    static func read(_ db: Database) throws -> SystemSettingsSnapshot {
        SystemSettingsSnapshot(
            betaExpiryNoticedAt: try readDate(db, key: SystemSettingsKey.betaExpiryNoticedAt),
            apiLastSeen: try readDate(db, key: SystemSettingsKey.apiLastSeen),
            lockedVersion: try readValue(db, key: SystemSettingsKey.lockedVersion),
            skippedUpdateVersion: try readValue(db, key: SystemSettingsKey.skippedUpdateVersion)
        )
    }

    static func writeBetaExpiryNoticedAt(_ db: Database, at: Date) throws {
        try writeDate(db, key: SystemSettingsKey.betaExpiryNoticedAt, date: at)
    }

    static func writeApiLastSeen(_ db: Database, at: Date) throws {
        try writeDate(db, key: SystemSettingsKey.apiLastSeen, date: at)
    }

    static func writeLockedVersion(_ db: Database, version: String) throws {
        try writeValue(db, key: SystemSettingsKey.lockedVersion, value: version)
    }

    static func writeSkippedUpdateVersion(_ db: Database, version: String?) throws {
        if let version {
            try writeValue(db, key: SystemSettingsKey.skippedUpdateVersion, value: version)
        } else {
            try db.execute(sql: "DELETE FROM settings WHERE key = ?", arguments: [SystemSettingsKey.skippedUpdateVersion])
        }
    }

    private static func readValue(_ db: Database, key: String) throws -> String? {
        try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key])
    }

    private static func readDate(_ db: Database, key: String) throws -> Date? {
        guard let seconds = try Int64.fetchOne(
            db,
            sql: "SELECT date FROM settings WHERE key = ?",
            arguments: [key]
        ) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private static func writeValue(_ db: Database, key: String, value: String) throws {
        try db.execute(
            sql: """
                INSERT INTO settings (key, value, date) VALUES (?, ?, NULL)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
            arguments: [key, value]
        )
    }

    private static func writeDate(_ db: Database, key: String, date: Date) throws {
        let seconds = Int64(date.timeIntervalSince1970)
        try db.execute(
            sql: """
                INSERT INTO settings (key, value, date) VALUES (?, NULL, ?)
                ON CONFLICT(key) DO UPDATE SET date = excluded.date
                """,
            arguments: [key, seconds]
        )
    }
}

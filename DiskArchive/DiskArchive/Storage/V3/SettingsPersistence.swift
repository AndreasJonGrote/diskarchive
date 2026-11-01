//
//  SettingsPersistence.swift
//  DiskArchive
//
//  App-Einstellungen in Tabelle `settings` (237).
//

import Foundation
import GRDB

nonisolated enum SettingsPersistence {
    static let appSettingsKey = "appSettings"

    static func readAppSettings(_ db: Database) throws -> PersistedAppSettings? {
        guard let raw = try String.fetchOne(
            db,
            sql: "SELECT value FROM settings WHERE key = ?",
            arguments: [appSettingsKey]
        ), let data = raw.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(PersistedAppSettings.self, from: data)
    }

    static func writeAppSettings(_ db: Database, _ settings: PersistedAppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try db.execute(
            sql: """
                INSERT INTO settings (key, value, date) VALUES (?, ?, NULL)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
            arguments: [appSettingsKey, json]
        )
    }

    /// Vor Store-Open (Crash-Pfad): read-only Peek in `archive.sqlite`.
    static func readAppSettings(at databaseURL: URL) throws -> PersistedAppSettings? {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return nil }
        let queue = try DatabaseQueue(path: databaseURL.path, configuration: readOnlyConfiguration())
        return try queue.read { db in try readAppSettings(db) }
    }

    private static func readOnlyConfiguration() -> Configuration {
        var config = Configuration()
        config.readonly = true
        config.label = "SettingsPeek"
        return config
    }
}

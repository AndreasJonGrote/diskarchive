//
//  AppSettingsRuntimeCache.swift
//  diskindex
//
//  Laufzeit-Cache für Einstellungen vor/nach Store-Open (237, Crash-Pfad).
//

import Foundation

nonisolated enum AppSettingsRuntimeCache {
    private static let lock = NSLock()
    private static var autoSendCrashReports = false
    private static var didBootstrap = false

    static func autoSendEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return autoSendCrashReports
    }

    static func setAutoSend(_ enabled: Bool) {
        lock.lock()
        autoSendCrashReports = enabled
        lock.unlock()
    }

    static func update(from persisted: PersistedAppSettings) {
        setAutoSend(persisted.autoSendCrashReports)
    }

    /// Vor `DiskIndexLog.start`: SQLite-Peek, sonst Legacy-UserDefaults, Default false.
    static func bootstrapBeforeStoreOpen(
        databaseURL: URL? = try? IndexStoreV3.storeFileURL(),
        defaults: UserDefaults = AppDefaults.current
    ) {
        lock.lock()
        if didBootstrap {
            lock.unlock()
            return
        }
        didBootstrap = true
        lock.unlock()

        if let databaseURL, let persisted = try? SettingsPersistence.readAppSettings(at: databaseURL) {
            update(from: persisted)
            return
        }
        let legacy = AppSettings.loadLegacyPersisted(from: defaults)
        update(from: legacy)
    }

    #if DEBUG
    static func resetBootstrapForTests() {
        lock.lock()
        didBootstrap = false
        autoSendCrashReports = false
        lock.unlock()
    }
    #endif
}

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

    #if DEBUG
    /// bug.0.4.120: Tests rechnen mit einem eigenen Speicher je Aufruf (`@TaskLocal`), nie mit dem prozessweiten Zustand
    /// (der Parallellauf teilt Prozesse).
    final class IsolatedStorage: @unchecked Sendable {
        let lock = NSLock()
        var autoSend = false
        var didBootstrap = false
    }

    @TaskLocal static var isolatedStorage: IsolatedStorage?

    static func isolating<T>(_ body: () async throws -> T) async rethrows -> T {
        try await $isolatedStorage.withValue(IsolatedStorage()) { try await body() }
    }
    #endif

    static func autoSendEnabled() -> Bool {
        #if DEBUG
        if let isolated = isolatedStorage {
            isolated.lock.lock()
            defer { isolated.lock.unlock() }
            return isolated.autoSend
        }
        #endif
        lock.lock()
        defer { lock.unlock() }
        return autoSendCrashReports
    }

    static func setAutoSend(_ enabled: Bool) {
        #if DEBUG
        if let isolated = isolatedStorage {
            isolated.lock.lock()
            isolated.autoSend = enabled
            isolated.lock.unlock()
            return
        }
        #endif
        lock.lock()
        autoSendCrashReports = enabled
        lock.unlock()
    }

    static func update(from persisted: PersistedAppSettings) {
        setAutoSend(persisted.autoSendCrashReports)
    }

    /// Vor `DiskIndexLog.start`: SQLite-Peek, sonst Default false (bug.0.4.208: keine Übernahme aus den Voreinstellungen).
    static func bootstrapBeforeStoreOpen(databaseURL: URL? = try? IndexStoreV3.storeFileURL()) {
        #if DEBUG
        if let isolated = isolatedStorage {
            isolated.lock.lock()
            let already = isolated.didBootstrap
            isolated.didBootstrap = true
            isolated.lock.unlock()
            if already { return }
        } else {
            lock.lock()
            let already = didBootstrap
            didBootstrap = true
            lock.unlock()
            if already { return }
        }
        #else
        lock.lock()
        if didBootstrap {
            lock.unlock()
            return
        }
        didBootstrap = true
        lock.unlock()
        #endif

        if let databaseURL, let persisted = try? SettingsPersistence.readAppSettings(at: databaseURL) {
            update(from: persisted)
            return
        }
        update(from: PersistedAppSettings())
    }
}

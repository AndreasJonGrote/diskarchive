//
//  PersistedAppSettings.swift
//  diskindex
//
//  App-Einstellungen in SQLite `settings` (237); ohne Sprache.
//

import Foundation

nonisolated struct PersistedAppSettings: Equatable, Codable {
    var scanDepth: Int = AppSettings.defaultScanDepth
    var favoriteOnlineNotificationsEnabled: Bool = true
    var ignoreHiddenFiles: Bool = true
    var artifactsIgnored: Bool = true
    var excludedPatterns: [String] = AppSettings.defaultExcludedPatterns
    var showFoldersRegardlessOfFilter: Bool = true
    var appearance: AppAppearance = .system
    var notificationsEnabled: Bool = true
    var notifySystem: Bool = true
    var notifyIndexed: Bool = true
    var notifyFavorites: Bool = true
    var autoSendCrashReports: Bool = false
}

extension AppSettings {
    mutating func applying(_ persisted: PersistedAppSettings) {
        scanDepth = persisted.scanDepth
        favoriteOnlineNotificationsEnabled = persisted.favoriteOnlineNotificationsEnabled
        ignoreHiddenFiles = persisted.ignoreHiddenFiles
        artifactsIgnored = persisted.artifactsIgnored
        excludedPatterns = persisted.excludedPatterns
        showFoldersRegardlessOfFilter = persisted.showFoldersRegardlessOfFilter
        appearance = persisted.appearance
        notificationsEnabled = persisted.notificationsEnabled
        notifySystem = persisted.notifySystem
        notifyIndexed = persisted.notifyIndexed
        notifyFavorites = persisted.notifyFavorites
        autoSendCrashReports = persisted.autoSendCrashReports
    }

    nonisolated func persistedSnapshot() -> PersistedAppSettings {
        PersistedAppSettings(
            scanDepth: scanDepth,
            favoriteOnlineNotificationsEnabled: favoriteOnlineNotificationsEnabled,
            ignoreHiddenFiles: ignoreHiddenFiles,
            artifactsIgnored: artifactsIgnored,
            excludedPatterns: excludedPatterns,
            showFoldersRegardlessOfFilter: showFoldersRegardlessOfFilter,
            appearance: appearance,
            notificationsEnabled: notificationsEnabled,
            notifySystem: notifySystem,
            notifyIndexed: notifyIndexed,
            notifyFavorites: notifyFavorites,
            autoSendCrashReports: autoSendCrashReports
        )
    }

    /// Legacy-Import: UserDefaults-Blob + optional separater Auto-Send-Key.
    nonisolated static func loadLegacyPersisted(from defaults: UserDefaults) -> PersistedAppSettings {
        var snapshot = load(from: defaults).persistedSnapshot()
        if defaults.object(forKey: IssueConsent.legacyAutoSendKey) != nil {
            snapshot.autoSendCrashReports = defaults.bool(forKey: IssueConsent.legacyAutoSendKey)
        }
        return snapshot
    }
}

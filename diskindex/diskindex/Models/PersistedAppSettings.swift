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
    /// todo.0.4.047: „Auf Updates hinweisen“.
    var notifyAboutUpdates: Bool = true
}

nonisolated extension PersistedAppSettings {
    /// bug.0.4.105: Fehlende Schlüssel (älterer Stand, neues Feld) bekommen die Voreinstellung, die übrigen
    /// Werte bleiben (wie `AppSettings.init(from:)`); sonst fiele der ganze Eintrag auf Voreinstellungen zurück.
    init(from decoder: Decoder) throws {
        let defaults = PersistedAppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scanDepth = try container.decodeIfPresent(Int.self, forKey: .scanDepth) ?? defaults.scanDepth
        favoriteOnlineNotificationsEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .favoriteOnlineNotificationsEnabled
        ) ?? defaults.favoriteOnlineNotificationsEnabled
        ignoreHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .ignoreHiddenFiles) ?? defaults.ignoreHiddenFiles
        artifactsIgnored = try container.decodeIfPresent(Bool.self, forKey: .artifactsIgnored) ?? defaults.artifactsIgnored
        excludedPatterns = try container.decodeIfPresent([String].self, forKey: .excludedPatterns) ?? defaults.excludedPatterns
        showFoldersRegardlessOfFilter = try container.decodeIfPresent(
            Bool.self, forKey: .showFoldersRegardlessOfFilter
        ) ?? defaults.showFoldersRegardlessOfFilter
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? defaults.appearance
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaults.notificationsEnabled
        notifySystem = try container.decodeIfPresent(Bool.self, forKey: .notifySystem) ?? defaults.notifySystem
        notifyIndexed = try container.decodeIfPresent(Bool.self, forKey: .notifyIndexed) ?? defaults.notifyIndexed
        notifyFavorites = try container.decodeIfPresent(Bool.self, forKey: .notifyFavorites) ?? defaults.notifyFavorites
        autoSendCrashReports = try container.decodeIfPresent(Bool.self, forKey: .autoSendCrashReports) ?? defaults.autoSendCrashReports
        notifyAboutUpdates = try container.decodeIfPresent(Bool.self, forKey: .notifyAboutUpdates) ?? defaults.notifyAboutUpdates
    }
}

/// bug.0.4.105: „kein Eintrag“ und „Lesefehler“ getrennt; nur „kein Eintrag“ darf neu geschrieben werden.
nonisolated enum PersistedAppSettingsLoad: Equatable {
    case missing
    case loaded(PersistedAppSettings)
    case unreadable
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
        notifyAboutUpdates = persisted.notifyAboutUpdates
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
            autoSendCrashReports: autoSendCrashReports,
            notifyAboutUpdates: notifyAboutUpdates
        )
    }
}

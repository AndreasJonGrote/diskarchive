//
//  AppSettings.swift
//  diskindex
//
//  UI + Mock-Zustand für Einstellungen (Aufgabe 19.8) — Backend liest später von hier.
//

import AppKit
import Foundation
import SwiftUI

nonisolated enum SettingsScrollTarget: Equatable {
    case scanDepth
}

nonisolated enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case files
    case storageMedia
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: LayoutCopy.tabGeneral
        case .files: LayoutCopy.tabFiles
        case .storageMedia: LayoutCopy.tabMedia
        case .advanced: LayoutCopy.tabAdvanced
        }
    }
}

nonisolated enum AppAppearance: String, Codable, CaseIterable, Equatable {
    case light
    case dark
    case system

    var title: String {
        switch self {
        case .light: LayoutCopy.appearanceLight
        case .dark: LayoutCopy.appearanceDark
        case .system: LayoutCopy.appearanceAuto
        }
    }

    @MainActor func apply() {
        switch self {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }
}

nonisolated struct AppSettings: Equatable, Codable {
    static let defaultScanDepth = 5
    static let defaultExcludedPatterns: [String] = []
    static let unlimitedScanDepth = 5

    /// 1…5 — bei 5 gilt „5+“ (uneingeschränkt).
    var scanDepth: Int = Self.defaultScanDepth
    var favoriteOnlineNotificationsEnabled: Bool = true
    var ignoreHiddenFiles: Bool = true
    var artifactsIgnored: Bool = true
    var excludedPatterns: [String] = Self.defaultExcludedPatterns
    /// Spaltenansicht: Ordner bleiben trotz Dateityp-/Endungs-Filter sichtbar (Aufgabe 33.5). Suche/Favoriten strikt.
    var showFoldersRegardlessOfFilter: Bool = true
    var appearance: AppAppearance = .system
    var notificationsEnabled: Bool = true
    var notifySystem: Bool = true
    var notifyIndexed: Bool = true
    var notifyFavorites: Bool = true
    var autoSendCrashReports: Bool = false
    /// UI-Sprache (DE/EN). Erststart: OS-Erkennung; Wirkung vollständig nach Neustart.
    var displayLanguage: AppDisplayLanguage = AppDisplayLanguage.resolveFromOperatingSystem()
    /// todo.0.4.047: „Auf Updates hinweisen“ (Tab Erweitert, Updatedialog). Aus = kein Updatedialog; der Versions-Check
    /// läuft weiter, Beta-Countdown und Sperre erscheinen immer.
    var notifyAboutUpdates: Bool = true

    mutating func resetGeneral() {
        scanDepth = Self.defaultScanDepth
        favoriteOnlineNotificationsEnabled = true
        showFoldersRegardlessOfFilter = true
    }

    mutating func resetIgnoredObjects() {
        excludedPatterns = Self.defaultExcludedPatterns
        ignoreHiddenFiles = true
        artifactsIgnored = true
    }

    var scanDepthLabel: String {
        scanDepthIsUnlimited ? "\(Self.unlimitedScanDepth)+" : "\(scanDepth)"
    }

    /// Uneingeschränkt ab Stufe 5.
    var scanDepthIsUnlimited: Bool {
        scanDepth >= Self.unlimitedScanDepth
    }

    /// `nil` bei „5+“ (keine Grenze).
    var indexedMaxDepth: Int? {
        scanDepthIsUnlimited ? nil : scanDepth
    }

    /// Ordner in Spalte `columnIndex` (Tiefe = Spaltenindex + 1) ist gelb, wenn seine Tiefe
    /// nicht unter `min(completedDepth, Scan-Tiefe)` liegt. Bei „5+“ zählt nur `completedDepth`.
    func isFolderContentUncaptured(columnIndex: Int, completedDepth: Int) -> Bool {
        let folderDepth = columnIndex + 1
        let limit = indexedMaxDepth.map { min(completedDepth, $0) } ?? completedDepth
        return folderDepth >= limit
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scanDepth = try container.decodeIfPresent(Int.self, forKey: .scanDepth) ?? Self.defaultScanDepth
        favoriteOnlineNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .favoriteOnlineNotificationsEnabled) ?? true
        ignoreHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .ignoreHiddenFiles) ?? true
        artifactsIgnored = try container.decodeIfPresent(Bool.self, forKey: .artifactsIgnored) ?? true
        _ = try container.decodeIfPresent([String].self, forKey: .artifactDisabledCategories)
        _ = try container.decodeIfPresent([String].self, forKey: .artifactIncludePatterns)
        excludedPatterns = try container.decodeIfPresent([String].self, forKey: .excludedPatterns) ?? Self.defaultExcludedPatterns
        _ = try container.decodeIfPresent([String: Date].self, forKey: .exclusionAddedAt)
        showFoldersRegardlessOfFilter = try container.decodeIfPresent(Bool.self, forKey: .showFoldersRegardlessOfFilter) ?? true
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notifySystem = try container.decodeIfPresent(Bool.self, forKey: .notifySystem) ?? true
        notifyIndexed = try container.decodeIfPresent(Bool.self, forKey: .notifyIndexed) ?? true
        notifyFavorites = try container.decodeIfPresent(Bool.self, forKey: .notifyFavorites) ?? favoriteOnlineNotificationsEnabled
        autoSendCrashReports = try container.decodeIfPresent(Bool.self, forKey: .autoSendCrashReports) ?? false
        displayLanguage = try container.decodeIfPresent(AppDisplayLanguage.self, forKey: .displayLanguage)
            ?? AppDisplayLanguage.resolveFromOperatingSystem()
        notifyAboutUpdates = try container.decodeIfPresent(Bool.self, forKey: .notifyAboutUpdates) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scanDepth, forKey: .scanDepth)
        try container.encode(favoriteOnlineNotificationsEnabled, forKey: .favoriteOnlineNotificationsEnabled)
        try container.encode(ignoreHiddenFiles, forKey: .ignoreHiddenFiles)
        try container.encode(artifactsIgnored, forKey: .artifactsIgnored)
        try container.encode(excludedPatterns, forKey: .excludedPatterns)
        try container.encode(showFoldersRegardlessOfFilter, forKey: .showFoldersRegardlessOfFilter)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(notifySystem, forKey: .notifySystem)
        try container.encode(notifyIndexed, forKey: .notifyIndexed)
        try container.encode(notifyFavorites, forKey: .notifyFavorites)
        try container.encode(displayLanguage, forKey: .displayLanguage)
        try container.encode(notifyAboutUpdates, forKey: .notifyAboutUpdates)
    }

    private enum CodingKeys: String, CodingKey {
        case scanDepth, favoriteOnlineNotificationsEnabled, ignoreHiddenFiles, artifactsIgnored
        case artifactDisabledCategories, artifactIncludePatterns // decode-only (121)
        case excludedPatterns, exclusionAddedAt, showFoldersRegardlessOfFilter, appearance
        case notificationsEnabled, notifySystem, notifyIndexed, notifyFavorites, autoSendCrashReports, displayLanguage
        case notifyAboutUpdates
    }
}

extension Binding where Value == AppSettings {
    /// Korrektes Two-Way-Binding für Felder in `AppSettings` (Value-Type — kein `wrappedValue.x = …` ohne Rückschreiben).
    func appSettingsField<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding<T>(
            get: { wrappedValue[keyPath: keyPath] },
            set: { newValue in
                var copy = wrappedValue
                copy[keyPath: keyPath] = newValue
                wrappedValue = copy
            }
        )
    }
}

enum ScanDepthExampleFormatting {
    struct Crumb: Identifiable {
        let id: Int
        let text: String
        let isCaptured: Bool
        let isLast: Bool
    }

    static func crumbs(depth: Int, unlimited: Bool) -> [Crumb] {
        if unlimited {
            return [
                Crumb(id: 0, text: LayoutCopy.diskCrumb, isCaptured: true, isLast: false),
                Crumb(id: 1, text: LayoutCopy.maxDepthCrumb, isCaptured: true, isLast: true),
            ]
        }

        let labels = [LayoutCopy.diskCrumb] + (1...4).map { LayoutCopy.scanDepthSubfolder($0) }
        let visibleCount = min(max(depth, 1), labels.count)
        return (0..<visibleCount).map { index in
            Crumb(
                id: index,
                text: labels[index],
                isCaptured: index == visibleCount - 1,
                isLast: index == visibleCount - 1
            )
        }
    }
}

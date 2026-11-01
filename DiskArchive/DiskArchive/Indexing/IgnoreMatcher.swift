//
//  IgnoreMatcher.swift
//  DiskArchive
//

import Foundation

nonisolated struct IgnoreMatcher: Sendable, Equatable {
    var ignoreHiddenFiles: Bool
    var excludedPatterns: [String] {
        didSet { parsedPatterns = Self.parse(excludedPatterns) }
    }
    /// bug.0.4.056 (REPORT 97): Muster einmal beim Anlegen zerlegt, nicht je Eintrag.
    private var parsedPatterns: [NamePattern]

    static let alwaysSkipped: Set<String> = [
        ".Spotlight-V100",
        ".fseventsd",
        ".Trashes",
        ".TemporaryItems",
        ".DocumentRevisions-V100",
        "System Volume Information",
    ]

    var artifactsIgnored: Bool = true

    init(ignoreHiddenFiles: Bool, excludedPatterns: [String], artifactsIgnored: Bool = true) {
        self.ignoreHiddenFiles = ignoreHiddenFiles
        self.excludedPatterns = excludedPatterns
        self.artifactsIgnored = artifactsIgnored
        self.parsedPatterns = Self.parse(excludedPatterns)
    }

    private static func parse(_ patterns: [String]) -> [NamePattern] {
        patterns.compactMap(NamePattern.parse)
    }

    func shouldSkip(name: String, isHidden: Bool, parentPath: [String] = []) -> Bool {
        _ = parentPath
        if name.hasPrefix("._") { return true }
        if Self.alwaysSkipped.contains(name) { return true }
        if ignoreHiddenFiles, isHidden || name.hasPrefix(".") { return true }
        guard artifactsIgnored || !parsedPatterns.isEmpty else { return false }
        // Einmal kleinschreiben für Artefakte und eigene Muster.
        let lower = name.lowercased()
        if artifactsIgnored, ArtifactRules.matches(lowercased: lower) {
            return true
        }
        for rule in parsedPatterns where rule.matches(lowercased: lower) { return true }
        return false
    }

    static func storedPathSegments(_ storedPath: String?) -> [String] {
        guard let storedPath else { return [] }
        return storedPath.split(separator: "/").map(String.init)
    }
}

nonisolated struct ScanConfiguration: Sendable, Equatable {
    /// `nil` = „5+“, keine Grenze.
    var maxDepth: Int?
    var ignoreHiddenFiles: Bool
    var artifactsIgnored: Bool = true
    var excludedPatterns: [String]
    var limits: IndexingRunLimits = .standard

    var matcher: IgnoreMatcher {
        IgnoreMatcher(
            ignoreHiddenFiles: ignoreHiddenFiles,
            excludedPatterns: excludedPatterns,
            artifactsIgnored: artifactsIgnored
        )
    }
}

/// Was die Oberfläche zeigt und was die Bereinigung löscht.
nonisolated struct IndexScope: Sendable, Equatable {
    var maxDepth: Int?
    var matcher: IgnoreMatcher
    /// Namensregeln gegen jede Zeile prüfen? Nur nötig, solange nach einer Regeländerung eine Bereinigung aussteht:
    /// der Scanner nimmt ausgeschlossene Dateien gar nicht erst auf. Sonst reines SQL (Tiefe immer).
    var checksNames = true

    static let revealAll = IndexScope(
        maxDepth: nil,
        matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
    )

    /// Regeln für Status-Reconcile und Bereinigung (234): unabhängig von `checksNames`.
    func shouldHide(name: String, depth: Int) -> Bool {
        if let maxDepth, depth > maxDepth { return true }
        return matcher.shouldSkip(name: name, isHidden: name.hasPrefix("."))
    }

    func hides(name: String, depth: Int) -> Bool {
        guard checksNames else { return false }
        return shouldHide(name: name, depth: depth)
    }

    static func from(_ settings: AppSettings, pruneAwaiting: Bool = false) -> IndexScope {
        IndexScope(
            maxDepth: settings.indexedMaxDepth,
            matcher: IgnoreMatcher(
                ignoreHiddenFiles: settings.ignoreHiddenFiles,
                excludedPatterns: settings.excludedPatterns,
                artifactsIgnored: settings.artifactsIgnored
            ),
            checksNames: false
        )
    }
}

nonisolated enum IndexSchedule {
    static let hour: TimeInterval = 3_600

    static func deadline(from now: Date) -> Date {
        now.addingTimeInterval(hour)
    }

    static func isDue(_ pruneAt: Date?, now: Date) -> Bool {
        guard let pruneAt else { return false }
        return pruneAt <= now
    }

    static func shrinks(from old: AppSettings, to new: AppSettings) -> Bool {
        if let next = new.indexedMaxDepth {
            if old.indexedMaxDepth == nil || next < (old.indexedMaxDepth ?? next) { return true }
        }
        if new.ignoreHiddenFiles, !old.ignoreHiddenFiles { return true }
        if new.artifactsIgnored, !old.artifactsIgnored { return true }
        return !Set(new.excludedPatterns).subtracting(old.excludedPatterns).isEmpty
    }

    static func grows(from old: AppSettings, to new: AppSettings) -> Bool {
        if let previous = old.indexedMaxDepth {
            if new.indexedMaxDepth == nil || (new.indexedMaxDepth ?? previous) > previous { return true }
        }
        if old.ignoreHiddenFiles, !new.ignoreHiddenFiles { return true }
        if old.artifactsIgnored, !new.artifactsIgnored { return true }
        return !Set(old.excludedPatterns).subtracting(new.excludedPatterns).isEmpty
    }
}

struct DirectoryReadStalled: Error {}

struct DirectoryIndexInterrupted: Error {
    var halt: ScanHalt
}

nonisolated enum ScanHalt: Sendable, Equatable {
    case none
    case pause
    case cancel
}

nonisolated enum IndexRunPhase: Sendable, Equatable {
    case counting
    case indexing
}

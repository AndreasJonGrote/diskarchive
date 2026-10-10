//
//  IgnoreMatcher.swift
//  diskindex
//

import Foundation

nonisolated struct IgnoreMatcher: Sendable, Equatable {
    var ignoreHiddenFiles: Bool
    var excludedPatterns: [String]

    static let alwaysSkipped: Set<String> = [
        ".Spotlight-V100",
        ".fseventsd",
        ".Trashes",
        ".TemporaryItems",
        ".DocumentRevisions-V100",
        "System Volume Information",
    ]

    var artifactsIgnored: Bool = true

    func shouldSkip(name: String, isHidden: Bool, parentPath: [String] = []) -> Bool {
        _ = parentPath
        if name.hasPrefix("._") { return true }
        if Self.alwaysSkipped.contains(name) { return true }
        if ignoreHiddenFiles, isHidden || name.hasPrefix(".") { return true }
        if artifactsIgnored, ArtifactRules.matches(name) {
            return true
        }
        for pattern in excludedPatterns {
            guard let rule = NamePattern.parse(pattern) else { continue }
            if rule.matches(name) { return true }
        }
        return false
    }

    static func storedPathSegments(_ storedPath: String?) -> [String] {
        guard let storedPath else { return [] }
        return storedPath.split(separator: "/").map(String.init)
    }
}

nonisolated struct IndexingRunLimits: Sendable, Equatable {
    var parallelDirectoryReads: Int = 1
    var batchEntryLimit: Int = 5_000
    var directoryChunkSize: Int = 2_000
    var directoryStallTimeout: TimeInterval = 30
    var consecutiveTimeoutLimit: Int = 3

    static let standard = IndexingRunLimits()
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

    static let revealAll = IndexScope(
        maxDepth: nil,
        matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
    )

    func hides(name: String, depth: Int) -> Bool {
        if let maxDepth, depth > maxDepth { return true }
        return matcher.shouldSkip(name: name, isHidden: name.hasPrefix("."))
    }

    static func from(_ settings: AppSettings) -> IndexScope {
        IndexScope(
            maxDepth: settings.indexedMaxDepth,
            matcher: IgnoreMatcher(
                ignoreHiddenFiles: settings.ignoreHiddenFiles,
                excludedPatterns: settings.excludedPatterns,
                artifactsIgnored: settings.artifactsIgnored
            )
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

nonisolated enum IndexingLimits {
    /// Produktions-Standard; Tests überschreiben über `ScanConfiguration.limits`.
    static var standard: IndexingRunLimits { .standard }
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

nonisolated struct IndexProgress: Sendable, Equatable {
    var phase: IndexRunPhase = .indexing
    var ratio: Double
    var filesStored: Int
    var filesDiscovered: Int
    var entriesTotal: Int = 0
    var entriesCompleted: Int = 0
    var countingCount: Int = 0
    var finished: Bool
}

nonisolated struct IndexRunOutcome: Sendable, Equatable {
    var status: StoredIndexStatus
    var readErrors: Int
    var progress: [Double]
    var completedDepths: [Int]
    var firstIndexedAt: Date?
}

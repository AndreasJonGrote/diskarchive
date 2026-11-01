//
//  ArtifactRules.swift
//  DiskArchive
//
//  Kuratierte Ausschlüsse (README, Regelliste Artefakte, 5.1–5.5).
//

import Foundation

nonisolated enum NamePattern: Equatable, Sendable {
    case exact(String)
    case prefix(String)
    case suffix(String)

    static func parse(_ pattern: String) -> NamePattern? {
        let text = pattern.lowercased()
        let stars = text.filter { $0 == "*" }.count
        if text.contains("?") || text.contains("[") || text.contains("]") || stars > 1 { return nil }
        if stars == 0 { return .exact(text) }
        if text.hasPrefix("*"), text.dropFirst().contains("*") == false {
            return .suffix(String(text.dropFirst()))
        }
        if text.hasSuffix("*"), text.dropLast().contains("*") == false {
            return .prefix(String(text.dropLast()))
        }
        return nil
    }

    func matches(_ name: String) -> Bool {
        matches(lowercased: name.lowercased())
    }

    /// bug.0.4.056 (REPORT 97): Name schon kleingeschrieben (einmal je Eintrag statt je Muster).
    func matches(lowercased lower: String) -> Bool {
        switch self {
        case .exact(let value):
            return lower == value
        case .prefix(let value):
            return lower.hasPrefix(value)
        case .suffix(let value):
            return lower.hasSuffix(value)
        }
    }
}

nonisolated enum ArtifactCategory: String, CaseIterable, Sendable {
    case temporary
    case backup
    case system
    case dependencyFolders
    case hiddenArtifacts
}

nonisolated enum ArtifactRules {
    static let patterns: [NamePattern] = ArtifactCategory.allCases.flatMap { categoryPatterns($0) }

    /// bug.0.4.056 (REPORT 97): Muster einmal zerlegt in genaue Namen (Set), Präfixe und Suffixe.
    private static let compiled: (exact: Set<String>, prefixes: [String], suffixes: [String]) = {
        var exact: Set<String> = []
        var prefixes: [String] = []
        var suffixes: [String] = []
        for pattern in patterns {
            switch pattern {
            case .exact(let value): exact.insert(value)
            case .prefix(let value): prefixes.append(value)
            case .suffix(let value): suffixes.append(value)
            }
        }
        return (exact, prefixes, suffixes)
    }()

    static func matches(_ name: String) -> Bool {
        matches(lowercased: name.lowercased())
    }

    static func matches(lowercased lower: String) -> Bool {
        let rules = compiled
        if rules.exact.contains(lower) { return true }
        for prefix in rules.prefixes where lower.hasPrefix(prefix) { return true }
        for suffix in rules.suffixes where lower.hasSuffix(suffix) { return true }
        return false
    }

    static func categoryPatterns(_ category: ArtifactCategory) -> [NamePattern] {
        rules(for: category).compactMap(NamePattern.parse)
    }

    private static func rules(for category: ArtifactCategory) -> [String] {
        switch category {
        case .temporary:
            [
                "*.tmp", "*.temp", "*.swp", "~$*", "*.crdownload", "*.part", "*.partial", "*.download", "*.opdownload", "*.log",
            ]
        case .backup:
            ["*~", "*.bak", "*.orig", "*.autosave"]
        case .system:
            ["thumbs.db", "ehthumbs.db", "desktop.ini", "$recycle.bin", "icon\u{000D}"]
        case .dependencyFolders:
            ["node_modules", "pods", "__pycache__", "deriveddata", "lib-cov"]
        case .hiddenArtifacts:
            [
                ".git*", ".svn", ".hg", ".venv", ".cache", ".next", ".nuxt", ".gradle", ".parcel-cache", ".turbo",
                ".pytest_cache", ".mypy_cache", ".sass-cache", ".ds_store", "._*", ".appledouble", ".lsoverride",
                ".trash-*", ".trash",
            ]
        }
    }
}

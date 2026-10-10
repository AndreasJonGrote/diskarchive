//
//  ArtifactRules.swift
//  diskindex
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
        let lower = name.lowercased()
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

    static func matches(_ name: String) -> Bool {
        patterns.contains { $0.matches(name) }
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

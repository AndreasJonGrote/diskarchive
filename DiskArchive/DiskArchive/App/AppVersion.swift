//
//  AppVersion.swift
//  DiskArchive
//
//  Versions-Vergleich n.n / n.n.n (c.0.3.3.001).
//

import Foundation

nonisolated struct AppVersion: Equatable, Sendable {
    var major: Int
    var minor: Int
    var patch: Int

    var isBeta: Bool { major == 0 }

    var displayString: String {
        if patch == 0 { return "\(major).\(minor)" }
        return "\(major).\(minor).\(patch)"
    }

    static func parse(_ raw: String) -> AppVersion? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else { return nil }
        let patch = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
        return AppVersion(major: major, minor: minor, patch: patch)
    }

    static func currentApp() -> AppVersion? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return nil }
        return parse(raw)
    }

    /// `CFBundleVersion` = yyyyMMddHHmm (Aufgabe 220), gelesen als UTC (246).
    static func buildTimestamp(from bundleVersion: String) -> Date? {
        let digits = bundleVersion.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        let prefix = String(digits.prefix(12))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        switch prefix.count {
        case 12:
            formatter.dateFormat = "yyyyMMddHHmm"
        case 8:
            formatter.dateFormat = "yyyyMMdd"
        default:
            return nil
        }
        return formatter.date(from: prefix)
    }

    static func currentBuildDate() -> Date? {
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else { return nil }
        return buildTimestamp(from: build)
    }

    func compareMajorMinor(to other: AppVersion) -> ComparisonResult {
        if major != other.major { return major < other.major ? .orderedAscending : .orderedDescending }
        if minor != other.minor { return minor < other.minor ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }

    func isOlderThanMajorMinor(_ other: AppVersion) -> Bool {
        compareMajorMinor(to: other) == .orderedAscending
    }

    /// Gesamte Semver für Entsperrung gegen `lockedVersion`.
    func compareFull(to other: AppVersion) -> ComparisonResult {
        if major != other.major { return major < other.major ? .orderedAscending : .orderedDescending }
        if minor != other.minor { return minor < other.minor ? .orderedAscending : .orderedDescending }
        if patch != other.patch { return patch < other.patch ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }
}

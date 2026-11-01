//
//  FileIdentity.swift
//  DiskArchive
//
//  Datei-Kennung für Umbenennen/Verschieben (235, datenbank-konzeption.md).
//

import Foundation

nonisolated enum FileIdentity {
    /// APFS/HFS+: `fileID` bleibt bei Umbenennen/Verschieben verlässlich.
    static func trustsFileID(fsType: String) -> Bool {
        let lower = fsType.lowercased()
        if lower == "apfs" { return true }
        if lower.hasPrefix("hfs") { return true }
        return false
    }

    static func scannedFileID(_ value: Int64?) -> String? {
        guard let value else { return nil }
        return String(value)
    }

    /// FAT: Ortszeit kann um ±1 h verschoben sein (Nutzer 11.10.).
    static func timestampsMatchFAT(_ lhs: Date?, _ rhs: Date?, tolerance: TimeInterval = 3600) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return abs(lhs.timeIntervalSince1970 - rhs.timeIntervalSince1970) <= tolerance
    }
}

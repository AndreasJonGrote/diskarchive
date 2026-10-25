//
//  Medium.swift
//  diskindex
//

import Foundation

enum MediumType: String, Codable, CaseIterable, Identifiable {
    case usb
    case ssd
    case hdd

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usb: "USB"
        case .ssd: "SSD"
        case .hdd: "HDD"
        }
    }
}

enum ConnectionStatus: String, Codable {
    case connected
    case offline
}

enum IndexStatus: String, Codable, CaseIterable {
    case indexing
    case indexed
    case error
    case pending
}

struct Medium: Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var type: MediumType
    var connectionStatus: ConnectionStatus
    var indexStatus: IndexStatus
    var allowIndexing: Bool
    var autoIndexPaused: Bool
    var decision: StoredIndexDecision = .index
    var capacityTotalBytes: Int64
    var capacityUsedBytes: Int64
    var fileCount: Int
    var folderCount: Int
    /// Gesamtzahl Einträge aus letztem Zähllauf (Migration v6).
    var scanTotal: Int = 0
    var lastSeenAt: Date?
    var firstIndexedAt: Date?
    /// Ende des letzten Indizierungslaufs.
    var lastIndexedAt: Date?
    /// Letzter Schreibvorgang am Index (Watcher, Scanner-Batch, Bereinigung).
    var lastIndexActivityAt: Date? = nil
    /// Letzte vollständig geschriebene Ebene. 0 = noch keine.
    var completedDepth: Int = 0
    var isForgotten: Bool
    /// Fortschritt beim Indizieren (0…1), nur relevant wenn `indexStatus == .indexing`.
    var indexingProgress: Double
    /// Laufende Zählphase (nur UI, nicht persistiert).
    var indexRunPhase: IndexRunPhase = .indexing
    /// Anzeige Belegung: Prozent vs. absolute Größe (pro Medium).
    var showAbsoluteCapacity: Bool = false
    /// Favorit (Mock bis 19.12 — konsistente Darstellung ab Dashboard).
    var isFavorite: Bool = false
    /// bug.0.4.200: der letzte Lauf bis zum Ende fand nicht lesbare Ordner (Merker `indexGaps`).
    var hasIndexGaps: Bool = false

    /// bug.0.4.200: Index bis auf die Lücke vollständig → verhält sich überall wie Online; nur Chip, „!“, Modal und
    /// Mitteilung sagen „Fehler“.
    var hasCompleteIndexExceptGaps: Bool {
        IndexGaps.completeExceptGaps(indexed: indexStatus == .indexed, error: indexStatus == .error, gaps: hasIndexGaps)
    }

    var hasIndex: Bool {
        completedDepth >= 1 || fileCount + folderCount > 0
    }

    /// Fortschritt 0…1; 100 % nur bei `indexStatus == .indexed` (Aufgabe 105 erweitert `scanTotal`).
    var indexProgressFraction: Double {
        if indexStatus == .indexed { return 1 }
        if indexStatus == .indexing, indexRunPhase == .counting { return 0 }
        let storedEntries = fileCount + folderCount
        if indexStatus == .indexing, indexingProgress > 0 {
            return min(0.99, indexingProgress)
        }
        if scanTotal > 0 {
            let total = max(scanTotal, storedEntries)
            return min(0.99, Double(storedEntries) / Double(total))
        }
        return min(max(indexingProgress, 0), 0.99)
    }

    /// Anzeige-Prozent 0…99, abgerundet; 100 nur bei vollständig indiziert.
    var indexProgressPercent: Int {
        if indexStatus == .indexed { return 100 }
        return Int(floor(indexProgressFraction * 100))
    }

    /// Dashboard, Seitenleiste, Suche und Favoriten: nur mit Index und Entscheidung.
    var isBrowsable: Bool {
        hasIndex && decision != .undecided && !isForgotten
    }

    var capacityUsedPercent: Double {
        guard capacityTotalBytes > 0 else { return 0 }
        return Double(capacityUsedBytes) / Double(capacityTotalBytes) * 100
    }

    var specLine: String {
        let files = DisplayNumberFormat.groupedInteger(fileCount)
        return "\(type.displayName) · \(totalCapacityLabel) · \(LayoutCopy.mediumFilesCount(files))"
    }
}

/// bug.0.4.200: eine Regel für `Medium` und `StoredMedium` (Regel 7).
nonisolated enum IndexGaps {
    static func completeExceptGaps(indexed: Bool, error: Bool, gaps: Bool) -> Bool {
        indexed || (error && gaps)
    }
}

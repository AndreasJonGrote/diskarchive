//
//  Medium.swift
//  DiskArchive
//

import Foundation

enum MediumType: String, Codable, CaseIterable, Identifiable {
    case usb
    case ssd
    case hdd

    var id: String { rawValue }
    // todo.0.4.3.007: kein Anzeigename – der Typ steht nie als Text, nur als Icon (Layout 00/19).
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
    /// todo.0.4.2.002: eigener Name (nur Anzeige); `name` bleibt der Originalname vom System.
    var customName: String? = nil
    /// todo.0.4.3.010 (Layout 06.03): Grund des letzten Fehlers; das Details-Fenster zeigt ihn bei Status „Fehler“.
    var failureReason: IndexFailureReason? = nil

    /// bug.0.4.200: Index bis auf die Lücke vollständig → verhält sich überall wie Online; nur Chip, „!“, Modal und
    /// Mitteilung sagen „Fehler“.
    var hasCompleteIndexExceptGaps: Bool {
        IndexGaps.completeExceptGaps(indexed: indexStatus == .indexed, error: indexStatus == .error, gaps: hasIndexGaps)
    }

    var hasIndex: Bool {
        completedDepth >= 1 || fileCount + folderCount > 0
    }

    /// Fortschritt 0…1; 100 % nur bei `indexStatus == .indexed` (Aufgabe 105 erweitert `scanTotal`).
    /// bug.0.4.210: nach der einen Rechnung (`IndexProgress.displayed`). Während eines Laufs dessen Wert
    /// (`indexingProgress`: gleiche Rechnung im Indexer, nie fallend, auch in der Zählphase), sonst der gespeicherte
    /// Stand – online und offline gleich.
    var indexProgressFraction: Double {
        if indexStatus == .indexing {
            return min(0.99, max(indexingProgress, 0))
        }
        return IndexProgress.displayed(entries: fileCount + folderCount, total: scanTotal, indexed: indexStatus == .indexed)
    }

    /// Anzeige-Prozent 0…99, abgerundet; 100 nur bei vollständig indiziert.
    var indexProgressPercent: Int {
        IndexProgress.percent(indexProgressFraction)
    }

    /// Dashboard, Seitenleiste, Suche und Favoriten: nur mit Index und Entscheidung.
    var isBrowsable: Bool {
        hasIndex && decision != .undecided && !isForgotten
    }

    var capacityUsedPercent: Double {
        guard capacityTotalBytes > 0 else { return 0 }
        return Double(capacityUsedBytes) / Double(capacityTotalBytes) * 100
    }

    /// todo.0.4.2.002: angezeigter Name – eigener Name, sonst Originalname.
    var shownName: String {
        customName ?? name
    }

    /// Medienlisten und Suche: findet über eigenen und Originalnamen (Umwandlung wie `Slug`).
    func matchesName(_ query: String) -> Bool {
        let term = Slug.make(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !term.isEmpty else { return true }
        return Slug.make(name).contains(term) || (customName.map { Slug.make($0).contains(term) } ?? false)
    }

    /// Eingabe im Details-Modal → gespeicherter Wert: Rand ohne Leerzeichen, höchstens `customNameMaxLength` Zeichen;
    /// leer oder gleich dem Originalnamen → `nil` (Schlüssel löschen).
    nonisolated static func normalizedCustomName(_ input: String, original: String) -> String? {
        let trimmed = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(customNameMaxLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == original ? nil : trimmed
    }

    nonisolated static let customNameMaxLength = 100

    var specLine: String {
        "\(totalCapacityLabel) · \(LayoutCopy.mediumFilesCount(fileCount))"
    }
}

/// bug.0.4.200: eine Regel für `Medium` und `StoredMedium` (Regel 7).
nonisolated enum IndexGaps {
    static func completeExceptGaps(indexed: Bool, error: Bool, gaps: Bool) -> Bool {
        indexed || (error && gaps)
    }
}

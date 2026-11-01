//
//  IndexRunTypes.swift
//  DiskArchive
//

import Foundation

/// Schreibfehler während eines Index-Laufs (bug.0.4.020 a).
nonisolated struct IndexWriteFailed: Error, Sendable {
    var underlying: Error
}

nonisolated struct IndexingRunLimits: Sendable, Equatable {
    var parallelDirectoryReads: Int = 1
    var batchEntryLimit: Int = 5_000
    var directoryChunkSize: Int = 2_000
    var directoryStallTimeout: TimeInterval = 30
    var consecutiveTimeoutLimit: Int = 3
    /// Wartezeiten vor den Wiederholungen beim Lesen eines Ordners; Tests verkürzen sie.
    var readRetryDelays: [Duration] = [.seconds(1), .seconds(3), .seconds(10)]
    /// bug.0.4.182: So lange wartet der Lauf nach einer nicht bestätigten Prüfung auf das Aushängen-Ereignis, bevor er
    /// als Fehler endet (beim echten Auswerfen kommt es kurz nach der Prüfung); Tests verkürzen es.
    var unmountGrace: Duration = .seconds(2)

    static let standard = IndexingRunLimits()
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

extension IndexProgress {
    /// bug.0.4.210: die eine Rechnung jeder Fortschrittsanzeige (Konzept „Fortschritt“, „Eine Rechnung“), rein und ohne
    /// Uhr. `entries` = gespeicherte Einträge (bei „Neu indizieren“ nur die dieses Laufs), `total` = Gesamtzahl
    /// (0 = noch nicht gezählt → 0). 1 nur bei „indiziert“, sonst höchstens 0,99 – auch „Fehler“ mit Lücke.
    nonisolated static func displayed(entries: Int, total: Int, indexed: Bool) -> Double {
        if indexed { return 1 }
        guard total > 0, entries > 0 else { return 0 }
        return min(0.99, Double(entries) / Double(max(total, entries)))
    }

    /// Ganze Prozent, abgerundet.
    nonisolated static func percent(_ fraction: Double) -> Int {
        Int(floor(fraction * 100))
    }
}

nonisolated struct IndexRunOutcome: Sendable, Equatable {
    var status: StoredIndexStatus
    var readErrors: Int
    var progress: [Double]
    var completedDepths: [Int]
    var firstIndexedAt: Date?
    /// Nur bei `.error` (und Abbruch durch Zeitüberschreitung): Grund aus dem Fehlerobjekt.
    var failureReason: IndexFailureReason?
    /// Abgebrochener Abgleich: DB `.indexed`, aber kein vollständiger Lauf (bug.0.4.014).
    var interrupted: Bool = false
    /// bug.0.4.127: Lauf bis zum Ende, aber mit nicht lesbaren Ordnern (bug.0.4.199: `.error`, Grund
    /// `.unreadableFolders`); Überwachung und Aufräumen wie nach einem vollständigen Lauf.
    var ranToEnd: Bool = false
}

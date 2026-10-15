//
//  IndexRunTypes.swift
//  diskindex
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
}

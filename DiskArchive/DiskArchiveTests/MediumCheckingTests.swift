//
//  MediumCheckingTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.013 (Layout 00, 03, 04): „Wird geprüft“ zwischen dem Erkennen und dem Start der Indizierung bzw. solange
//  der Lauf zählt – Chip ohne Prozent, Popover mit grünem Punkt. Folgt eine Indizierung → „{n} % indiziert“, ist nichts
//  zu tun → „Online“. Ein gespeichertes „wird indiziert“ zeigt beim Wiedererkennen nie den alten Prozentwert (99 %).
//  Popover: „Entscheidung ausstehend“ (gelb), „Speichermedium fehlerhaft“ (rot).
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct MediumCheckingTests {
    private static func medium(
        _ status: IndexStatus,
        decision: StoredIndexDecision = .index,
        phase: IndexRunPhase = .indexing,
        indexed: Bool = false,
        progress: Double = 0
    ) -> Medium {
        var medium = Medium(
            id: UUID(), name: "Zoom H6-01", type: .usb, connectionStatus: .connected, indexStatus: status,
            allowIndexing: decision == .index, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0,
            fileCount: indexed ? 10 : 0, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: indexed ? Date() : nil,
            lastIndexedAt: indexed ? Date() : nil, isForgotten: false, indexingProgress: progress
        )
        medium.decision = decision
        medium.indexRunPhase = phase
        if indexed { medium.completedDepth = 2 }
        return medium
    }

    @Test func newMediumIsCheckedThenIndexed() {
        L10n.$languageOverride.withValue(.german) {
            // Neu, „Indizieren“ entschieden, Lauf noch nicht gestartet.
            let waiting = Self.medium(.pending)
            #expect(MediumChip.presentation(waiting).text == "Wird geprüft")
            #expect(MediumChip.presentation(waiting).pulse && MediumChip.presentation(waiting).dashed)
            #expect(waiting.popoverStatusLine(paused: false, hasProgress: false) == .checking)
            // In der Pause startet keiner → nicht „geprüft“.
            #expect(MediumChip.presentation(waiting, globalAutoIndexPaused: true).text != "Wird geprüft")
            // Lauf zählt noch (keine Prozentangabe).
            let counting = Self.medium(.indexing, phase: .counting)
            #expect(MediumChip.presentation(counting).text == "Wird geprüft")
            #expect(counting.popoverStatusLine(paused: false, hasProgress: true) == .checking)
            // Indizierung läuft → Prozent.
            let running = Self.medium(.indexing, progress: 0.42)
            #expect(MediumChip.presentation(running).text == "42 % indiziert")
            #expect(running.popoverStatusLine(paused: false, hasProgress: true) == .progress)
            // Nichts zu tun → Online.
            #expect(MediumChip.presentation(Self.medium(.indexed, indexed: true)).text == "Online")
        }
    }

    /// Wiedererkennen eines beim Abziehen unterbrochenen Mediums: gespeichert „wird indiziert“ mit 99 %; ohne aktiven
    /// Lauf steht `awaitingRun` → „Wird geprüft“, nie „99 % indiziert“. Zählt ein Lauf mit bekanntem Stand (Abgleich),
    /// bleibt der Prozentwert.
    @Test func reconnectedMediumNeverShowsTheStoredPercent() {
        L10n.$languageOverride.withValue(.german) {
            let reconnected = Self.medium(.indexing, phase: .awaitingRun, indexed: true, progress: 0.99)
            #expect(MediumChip.presentation(reconnected).text == "Wird geprüft")
            #expect(!MediumChip.presentation(reconnected).text.contains("99"))
            #expect(reconnected.popoverStatusLine(paused: false, hasProgress: true) == .checking)
            #expect(MediumChip.presentation(Self.medium(.indexing, phase: .counting, indexed: true, progress: 0.1)).text == "10 % indiziert")
            // In der Pause (Lauf angehalten, gespeichert „wird indiziert“) kein „Wird geprüft“.
            #expect(MediumChip.presentation(reconnected, globalAutoIndexPaused: true).text != "Wird geprüft")
            #expect(reconnected.popoverStatusLine(paused: true, hasProgress: true) == .progress)
        }
    }

    @Test func popoverLinesForDecisionAndErrors() {
        let undecided = Self.medium(.pending, decision: .undecided)
        #expect(undecided.popoverStatusLine(paused: false, hasProgress: false) == .decisionPending)
        #expect(Self.medium(.error, indexed: true).popoverStatusLine(paused: false, hasProgress: false) == .hasErrors)
        let indexed = Self.medium(.indexed, indexed: true)
        #expect(indexed.popoverStatusLine(paused: false, hasProgress: false) == .lastIndexed(indexed.lastIndexedValue))
    }
}

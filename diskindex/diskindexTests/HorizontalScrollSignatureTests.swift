//
//  HorizontalScrollSignatureTests.swift
//  diskindexTests
//
//  bug.0.4.184 (Beweis für bug.0.4.180 b): Eine Mehrfachauswahl, von der nur ein Teil in der zwischengespeicherten Spalte
//  steht, wird nicht als Namensliste aufgezeichnet; das spätere Neuladen mit allen Namen ist dann kein „geändert“.
//  Ohne Fenster und ohne Zeiten – die Signatur allein.
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct HorizontalScrollSignatureTests {
    private let id1 = UUID()
    private let id2 = UUID()

    private func signature(names: [String]?, selection: [UUID]) -> HorizontalScrollSignature {
        HorizontalScrollSignature(mediumID: nil, pathStack: ["A"], selection: selection, selectionNames: names)
    }

    @Test func partlyKnownSelectionIsNotRecorded() {
        let partial = signature(names: ["a"], selection: [id1, id2])
        #expect(partial.recordable.selectionNames == nil)
        let full = signature(names: ["a", "b"], selection: [id1, id2])
        #expect(partial.recordable.match(full) == .same, "Neuladen mit allen Namen gilt als geändert")
    }

    /// Gegenprobe: eine vollständige Liste bleibt erhalten (live umbenannt = geändert), eine leere wird unbekannt.
    @Test func completeListIsKeptAndEmptyListBecomesUnknown() {
        let complete = signature(names: ["a", "b"], selection: [id1, id2])
        #expect(complete.recordable.selectionNames == ["a", "b"])
        #expect(complete.recordable.match(signature(names: ["a", "c"], selection: [id1, id2])) == .changed)
        let empty = signature(names: [], selection: [id1])
        #expect(empty.recordable.selectionNames == nil)
    }
}

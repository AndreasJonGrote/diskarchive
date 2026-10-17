//
//  ColumnSelectionScaleTests.swift
//  diskindexTests
//
//  bug.0.4.035 — ⌘A in großen Ordnern ohne quadratischen Aufwand: 50.000 Einträge, `selectAll`, `commit`
//  (Auswahlreihenfolge + Pfadeffekt) und `selectedIDs` jeweils < 50 ms (Laufzeitgrenze, bewusst).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct ColumnSelectionScaleTests {
    private static let count = 50_000

    private func items() -> [IndexedItem] {
        let medium = UUID()
        return (0..<Self.count).map { index in
            IndexedItem(
                id: IndexedItem.stableID(mediumID: medium, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: "datei-\(index).txt",
                kind: .file,
                parentPath: [],
                modifiedAt: nil,
                sizeBytes: 1,
                listedAt: nil
            )
        }
    }

    /// Kürzeste von drei Messungen (Ausreißer durch andere Prozesse), Ergebnis in Millisekunden.
    private func fastest(_ work: () -> Void) -> Double {
        var best = Double.infinity
        for _ in 0..<3 {
            let start = ContinuousClock.now
            work()
            let elapsed = start.duration(to: .now)
            best = min(best, Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)
        }
        return best
    }

    @Test func selectAllCommitAndSelectedIDsStayLinear() {
        let items = items()
        let visible = items.map(\.id)
        var selection = ColumnSelection()

        let selectAll = fastest { selection.selectAll(visible: visible, column: 0) }
        #expect(selection.ids.count == Self.count)

        var ordered: [IndexedItem] = []
        let commit = fastest {
            ordered = selection.ordered(in: items)
            _ = ColumnPathEffect.make(columnIndex: 0, existingPath: [], selected: ordered, uncapturedFolder: false)
        }
        #expect(ordered.count == Self.count)

        var marked = Set<UUID>()
        let selectedIDs = fastest {
            marked = ColumnBrowserSelectionHighlight.selectedIDs(
                items: items,
                columnIndex: 0,
                pathStack: [],
                selection: selection,
                selectedUncapturedFolderID: nil
            )
        }
        #expect(marked.count == Self.count)

        print("BENCH bug.0.4.035 selectAll=\(selectAll) ms commit=\(commit) ms selectedIDs=\(selectedIDs) ms (Debug)")
        #expect(selectAll < 50, "selectAll \(selectAll) ms")
        #expect(commit < 50, "commit \(commit) ms")
        #expect(selectedIDs < 50, "selectedIDs \(selectedIDs) ms")
    }

    @Test func ignoreBatchAndMenuPlanUseSets() {
        let patterns = (0..<Self.count).map { "name-\($0)" }
        var result: [String] = []
        let applying = fastest { result = IgnoreBatch.applying(patterns + patterns, to: Array(patterns.prefix(10))) }
        #expect(result.count == Self.count)
        #expect(Array(result.prefix(3)) == ["name-0", "name-1", "name-2"])
        print("BENCH bug.0.4.035 IgnoreBatch.applying=\(applying) ms (Debug)")
        #expect(applying < 50, "IgnoreBatch \(applying) ms")
    }
}

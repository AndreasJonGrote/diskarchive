//
//  ColumnSelectionScaleTests.swift
//  diskindexTests
//
//  bug.0.4.035 — ⌘A in großen Ordnern ohne quadratischen Aufwand. bug.0.3.9.005 a: geprüft über das Verhältnis
//  50.000 zu 5.000 Einträgen (linear ≈ 10, quadratisch ≈ 100; Grenze 40), nicht über Wanduhr-Millisekunden —
//  Last verlangsamt beide Messungen gleich. Die Millisekunden stehen nur im Testbericht.
//

import Foundation
import Testing
@testable import diskindex

extension MeasurementTestGroup {
@Suite(.serialized) @MainActor
struct ColumnSelectionScaleTests {
    private static let small = 5_000
    private static let large = 50_000
    /// Linear wäre 10, quadratisch 100.
    private static let ratioLimit = 40.0

    private func items(_ count: Int) -> [IndexedItem] {
        let medium = UUID()
        return (0..<count).map { index in
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

    /// Kürzeste von fünf Messungen (Ausreißer durch andere Prozesse), Ergebnis in Millisekunden.
    private func fastest(_ work: () -> Void) -> Double {
        var best = Double.infinity
        for _ in 0..<5 {
            let start = ContinuousClock.now
            work()
            let elapsed = start.duration(to: .now)
            best = min(best, Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)
        }
        return best
    }

    /// Verhältnis groß/klein; die kleine Messung mindestens 0,05 ms, damit Rauschen nahe null das Verhältnis nicht aufbläst.
    private func ratio(_ name: String, _ work: (Int) -> Void) -> Double {
        let smallMs = fastest { work(Self.small) }
        let largeMs = fastest { work(Self.large) }
        let ratio = largeMs / max(smallMs, 0.05)
        print("BENCH bug.0.3.9.005 \(name) \(Self.small)=\(smallMs) ms \(Self.large)=\(largeMs) ms Verhältnis=\(ratio) (Debug)")
        return ratio
    }

    @Test func selectAllCommitAndSelectedIDsStayLinear() {
        let smallItems = items(Self.small)
        let largeItems = items(Self.large)
        func rows(_ count: Int) -> [IndexedItem] { count == Self.small ? smallItems : largeItems }

        var selected = 0
        let selectAll = ratio("selectAll") { count in
            var selection = ColumnSelection()
            selection.selectAll(visible: rows(count).map(\.id), column: 0)
            selected = selection.ids.count
        }
        #expect(selected == Self.large)

        var ordered = 0
        let commit = ratio("commit") { count in
            var selection = ColumnSelection()
            selection.selectAll(visible: rows(count).map(\.id), column: 0)
            let list = selection.ordered(in: rows(count))
            _ = ColumnPathEffect.make(columnIndex: 0, existingPath: [], selected: list, uncapturedFolder: false)
            ordered = list.count
        }
        #expect(ordered == Self.large)

        var marked = 0
        let selectedIDs = ratio("selectedIDs") { count in
            var selection = ColumnSelection()
            selection.selectAll(visible: rows(count).map(\.id), column: 0)
            marked = ColumnBrowserSelectionHighlight.selectedIDs(
                items: rows(count),
                columnIndex: 0,
                pathStack: [],
                selection: selection,
                selectedUncapturedFolderID: nil
            ).count
        }
        #expect(marked == Self.large)

        #expect(selectAll < Self.ratioLimit, "selectAll Verhältnis \(selectAll)")
        #expect(commit < Self.ratioLimit, "commit Verhältnis \(commit)")
        #expect(selectedIDs < Self.ratioLimit, "selectedIDs Verhältnis \(selectedIDs)")
    }

    /// `IgnoreBatch.applying` und `ContextMenuPlan.multiple` (Häkchen „Name/Typ ignoriert“) über Mengen (bug.0.4.035).
    @Test func ignoreBatchAndMenuPlanUseSets() {
        func patterns(_ count: Int) -> [String] { (0..<count).map { "name-\($0)" } }
        var result: [String] = []
        let applying = ratio("IgnoreBatch.applying") { count in
            let list = patterns(count)
            result = IgnoreBatch.applying(list + list, to: Array(list.prefix(10)))
        }
        #expect(result.count == Self.large)
        #expect(Array(result.prefix(3)) == ["name-0", "name-1", "name-2"])

        let medium = UUID()
        func targets(_ count: Int) -> [ObjectContextTarget] {
            (0..<count).map { ObjectContextTarget(id: UUID(), name: "name-\($0)", kind: .file, mediumID: medium) }
        }
        let smallTargets = targets(Self.small)
        let largeTargets = targets(Self.large)
        let smallIgnored = patterns(Self.small)
        let largeIgnored = patterns(Self.large)
        var plan: ContextMenuPlan?
        let menu = ratio("ContextMenuPlan.multiple") { count in
            let isSmall = count == Self.small
            let list = isSmall ? smallTargets : largeTargets
            plan = ContextMenuPlan.multiple(
                targets: list,
                favorites: Array(repeating: false, count: list.count),
                ignored: isSmall ? smallIgnored : largeIgnored
            )
        }
        #expect(plan?.ignoreNameChecked == true)
        #expect(plan?.ignoreTypeChecked == false)

        #expect(applying < Self.ratioLimit, "IgnoreBatch Verhältnis \(applying)")
        #expect(menu < Self.ratioLimit, "ContextMenuPlan Verhältnis \(menu)")
    }
}
}

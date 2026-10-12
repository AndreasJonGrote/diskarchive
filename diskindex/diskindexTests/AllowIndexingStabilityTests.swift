//
//  AllowIndexingStabilityTests.swift
//  diskindexTests
//
//  Aufgabe 149 — Ja/Nein-Gruppe body bleibt bei Fortschrittsticks stabil.
//  Aufgabe 222 — Die Prüfung hängt nicht mehr an der Zahl der Zeichenläufe eines echten Fensters (die schwankte mit dem
//  Zustand der App: 6, 18, 20, 50 statt ≤ 4), sondern am Vertrag, der die Neuberechnung verhindert.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct AllowIndexingStabilityTests {
    private let id = UUID()

    private func group(
        _ mediumID: UUID? = nil, allow: Bool = true, pending: Bool = false, onChange: @escaping (Bool) -> Void = { _ in }
    ) -> AllowIndexingBinaryGroup {
        AllowIndexingBinaryGroup(mediumID: mediumID ?? id, allowIndexing: allow, isPending: pending, onChange: onChange)
    }

    /// Fortschrittstakte ändern nur Werte, die die Gruppe nicht betreffen: 50 gleiche Eingaben sind gleich, auch wenn
    /// der Rückruf jedes Mal ein neuer Verschluss ist. Dann überspringt `EquatableView` die Neuberechnung.
    @Test func groupStaysEqualAcrossProgressTicks() {
        let first = group()
        var calls = 0
        for tick in 0..<50 {
            let next = group(onChange: { _ in calls += tick })
            #expect(first == next, "Takt \(tick)")
        }
        #expect(calls == 0)
    }

    /// Die Gleichheit ist nicht zu großzügig: jede sichtbare Änderung führt zur Neuberechnung.
    @Test func groupChangesWhenAnythingVisibleChanges() {
        let base = group()
        #expect(base != group(UUID()))
        #expect(base != group(allow: false))
        #expect(base != group(pending: true))
    }

    /// Beide Verwendungen schützen die Gruppe mit `EquatableView`.
    @Test func bothCallSitesWrapTheGroupInEquatableView() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in ["diskindex/Views/Registry/RegistryTableRow.swift", "diskindex/Views/Detail/MediumDetailModalView.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            #expect(source.contains("EquatableView(content: AllowIndexingBinaryGroup("), "\(path)")
        }
    }

    @Test func groupHeightMatchesTheCatalog() async throws {
        let alone = NSHostingView(rootView: group())
        alone.layoutSubtreeIfNeeded()
        #expect(abs(alone.fittingSize.height - 24.4) <= 1.0)
    }
}
}

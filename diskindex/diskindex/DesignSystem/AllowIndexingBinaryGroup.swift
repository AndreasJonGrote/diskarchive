//
//  AllowIndexingBinaryGroup.swift
//  diskindex
//
//  Aufgabe 149 — Ja/Nein-Gruppe stabil; hört nur auf selection, nicht auf Fortschritt.
//

import SwiftUI

struct AllowIndexingBinaryGroup: View, Equatable {
    let mediumID: UUID
    let allowIndexing: Bool
    let isPending: Bool
    var onChange: (Bool) -> Void

    static func == (lhs: AllowIndexingBinaryGroup, rhs: AllowIndexingBinaryGroup) -> Bool {
        lhs.mediumID == rhs.mediumID
            && lhs.allowIndexing == rhs.allowIndexing
            && lhs.isPending == rhs.isPending
    }

    var body: some View {
        let selection = Binding<BinaryButtonGroupSelection>(
            get: {
                if isPending { return .none }
                return allowIndexing ? .first : .second
            },
            set: { value in
                guard value != .none else { return }
                onChange(value == .first)
            }
        )
        BinaryButtonGroup(firstTitle: LayoutCopy.binaryYes, secondTitle: LayoutCopy.binaryNo, selection: selection)
            .transaction { $0.animation = nil }
            .id(mediumID)
    }
}

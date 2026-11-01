//
//  AllowIndexingBinaryGroup.swift
//  DiskArchive
//
//  Aufgabe 149 — Ja/Nein-Gruppe stabil; hört nur auf selection, nicht auf Fortschritt.
//

import SwiftUI

struct AllowIndexingBinaryGroup: View, Equatable {
    let mediumID: UUID
    let allowIndexing: Bool
    let isPending: Bool
    var isEnabled: Bool = true
    var onChange: (Bool) -> Void

    static func == (lhs: AllowIndexingBinaryGroup, rhs: AllowIndexingBinaryGroup) -> Bool {
        lhs.mediumID == rhs.mediumID
            && lhs.allowIndexing == rhs.allowIndexing
            && lhs.isPending == rhs.isPending
            && lhs.isEnabled == rhs.isEnabled
    }

    var body: some View {
        let selection = Binding<BinaryButtonGroupSelection>(
            get: {
                if isPending { return .none }
                return allowIndexing ? .first : .second
            },
            set: { value in
                guard isEnabled, value != .none else { return }
                onChange(value == .first)
            }
        )
        BinaryButtonGroup(firstTitle: LayoutCopy.binaryYes, secondTitle: LayoutCopy.binaryNo, selection: selection)
            .transaction { $0.animation = nil }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
            .id(mediumID)
    }
}

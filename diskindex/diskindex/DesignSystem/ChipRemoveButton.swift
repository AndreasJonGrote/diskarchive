//
//  ChipRemoveButton.swift
//  diskindex
//
//  Entfernen-X auf Chips — Filter: unsichtbares Quadrat (Chip-Höhe); Ausschlüsse: Fläche bis zum Label.
//

import SwiftUI

enum ChipRemoveHitArea {
    /// Ignore-Chips: volle Höhe, horizontal vom Label bis zum rechten Rand.
    case band(gapAfterLabel: CGFloat, trailingPadding: CGFloat, verticalPadding: CGFloat)
}

struct ChipRemoveButton: View {
    var hitArea: ChipRemoveHitArea
    var action: () -> Void

    var body: some View {
        switch hitArea {
        case let .band(gapAfterLabel, trailingPadding, verticalPadding):
            bandButton(
                gapAfterLabel: gapAfterLabel,
                trailingPadding: trailingPadding,
                verticalPadding: verticalPadding
            )
        }
    }

    private func bandButton(
        gapAfterLabel: CGFloat,
        trailingPadding: CGFloat,
        verticalPadding: CGFloat
    ) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .padding(.leading, gapAfterLabel)
                .padding(.trailing, trailingPadding)
                .padding(.vertical, verticalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
    }
}

/// Filter-Chips: Optik unverändert (kleines X), Klickfläche = Quadrat mit Seitenlänge = Chip-Höhe, rechts bündig.
struct ChipRemoveSquareHitOverlay: View {
    var action: () -> Void

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.height
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button(action: action) {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plainFullHit)
                .pointerCursor()
                .frame(width: side, height: side)
            }
        }
    }
}

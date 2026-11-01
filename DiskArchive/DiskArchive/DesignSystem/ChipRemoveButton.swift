//
//  ChipRemoveButton.swift
//  DiskArchive
//
//  Entfernen-X auf Filter-Chips: unsichtbares Quadrat (Chip-Höhe). bug.0.4.195: unbenutzte Band-Variante entfernt.
//

import SwiftUI

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

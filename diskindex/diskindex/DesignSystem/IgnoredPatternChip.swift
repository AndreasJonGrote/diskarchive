//
//  IgnoredPatternChip.swift
//  diskindex
//
//  Aufgabe 128/131 — Katalogmaße: 10/400, 3/10, Höhe 23,5, ✕ mittig.
//

import SwiftUI

struct IgnoredPatternChip: View {
    let pattern: String
    var onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(pattern)
                .font(.system(size: 10, weight: .regular))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 10, height: 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plainFullHit)
            .pointerCursor()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(minHeight: 23.5)
        .foregroundStyle(DesignColor.stateIgnored)
        .background(DesignColor.chipFill(DesignColor.stateIgnored))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.sm)
                .strokeBorder(DesignColor.chipBorder(DesignColor.stateIgnored), lineWidth: DesignBorder.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}

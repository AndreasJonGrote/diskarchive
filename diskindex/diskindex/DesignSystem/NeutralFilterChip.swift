//
//  NeutralFilterChip.swift
//  diskindex
//
//  Aufgabe 131 — Katalog: Chip 10/400, 3/10, Höhe 23,5.
//

import SwiftUI

struct NeutralFilterChip: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .regular))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .frame(minHeight: 23.5)
                .foregroundStyle(isSelected ? DesignColor.text : DesignColor.neutral800)
                .background(isSelected ? Color.clear : DesignColor.neutral200)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(
                            isSelected ? DesignColor.neutral500 : DesignColor.neutral300,
                            lineWidth: DesignBorder.width
                        )
                }
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
    }
}

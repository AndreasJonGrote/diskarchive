//
//  ChipButton.swift
//  DiskArchive
//
//  Das eine Chip-Rezept (Katalog „Chips“, Layout 09 `.tag`): Schrift 10/400, Innenabstand 10/3, Mindesthöhe 23,5,
//  Rahmen innen (`strokeBorder`), ganze Fläche klickbar. Farben kommen als Parameter (bug.0.4.149, Regel 12).
//

import SwiftUI

struct ChipButton: View {
    let title: String
    let foreground: Color
    let background: Color
    let border: Color
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
                .foregroundStyle(foreground)
                .background(background)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(border, lineWidth: DesignBorder.width)
                }
        }
        .buttonStyle(.plainFullHit)
    }
}

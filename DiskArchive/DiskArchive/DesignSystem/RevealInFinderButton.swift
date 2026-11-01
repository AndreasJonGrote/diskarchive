//
//  RevealInFinderButton.swift
//  DiskArchive
//
//  „Im Finder anzeigen“ in der Detail-Spalte (Layout Sektion 07, Aufgabe 23.8).
//

import SwiftUI

struct RevealInFinderButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image("IconArrowSquareOut")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                Text(LayoutCopy.revealInFinder)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignColor.text)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .fill(isHovered ? DesignColor.text.opacity(0.07) : Color.clear)
            }
            .designControlBorder(DesignBorder.secondaryControlBorderColor)
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .onHover { isHovered = $0 }
    }
}

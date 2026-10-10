//
//  SearchFieldClearButton.swift
//  diskindex
//
//  Aufgabe 19.2 — X in grauem Kreis zum Leeren des Suchfelds.
//

import SwiftUI

struct SearchFieldClearButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DesignColor.text.opacity(0.65))
                .frame(width: 14, height: 14)
                .background(Circle().fill(DesignColor.neutral300))
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .accessibilityLabel(ProposalCopy.prefixIfNeeded(ProposalCopy.clearSearchAccessibility))
    }
}

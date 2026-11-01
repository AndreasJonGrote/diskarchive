//
//  NeutralFilterChip.swift
//  DiskArchive
//
//  Aufgabe 131 — Katalog: Chip 10/400, 3/10, Höhe 23,5.
//

import SwiftUI

struct NeutralFilterChip: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        ChipButton(
            title: title,
            foreground: isSelected ? DesignColor.text : DesignColor.neutral800,
            background: isSelected ? Color.clear : DesignColor.neutral200,
            border: isSelected ? DesignColor.neutral500 : DesignColor.neutral300,
            action: action
        )
        .pointerCursor()
    }
}

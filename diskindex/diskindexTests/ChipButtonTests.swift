//
//  ChipButtonTests.swift
//  diskindexTests
//
//  bug.0.4.149: das eine Chip-Rezept an der Quelle (Katalog „Chips“: Höhe 23,5, Innenabstand 10/3, Schrift 10), dazu die
//  drei Chips, die es nutzen.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct ChipButtonTests {
    private func size<V: View>(_ view: V) -> CGSize {
        NSHostingView(rootView: view).fittingSize
    }

    @Test func singleLineChipIs23Point5High() {
        let chip = ChipButton(title: "Bild", foreground: .primary, background: .clear, border: .gray) {}
        let fitted = size(chip)
        #expect(abs(fitted.height - 23.5) <= 0.5, "Höhe \(fitted.height)")
        // Innenabstand links/rechts 10: breiter als der Text allein um mindestens 20.
        let text = size(Text("Bild").font(.system(size: 10, weight: .regular)))
        #expect(abs(fitted.width - (text.width + 20)) <= 1, "Breite \(fitted.width) gegenüber Text \(text.width)")
    }

    @Test func allChipsShareTheRecipe() {
        let a = size(NeutralFilterChip(title: "Alle", isSelected: false) {})
        let b = size(FilterTypeChipButton(label: "Alle", isSelected: false) {})
        let c = size(ChipButton(title: "Alle", foreground: .primary, background: .clear, border: .gray) {})
        // bug.0.4.163 (c): auch der Verbindungs-Chip der Favoriten (gewählt und nicht gewählt).
        let d = size(FavoritesConnectionChip(title: "Alle", isSelected: false) {})
        let e = size(FavoritesConnectionChip(title: "Alle", isSelected: true) {})
        #expect(abs(a.height - 23.5) <= 0.5 && abs(b.height - 23.5) <= 0.5)
        #expect(abs(d.height - 23.5) <= 0.5 && abs(e.height - 23.5) <= 0.5, "\(d) \(e)")
        #expect(abs(a.width - c.width) <= 0.5 && abs(b.width - c.width) <= 0.5, "\(a) \(b) \(c)")
        #expect(abs(d.width - c.width) <= 0.5 && abs(e.width - c.width) <= 0.5, "\(d) \(e) \(c)")
    }
}

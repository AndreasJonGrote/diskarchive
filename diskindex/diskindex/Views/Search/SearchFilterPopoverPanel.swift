//
//  SearchFilterPopoverPanel.swift
//  diskindex
//
//  Filter-Popover (Layout 07B, Aufgabe 23.4): blauer Rahmen, Radius 14, Nase oben links auf der Kante.
//

import SwiftUI

struct SearchFilterPopoverPanel: View {
    /// Abstand vom oberen Kastenrand zur Nasenspitze (halbe Diagonale des 11er-Quadrats, abzüglich Versatz).
    static let noseHeight: CGFloat = 8

    var body: some View {
        SearchFilterPopover()
            .background(DesignColor.bg)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.lg)
                    .strokeBorder(DesignColor.filterSearch, lineWidth: DesignBorder.width)
            }
            // Nase außerhalb des Clips: halb über, halb auf der oberen Kante (überdeckt den Rand).
            .overlay(alignment: .topLeading) {
                FilterPopoverNose()
                    .offset(x: 18, y: -6)
            }
            // Schatten nur für die Gesamtform, nicht für jede Unteransicht.
            .compositingGroup()
            .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }
}

/// Quadrat 11 × 11, 45° gedreht, Fläche `bg`, blauer Rand nur oben und links.
private struct FilterPopoverNose: View {
    private let side: CGFloat = 11

    var body: some View {
        Rectangle()
            .fill(DesignColor.bg)
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 0.5, y: side))
                    path.addLine(to: CGPoint(x: 0.5, y: 0.5))
                    path.addLine(to: CGPoint(x: side, y: 0.5))
                }
                .stroke(DesignColor.filterSearch, lineWidth: DesignBorder.width)
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(45))
    }
}

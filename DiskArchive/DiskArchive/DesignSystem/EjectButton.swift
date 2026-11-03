//
//  EjectButton.swift
//  DiskArchive
//
//  todo.0.4.3.011 (Layout 04, 05, 19): Auswerfen-Knopf direkt am Status-Chip – schlichtes Eject-Icon (16) mit Rahmen in
//  Textfarbe, nie grau; beim Hover gefüllt (Fläche Textfarbe, Icon Hintergrundfarbe). Quadratisch in Chip-Höhe.
//  Nur bei angeschlossenen Medien, nie in Seitenleisten und Medienspalten, nie automatisch.
//

import SwiftUI

struct EjectButton: View {
    @Environment(AppState.self) private var appState
    let mediumID: UUID
    @State private var isHovered = false

    /// Chip-Höhe (`docs/Komponenten-Masse.md`: 23,5).
    static let side: CGFloat = 23.5

    var body: some View {
        Button {
            Task { await appState.ejectMedium(id: mediumID) }
        } label: {
            Image("IconEjectSimple")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(isHovered ? DesignColor.bg : DesignColor.text)
                .frame(width: Self.side, height: Self.side)
                .background(isHovered ? DesignColor.text : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(DesignColor.text, lineWidth: DesignBorder.width)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .onHover { isHovered = $0 }
        .help(LayoutCopy.eject)
        .accessibilityLabel(LayoutCopy.eject)
    }
}

//
//  TableSortHeader.swift
//  diskindex
//
//  Tabellenregel: Die sortierte Spalte erkennt man allein an Schwarz + Fett;
//  alle anderen Köpfe regular und gedämpft (Aufgabe 20.9).
//

import SwiftUI

struct TableSortHeader: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Self.label(title, isActive: isActive)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
    }

    static func label(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: isActive ? .bold : .regular))
            .foregroundStyle(isActive ? DesignColor.control : DesignColor.text.opacity(0.55))
    }
}

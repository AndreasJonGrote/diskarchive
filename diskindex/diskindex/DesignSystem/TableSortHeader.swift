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
    /// `false`: Kopf nicht klickbar, gedämpft wie ein deaktivierter Knopf (bug.0.4.038, Deckkraft wie `MenuBarGhostButton`).
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Self.label(title, isActive: isActive)
        }
        .buttonStyle(.plainFullHit)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .pointerCursor(isEnabled)
    }

    static func label(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: isActive ? .bold : .regular))
            .foregroundStyle(isActive ? DesignColor.control : DesignColor.text.opacity(0.55))
    }
}

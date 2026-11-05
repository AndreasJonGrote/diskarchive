//
//  TableSortHeader.swift
//  DiskArchive
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
    /// Lage der Beschriftung in der Spalte (rechtsbündige Spalten: `.trailing`).
    var alignment: Alignment = .leading
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // bug.0.4.081: Die Beschriftung füllt die ganze Spaltenbreite, die ganze Spalte ist klickbar (vorher nur der
            // Text: Mitte/rechter Rand bzw. bei „Status“ linker Rand und Mitte trafen nicht, gleich in welchem Stil).
            Self.label(title, isActive: isActive)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
        .buttonStyle(.plainFullHit)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .pointerCursor(isEnabled)
    }

    static func label(_ title: String, isActive: Bool) -> some View {
        Text(title)
            // todo.0.4.3.018 (Layout 05.02, 19): Kopf 11 pt fett, aktive Spalte in Textfarbe (schwarz), sonst leise; keine
            // Sortierpfeile.
            .font(.system(size: DesignTable.headerFont, weight: .bold))
            .foregroundStyle(isActive ? DesignColor.text : DesignColor.text.opacity(DesignTable.quietOpacity))
    }
}

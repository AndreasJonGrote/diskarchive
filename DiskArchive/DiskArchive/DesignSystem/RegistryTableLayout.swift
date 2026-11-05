//
//  RegistryTableLayout.swift
//  DiskArchive
//
//  Spaltenmaße Screen 01B (Mockup-Tabelle).
//

import CoreGraphics

enum RegistryTableLayout {
    static let horizontalPadding: CGFloat = 16
    static let statusWidth: CGFloat = 148
    static let indexingWidth: CGFloat = 118
    static let detailActionWidth: CGFloat = 44
    static let rowVerticalPadding: CGFloat = DesignTable.verticalPadding
    /// todo.0.4.3.018: Spalte „Zuletzt gesehen“ (rechtsbündig, Layout 05.02).
    static let lastSeenWidth: CGFloat = 112
}

/// todo.0.4.3.018 (Layout 19, `docs/Komponenten-Masse.md` „Tabellenzeile“): gleiche Werte in allen Tabellen (Suche,
/// Favoriten, Speichermedien) – Zeilen 14 pt mit 11 pt Innenabstand oben und unten, Kopf 11 pt fett, Datum 13 pt leise.
enum DesignTable {
    static let rowFont: CGFloat = 14
    static let headerFont: CGFloat = 11
    static let dateFont: CGFloat = 13
    static let verticalPadding: CGFloat = 11
    /// Leise Werte (Kopf inaktiv, Datum): 60 % Textfarbe.
    static let quietOpacity: Double = 0.6
}

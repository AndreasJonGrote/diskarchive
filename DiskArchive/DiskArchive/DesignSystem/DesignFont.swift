//
//  DesignFont.swift
//  DiskArchive
//
//  todo.0.4.3.019 (Nutzer 03.11., Layout 19): Archivo für Titel von Kacheln und Fenstern (Gewicht 800). Die Schrift liegt
//  im Bundle (`Resources/Fonts/Archivo-Variable.ttf`, Lizenz `OFL.txt`) und wird beim Start für den Prozess registriert.
//  Fehlt sie zur Laufzeit, gilt System-Fett.
//

import AppKit
import CoreText
import SwiftUI

enum DesignFont {
    /// Benannte Instanz der variablen Schrift mit Gewicht 800.
    static let headingName = "ArchivoRoman-ExtraBold"
    static let fileName = "Archivo-Variable"

    /// Registriert die Schrift einmal je Prozess; `true`, wenn sie danach verfügbar ist.
    @discardableResult
    static func registerBundledFonts(bundle: Bundle = .main) -> Bool {
        if NSFont(name: headingName, size: 12) != nil { return true }
        guard let url = bundle.url(forResource: fileName, withExtension: "ttf") else { return false }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return NSFont(name: headingName, size: 12) != nil
    }

    /// Titel (Kachel 17 pt, Dialog 16 pt): Archivo 800, sonst System-Fett.
    static func heading(size: CGFloat) -> Font {
        if let font = headingNSFont(size: size) {
            return Font(font)
        }
        return .system(size: size, weight: .bold)
    }

    static func headingNSFont(size: CGFloat) -> NSFont? {
        registerBundledFonts()
        return NSFont(name: headingName, size: size)
    }
}

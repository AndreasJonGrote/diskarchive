//
//  MediumEject.swift
//  DiskArchive
//
//  todo.0.4.3.011 (`konzept/datenschutz-plattform.md`, Nutzer 01.11.): einzige Stelle der App, die ein Medium auswirft
//  – Ausnahme der Schreibschranke (`ReadOnlyMediaGuardTests`), nur auf ausdrücklichen Klick, nie automatisch.
//  Auswerfen ändert keine Daten auf dem Medium.
//

import AppKit

nonisolated enum MediumEject {
    /// Hängt das Volume am Pfad aus und wirft es aus. Wirft, wenn macOS ablehnt (z. B. Medium in Benutzung).
    /// Läuft nie auf dem Hauptfaden (Regel 5): `NSWorkspace` wartet hier auf das System.
    @concurrent
    static func unmountAndEject(path: String) async throws {
        try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: path, isDirectory: true))
    }
}

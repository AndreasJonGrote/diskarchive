//
//  KeyablePanel.swift
//  DiskArchive
//
//  Borderless Popover-Panel mit Tastatur-Fokus (TextFields).
//

import AppKit

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Erster Klick trifft Controls im Popover, nicht nur Aktivierung (Aufgabe 86 D).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }
}

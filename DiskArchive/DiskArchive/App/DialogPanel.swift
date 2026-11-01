//
//  DialogPanel.swift
//  DiskArchive
//
//  bug.0.4.221: Panel der Dialoge (Erkennung, „Ersetzt dieses Medium?“, „Ignorieren bestätigen“, Absturzbericht).
//  Kann Key und Main werden: die Aktivierung beim Erscheinen holt so nur den Dialog nach vorn, nicht das
//  Hauptfenster. Das Popover der Menüleiste bleibt bei `KeyablePanel` (nie Main).
//

import AppKit

final class DialogPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Wie `KeyablePanel`: der erste Klick trifft die Controls, nicht nur die Aktivierung.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }
}

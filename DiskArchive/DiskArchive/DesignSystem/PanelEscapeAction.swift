//
//  PanelEscapeAction.swift
//  DiskArchive
//
//  bug.0.3.9.005 c — Esc in einem Rückfrage-Panel (Ignorieren, Medium ersetzen).
//
//  Abgrenzung zu `onEscapeKey` (EscapeKeyMonitor.swift): Das ist ein app-weiter Monitor für Overlays im
//  Hauptfenster; im schwebenden, nicht aktivierenden Panel finge er Esc auch im Hauptfenster ab, solange das Panel
//  offen ist. `onExitCommand` löst ohne fokussiertes Element nicht aus (die Dialoge haben keins). Hier greift ein
//  unsichtbarer Knopf mit `.cancelAction` über die Tastenkürzel genau dieses Fensters.
//

import SwiftUI

extension View {
    /// Ruft `action` bei Esc auf, solange diese Ansicht im Fenster ist (nur dieses Fenster).
    func onPanelEscape(_ action: @escaping () -> Void) -> some View {
        background {
            Button("", action: action)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .focusable(false)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

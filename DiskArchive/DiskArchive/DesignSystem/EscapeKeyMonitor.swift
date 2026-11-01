//
//  EscapeKeyMonitor.swift
//  DiskArchive
//
//  Escape schließt eingeblendete Overlays (Filter-Popover, Kontextmenü) — unabhängig vom Fokus.
//

import AppKit
import SwiftUI

private struct EscapeKeyModifier: ViewModifier {
    let action: () -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.keyCode == 53 else { return event } // Escape
                    MainActor.assumeIsolated { action() }
                    return nil
                }
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
                monitor = nil
            }
    }
}

extension View {
    /// Ruft `action` bei Escape auf, solange die View sichtbar ist; das Event wird verschluckt.
    func onEscapeKey(perform action: @escaping () -> Void) -> some View {
        modifier(EscapeKeyModifier(action: action))
    }
}

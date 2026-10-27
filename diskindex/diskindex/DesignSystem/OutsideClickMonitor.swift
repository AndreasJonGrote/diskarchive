//
//  OutsideClickMonitor.swift
//  diskindex
//
//  bug.0.4.212: Klick neben ein eingeblendetes Panel (Filter) schließt es, ohne dort etwas auszulösen – ohne
//  fensterfüllende Fläche, damit Scrollen und Mausbewegung darunter weiter ankommen.
//

import AppKit
import SwiftUI

extension View {
    /// Mausklick im selben Fenster außerhalb dieser Ansicht → `action`; der Klick wird verschluckt (erreicht das Ziel
    /// darunter nicht). Klicks in die Ansicht, in andere Fenster und Scrollen bleiben unberührt.
    func onClickOutside(perform action: @escaping () -> Void) -> some View {
        background(OutsideClickMonitorView(action: action))
    }
}

private struct OutsideClickMonitorView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> OutsideClickMonitorNSView {
        let view = OutsideClickMonitorNSView()
        view.action = action
        return view
    }

    func updateNSView(_ view: OutsideClickMonitorNSView, context: Context) {
        view.action = action
    }

    static func dismantleNSView(_ view: OutsideClickMonitorNSView, coordinator: ()) {
        view.removeMonitor()
    }
}

/// Liegt hinter dem Panel und hat seine Größe; Tests lesen daraus den Rahmen des Panels.
final class OutsideClickMonitorNSView: NSView {
    var action: () -> Void = {}
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeMonitor()
        } else if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                let location = event.locationInWindow
                let windowNumber = event.windowNumber
                let closes = MainActor.assumeIsolated {
                    self?.closesOnClick(at: location, windowNumber: windowNumber) ?? false
                }
                return closes ? nil : event
            }
        }
    }

    private func closesOnClick(at location: NSPoint, windowNumber: Int) -> Bool {
        guard let window, window.windowNumber == windowNumber else { return false }
        guard !bounds.contains(convert(location, from: nil)) else { return false }
        action()
        return true
    }

    func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

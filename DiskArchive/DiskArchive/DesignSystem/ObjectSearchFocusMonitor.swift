//
//  ObjectSearchFocusMonitor.swift
//  DiskArchive
//
//  Entzieht dem Objekt-Suchfeld den Fokus bei Klicks außerhalb (inkl. Titelleiste).
//

import AppKit
import SwiftUI

struct ObjectSearchFieldFrameInWindowKey: PreferenceKey {
    static var defaultValue: ObjectSearchFieldWindowFrame = .init()

    static func reduce(value: inout ObjectSearchFieldWindowFrame, nextValue: () -> ObjectSearchFieldWindowFrame) {
        let next = nextValue()
        if next.frame != .zero {
            value = next
        }
    }
}

struct ObjectSearchFieldWindowFrame: Equatable {
    var frame: CGRect = .zero
    var windowIdentifier: ObjectIdentifier?
}

struct ObjectSearchFieldFrameInWindowReporter: NSViewRepresentable {
    @Binding var frameInWindow: ObjectSearchFieldWindowFrame

    func makeCoordinator() -> Coordinator {
        Coordinator(frameInWindow: $frameInWindow)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ReportingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ReportingView)?.coordinator = context.coordinator
        (nsView as? ReportingView)?.publishFrameIfNeeded()
    }

    final class Coordinator {
        var frameInWindow: Binding<ObjectSearchFieldWindowFrame>

        init(frameInWindow: Binding<ObjectSearchFieldWindowFrame>) {
            self.frameInWindow = frameInWindow
        }
    }

    final class ReportingView: NSView {
        weak var coordinator: Coordinator?
        private var lastPublished: ObjectSearchFieldWindowFrame = .init()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            publishFrameIfNeeded()
        }

        override func layout() {
            super.layout()
            publishFrameIfNeeded()
        }

        func publishFrameIfNeeded() {
            guard let window, let coordinator else { return }
            let frame = convert(bounds, to: nil)
            let payload = ObjectSearchFieldWindowFrame(
                frame: frame,
                windowIdentifier: ObjectIdentifier(window)
            )
            guard payload != lastPublished else { return }
            lastPublished = payload
            DispatchQueue.main.async {
                coordinator.frameInWindow.wrappedValue = payload
            }
        }
    }
}

@MainActor
final class ObjectSearchFocusClickMonitor {
    static let shared = ObjectSearchFocusClickMonitor()

    private struct Client {
        var fieldFrame: ObjectSearchFieldWindowFrame
        let isFocused: () -> Bool
        let dismissFocus: () -> Void
    }

    private var clients: [UUID: Client] = [:]
    private var eventMonitor: Any?

    private init() {}

    func register(
        id: UUID,
        fieldFrame: ObjectSearchFieldWindowFrame,
        isFocused: @escaping () -> Bool,
        dismissFocus: @escaping () -> Void
    ) {
        clients[id] = Client(fieldFrame: fieldFrame, isFocused: isFocused, dismissFocus: dismissFocus)
        installMonitorIfNeeded()
    }

    func updateFieldFrame(id: UUID, fieldFrame: ObjectSearchFieldWindowFrame) {
        clients[id]?.fieldFrame = fieldFrame
    }

    func unregister(id: UUID) {
        clients.removeValue(forKey: id)
        if clients.isEmpty {
            removeMonitor()
        }
    }

    private func installMonitorIfNeeded() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseDown(event)
            }
            return event
        }
    }

    private func removeMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let eventWindow = event.window else { return }
        let eventWindowID = ObjectIdentifier(eventWindow)
        let point = event.locationInWindow

        for client in clients.values {
            guard client.isFocused() else { continue }
            guard client.fieldFrame.windowIdentifier == eventWindowID else { continue }

            let frame = client.fieldFrame.frame
            if frame != .zero {
                let padded = frame.insetBy(dx: -6, dy: -6)
                if padded.contains(point) {
                    continue
                }
            }

            client.dismissFocus()
        }
    }
}

struct ObjectSearchFocusOutsideClickDismissModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    @State private var fieldFrameInWindow: ObjectSearchFieldWindowFrame = .init()
    @State private var clientID = UUID()

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ObjectSearchFieldFrameInWindowKey.self) { fieldFrameInWindow = $0 }
            .onAppear {
                ObjectSearchFocusClickMonitor.shared.register(
                    id: clientID,
                    fieldFrame: fieldFrameInWindow,
                    isFocused: { isFocused },
                    dismissFocus: { isFocused = false }
                )
            }
            .onDisappear {
                ObjectSearchFocusClickMonitor.shared.unregister(id: clientID)
            }
            .onChange(of: fieldFrameInWindow) { _, newValue in
                ObjectSearchFocusClickMonitor.shared.updateFieldFrame(id: clientID, fieldFrame: newValue)
            }
    }
}

extension View {
    /// Suchfeld-Fokus bei Klick irgendwo im Fenster abgeben (AppKit-Monitor, deckt Titelleiste mit ab).
    func dismissObjectSearchFocusOnOutsideClick(isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(ObjectSearchFocusOutsideClickDismissModifier(isFocused: isFocused))
    }
}

//
//  AppWindowPresenter.swift
//  diskindex
//
//  Einziges Fenster-Management (NSWindow + NSHostingController) — keine SwiftUI-Window-Scenes.
//

import AppKit
import SwiftUI

@MainActor
enum AppWindowPresenter {
    private static let mainWindowAutosaveName = "DiskIndexMainWindow"
    private static let defaultMainWindowSize = NSSize(width: 1100, height: 750)

    private static var mainWindow: NSWindow?
    private static var newMediumWindow: NSPanel?
    private static var crashReportWindow: NSPanel?
    private static var windowDelegates: [ObjectIdentifier: PresenterWindowDelegate] = [:]

    /// Öffnet bzw. holt das Hauptfenster nach vorn; `destination == nil` behält die aktuelle Ansicht.
    static func openMain(appState: AppState, destination: MainWindowDestination? = nil) {
        if let destination {
            appState.mainWindowDestination = destination
        }
        AppActivationPolicy.showDockIconForMainWindow()
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            clearInitialFocus(in: window, appState: appState)
            return
        }

        let host = NSHostingController(
            rootView: MainWindowHostView()
                .environment(appState)
                .frame(minWidth: 720, minHeight: 480)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultMainWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = LayoutCopy.diskIndex
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = true
        window.backgroundColor = DesignColor.windowChrome
        window.contentViewController = host
        window.setFrameAutosaveName(mainWindowAutosaveName)
        if !window.setFrameUsingName(mainWindowAutosaveName) {
            centerMainWindowOnVisibleScreen(window)
        }
        register(window) {
            mainWindow = nil
        }
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        tintWindowTitle(window)
        clearInitialFocus(in: window, appState: appState)
    }

    /// Aufgabe 28: Nach `openMain` hat kein Feld den Fokus. AppKit macht beim Key-Werden das erste Element
    /// der Key-View-Loop (Toolbar-Suchfeld) zum First Responder; SwiftUI setzt Fokus teils erst nach dem
    /// ersten Layout — daher ein Durchlauf im nächsten Runloop und ein Nachzügler nach dem Layout.
    /// Bewusst NICHT bei jedem `didBecomeKey` (⌘-Tab zurück behält den Cursor).
    /// Systemtitel bleibt, die Farbe ist `text` bei 60 % statt der warmen Systemfarbe.
    private static func tintWindowTitle(_ window: NSWindow) {
        let color = DesignColor.windowTitle
        func walk(_ view: NSView) {
            if let field = view as? NSTextField, field.stringValue == window.title {
                field.textColor = color
            }
            view.subviews.forEach(walk)
        }
        if let content = window.contentView?.superview {
            walk(content)
        }
    }

    private static func clearInitialFocus(in window: NSWindow, appState: AppState) {
        appState.searchFieldFocusResetCount += 1
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Nur ein automatisch gesetzter Textfeld-Fokus wird entfernt, kein anderer Responder.
            if window.firstResponder is NSText {
                window.makeFirstResponder(nil)
                appState.searchFieldFocusResetCount += 1
            }
        }
    }

    /// Systemweites „Neues Medium“-Panel (Aufgabe 9) — schwebt über allen Fenstern.
    static func openNewMedium(appState: AppState) {
        guard appState.newMediumDialogMediumID != nil else { return }

        if let window = newMediumWindow {
            window.orderFrontRegardless()
            window.makeKey()
            return
        }

        let hosting = NSHostingView(
            rootView: NewMediumDialogWindowHost()
                .environment(appState)
        )
        let size = hosting.fittingSize
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = hosting
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.center()
        register(panel) {
            newMediumWindow = nil
        }
        newMediumWindow = panel
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    static func closeNewMedium() {
        newMediumWindow?.close()
    }

    /// Fenster ohne Animation ausblenden — vor dem Prozessende, damit SwiftUI nicht mehr rendert.
    static func prepareForTermination() {
        mainWindow?.orderOut(nil)
        newMediumWindow?.orderOut(nil)
        crashReportWindow?.orderOut(nil)
    }

    static func openCrashReport() {
        if let window = crashReportWindow {
            window.orderFrontRegardless()
            window.makeKey()
            return
        }
        let hosting = NSHostingView(
            rootView: CrashReportDialog {
                DiskIndexLog.shared.acknowledgeCrashDialog()
                crashReportWindow?.close()
            }
        )
        let size = hosting.fittingSize
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentView = hosting
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.center()
        register(panel) { crashReportWindow = nil }
        crashReportWindow = panel
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private static func centerMainWindowOnVisibleScreen(_ window: NSWindow) {
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        var frame = window.frame
        frame.size = defaultMainWindowSize
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(frame, display: false)
    }

    private static func register(_ window: NSWindow, onClose: @escaping () -> Void) {
        window.isRestorable = false
        let key = ObjectIdentifier(window)
        let delegate = PresenterWindowDelegate {
            windowDelegates.removeValue(forKey: key)
            onClose()
        }
        windowDelegates[key] = delegate
        window.delegate = delegate
        window.isReleasedWhenClosed = false
    }
}

private final class PresenterWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

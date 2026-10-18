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
    nonisolated private static let newMediumStackOffset: CGFloat = 24
    /// Goldener Schnitt von oben (todo.0.4.012): Panel-Mitte bei 38,2 % der sichtbaren Höhe.
    nonisolated private static let newMediumGoldenRatioFromTop: CGFloat = 0.382

    private static var mainWindow: NSWindow?
    private static var newMediumPanels: [UUID: NSPanel] = [:]
    private static var crashReportWindow: NSPanel?
    /// Rückfrage-Panels je `AppState`-Instanz (bug.0.3.9.005 c): in der App genau eins je Art; Tests mit eigener
    /// Instanz sehen und schließen nie das Panel eines anderen Tests.
    private static var replaceMediumPanels: [ObjectIdentifier: NSPanel] = [:]
    private static var ignoreConfirmPanels: [ObjectIdentifier: NSPanel] = [:]
    private static var windowDelegates: [ObjectIdentifier: PresenterWindowDelegate] = [:]

    /// Anzahl offener Erkennungs-Panels (Tests).
    static var openNewMediumPanelCount: Int { newMediumPanels.count }

    /// Ob das Hauptfenster existiert und sichtbar ist (todo.0.4.011).
    static var isMainWindowVisible: Bool { mainWindow?.isVisible == true }

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

    /// Pro unentschiedenem oder erneut gefragtem Medium (todo.0.4.026) ein schwebendes Panel (0.3.2), unten rechts
    /// gestapelt.
    static func syncNewMediumPanels(appState: AppState, revealDismissed: Bool = false) {
        let activeIDs = appState.pendingNewMediumDecisionIDs.filter { id in
            guard appState.needsNewMediumDialog(id) else { return false }
            if !revealDismissed, appState.dismissedNewMediumPanelIDs.contains(id) { return false }
            return true
        }

        let stale = Set(newMediumPanels.keys).subtracting(activeIDs)
        for id in stale {
            closeNewMediumPanel(mediumID: id, appState: appState, userDismissed: false)
        }

        for (stackIndex, id) in activeIDs.enumerated() {
            openOrUpdateNewMediumPanel(mediumID: id, appState: appState, stackIndex: stackIndex, stackCount: activeIDs.count)
        }

        if let frontID = activeIDs.last, let panel = newMediumPanels[frontID] {
            panel.orderFrontRegardless()
            panel.makeKey()
        }
    }

    static func openNewMedium(appState: AppState) {
        guard appState.hasPendingNewMediumDecisions else { return }
        syncNewMediumPanels(appState: appState, revealDismissed: true)
    }

    /// Schließen ohne Ja/Nein: Panel weg, Medium bleibt `undecided` (Queue/Badge).
    static func closeNewMediumPanel(mediumID: UUID, appState: AppState, userDismissed: Bool) {
        if userDismissed {
            appState.dismissedNewMediumPanelIDs.insert(mediumID)
        }
        newMediumPanels[mediumID]?.close()
    }

    /// Fenster ohne Animation ausblenden — vor dem Prozessende, damit SwiftUI nicht mehr rendert.
    static func prepareForTermination() {
        mainWindow?.orderOut(nil)
        for panel in newMediumPanels.values {
            panel.orderOut(nil)
        }
        crashReportWindow?.orderOut(nil)
        closePromptPanels()
    }

    /// Schließt die Rückfrage-Panels (`appState == nil`: alle, beim Beenden) ohne Neuzeichnen; `windowWillClose`
    /// setzt die zugehörige Rückfrage in `AppState` zurück (bug.0.3.9.007 b), sonst bliebe eine Rückfrage ohne
    /// sichtbares Panel stehen.
    static func closePromptPanels(for appState: AppState? = nil) {
        let key = appState.map(ObjectIdentifier.init)
        let panels = [replaceMediumPanels, ignoreConfirmPanels].flatMap { panels in
            panels.filter { key == nil || $0.key == key }.map(\.value)
        }
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
    }

    /// Rückfrage „Ersetzt dieses Medium?“ als schwebendes Panel wie der Erkennungs-Dialog (bug.0.4.031 c).
    static func openReplaceMediumPrompt(appState: AppState, placement: PromptPanelPlacement = .centered) {
        guard appState.replaceMediumPrompt != nil else { return }
        let key = ObjectIdentifier(appState)
        if let panel = replaceMediumPanels[key] {
            show(panel, placement: placement)
            return
        }
        let hosting = NSHostingView(
            rootView: ReplaceMediumDialogWindowHost(onDone: { replaceMediumPanels[key]?.close() })
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
        panel.contentView = hosting
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        register(panel) { [weak appState] in
            replaceMediumPanels[key] = nil
            appState?.replaceMediumPrompt = nil
        }
        replaceMediumPanels[key] = panel
        place(panel, placement: placement)
        show(panel, placement: placement)
    }

    /// Rückfrage vor dem Ignorieren vieler Ziele (bug.0.4.035), gleiches Panel wie die Medium-Rückfrage.
    static func openIgnoreConfirmation(appState: AppState, placement: PromptPanelPlacement = .centered) {
        guard appState.ignoreConfirmationPrompt != nil else { return }
        let key = ObjectIdentifier(appState)
        if let panel = ignoreConfirmPanels[key] {
            show(panel, placement: placement)
            return
        }
        let hosting = NSHostingView(
            rootView: IgnoreConfirmDialogWindowHost(onDone: { ignoreConfirmPanels[key]?.close() })
                .environment(appState)
        )
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
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
        register(panel) { [weak appState] in
            ignoreConfirmPanels[key] = nil
            appState?.ignoreConfirmationPrompt = nil
        }
        ignoreConfirmPanels[key] = panel
        place(panel, placement: placement)
        show(panel, placement: placement)
    }

    /// Offenes Ignorier-Panel dieser Instanz (Tests, bug.0.3.9.005 c).
    static func ignoreConfirmationPanel(for appState: AppState) -> NSPanel? {
        ignoreConfirmPanels[ObjectIdentifier(appState)]
    }

    /// Offenes Panel „Ersetzt dieses Medium?“ dieser Instanz (Tests, bug.0.3.9.005 c).
    static func replaceMediumPromptPanel(for appState: AppState) -> NSPanel? {
        replaceMediumPanels[ObjectIdentifier(appState)]
    }

    private static func place(_ panel: NSPanel, placement: PromptPanelPlacement) {
        switch placement {
        case .centered:
            panel.center()
        case .offscreen:
            panel.setFrameOrigin(PromptPanelPlacement.offscreenOrigin)
        }
    }

    /// Gleicher Responder in App und Test; nur die App macht das Panel zum Key-Fenster (Tests: Regel 19/21).
    private static func show(_ panel: NSPanel, placement: PromptPanelPlacement) {
        panel.orderFrontRegardless()
        panel.makeFirstResponder(panel.contentView)
        if placement == .centered {
            panel.makeKey()
        }
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

    private static func openOrUpdateNewMediumPanel(
        mediumID: UUID,
        appState: AppState,
        stackIndex: Int,
        stackCount: Int
    ) {
        let hosting: NSHostingView<AnyView>
        if let panel = newMediumPanels[mediumID], let existing = panel.contentView as? NSHostingView<AnyView> {
            hosting = existing
        } else {
            hosting = NSHostingView(
                rootView: AnyView(
                    NewMediumDialogWindowHost(mediumID: mediumID)
                        .environment(appState)
                )
            )
            let panel = makeNewMediumPanel(hosting: hosting)
            register(panel) {
                newMediumPanels.removeValue(forKey: mediumID)
            }
            newMediumPanels[mediumID] = panel
            let depthFromNewest = stackCount - 1 - stackIndex
            placeNewMediumPanel(panel, depthFromNewest: depthFromNewest)
        }

        guard let panel = newMediumPanels[mediumID] else { return }
        panel.orderFrontRegardless()
    }

    /// Erkennungs-Panel ohne Lage und ohne Anzeige (bug.0.3.9.014 a: dieselbe Erzeugung in App und Test).
    static func makeNewMediumPanel(hosting: NSHostingView<AnyView>) -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
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
        return panel
    }

    /// Reine Lage-Rechnung (todo.0.4.012); Tests ohne AppKit-Fenster.
    nonisolated static func newMediumPanelFrame(
        visibleFrame: CGRect,
        panelSize: CGSize,
        depthFromNewest: Int
    ) -> CGRect {
        let offset = CGFloat(depthFromNewest) * newMediumStackOffset
        let centerX = visibleFrame.midX - offset
        let centerY = visibleFrame.maxY - visibleFrame.height * newMediumGoldenRatioFromTop - offset
        return CGRect(
            x: centerX - panelSize.width / 2,
            y: centerY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private static func placeNewMediumPanel(_ panel: NSPanel, depthFromNewest: Int) {
        let visible = NSScreen.main?.visibleFrame ?? .zero
        var size = panel.frame.size
        if size.width < 10 || size.height < 10, let hosting = panel.contentView as? NSHostingView<AnyView> {
            size = hosting.fittingSize
        }
        let frame = newMediumPanelFrame(visibleFrame: visible, panelSize: size, depthFromNewest: depthFromNewest)
        panel.setFrame(frame, display: true)
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

/// Wo die Rückfrage-Panels (Ignorieren, Medium ersetzen) erscheinen — je `AppState`-Instanz
/// (`AppState.promptPanelPlacement`, bug.0.3.9.005 c), nicht über einen Prozess-Schalter.
enum PromptPanelPlacement: Equatable {
    /// App: Bildschirmmitte, wird Key-Fenster.
    case centered
    /// Tests: außerhalb des sichtbaren Bereichs, ohne Key-Fenster (Regel 19/21).
    case offscreen

    static let offscreenOrigin = NSPoint(x: -20_000, y: -20_000)
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

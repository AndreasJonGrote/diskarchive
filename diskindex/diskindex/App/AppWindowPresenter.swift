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
    /// Erkennungs-Panels je `AppState`-Instanz (bug.0.4.117): ein Test sieht und schließt nie die Panels eines
    /// anderen Tests.
    private static var newMediumPanels: [ObjectIdentifier: [UUID: NSPanel]] = [:]
    private static var crashReportWindow: NSPanel?
    /// Rückfrage-Panels je `AppState`-Instanz (bug.0.3.9.005 c): in der App genau eins je Art; Tests mit eigener
    /// Instanz sehen und schließen nie das Panel eines anderen Tests.
    private static var replaceMediumPanels: [ObjectIdentifier: NSPanel] = [:]
    private static var ignoreConfirmPanels: [ObjectIdentifier: NSPanel] = [:]
    private static var windowDelegates: [ObjectIdentifier: PresenterWindowDelegate] = [:]

    #if DEBUG
    /// Anzahl offener Erkennungs-Panels dieser Instanz (Tests).
    static func openNewMediumPanelCount(for appState: AppState) -> Int {
        newMediumPanels[ObjectIdentifier(appState)]?.count ?? 0
    }
    #endif

    /// bug.0.4.142: Lage, die ein `open*` tatsächlich benutzt. Im Testprozess immer außerhalb des Bildschirms (Regel 19/21),
    /// auch wenn ein Test die Lage nicht gesetzt oder `.centered` angefordert hat; sonst die angeforderte Lage.
    nonisolated static func effectivePlacement(_ requested: PromptPanelPlacement?) -> PromptPanelPlacement {
        RuntimeEnvironment.isRunningTests ? .offscreen : (requested ?? .centered)
    }

    /// bug.0.4.162 (g): Lage der Erkennungs-Panels – `nil` = kein Panel, sonst über `effectivePlacement` (im Test nie
    /// auf dem Bildschirm, auch bei `.centered`).
    static func newMediumPanelPlacement(for appState: AppState) -> PromptPanelPlacement? {
        appState.promptPanelPlacement.map { effectivePlacement($0) }
    }

    static func mainWindowPlacement(for appState: AppState) -> PromptPanelPlacement {
        effectivePlacement(appState.promptPanelPlacement)
    }

    #if DEBUG
    /// Ob das Hauptfenster existiert und sichtbar ist (todo.0.4.011).
    static var isMainWindowVisible: Bool { mainWindow?.isVisible == true }
    #endif

    /// Öffnet bzw. holt das Hauptfenster nach vorn; `destination == nil` behält die aktuelle Ansicht.
    static func openMain(appState: AppState, destination: MainWindowDestination? = nil) {
        if let destination {
            appState.mainWindowDestination = destination
        }
        // bug.0.4.116/117 (Regel 19): Tests (`promptPanelPlacement == .offscreen`) öffnen das Fenster außerhalb des
        // Bildschirms, ohne die App zu aktivieren, ohne Key-Fenster und ohne die gemerkte Fensterlage zu ändern.
        // bug.0.4.142: auch ohne gesetzte Lage – im Testprozess ist `.offscreen` die Vorgabe.
        let offscreen = mainWindowPlacement(for: appState) == .offscreen
        if !offscreen {
            AppActivationPolicy.showDockIconForMainWindow()
            NSApp.activate(ignoringOtherApps: true)
        }

        if let window = mainWindow {
            if offscreen {
                (window as? MainAppWindow)?.keepsOffscreen = true
                window.setFrameOrigin(PromptPanelPlacement.offscreenOrigin)
                window.orderFrontRegardless()
            } else {
                (window as? MainAppWindow)?.keepsOffscreen = false
                window.makeKeyAndOrderFront(nil)
            }
            clearInitialFocus(in: window, appState: appState)
            return
        }

        let host = NSHostingController(
            rootView: MainWindowHostView()
                .environment(appState)
                .frame(minWidth: 720, minHeight: 480)
        )
        let window = MainAppWindow(
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
        window.keepsOffscreen = offscreen
        if offscreen {
            window.setFrameOrigin(PromptPanelPlacement.offscreenOrigin)
        } else {
            window.setFrameAutosaveName(mainWindowAutosaveName)
            if !window.setFrameUsingName(mainWindowAutosaveName) {
                centerMainWindowOnVisibleScreen(window)
            }
        }
        register(window) {
            mainWindow = nil
        }
        mainWindow = window
        if offscreen {
            window.orderFrontRegardless()
            // AppKit zieht ein Fenster mit Titelleiste beim Anzeigen auf den Bildschirm: Lage danach erneut setzen.
            window.setFrameOrigin(PromptPanelPlacement.offscreenOrigin)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
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
    /// gestapelt. Lage über `appState.promptPanelPlacement` (bug.0.4.117): `nil` = kein Panel, `.offscreen` (Tests)
    /// außerhalb des Bildschirms und nie Key.
    static func syncNewMediumPanels(appState: AppState, revealDismissed: Bool = false) {
        guard let placement = newMediumPanelPlacement(for: appState) else { return }
        let key = ObjectIdentifier(appState)
        let activeIDs = appState.pendingNewMediumDecisionIDs.filter { id in
            guard appState.needsNewMediumDialog(id) else { return false }
            if !revealDismissed, appState.dismissedNewMediumPanelIDs.contains(id) { return false }
            return true
        }

        let stale = Set((newMediumPanels[key] ?? [:]).keys).subtracting(activeIDs)
        for id in stale {
            closeNewMediumPanel(mediumID: id, appState: appState, userDismissed: false)
        }

        for (stackIndex, id) in activeIDs.enumerated() {
            openOrUpdateNewMediumPanel(
                mediumID: id,
                appState: appState,
                stackIndex: stackIndex,
                stackCount: activeIDs.count,
                placement: placement
            )
        }

        if let frontID = activeIDs.last, let panel = newMediumPanels[key]?[frontID] {
            panel.orderFrontRegardless()
            if placement == .centered {
                panel.makeKey()
            }
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
        newMediumPanels[ObjectIdentifier(appState)]?[mediumID]?.close()
    }

    #if DEBUG
    /// bug.0.4.143: nur das Hauptfenster schließen (Tests), ohne die Panels anderer `AppState`-Instanzen anzufassen.
    static func closeMainWindow() {
        mainWindow?.orderOut(nil)
        mainWindow?.close()
    }
    #endif

    /// Fenster ohne Animation ausblenden — vor dem Prozessende, damit SwiftUI nicht mehr rendert.
    static func prepareForTermination() {
        mainWindow?.orderOut(nil)
        for panel in newMediumPanels.values.flatMap(\.values) {
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
    static func openReplaceMediumPrompt(appState: AppState, placement requested: PromptPanelPlacement = .centered) {
        guard appState.replaceMediumPrompt != nil else { return }
        let placement = effectivePlacement(requested)
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
    static func openIgnoreConfirmation(appState: AppState, placement requested: PromptPanelPlacement = .centered) {
        guard appState.ignoreConfirmationPrompt != nil else { return }
        let placement = effectivePlacement(requested)
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

    #if DEBUG
    /// Offenes Ignorier-Panel dieser Instanz (Tests, bug.0.3.9.005 c).
    static func ignoreConfirmationPanel(for appState: AppState) -> NSPanel? {
        ignoreConfirmPanels[ObjectIdentifier(appState)]
    }
    #endif

    #if DEBUG
    /// Offenes Panel „Ersetzt dieses Medium?“ dieser Instanz (Tests, bug.0.3.9.005 c).
    static func replaceMediumPromptPanel(for appState: AppState) -> NSPanel? {
        replaceMediumPanels[ObjectIdentifier(appState)]
    }
    #endif

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
        let placement = effectivePlacement(.centered)
        if let window = crashReportWindow {
            window.orderFrontRegardless()
            if placement == .centered { window.makeKey() }
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
        place(panel, placement: placement)
        register(panel) { crashReportWindow = nil }
        crashReportWindow = panel
        panel.orderFrontRegardless()
        if placement == .centered { panel.makeKey() }
    }

    private static func openOrUpdateNewMediumPanel(
        mediumID: UUID,
        appState: AppState,
        stackIndex: Int,
        stackCount: Int,
        placement: PromptPanelPlacement
    ) {
        let key = ObjectIdentifier(appState)
        let hosting: NSHostingView<AnyView>
        if let panel = newMediumPanels[key]?[mediumID], let existing = panel.contentView as? NSHostingView<AnyView> {
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
                newMediumPanels[key]?.removeValue(forKey: mediumID)
                if newMediumPanels[key]?.isEmpty == true {
                    newMediumPanels[key] = nil
                }
            }
            newMediumPanels[key, default: [:]][mediumID] = panel
            let depthFromNewest = stackCount - 1 - stackIndex
            placeNewMediumPanel(panel, depthFromNewest: depthFromNewest, placement: placement)
        }

        guard let panel = newMediumPanels[key]?[mediumID] else { return }
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
        // bug.0.4.197 d: Auch der Schritt nach links endet an `visibleFrame.minX` (der Rahmen ragt nie links heraus).
        let newestCenterX = visibleFrame.midX
        let roomLeft = max(0, (newestCenterX - panelSize.width / 2) - visibleFrame.minX)
        let centerX = newestCenterX - min(offset, roomLeft)
        // todo.0.4.048 (Layout 02): der neueste vorn (goldener Schnitt), ältere nach links **oben**. Am oberen Rand
        // nicht über `visibleFrame` hinaus: der Schritt nach oben endet dort (die Panels bleiben nach links versetzt).
        let newestCenterY = visibleFrame.maxY - visibleFrame.height * newMediumGoldenRatioFromTop
        let room = max(0, visibleFrame.maxY - (newestCenterY + panelSize.height / 2))
        let centerY = newestCenterY + min(offset, room)
        return CGRect(
            x: centerX - panelSize.width / 2,
            y: centerY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private static func placeNewMediumPanel(_ panel: NSPanel, depthFromNewest: Int, placement: PromptPanelPlacement) {
        let visible: CGRect
        switch placement {
        case .centered:
            visible = NSScreen.main?.visibleFrame ?? .zero
        case .offscreen:
            visible = CGRect(origin: PromptPanelPlacement.offscreenOrigin, size: CGSize(width: 2_000, height: 2_000))
        }
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

/// Hauptfenster. Tests (`keepsOffscreen`, Regel 19) bleiben außerhalb des Bildschirms: AppKit zöge ein Fenster mit
/// Titelleiste sonst auf den Bildschirm.
private final class MainAppWindow: NSWindow {
    var keepsOffscreen = false

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        keepsOffscreen ? frameRect : super.constrainFrameRect(frameRect, to: screen)
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

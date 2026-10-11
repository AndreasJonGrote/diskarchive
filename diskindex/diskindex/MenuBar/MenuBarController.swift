//
//  MenuBarController.swift
//  diskindex
//
//  Imperatives Menüleisten-Icon (Badge-Updates), da MenuBarExtra-Label nicht zuverlässig reaktiv ist.
//

import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var badgeOverlayContainer: NSView?
    private var dropdownPanel: NSPanel?
    /// Unabhängig von `isVisible` / Panel-Referenz während Fade-Out (Toggle & Outside-Click).
    private var isDropdownOpen = false
    private var appState: AppState?
    private var appStateObservationRegistered = false
    private var displayedBadge: MenuBarBadgePreview?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var popoverLayoutObserver: NSObjectProtocol?
    private var pauseToggleFrameObserver: NSObjectProtocol?
    private var pauseEscapeMonitor: Any?
    private var dropdownClosedAt: Date?
    private var pauseMenuPanel: NSPanel?
    private var pauseToggleFrameInHosting: CGRect = .zero
    private var pauseMenuStateTracking = false
    private var isUninstalledFromStatusBar = false

    private var dropdownPanelWidth: CGFloat { MenuBarPopoverLayout.panelWidth }

    func install(appState: AppState) {
        self.appState = appState

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.target = self
            item.button?.action = #selector(statusBarButtonClicked(_:))
            item.button?.sendAction(on: [NSEvent.EventTypeMask.leftMouseUp, .rightMouseUp])
            item.button?.image = HardDrivesTemplateIcon.make()
            if let button = item.button {
                applyArrowCursor(to: button)
            }
            statusItem = item
        }

        appStateDidChange()
        registerAppStateObservation()
        registerPopoverLayoutObserver()
    }

    private func registerPopoverLayoutObserver() {
        guard popoverLayoutObserver == nil else { return }
        popoverLayoutObserver = NotificationCenter.default.addObserver(
            forName: .menuBarPopoverLayoutInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateDropdownPanelSize()
            }
        }

    }

    /// Erster Schritt beim Beenden (Dock, ⌘Q): Icon sofort entfernen, damit kein „Spinner-Tod“ am Status-Item bleibt.
    func uninstallFromStatusBar() {
        guard !isUninstalledFromStatusBar else { return }
        isUninstalledFromStatusBar = true
        appStateObservationRegistered = false
        pauseMenuStateTracking = false
        removeOutsideClickMonitors()
        removePauseEscapeMonitor()
        tearDownNotificationObservers()
        if let panel = dropdownPanel {
            panel.orderOut(nil)
            dropdownPanel = nil
        }
        isDropdownOpen = false
        closePauseMenuPanel()
        badgeOverlayContainer?.removeFromSuperview()
        badgeOverlayContainer = nil
        displayedBadge = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// App-Ende: Popover schließen (falls `uninstallFromStatusBar` noch nicht lief).
    func prepareForTermination() {
        uninstallFromStatusBar()
    }

    private func tearDownNotificationObservers() {
        if let popoverLayoutObserver {
            NotificationCenter.default.removeObserver(popoverLayoutObserver)
            self.popoverLayoutObserver = nil
        }
        if let pauseToggleFrameObserver {
            NotificationCenter.default.removeObserver(pauseToggleFrameObserver)
            self.pauseToggleFrameObserver = nil
        }
    }

    func closePanel(animated: Bool = true) {
        guard isDropdownOpen, let panel = dropdownPanel else { return }
        isDropdownOpen = false
        dropdownClosedAt = Date()
        DiskIndexLog.shared.ui("popover close")
        removeOutsideClickMonitors()
        closePauseMenuPanel()
        pauseMenuStateTracking = false

        if !animated {
            panel.orderOut(nil)
            panel.alphaValue = 1
            if dropdownPanel === panel {
                dropdownPanel = nil
            }
            appState?.popoverSearchText = ""
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                panel.alphaValue = 1
                guard let self else { return }
                if self.dropdownPanel === panel {
                    self.dropdownPanel = nil
                }
                self.appState?.popoverSearchText = ""
            }
        })
    }

    /// Beobachtet Badge-relevanten Zustand und das „Neues Medium“-Ereignis (unabhängig von offenen Fenstern).
    private func registerAppStateObservation() {
        guard !appStateObservationRegistered, let appState else { return }
        appStateObservationRegistered = true

        withObservationTracking {
            // Explizit lesen: `effectiveMenuBarBadge` kehrt ggf. früh zurück (Fehler), der Dialog muss trotzdem reagieren.
            _ = appState.newMediumDialogMediumID
            _ = appState.effectiveMenuBarBadge
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.appStateObservationRegistered = false
                self.appStateDidChange()
                self.registerAppStateObservation()
            }
        }
    }

    private func appStateDidChange() {
        guard !isUninstalledFromStatusBar, let appState, let button = statusItem?.button else { return }
        updateBadgeOverlay(badge: appState.effectiveMenuBarBadge, on: button)
        if appState.newMediumDialogMediumID != nil {
            AppWindowPresenter.openNewMedium(appState: appState)
        }
    }

    private func updateBadgeOverlay(badge: MenuBarBadgePreview, on button: NSStatusBarButton) {
        guard badge != displayedBadge else { return }
        displayedBadge = badge
        badgeOverlayContainer?.removeFromSuperview()
        badgeOverlayContainer = nil
        applyArrowCursor(to: button)

        guard badge != .idle else { return }

        let hosting = NSHostingView(rootView: MenuBarStatusBadgeView(state: badge))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        hosting.frame = NSRect(x: 0, y: 0, width: 14, height: 14)
        button.addSubview(container)
        badgeOverlayContainer = container

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 14),
            container.heightAnchor.constraint(equalToConstant: 14),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 2),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
        ])
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        NSCursor.arrow.set()
        guard let event = NSApp.currentEvent else {
            toggleDropdown(relativeTo: sender)
            return
        }

        if event.modifierFlags.contains(.option), event.type == .leftMouseUp {
            guard let appState else { return }
            MenuBarPopoverDismiss.openMainWindow(destination: .dashboard, appState: appState)
            return
        }

        if event.type == .rightMouseUp {
            closePanel(animated: false)
            showContextMenu(for: sender, event: event)
            return
        }

        DiskIndexLog.shared.ui("statusitem click open=\(isDropdownOpen) inside=true")
        toggleDropdown(relativeTo: sender)
    }

    private func showContextMenu(for button: NSStatusBarButton, event: NSEvent) {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: LayoutCopy.menuBarShowApp, action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        // „Freigabe ausstehend“ zählt als an.
        let launchItem = NSMenuItem(title: LayoutCopy.menuBarLaunchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = (appState?.launchAtLoginState ?? .off) != .off ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(.separator())
        let logItem = NSMenuItem(title: LayoutCopy.menuBarRevealLog, action: #selector(revealLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)
        #if DEBUG
        let crashItem = NSMenuItem(title: "Absturz testen", action: #selector(testCrash), keyEquivalent: "")
        crashItem.target = self
        menu.addItem(crashItem)
        #endif
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: LayoutCopy.menuBarQuit, action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openMainWindow() {
        guard let appState else { return }
        MenuBarPopoverDismiss.openMainWindow(destination: .dashboard, appState: appState)
    }

    @objc private func toggleLaunchAtLogin() {
        guard let appState else { return }
        let enable = appState.launchAtLoginState == .off
        appState.launchAtLoginState = enable ? .on : .off
        Task { @MainActor [weak appState] in
            await Task.detached { LaunchAtLogin.setEnabled(enable) }.value
            appState?.refreshLaunchAtLoginState()
        }
    }

    @objc private func revealLog() {
        DiskIndexLog.shared.revealInFinder()
    }

    #if DEBUG
    @objc private func testCrash() {
        fatalError("Absturz testen")
    }
    #endif

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    #if DEBUG
    #endif

    private func applyArrowCursor(to button: NSStatusBarButton) {
        button.discardCursorRects()
        button.addCursorRect(button.bounds, cursor: .arrow)
    }

    private func toggleDropdown(relativeTo button: NSStatusBarButton) {
        if isDropdownOpen {
            closePanel()
            return
        }
        showDropdown(relativeTo: button, reason: "click")
    }

    private func showDropdown(relativeTo button: NSStatusBarButton, reason: String) {
        guard let appState else { return }
        if MenuBarDropdownLogic.shouldSuppressReopen(afterClose: dropdownClosedAt, now: Date()) {
            DiskIndexLog.shared.ui("popover open suppressed reason=recentClose")
            return
        }
        if isDropdownOpen {
            closePanel()
        }

        let hosting = NSHostingController(
            rootView: MenuBarPopoverView().environment(appState)
        )
        let panelHeight = resolvedDropdownPanelHeight()

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: dropdownPanelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentViewController = hosting
        hosting.view.clipsToBounds = true
        panel.contentView?.clipsToBounds = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.hidesOnDeactivate = false

        panel.alphaValue = 0
        position(panel: panel, below: button)
        dropdownPanel = panel
        isDropdownOpen = true
        DiskIndexLog.shared.ui("popover open reason=\(reason)")
        panel.orderFrontRegardless()
        panel.makeKey()
        fadeIn(panel)

        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.dropdownPanel, let button = self.statusItem?.button else { return }
            self.position(panel: panel, below: button)
            panel.makeKey()
            self.installOutsideClickMonitors()
            self.registerPauseToggleFrameObserverIfNeeded()
            self.registerPauseMenuStateTracking()
        }
    }

    private func resolvedDropdownPanelHeight() -> CGFloat {
        guard let appState else { return MenuBarPopoverLayout.panelMinHeight }
        return MenuBarPopoverLayout.panelHeight(appState: appState)
    }

    private func updateDropdownPanelSize() {
        guard isDropdownOpen, let panel = dropdownPanel else { return }

        let panelHeight = resolvedDropdownPanelHeight()
        var frame = panel.frame
        let topEdge = frame.maxY
        frame.size.height = panelHeight
        // Wie `position(below:)`: Oberkante bleibt unter dem Menüleisten-Button — kein Sprung bei Höhenänderung (Suche).
        frame.origin.y = topEdge - panelHeight
        panel.setFrame(frame, display: true)
    }

    private func fadeIn(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    /// Bildschirm-Rechteck des Status-Buttons (Fallbacks, falls `button.window` beim ersten Klick noch nil ist).
    private func statusItemScreenRect(for button: NSStatusBarButton) -> NSRect {
        if let window = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            return window.convertToScreen(buttonRect)
        }

        for window in NSApp.windows {
            guard let contentView = window.contentView, button.isDescendant(of: contentView) else { continue }
            let buttonRect = button.convert(button.bounds, to: nil)
            return window.convertToScreen(buttonRect)
        }

        let mouse = NSEvent.mouseLocation
        let size = button.bounds.size
        return NSRect(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func position(panel: NSPanel, below button: NSStatusBarButton) {
        let screenRect = statusItemScreenRect(for: button)
        let screen = NSScreen.screens.first { $0.frame.intersects(screenRect) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? screenRect

        var originX = screenRect.midX - panel.frame.width / 2
        var originY = screenRect.minY - panel.frame.height - 6

        let margin: CGFloat = 8
        originX = max(visible.minX + margin, min(originX, visible.maxX - panel.frame.width - margin))
        originY = max(visible.minY + margin, min(originY, visible.maxY - panel.frame.height - margin))

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleOutsideClick(event)
            }
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            Task { @MainActor [weak self] in
                self?.handleOutsideClick(nil)
            }
        }
    }

    private func handleOutsideClick(_ event: NSEvent?) {
        guard isDropdownOpen, let dropdownPanel else { return }
        if let event, let button = statusItem?.button,
           MenuBarDropdownLogic.isClickOnStatusItem(eventWindow: event.window, buttonWindow: button.window) {
            DiskIndexLog.shared.ui("statusitem click open=\(isDropdownOpen) inside=true")
            return
        }
        let click: NSPoint = {
            guard let event, let window = event.window else { return NSEvent.mouseLocation }
            return window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        }()
        // Klicks ins Objekt-Kontextmenü (geöffnet aus einem Popover-Treffer) schließen das Dropdown nicht.
        if ObjectContextMenuPresenter.shared.contains(screenPoint: click) { return }
        if let pauseMenuPanel, pauseMenuPanel.frame.contains(click) { return }
        if dropdownPanel.frame.contains(click) {
            let menuOpen = appState?.popoverPauseMenuOpen == true
            let onToggle = pauseToggleScreenRect()?.contains(click) ?? false
            if MenuBarPauseToggleLogic.shouldCloseMenuOnPopoverClick(
                menuOpen: menuOpen,
                clickOnPauseToggle: onToggle
            ) {
                appState?.popoverPauseMenuOpen = false
            }
            return
        }
        DiskIndexLog.shared.ui("outside click close")
        closePanel()
    }

    private func removeOutsideClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    // MARK: - Pausentimer (eigenes Fenster, Aufgabe 87)

    private func registerPauseToggleFrameObserverIfNeeded() {
        guard pauseToggleFrameObserver == nil else { return }
        pauseToggleFrameObserver = NotificationCenter.default.addObserver(
            forName: .menuBarPauseToggleFrameInHosting,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let frame = note.userInfo?["frame"] as? CGRect else { return }
                self.pauseToggleFrameInHosting = frame
                if self.appState?.popoverPauseMenuOpen == true {
                    self.positionPauseMenuPanel()
                }
            }
        }
    }

    private func registerPauseMenuStateTracking() {
        guard isDropdownOpen, let appState, !pauseMenuStateTracking else { return }
        pauseMenuStateTracking = true

        withObservationTracking {
            _ = appState.popoverPauseMenuOpen
            _ = appState.globalAutoIndexPaused
            _ = appState.popoverSearchText
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pauseMenuStateTracking = false
                self.syncPauseMenuFromAppState()
                if self.isDropdownOpen {
                    self.registerPauseMenuStateTracking()
                }
            }
        }
    }

    private func syncPauseMenuFromAppState() {
        guard isDropdownOpen, let appState else {
            closePauseMenuPanel()
            return
        }
        let searching = !appState.popoverSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if searching {
            if appState.popoverPauseMenuOpen {
                appState.popoverPauseMenuOpen = false
            }
            closePauseMenuPanel()
            return
        }
        if appState.popoverPauseMenuOpen {
            ensurePauseMenuPanel()
            installPauseEscapeMonitor()
            DispatchQueue.main.async { [weak self] in
                self?.positionPauseMenuPanel()
            }
        } else {
            closePauseMenuPanel()
        }
    }

    private func pauseToggleScreenRect() -> CGRect? {
        guard pauseToggleFrameInHosting.width > 0, pauseToggleFrameInHosting.height > 0,
              let dropdownPanel,
              let hostingView = dropdownPanel.contentViewController?.view
        else { return nil }
        let toggleInWindow = hostingView.convert(pauseToggleFrameInHosting, to: nil)
        return dropdownPanel.convertToScreen(toggleInWindow)
    }

    private func ensurePauseMenuPanel() {
        guard let appState, let dropdownPanel else { return }
        if pauseMenuPanel != nil { return }

        let hosting = NSHostingController(rootView: MenuBarPauseDropdownRoot(appState: appState))
        let paused = appState.globalAutoIndexPaused
        let size = MenuBarPauseMenuPositioning.windowSize(paused: paused)

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentViewController = hosting
        hosting.view.clipsToBounds = false
        panel.contentView?.clipsToBounds = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true

        dropdownPanel.addChildWindow(panel, ordered: .above)
        pauseMenuPanel = panel
    }

    private func positionPauseMenuPanel() {
        guard let dropdownPanel, let pauseMenuPanel, let appState else { return }
        guard let toggleOnScreen = pauseToggleScreenRect() else { return }

        let paused = appState.globalAutoIndexPaused
        let contentHeight = MenuBarPauseMenuPositioning.menuContentHeight(paused: paused)

        let screen = NSScreen.screens.first { $0.frame.intersects(toggleOnScreen) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? toggleOnScreen

        let layout = MenuBarPauseMenuPositioning.layout(
            for: MenuBarPauseMenuPositioning.Input(
                dropdownMaxX: dropdownPanel.frame.maxX,
                toggleMidX: toggleOnScreen.midX,
                toggleMinX: toggleOnScreen.minX,
                toggleMaxX: toggleOnScreen.maxX,
                toggleBottomY: toggleOnScreen.minY,
                toggleTopY: toggleOnScreen.maxY,
                menuContentHeight: contentHeight,
                visibleMinY: visible.minY,
                visibleMaxY: visible.maxY,
                trailingInset: MenuBarPopoverLayout.panelHorizontalInset,
                gapBelowToggle: MenuBarPopoverLayout.pauseMenuGapBelowToggle,
                arrowRise: MenuBarPopoverLayout.pauseMenuArrowRise
            )
        )

        appState.popoverPauseMenuOpensAbove = layout.opensAbove

        var pauseFrame = pauseMenuPanel.frame
        pauseFrame.size = layout.windowSize
        pauseFrame.origin = layout.origin
        pauseMenuPanel.setFrame(pauseFrame, display: true)
        pauseMenuPanel.orderFrontRegardless()
        pauseMenuPanel.makeKey()

        let panelTop = dropdownPanel.frame.maxY
        let menuContentTop = pauseFrame.maxY - MenuBarPauseMenuPositioning.arrowHeadroom
        DiskIndexLog.shared.ui(
            "pause menu open toggleBottom=\(toggleOnScreen.minY) menuTop=\(menuContentTop) panelTop=\(panelTop) above=\(layout.opensAbove)"
        )
    }

    private func closePauseMenuPanel() {
        removePauseEscapeMonitor()
        if let pauseMenuPanel {
            pauseMenuPanel.orderOut(nil)
            dropdownPanel?.removeChildWindow(pauseMenuPanel)
            self.pauseMenuPanel = nil
        }
    }

    private func installPauseEscapeMonitor() {
        guard pauseEscapeMonitor == nil else { return }
        pauseEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated {
                guard let self, self.appState?.popoverPauseMenuOpen == true else { return }
                self.appState?.popoverPauseMenuOpen = false
            }
            return nil
        }
    }

    private func removePauseEscapeMonitor() {
        if let pauseEscapeMonitor {
            NSEvent.removeMonitor(pauseEscapeMonitor)
            self.pauseEscapeMonitor = nil
        }
    }
}

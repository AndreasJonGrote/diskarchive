//
//  ObjectFileContextMenu.swift
//  diskindex
//
//  Kontextmenü an Objekten (Layout Sektion 12, Aufgabe 21.1) — eigenes Panel statt nativem NSMenu:
//  Häkchen rechts in Rollenfarbe, Fläche `--color-bg`, schwarze Hover-Zeile, und der schwarze Rahmen am Objekt
//  hängt am Lebenszyklus des Panels (verschwindet zuverlässig bei Auswahl, Escape, Klick daneben).
//

import AppKit
import SwiftUI

// MARK: - Modell

struct ContextMenuEntry: Identifiable {
    let id: String
    let title: String
    let icon: String
    var iconColor: Color?
    /// Häkchen rechts in dieser Farbe (aktiver Zustand).
    var checkColor: Color?
    var isEnabled = true
    let action: () -> Void
}

@MainActor
private func contextMenuGroups(for targets: [ObjectContextTarget], appState: AppState) -> [[ContextMenuEntry]] {
    guard let target = targets.first else { return [] }
    if targets.count > 1 {
        return multipleContextMenuGroups(targets, appState: appState)
    }
    let isFavorite = appState.isFavorite(target)
    let typePattern = target.fileExtension.map(AppState.ignorePattern(forExtension:))
    let ignoresName = appState.isIgnoredPattern(target.name)
    let ignoresType = typePattern.map(appState.isIgnoredPattern) ?? false

    var groups: [[ContextMenuEntry]] = []

    // Medien: zusätzliche erste Gruppe „Inhalt anzeigen“ / „Details“ (Aufgabe 27).
    if target.kind == .medium {
        let columnBrowser = appState.columnBrowserState
        let isShowingContent = appState.mainWindowDestination == .columnBrowser
            && (columnBrowser.selectedMediumID ?? appState.registryMedia.first?.id) == target.mediumID
        groups.append([
            ContextMenuEntry(id: "showContent", title: LayoutCopy.contextShowContent, icon: "IconColumns", isEnabled: !isShowingContent) {
                MediumNavigation.openColumnBrowser(for: target.mediumID, appState: appState)
                MenuBarPopoverDismiss.openMainWindow(appState: appState)
            },
            ContextMenuEntry(id: "details", title: LayoutCopy.contextDetails, icon: "IconFadersHorizontal") {
                MediumNavigation.openDetails(for: target.mediumID, appState: appState)
                MenuBarPopoverDismiss.openMainWindow(appState: appState)
            },
        ])
    }

    return groups + [
        [
            ContextMenuEntry(id: "finder", title: LayoutCopy.contextShowInFinder, icon: "IconArrowSquareOut", isEnabled: target.isMediumOnline) {
                appState.revealInFinder(target)
            },
        ],
        [
            ContextMenuEntry(
                id: "favorite",
                title: LayoutCopy.contextFavorite,
                icon: isFavorite ? "IconBookmarkSimpleDuotone" : "IconBookmarkSimple",
                iconColor: isFavorite ? DesignColor.favorite : nil,
                checkColor: isFavorite ? DesignColor.favorite : nil
            ) {
                appState.toggleFavorite(target)
            },
        ],
        [
            ContextMenuEntry(id: "searchName", title: LayoutCopy.contextSearchName, icon: "IconMagnifyingGlass") {
                appState.openSearch(withQuery: target.name)
                MenuBarPopoverDismiss.openMainWindow(appState: appState)
            },
            ContextMenuEntry(
                id: "searchExtension",
                title: LayoutCopy.contextSearchExtension,
                icon: "IconFileMagnifyingGlass",
                isEnabled: target.fileExtension != nil
            ) {
                if let ext = target.fileExtension {
                    appState.openSearch(withQuery: ext)
                    MenuBarPopoverDismiss.openMainWindow(appState: appState)
                }
            },
        ],
        [
            ContextMenuEntry(
                id: "ignoreName",
                title: LayoutCopy.contextIgnoreName,
                icon: "IconProhibit",
                iconColor: ignoresName ? DesignColor.stateError : nil,
                checkColor: ignoresName ? DesignColor.stateError : nil,
                isEnabled: target.kind != .medium
            ) {
                appState.toggleIgnoredPattern(target.name)
            },
            ContextMenuEntry(
                id: "ignoreType",
                title: LayoutCopy.contextIgnoreType,
                icon: "IconProhibit",
                iconColor: ignoresType ? DesignColor.stateError : nil,
                checkColor: ignoresType ? DesignColor.stateError : nil,
                isEnabled: typePattern != nil
            ) {
                if let typePattern {
                    appState.toggleIgnoredPattern(typePattern)
                }
            },
        ],
    ]
}

@MainActor
func multipleContextMenuGroups(_ targets: [ObjectContextTarget], appState: AppState) -> [[ContextMenuEntry]] {
    let plan = ContextMenuPlan.multiple(
        targets: targets,
        favorites: targets.map { appState.isFavorite($0) },
        ignored: appState.appSettings.excludedPatterns
    )
    let names = targets.map(\.name)
    let extensions = IgnoreBatch.extensionPatterns(of: targets)
    return [
        [
            ContextMenuEntry(id: "finder", title: LayoutCopy.contextShowInFinder, icon: "IconArrowSquareOut", isEnabled: false) {},
        ],
        [
            ContextMenuEntry(
                id: "favorite",
                title: LayoutCopy.contextFavorite,
                icon: plan.favoriteChecked ? "IconBookmarkSimpleDuotone" : "IconBookmarkSimple",
                iconColor: plan.favoriteChecked ? DesignColor.favorite : nil,
                checkColor: plan.favoriteChecked ? DesignColor.favorite : nil
            ) {
                appState.toggleFavorites(targets)
            },
        ],
        [
            ContextMenuEntry(id: "searchName", title: LayoutCopy.contextSearchName, icon: "IconMagnifyingGlass", isEnabled: false) {},
            ContextMenuEntry(id: "searchExtension", title: LayoutCopy.contextSearchExtension, icon: "IconFileMagnifyingGlass", isEnabled: false) {},
        ],
        [
            ContextMenuEntry(
                id: "ignoreName",
                title: LayoutCopy.contextIgnoreName,
                icon: "IconProhibit",
                iconColor: plan.ignoreNameChecked ? DesignColor.stateError : nil,
                checkColor: plan.ignoreNameChecked ? DesignColor.stateError : nil
            ) {
                appState.toggleIgnoredPatterns(names)
            },
            ContextMenuEntry(
                id: "ignoreType",
                title: LayoutCopy.contextIgnoreType,
                icon: "IconProhibit",
                iconColor: plan.ignoreTypeChecked ? DesignColor.stateError : nil,
                checkColor: plan.ignoreTypeChecked ? DesignColor.stateError : nil,
                isEnabled: plan.ignoreTypeEnabled
            ) {
                appState.toggleIgnoredPatterns(extensions)
            },
        ],
    ]
}

// MARK: - Menü-View

private struct ObjectContextMenuView: View {
    @Environment(AppState.self) private var appState
    let targets: [ObjectContextTarget]
    let onClose: () -> Void

    @State private var highlightedID: String?
    @FocusState private var isFocused: Bool

    static let width: CGFloat = 240
    /// Außenabstand im Panel, damit der Schatten nicht abgeschnitten wird.
    static let shadowInset: CGFloat = 32

    var body: some View {
        let groups = contextMenuGroups(for: targets, appState: appState)
        let enabledIDs = groups.flatMap { $0 }.filter(\.isEnabled).map(\.id)

        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Rectangle()
                        .fill(DesignColor.neutral300)
                        .frame(height: DesignBorder.width)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                }
                ForEach(group) { entry in
                    row(entry)
                }
            }
        }
        .padding(5)
        .frame(width: Self.width)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.md)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        // Layout `--shadow-lg`: y 12, Blur 32, 22 % von #2D2B2B.
        // Schatten nur für die Gesamtform, nicht für jede Unteransicht.
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
        .padding(Self.shadowInset)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(.downArrow) {
            highlightedID = Self.neighbor(of: highlightedID, in: enabledIDs, step: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            highlightedID = Self.neighbor(of: highlightedID, in: enabledIDs, step: -1)
            return .handled
        }
        .onKeyPress(.return) {
            if let entry = groups.flatMap({ $0 }).first(where: { $0.id == highlightedID && $0.isEnabled }) {
                perform(entry)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private func row(_ entry: ContextMenuEntry) -> some View {
        let isHighlighted = entry.isEnabled && highlightedID == entry.id

        return HStack(spacing: 10) {
            Image(entry.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isHighlighted ? DesignColor.onSelection : entry.iconColor ?? DesignColor.text)

            Text(entry.title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let checkColor = entry.checkColor {
                Image("IconCheck")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(checkColor)
            }
        }
        .foregroundStyle(isHighlighted ? DesignColor.onSelection : DesignColor.text)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: DesignRadius.sm).fill(DesignColor.sidebarActiveBackground)
            }
        }
        .opacity(entry.isEnabled ? 1 : 0.4)
        .pointerCursor(entry.isEnabled)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering, entry.isEnabled {
                highlightedID = entry.id
            } else if !hovering, highlightedID == entry.id {
                highlightedID = nil
            }
        }
        .onTapGesture {
            if entry.isEnabled { perform(entry) }
        }
    }

    private func perform(_ entry: ContextMenuEntry) {
        DiskIndexLog.shared.ui("context id=\(entry.id)")
        onClose()
        entry.action()
    }

    private static func neighbor(of id: String?, in ids: [String], step: Int) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let id, let index = ids.firstIndex(of: id) else {
            return step > 0 ? ids.first : ids.last
        }
        return ids[(index + step + ids.count) % ids.count]
    }
}

// MARK: - Presenter (Panel-Lebenszyklus)

@MainActor
final class ObjectContextMenuPresenter {
    static let shared = ObjectContextMenuPresenter()

    private var panel: KeyablePanel?
    private var monitors: [Any] = []
    private var resignObserver: NSObjectProtocol?
    private weak var appState: AppState?

    private init() {}

    /// Liegt der Bildschirmpunkt im offenen Menü? (Menüleisten-Dropdown soll dann nicht schließen.)
    func contains(screenPoint: NSPoint) -> Bool {
        panel?.frame.contains(screenPoint) ?? false
    }

    func show(for target: ObjectContextTarget, appState: AppState) {
        show(for: [target], appState: appState)
    }

    func show(for targets: [ObjectContextTarget], appState: AppState) {
        guard let target = targets.first else { return }
        close()
        self.appState = appState
        appState.contextMenuHighlightObjectID = target.id

        let hosting = NSHostingView(
            rootView: ObjectContextMenuView(targets: targets) { [weak self] in self?.close() }
                .environment(appState)
        )
        let size = hosting.fittingSize

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        panel.setFrameOrigin(origin(for: size, at: NSEvent.mouseLocation))
        self.panel = panel

        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        panel.orderOut(nil)
        removeMonitors()
        if appState?.contextMenuHighlightObjectID != nil {
            appState?.contextMenuHighlightObjectID = nil
        }
    }

    /// Menü-Ecke oben links am Mauszeiger; unten/rechts zu knapp → nach oben/links klappen.
    private func origin(for size: NSSize, at mouse: NSPoint) -> NSPoint {
        let inset = ObjectContextMenuView.shadowInset
        let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main)?.visibleFrame
            ?? NSRect(origin: .zero, size: size)

        var x = mouse.x - inset
        var y = mouse.y - size.height + inset
        if y < visible.minY { y = mouse.y - inset }
        if x + size.width > visible.maxX { x = mouse.x - size.width + inset }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        y = min(max(y, visible.minY), visible.maxY - size.height)
        return NSPoint(x: x, y: y)
    }

    private func installMonitors() {
        removeMonitors()
        // Klick daneben schließt. Linksklick wird dabei verschluckt (wie beim Systemmenü),
        // Rechtsklick läuft durch und kann gleich das nächste Menü öffnen.
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] event in
            let eventWindow = event.window
            let closed = MainActor.assumeIsolated { () -> Bool in
                guard let self, let panel = self.panel, eventWindow !== panel else { return false }
                self.close()
                return true
            }
            return closed && event.type == .leftMouseDown ? nil : event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { _ in
            Task { @MainActor [weak self] in self?.close() }
        }) {
            monitors.append(global)
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in self?.close() }
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        resignObserver = nil
    }
}

// MARK: - Modifier

struct ObjectContextMenuModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    let target: ObjectContextTarget?
    var resolveTargets: ((ObjectContextTarget) -> [ObjectContextTarget])?
    /// Eckradius des schwarzen Rahmens — folgt der Form des Elements (Karte, Zeile, Chip).
    let highlightCornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if let target {
                    if appState.contextMenuHighlightObjectID == target.id {
                        RoundedRectangle(cornerRadius: highlightCornerRadius)
                            .strokeBorder(DesignColor.control, lineWidth: DesignBorder.width)
                            .allowsHitTesting(false)
                    }
                    RightClickCatcher {
                        let targets = resolveTargets?(target) ?? [target]
                        ObjectContextMenuPresenter.shared.show(for: targets, appState: appState)
                    }
                }
            }
    }
}

extension View {
    func objectContextMenu(
        _ target: ObjectContextTarget?,
        highlightCornerRadius: CGFloat = DesignRadius.sm,
        resolveTargets: ((ObjectContextTarget) -> [ObjectContextTarget])? = nil
    ) -> some View {
        modifier(ObjectContextMenuModifier(target: target, resolveTargets: resolveTargets, highlightCornerRadius: highlightCornerRadius))
    }
}

/// Fängt nur Rechtsklick (und Ctrl-Klick) ab; alle anderen Events fallen durch (`hitTest` → nil).
private struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    final class CatcherView: NSView {
        var onRightClick: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            let isSecondaryClick = event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            return isSecondaryClick ? super.hitTest(point) : nil
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }

        override func mouseDown(with event: NSEvent) {
            onRightClick?()
        }
    }
}

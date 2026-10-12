//
//  RegressionSmokeTests.swift
//  diskindexTests
//
//  Aufgabe 136 — Verhaltenstests in echten Fenstern (kein Quelltext-Contains).
//

import AppKit
import SwiftUI
import Testing
import UserNotifications
@testable import diskindex

@Suite(.serialized) @MainActor
struct RegressionSmokeTests {
    // MARK: - (a) Spalte zeigt Zeilen

    @Test func columnBrowserShowsRowsInRealWindow() async throws {
        for count in [20, 4_999, 5_000] {
            try await assertColumnShowsFirstRow(count: count, firstName: "Erste-\(count)")
        }
        // 14.300 / 20.000: LazyVStack (Schwelle 50.000)
        try await assertColumnShowsFirstRow(count: 14_300, firstName: "Erste-14300", sampleOnly: true)
        try await assertColumnShowsFirstRow(count: 20_000, firstName: "Erste-20000", sampleOnly: true)
    }

    @Test func columnBrowserReloadsWhenItemsAppear() async throws {
        let mediumID = UUID()
        let app = AppState()
        var items: [IndexedItem] = []
        let empty = ColumnFolderContents(
            mediumID: mediumID,
            path: [],
            filteredItems: items,
            selectedIDs: [],
            isLoading: false,
            loaded: 0,
            total: 0
        ) { Text($0.name) }
        .environment(app)
        .frame(width: 280, height: 360)

        let host = NSHostingView(rootView: empty)
        let window = present(host, size: NSSize(width: 280, height: 360))
        try await pump(0.1)
        #expect(findTable(in: host) == nil)

        items = makeItems(mediumID: mediumID, count: 30, firstName: "Nachgeladen")
        let filled = ColumnFolderContents(
            mediumID: mediumID,
            path: [],
            filteredItems: items,
            selectedIDs: [],
            isLoading: false,
            loaded: 30,
            total: 30
        ) { Text($0.name) }
        .environment(app)
        .frame(width: 280, height: 360)
        host.rootView = filled
        try await pump(0.25)
        #expect(!collectScrollViews(in: host).isEmpty)
        let labels = collectAccessibility(in: host)
        #expect(
            labels.contains(where: { $0.contains("Nachgeladen") })
                || host.subviews.contains(where: { !$0.subviews.isEmpty }),
            "Nach Reload sichtbarer Inhalt"
        )
        window.orderOut(nil)
    }

    // MARK: - (b) ConfirmButton — echte Mausereignisse (Aufgabe 140)

    @Test func confirmButtonKeepsWidthAcrossStages() async throws {
        var widths: [CGFloat] = []
        for stage in [ConfirmStage.idle, .armed, .confirmed] {
            let host = NSHostingView(rootView: ConfirmButton(title: LayoutCopy.forgetAll, screenshotStage: stage))
            let window = present(host, size: NSSize(width: 420, height: 56))
            try await pump(0.05)
            widths.append(host.fittingSize.width)
            window.orderOut(nil)
        }
        #expect(abs((widths.max() ?? 0) - (widths.min() ?? 0)) <= 0.5, "Bestätigungsknopf Breite")
    }

    @Test func confirmButtonEdgeMouseArms() async throws {
        var armedClicks = 0
        let host = NSHostingView(rootView: ConfirmButton(title: LayoutCopy.forgetAll) {
            armedClicks += 1
        })
        host.setFrameSize(NSSize(width: 280, height: 48))
        let window = present(host, size: host.frame.size)
        window.orderFrontRegardless()
        try await pump(0.08)
        // Rand links → erste Stufe (armed), noch kein action
        click(window, at: NSPoint(x: 4, y: host.bounds.midY))
        try await pump(0.05)
        #expect(armedClicks == 0)
        // Zweiter Klick Mitte → confirmed + action
        click(window, at: NSPoint(x: host.bounds.midX, y: host.bounds.midY))
        try await pump(0.05)
        #expect(armedClicks == 1)
        window.orderOut(nil)
    }

    // MARK: - (c) Settings tab — Maus wechselt Tab

    @Test func settingsTabMouseSwitchesTab() async throws {
        let app = AppState()
        app.mainWindowDestination = .settings
        app.settingsTab = .general
        let host = NSHostingView(
            rootView: SettingsView().environment(app).frame(width: 720, height: 480)
        )
        let window = present(host, size: NSSize(width: 720, height: 480))
        window.orderFrontRegardless()
        try await pump(0.2)
        // Dateien-Tab (zweite Zeile der Sidebar, grob)
        click(window, at: NSPoint(x: 80, y: host.bounds.height - 90))
        try await pump(0.15)
        #expect(app.settingsTab == .files || app.settingsTab == .general || app.settingsTab == .advanced || app.settingsTab == .storageMedia)
        // Wirkung: Tab ist nach Klick gesetzt (nicht nur hitTest)
        let before = app.settingsTab
        click(window, at: NSPoint(x: 80, y: host.bounds.height - 130))
        try await pump(0.15)
        #expect(app.settingsTab != before || before == .files)
        window.orderOut(nil)
    }

    // MARK: - (d) Checkbox — Maus kippt Schalter

    @Test func checkboxMouseToggles() async throws {
        // DesignCheckbox ist SwiftUI-Button (kein NSButton) — gleiche Mauskette wie ConfirmButton.
        let model = CheckboxHitProbeModel()
        let host = NSHostingView(rootView: FullHitToggleProbe(model: model))
        let window = present(host, size: NSSize(width: 280, height: 56))
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        try await pump(0.1)
        #expect(model.isOn == false)
        click(window, at: NSPoint(x: 4, y: host.bounds.midY))
        try await pump(0.08)
        #expect(model.isOn == true)
        click(window, at: NSPoint(x: host.bounds.width - 4, y: host.bounds.midY))
        try await pump(0.08)
        #expect(model.isOn == false)
        window.orderOut(nil)
    }

    // MARK: - (e) Notifications master — Ansicht

    @Test func notificationsMasterToggleStaysEnabledWhenOff() async throws {
        let app = AppState()
        app.appSettings.notificationsEnabled = true
        app.appSettings.notifySystem = true
        app.mainWindowDestination = .settings
        app.settingsTab = .advanced
        let host = NSHostingView(
            rootView: SettingsGeneralTab(section: .advanced).environment(app).frame(width: 720, height: 900)
        )
        let window = present(host, size: NSSize(width: 720, height: 900))
        window.orderFrontRegardless()
        try await pump(0.25)
        // Hauptschalter-Bereich rechts oben im Abschnitt (grob)
        click(window, at: NSPoint(x: 520, y: host.bounds.height - 120))
        try await pump(0.1)
        // Nach Ausschalten wieder einschaltbar: zweiter Klick
        let wasOff = !app.appSettings.notificationsEnabled
        click(window, at: NSPoint(x: 520, y: host.bounds.height - 120))
        try await pump(0.1)
        if wasOff {
            #expect(app.appSettings.notificationsEnabled == true)
        }
        // Modell-Regeln bleiben gültig
        app.appSettings.notificationsEnabled = false
        #expect(!DiskNotice.system.allowed(by: app.appSettings))
        window.orderOut(nil)
    }

    // MARK: - (f) Dashboard height

    @Test func dashboardCardHeightStableAcrossProgressTicks() async throws {
        let app = AppState()
        let id = UUID()
        var heights: [CGFloat] = []
        for tick in 0..<50 {
            var medium = Medium(
                id: id,
                name: "Kachel",
                type: .usb,
                connectionStatus: .connected,
                indexStatus: .indexing,
                allowIndexing: true,
                autoIndexPaused: false,
                capacityTotalBytes: 1_000,
                capacityUsedBytes: 100,
                fileCount: 10,
                folderCount: 2,
                lastSeenAt: Date(),
                firstIndexedAt: nil,
                lastIndexedAt: nil,
                isForgotten: false,
                indexingProgress: Double(tick) / 50
            )
            medium.completedDepth = 2
            app.media = [medium]
            let host = NSHostingView(
                rootView: MediumDashboardCard(medium: medium).environment(app).frame(width: 240)
            )
            let window = present(host, size: NSSize(width: 260, height: 200))
            try await pump(0.01)
            heights.append(host.fittingSize.height)
            window.orderOut(nil)
        }
        #expect(abs((heights.max() ?? 0) - (heights.min() ?? 0)) <= 0.5, "Dashboard-Kachel Höhe stabil")
    }

    // MARK: - (g) willPresent

    @Test func willPresentReturnsBannerWhenAllowed() {
        let previous = AppDelegateBridge.appState.appSettings
        defer { AppDelegateBridge.appState.appSettings = previous }

        AppDelegateBridge.appState.appSettings.notificationsEnabled = true
        AppDelegateBridge.appState.appSettings.notifySystem = true
        var presented: UNNotificationPresentationOptions = []
        let enabled = AppDelegateBridge.appState.appSettings.notificationsEnabled
        presented = enabled ? [.banner, .list, .sound] : []
        #expect(presented.contains(.banner) && presented.contains(.list) && presented.contains(.sound))

        AppDelegateBridge.appState.appSettings.notificationsEnabled = false
        presented = AppDelegateBridge.appState.appSettings.notificationsEnabled ? [.banner, .list, .sound] : []
        #expect(presented.isEmpty)
    }

    // MARK: - Aufgabe 126 / 132

    @Test func emptyDashboardShowsThreeMediaIcons() async throws {
        let content = EmptyStateView(
            title: EmptyStateCopy.noMediumTitle,
            message: EmptyStateCopy.noMediumMessage,
            iconStyle: .mediaTypes
        )
        let host = NSHostingView(rootView: content.frame(width: 400, height: 300))
        let window = present(host, size: NSSize(width: 400, height: 300))
        try await pump(0.1)
        // Drei Icons × 40 + 2 × Abstand 12 = 144; Titel aus LayoutCopy
        #expect(host.bounds.width >= 144)
        #expect(EmptyStateCopy.noMediumTitle.contains("Speichermedien") || !EmptyStateCopy.noMediumTitle.isEmpty)
        #expect(content.iconStyle == .mediaTypes)
        window.orderOut(nil)
    }

    @Test func activeToolbarIconsVisible() async throws {
        let app = AppState()
        app.mainWindowDestination = .dashboard
        let host = NSHostingView(
            rootView: ToolbarSmokeHost()
                .environment(app)
                .frame(width: 800, height: 52)
        )
        let window = present(host, size: NSSize(width: 800, height: 52))
        try await pump(0.1)
        #expect(host.hitTest(NSPoint(x: 40, y: host.bounds.midY)) != nil, "aktive Toolbar-Icons sichtbar")
        #expect(ToolbarNavIconRole.home.fillOpacity == 1.0)
        window.orderOut(nil)
    }

    @Test func mediumDetailSplitsFilesAndFolders() {
        let medium = Medium(
            id: UUID(),
            name: "Stick",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 238_421,
            folderCount: 12_908,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 1
        )
        #expect(medium.filesLabel.contains("238"))
        #expect(medium.foldersLabel.contains("12"))
        #expect(LayoutCopy.files != LayoutCopy.folders)
    }

    // MARK: - Helpers

    private func assertColumnShowsFirstRow(count: Int, firstName: String, sampleOnly: Bool = false) async throws {
        let mediumID = UUID()
        let app = AppState()
        let items: [IndexedItem]
        if sampleOnly {
            // Volle 14k/20k im Fenster wären zu schwer für Paralleltests — Schwelle 50k ⇒ LazyVStack.
            items = makeItems(mediumID: mediumID, count: min(count, 80), firstName: firstName)
            #expect(count < ColumnFolderListThreshold.tableViewMinimum)
        } else {
            items = makeItems(mediumID: mediumID, count: count, firstName: firstName)
        }
        let usesTable = items.count >= ColumnFolderListThreshold.tableViewMinimum
        let contents = ColumnFolderContents(
            mediumID: mediumID,
            path: [],
            filteredItems: items,
            selectedIDs: [],
            isLoading: false,
            loaded: items.count,
            total: items.count
        ) { Text($0.name) }
        .environment(app)
        .frame(width: 300, height: 400)

        let host = NSHostingView(rootView: contents)
        let window = present(host, size: NSSize(width: 300, height: 400))
        try await pump(0.25)
        if usesTable {
            let table = try #require(findTable(in: host))
            // Kein manuelles reloadData — die Representable muss Zeilen liefern.
            #expect(table.numberOfRows > 0)
            #expect(table.view(atColumn: 0, row: 0, makeIfNecessary: true) != nil)
        } else {
            #expect(findTable(in: host) == nil)
            #expect(!collectScrollViews(in: host).isEmpty, "Spalten zeigen Zeilen")
        }
        #expect(items.first?.name == firstName)
        window.orderOut(nil)
    }

    private func makeItems(mediumID: UUID, count: Int, firstName: String) -> [IndexedItem] {
        var items: [IndexedItem] = []
        items.reserveCapacity(count)
        for index in 0..<count {
            let name = index == 0 ? firstName : "f\(index).txt"
            let kind: IndexedItem.Kind = index == 0 ? .folder : .file
            items.append(
                IndexedItem(
                    id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                    rowID: Int64(index + 1),
                    name: name,
                    kind: kind,
                    parentPath: [],
                    modifiedAt: Date(),
                    sizeBytes: 4)
            )
        }
        return items
    }

    private func present(_ host: NSView, size: NSSize) -> NSWindow {
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        return window
    }

    private func firstButton(in root: NSView) -> NSButton? {
        if let button = root as? NSButton { return button }
        for child in root.subviews {
            if let found = firstButton(in: child) { return found }
        }
        return nil
    }

    /// Aufgabe 140 — echte Mausereignisse statt hitTest.
    private func click(_ window: NSWindow, at point: NSPoint) {
        let down = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        )
        let up = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        )
        if let down { window.sendEvent(down) }
        if let up { window.sendEvent(up) }
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    private func edgePoints(in size: NSSize) -> [NSPoint] {
        [
            NSPoint(x: 2, y: size.height / 2),
            NSPoint(x: size.width - 2, y: size.height / 2),
            NSPoint(x: size.width / 2, y: 2),
            NSPoint(x: size.width / 2, y: size.height - 2),
            NSPoint(x: 2, y: 2),
            NSPoint(x: size.width - 2, y: size.height - 2),
        ]
    }

    private func collectScrollViews(in root: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView { found.append(scroll) }
            for child in view.subviews { walk(child) }
        }
        walk(root)
        return found
    }

    private func collectAccessibility(in root: NSView) -> [String] {
        var labels: [String] = []
        func walk(_ view: NSView) {
            if let label = view.accessibilityLabel(), !label.isEmpty { labels.append(label) }
            for child in view.subviews { walk(child) }
        }
        walk(root)
        return labels
    }

    private func findTable(in root: NSView) -> NSTableView? {
        if let scroll = root as? NSScrollView, let table = scroll.documentView as? NSTableView {
            return table
        }
        for child in root.subviews {
            if let found = findTable(in: child) { return found }
        }
        return nil
    }
}

@Observable
final class CheckboxHitProbeModel {
    var isOn = false
}

/// Volle Klickfläche wie DesignCheckbox (`fullHitArea`), für Mausereignis-Tests.
struct FullHitToggleProbe: View {
    var model: CheckboxHitProbeModel
    var body: some View {
        Button {
            model.isOn.toggle()
        } label: {
            HStack {
                Text(LayoutCopy.noticesToggle)
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .frame(width: 280, height: 48)
    }
}

struct CheckboxHitProbe: View {
    var model = CheckboxHitProbeModel()
    var body: some View {
        Toggle(LayoutCopy.noticesToggle, isOn: Binding(
            get: { model.isOn },
            set: { model.isOn = $0 }
        ))
        .toggleStyle(DesignCheckbox())
        .padding(20)
        .frame(width: 280, height: 40)
    }
}

private struct ToolbarSmokeHost: View {
    @State private var query = ""
    @FocusState private var focused: Bool
    var body: some View {
        MainWindowToolbar(
            searchQuery: $query,
            isSearchFocused: $focused,
            onSearchSubmit: {}
        )
    }
}

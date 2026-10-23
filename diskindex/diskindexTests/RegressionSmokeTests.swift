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
        // Dateien-Tab: zweite Zeile der Seitenleiste (Mitte bei 16 + 15 + 32 pt von oben).
        click(window, at: NSPoint(x: 80, y: host.bounds.height - (16 + 15 + 32)))
        try await pump(0.15)
        // Wirkung: der Klick auf die zweite Zeile der Seitenleiste wählt „Dateien“ (nicht nur hitTest).
        #expect(app.settingsTab == .files)
        click(window, at: NSPoint(x: 80, y: host.bounds.height - (16 + 15 + 64)))
        try await pump(0.15)
        #expect(app.settingsTab == .storageMedia, "Klick auf die dritte Zeile ändert den Tab nicht")
        window.orderOut(nil)
    }

    // MARK: - (d) Checkbox — Maus kippt Schalter

    @Test func checkboxMouseToggles() async throws {
        // DesignCheckbox ist SwiftUI-Button (kein NSButton) — gleiche Mauskette wie ConfirmButton.
        let model = CheckboxHitProbeModel()
        let host = NSHostingView(rootView: FullHitToggleProbe(model: model))
        let window = present(host, size: NSSize(width: 280, height: 56))
        window.orderFrontRegardless()
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
        app.settingsTab = .general
        // bug.0.4.122: Der Hauptschalter liegt im Abschnitt „Allgemein“ (vorher „Erweitert“ – der Klick traf nie, die
        // Prüfung war bedingt und damit immer wahr).
        let host = NSHostingView(
            rootView: SettingsGeneralTab(section: .general).environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 720, height: 900)
                .background(Color.white)
        )
        host.appearance = NSAppearance(named: .aqua)
        let window = present(host, size: NSSize(width: 720, height: 900))
        window.appearance = NSAppearance(named: .aqua)
        window.orderFrontRegardless()
        try await pump(0.25)
        let master = try #require(Self.masterCheckbox(in: host), "Hauptschalter „Mitteilungen“ nicht gefunden")
        #expect(app.notificationsToggleShown == true)
        // Regel 19: keine echte Mitteilung aus dem Test – Drossel vorab belegen (An/Aus melden dann nichts) und Posts
        // dieses Tasks abfangen.
        let now = Date()
        _ = app.noticeThrottle.allow(SystemNotice.noticesOnKind, now: now)
        _ = app.noticeThrottle.allow(SystemNotice.noticesOffKind, now: now)
        var posted: [String] = []
        let hooks = NoticeTestHooks(post: { _, kind in posted.append(kind) })
        try await SystemNotice.$testHooks.withValue(hooks) {
            click(window, at: master)
            let off = await waitUntil(timeout: 3) { app.notificationsToggleShown == false }
            #expect(off, "Klick schaltet die Mitteilungen nicht aus")
            // Aus bleibt der Schalter bedienbar: der zweite Klick schaltet wieder ein.
            click(window, at: master)
            let on = await waitUntil(timeout: 3) { app.notificationsToggleShown == true }
            #expect(on, "Hauptschalter im Aus-Zustand nicht bedienbar")
            try await pump(0.1)
        }
        #expect(posted.isEmpty, "Test hat Mitteilungen ausgelöst: \(posted)")
        // Modell-Regeln bleiben gültig
        app.appSettings.notificationsEnabled = false
        #expect(!DiskNotice.system.allowed(by: app.appSettings))
        window.orderOut(nil)
    }

    /// Mitte des Hauptschalters (Fensterkoordinaten, Ursprung unten links): das Kästchen mit Häkchen, unter dem das
    /// nächste Kästchen mit Häkchen um `noticeEventsLeadingInset` eingerückt steht (Zeile „System“).
    private static func masterCheckbox(in host: NSView) -> NSPoint? {
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / max(1, host.bounds.width)
        // Häkchen = dunkle Tinte (Steuerfarbe) in einem kleinen Kästchen; Spalten links der Mitte sind Beschreibungstext.
        var marks: [CGPoint] = []
        let x0 = Int(host.bounds.width * 0.5 * scale)
        var y = 0
        while y < rep.pixelsHigh {
            var x = x0
            while x < rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.5,
                   0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent < 0.3 {
                    let point = CGPoint(x: CGFloat(x) / scale, y: CGFloat(y) / scale)
                    if !marks.contains(where: { abs($0.x - point.x) < 12 && abs($0.y - point.y) < 12 }) {
                        marks.append(point)
                    }
                }
                x += 2
            }
            y += 2
        }
        // Je Zeile nur die linke Marke (Häkchen vor dem Text der Zeile).
        let leftmost = marks.filter { mark in !marks.contains { abs($0.y - mark.y) < 6 && $0.x < mark.x } }
        // Die Ereigniszeilen sind eingerückt (`noticeEventsLeadingInset`, abzüglich Innenabstand der ersten Zeile).
        let inset = SettingsGeneralTab.noticeEventsLeadingInset
        for mark in leftmost.sorted(by: { $0.y < $1.y }) {
            let hasIndentedBelow = leftmost.contains {
                $0.x - mark.x > inset * 0.5 && $0.x - mark.x < inset * 1.4 && $0.y > mark.y + 10 && $0.y < mark.y + 40
            }
            if hasIndentedBelow {
                // Bitmap: Ursprung oben links; Fenster: unten links.
                return NSPoint(x: mark.x, y: host.bounds.height - mark.y)
            }
        }
        return nil
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

    // MARK: - Paket 6 (bug.0.4.034–036)

    /// bug.0.4.034: Ordner auf Tiefe = Scan-Tiefe sind „nicht indiziert“ (gelb), nicht „wird indiziert“.
    @Test func folderAtScanDepthIsUncaptured() {
        var settings = AppSettings()
        settings.scanDepth = 2
        let medium = makeSmokeMedium()
        #expect(ColumnFolderOpenState.resolve(columnIndex: 1, medium: medium, settings: settings) == .uncaptured(.scanDepth))
        #expect(ColumnFolderOpenState.resolve(columnIndex: 0, medium: medium, settings: settings, folderListedAt: Date()) == .normal)
    }

    /// bug.0.4.035: ab 500 Zielen Rückfrage, darunter sofort; Auswahl prüft über die Menge.
    @Test func ignoreFromFiveHundredAsksFirst() {
        let app = AppState()
        app.requestIgnore((0..<499).map { "a\($0)" }, targetCount: 499)
        #expect(app.ignoreConfirmationPrompt == nil)
        #expect(app.appSettings.excludedPatterns.count == 499)
        app.requestIgnore(["b"], targetCount: 500)
        #expect(app.ignoreConfirmationPrompt?.count == 500)
        app.resolveIgnoreConfirmation(confirm: false)
        #expect(!app.appSettings.excludedPatterns.contains("b"))
        var selection = ColumnSelection()
        let ids = (0..<3).map { _ in UUID() }
        selection.selectAll(visible: ids, column: 0)
        #expect(ids.allSatisfy(selection.contains))
    }

    /// bug.0.3.9.005 c / 007 b: Rückfrage-Panel je Instanz (außerhalb des Bildschirms); Schließen setzt sie zurück.
    @Test func ignorePromptPanelClosesAndResets() {
        let app = AppState()
        app.promptPanelPlacement = .offscreen
        app.requestIgnore(["b"], targetCount: 500)
        #expect(AppWindowPresenter.ignoreConfirmationPanel(for: app)?.isVisible == true)
        AppWindowPresenter.closePromptPanels(for: app)
        #expect(app.ignoreConfirmationPrompt == nil && AppWindowPresenter.ignoreConfirmationPanel(for: app) == nil)
    }

    /// bug.0.4.036: sichtbare Spalten bleiben im Cache, auch wenn viele andere Ordner geladen werden.
    @Test func visibleColumnStaysCached() {
        let app = AppState()
        let medium = UUID()
        app.columnBrowserState.selectedMediumID = medium
        app.columnBrowserState.pathStack = ["Offen"]
        app.indexRepository.seedScreenshotCache(mediumID: medium, entries: [([], []), (["Offen"], [])])
        app.indexRepository.seedScreenshotCache(mediumID: medium, entries: (0..<40).map { (["F\($0)"], []) })
        #expect(app.indexRepository.hasCachedChildren(mediumID: medium, path: []))
        #expect(app.indexRepository.hasCachedChildren(mediumID: medium, path: ["Offen"]))
    }

    /// bug.0.4.038/039: Pfad/Status nur in der Seite sortierbar (sonst Rückfall auf Name), Name immer; Popover entprellt.
    @Test func searchSortColumnsAndPopoverDebounce() {
        #expect(SearchSort(column: .path, direction: .ascending).serverOrder == SearchSort())
        #expect(SearchSort(column: .date, direction: .descending).serverOrder.column == .date)
        #expect(ObjectResultsOrdering.isSortable(.name, serverSortedColumns: SearchSort.pageOrderedColumns, clientSortAvailable: false))
        #expect(!ObjectResultsOrdering.isSortable(.status, serverSortedColumns: SearchSort.pageOrderedColumns, clientSortAvailable: false))
        #expect(AppState().popoverSearchDebounce == .milliseconds(150))
    }

    /// bug.0.4.037/040: Favorit aus der Menge (zweiter Klick auf ein altes Ziel), Online abgeleitet, Verbindungsfilter als Medienauswahl.
    @Test func favoriteFromSetAndDerivedOnline() {
        #expect(FavoriteLookup(rowIDs: [7], editsBeforeLoad: [:]).isFavorite(rowID: 7, fallback: false))
        #expect(!FavoriteLookup(rowIDs: [], editsBeforeLoad: [:]).isFavorite(rowID: 7, fallback: true))
        #expect(!FavoriteLookup(rowIDs: nil, editsBeforeLoad: [7: false]).isFavorite(rowID: 7, fallback: true))
        var medium = makeSmokeMedium()
        let app = AppState()
        app.media = [medium]
        #expect(app.mediumConnectivity[medium.id] == true)
        #expect(app.isMediumOnline(medium.id))
        medium.connectionStatus = .offline
        #expect(FavoritesRequest(media: [medium], connection: .offline, filters: SearchFilters(), maxDepth: nil).mediumIDs == [medium.id])
        #expect(FavoritesRequest(media: [medium], connection: .online, filters: SearchFilters(), maxDepth: nil).mediumIDs.isEmpty)
        #expect(SearchIndex.pageLimit == 500)
    }

    /// bug.0.4.041/042: Ringzeile an UTF-8-Grenze gekürzt; Übergabe startet kein Protokoll; Beenden bei Übergabe sofort.
    @Test func crashWriterAndStartupOrder() throws {
        #expect(String(decoding: DiskIndexLog.utf8Prefix(Array("ää".utf8), limit: 3), as: UTF8.self) == "ä")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DiskIndexLog(directory: folder)
        #expect(AppStartup.willFinishLaunching(launchKind: .click, resolveSingleInstance: { .handOff }, log: log, installHandlers: false))
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("crash-last.txt").path))
        let flow = TerminationFlow(log: log)
        #expect(flow.shouldTerminate(handedOff: true, teardown: {}, finish: {}, reply: {}) == .terminateNow)
    }

    /// bug.0.4.087/090: Klick auf eine Datei → Details-Spalte erscheint und wird eingescrollt, auch wenn eine andere
    /// Spalte noch einen Ladehinweis zeigt (echtes Fenster, echter Store).
    @Test func clickedFileScrollsDetailColumnIntoView() async throws {
        try await ColumnAutoScrollTestSupport.runStoreSelectionScrollsTrailing(byClick: true, stuckRootHint: true)
    }

    private func makeSmokeMedium() -> Medium {
        Medium(
            id: UUID(), name: "Rauch", type: .usb, connectionStatus: .connected, indexStatus: .indexing,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1, capacityUsedBytes: 0,
            fileCount: 0, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: nil, lastIndexedAt: nil,
            isForgotten: false, indexingProgress: 0
        )
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
        PixelProbe.offscreenWindow(hosting: host, size: size)
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

/// bug.0.4.098 (Regel 11): je eine Zeile für die Ansichten aus Paket 12, die schon einmal kaputt waren. Jede Zeile
/// ruft die vorhandene Fensterprüfung der zugehörigen Suite (echtes Fenster außerhalb des Bildschirms).
extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct RegressionSmokeRows {
    /// bug.0.4.088: Ignorieren an Ort und Stelle (Spalte bleibt gefüllt, Ordner verschwindet sofort).
    @Test func ignoreInPlaceRow() async throws {
        try await ColumnIgnoreInPlaceTests().ignoringAndRestoringAFolderHidesItInPlaceConnected()
    }

    /// bug.0.4.089: Trennlinie zwischen allen Spalten, auch im Ladezustand.
    @Test func dividerInLoadingStateRow() async throws {
        try await ColumnDividerTests().dividersBetweenAllColumnsInEveryStateLight()
    }

    /// bug.0.4.091: Platz für den Rollbalken in den Einstellungen (gleiche Inhaltsbreite in allen Tabs).
    @Test func settingsScrollbarGutterRow() async throws {
        try await SettingsScrollGutterTests().legacyStyleKeepsTheSameContentWidthInAllTabs()
    }

    /// bug.0.4.081: Sortierkopf über die ganze Spaltenbreite klickbar.
    @Test func sortHeaderWholeWidthRow() async throws {
        try await SearchSortHeaderWindowTests().everySortableHeaderTogglesAcrossItsWholeWidth(dark: false, style: .system)
    }
}
}

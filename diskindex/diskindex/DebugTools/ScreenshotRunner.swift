//
//  ScreenshotRunner.swift
//  diskindex
//
//  Debug: --screenshots <Ordner> zeichnet jedes Fenster und beendet die App.
//

import AppKit
import SwiftUI

#if DEBUG

enum ScreenshotRunner {
    @MainActor
    static func run(folder: String, appState: AppState) {
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let fixture = ScreenshotFixture.make()
        var failed: [String] = []
        for name in screenshotNames() {
            let dark = name.hasSuffix("dunkel")
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            NSApp.appearance = appearance
            configure(fixture, name: name)
            let root = screenshotView(name: name, appState: fixture)
                .environment(fixture)
                .frame(width: 1280, height: 800)
            let needsRows = baseNeedsColumnRows(name)
            guard let rep = capture(root, appearance: appearance, requireColumnRows: needsRows),
                  !ScreenshotPixels.isUniform(rep),
                  (!needsRows || ScreenshotPixels.hasDistinctInk(rep)),
                  let data = rep.representation(using: .png, properties: [:]) else {
                failed.append(name)
                continue
            }
            try? data.write(to: url.appendingPathComponent("\(name).png"))
        }
        NSApp.appearance = nil
        if !failed.isEmpty {
            fputs("screenshot leer: \(failed.joined(separator: ", "))\n", stderr)
            exit(1)
        }
        NSApp.terminate(nil)
    }

    /// Optional: `SCREENSHOT_PREFIX=07-wird-indiziert` (Komma-getrennt für mehrere Basen).
    private static func screenshotNames() -> [String] {
        let all = ScreenshotPlan.names
        guard let raw = ProcessInfo.processInfo.environment["SCREENSHOT_PREFIX"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return all }
        let prefixes = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !prefixes.isEmpty else { return all }
        return all.filter { name in prefixes.contains { name.hasPrefix($0) } }
    }

    private static func baseNeedsColumnRows(_ name: String) -> Bool {
        let base = name
            .replacingOccurrences(of: "-hell", with: "")
            .replacingOccurrences(of: "-dunkel", with: "")
            .replacingOccurrences(of: "-vorschlag", with: "")
        return ["07-spalten", "07-tiefe", "07-kontext", "07-mehrfach"].contains(base)
    }

    @MainActor
    private static func capture(
        _ view: some View,
        appearance: NSAppearance?,
        requireColumnRows: Bool
    ) -> NSBitmapImageRep? {
        let host = NSHostingView(rootView: view)
        host.appearance = appearance
        host.frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        let until = Date().addingTimeInterval(0.8)
        while Date() < until {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            prepareColumnTables(in: host)
        }
        host.layoutSubtreeIfNeeded()
        window.display()
        if requireColumnRows, !columnTablesHaveVisibleRows(in: host) {
            window.orderOut(nil)
            return nil
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            window.orderOut(nil)
            return nil
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        return rep
    }

    /// NSTableView-Zeilen erst nach Layout/RunLoop erzeugen (Offscreen-Screenshots).
    @MainActor
    private static func prepareColumnTables(in root: NSView) {
        if let scroll = root as? NSScrollView, let table = scroll.documentView as? NSTableView {
            table.reloadData()
            table.tile()
            table.layoutSubtreeIfNeeded()
            if table.numberOfRows > 0 {
                _ = table.view(atColumn: 0, row: 0, makeIfNecessary: true)
            }
        }
        for child in root.subviews {
            prepareColumnTables(in: child)
        }
    }

    /// NSTableView (≥5000) oder LazyVStack-ScrollView (<5000) mit sichtbarem Inhalt.
    @MainActor
    private static func columnTablesHaveVisibleRows(in root: NSView) -> Bool {
        var sawTable = false
        var tableOK = true
        var sawLazyStackContent = false
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                if let table = scroll.documentView as? NSTableView {
                    sawTable = true
                    table.reloadData()
                    table.layoutSubtreeIfNeeded()
                    guard table.numberOfRows > 0,
                          table.view(atColumn: 0, row: 0, makeIfNecessary: true) != nil else {
                        tableOK = false
                        return
                    }
                } else if let doc = scroll.documentView,
                          doc.bounds.height > 8,
                          !doc.subviews.isEmpty {
                    sawLazyStackContent = true
                }
            }
            for child in view.subviews {
                walk(child)
            }
        }
        walk(root)
        if sawTable { return tableOK }
        return sawLazyStackContent
    }

    @MainActor
    private static func patchProgressMedium(_ app: AppState, percent: Int, scanTotal: Int) {
        guard let id = app.media.first?.id else { return }
        let stored = max(1, scanTotal * percent / 100)
        app.updateMedium(id: id, persist: false) {
            $0.indexStatus = .indexing
            $0.indexRunPhase = .indexing
            $0.scanTotal = scanTotal
            $0.fileCount = stored
            $0.folderCount = 0
            $0.indexingProgress = Double(stored) / Double(scanTotal)
        }
    }

    @MainActor
    private static func configure(_ app: AppState, name: String) {
        let isVorschlagShot = name.contains("-vorschlag")
        let base = name
            .replacingOccurrences(of: "-hell", with: "")
            .replacingOccurrences(of: "-dunkel", with: "")
            .replacingOccurrences(of: "-vorschlag", with: "")
        ScreenshotFixture.resetForShot(app)
        app.screenshotFrozenLists = true
        app.noticePreviewPin = nil
        app.detailMediumID = nil
        app.indexingFailure = nil
        app.clearNewMediumDecisionQueue()
        app.globalAutoIndexPaused = false
        app.popoverSearchText = ""
        app.isFilterBarVisible = false
        app.mainWindowDestination = .dashboard
        app.settingsTab = .general
        app.appSettings.appearance = .system
        switch base {
        case "05-erscheinung-hell":
            app.settingsTab = .general
            app.appSettings.appearance = .light
            app.mainWindowDestination = .settings
        case "05-erscheinung-dunkel":
            app.settingsTab = .general
            app.appSettings.appearance = .dark
            app.mainWindowDestination = .settings
        case "04-uebersicht-einzeln":
            if let one = app.media.first {
                app.media = [one]
            }
            app.mainWindowDestination = .dashboard
        case "04-uebersicht-leer":
            app.media = []
            app.mainWindowDestination = .dashboard
        case "05-allgemein":
            app.mainWindowDestination = .settings
            app.settingsTab = .general
        case "05-dateien":
            app.mainWindowDestination = .settings
            app.settingsTab = .files
        case "05-dateien-chips":
            app.mainWindowDestination = .settings
            app.settingsTab = .files
            app.appSettings.excludedPatterns = [
                "*.log",
                String(repeating: "sehr-langes-ausschlussmuster-", count: 4) + "ende",
            ]
        case "04-dashboard-chips":
            app.mainWindowDestination = .dashboard
        case "04-dashboard-chips-zaehlt":
            app.mainWindowDestination = .dashboard
            if let id = app.media.first?.id {
                app.updateMedium(id: id, persist: false) {
                    $0.indexStatus = .indexing
                    $0.indexRunPhase = .counting
                }
            }
        case "04-dashboard-chips-9":
            app.mainWindowDestination = .dashboard
            patchProgressMedium(app, percent: 9, scanTotal: 10_000)
        case "04-dashboard-chips-47":
            app.mainWindowDestination = .dashboard
            patchProgressMedium(app, percent: 47, scanTotal: 10_000)
        case "04-dashboard-chips-99":
            app.mainWindowDestination = .dashboard
            patchProgressMedium(app, percent: 99, scanTotal: 10_000)
        case "05-medien":
            app.mainWindowDestination = .settings
            app.settingsTab = .storageMedia
        case "05-medien-leer":
            app.media = []
            app.mainWindowDestination = .settings
            app.settingsTab = .storageMedia
        case "05-erweitert":
            app.mainWindowDestination = .settings
            app.settingsTab = .advanced
            if isVorschlagShot {
                app.noticePreviewPin = .system
            }
        case "05-erweitert-indiziert":
            app.mainWindowDestination = .settings
            app.settingsTab = .advanced
            app.noticePreviewPin = .indexed
        case "05-erweitert-favoriten":
            app.mainWindowDestination = .settings
            app.settingsTab = .advanced
            app.noticePreviewPin = .favorites
        case "06-detail":
            app.detailMediumID = app.media.first?.id
        case "07-spalten", "07-spalten-langname", "07-tiefe", "07-kontext", "07-mehrfach",
             "07-nicht-erfasst", "07-wird-indiziert", "07-inhalte-geladen":
            ScreenshotFixture.configureColumnBrowser(app, variant: base)
        case "08-filter", "08-filter-und-sichtbar", "08-filter-und-aus":
            ScreenshotFixture.configureColumnBrowser(app, variant: base)
            app.isFilterBarVisible = true
            if base == "08-filter-und-sichtbar" {
                app.searchState.filters.fileTypes = [.documents]
                app.searchState.filters.age = .lastYear
                app.searchState.filters.combineWithAnd = false
            } else if base == "08-filter-und-aus" {
                app.searchState.filters.fileTypes = [.documents]
            }
        case "09-filterpopover":
            app.mainWindowDestination = .search
            app.isFilterBarVisible = true
        case "10-suche-1":
            app.mainWindowDestination = .search
            app.isFilterBarVisible = true
        case "10-suche-2":
            app.mainWindowDestination = .search
            app.searchState.submittedQuery = "rechnung"
            app.searchMatch = ScreenshotFixture.match(app)
        case "10-suche-3":
            app.mainWindowDestination = .search
            app.isFilterBarVisible = true
            app.searchState.filters.fileTypes = [.documents]
            app.searchMatch = ScreenshotFixture.match(app)
        case "10-suche-4":
            app.mainWindowDestination = .search
            app.isFilterBarVisible = true
            app.searchState.submittedQuery = "rechnung"
            app.searchState.filters.fileTypes = [.documents]
            app.searchMatch = ScreenshotFixture.match(app)
        case "10-suche-5":
            app.mainWindowDestination = .search
            app.searchState.submittedQuery = "nichts"
        case "10-suche-6":
            app.mainWindowDestination = .search
            app.searchState.submittedQuery = "rechnung"
            app.searchState.isSearchInProgress = true
        case "10-suche-vorschlag":
            app.mainWindowDestination = .search
        case "10-suche-keine":
            app.mainWindowDestination = .search
            app.searchState.submittedQuery = "nichts"
            app.searchMatch = SearchMatch()
        case "11-favoriten", "11-favoriten-kontext":
            app.mainWindowDestination = .favorites
            if isVorschlagShot {
                app.favoriteObjects = []
                app.media = app.media.map {
                    var copy = $0
                    copy.isFavorite = false
                    return copy
                }
            } else {
                app.favoriteObjects = ScreenshotFixture.favorites(app)
            }
        case "11-favoriten-leer":
            app.mainWindowDestination = .favorites
            app.favoriteObjects = []
            app.media = app.media.map {
                var copy = $0
                copy.isFavorite = false
                return copy
            }
        case "10-suche-leer":
            app.mainWindowDestination = .search
            app.searchState.submittedQuery = ""
            app.searchMatch = SearchMatch()
        case "toolbar-dashboard":
            app.mainWindowDestination = .dashboard
        case "toolbar-favorites":
            app.mainWindowDestination = .favorites
        case "toolbar-settings":
            app.mainWindowDestination = .settings
        case "toolbar-search":
            app.mainWindowDestination = .search
        case "toolbar-filter":
            ScreenshotFixture.configureColumnBrowser(app, variant: "07-spalten")
            app.isFilterBarVisible = true
        case "14-fehler":
            if let medium = app.media.first(where: { $0.indexStatus == .error }) {
                app.indexingFailure = IndexingFailureNotice(id: medium.id, name: medium.name, reason: .permission)
            }
        case "03-pause-pausiert":
            app.globalAutoIndexPaused = true
            app.pauseIndexing(until: Date().addingTimeInterval(3_600), defaults: UserDefaults(suiteName: "diskindex-screenshots")!)
        default:
            break
        }
    }

    @MainActor
    @ViewBuilder
    private static func screenshotView(name: String, appState: AppState) -> some View {
        let base = name.replacingOccurrences(of: "-hell", with: "").replacingOccurrences(of: "-dunkel", with: "")
        ZStack {
            DesignColor.bg
            switch base {
            case "02-erkennung":
                if let medium = appState.media.first(where: { $0.decision == .undecided }) {
                    NewMediumDetectedDialog(medium: medium)
                }
            case "03-ruhe":
                MenuBarPopoverView()
            case "03-pause-an", "03-pause-pausiert":
                MenuBarPopoverView(showsPauseMenu: true)
            case "03-suche":
                MenuBarPopoverView()
                    .onAppear { appState.popoverSearchText = "rechnung" }
            case "03-hover":
                MenuBarPopoverView(highlightFirstRow: true)
            case "13-absturz":
                CrashReportDialog {}
            case "14-mitteilung":
                NoticePreviewCard(event: .system)
                    .frame(width: 320)
            case "09-filterpopover":
                SearchFilterPopoverPanel()
                    .frame(width: 640)
            case "07-kontext":
                ZStack(alignment: .topLeading) {
                    MainWindowHostView()
                    ScreenshotContextMenu(targets: [ScreenshotFixture.contextFolderTarget(appState)])
                        .padding(.leading, 400)
                        .padding(.top, 200)
                }
            case "12-kontext":
                ScreenshotContextMenu(targets: [ScreenshotFixture.contextFolderTarget(appState)])
            case "11-favoriten-kontext":
                ZStack(alignment: .topLeading) {
                    MainWindowHostView()
                    ScreenshotContextMenu(targets: [ScreenshotFixture.contextFolderTarget(appState)])
                        .padding(80)
                }
            case "07-mehrfach":
                ZStack(alignment: .topLeading) {
                    MainWindowHostView()
                    ScreenshotContextMenu(targets: ScreenshotFixture.contextMultiFileTargets(appState))
                        .padding(.leading, 400)
                        .padding(.top, 260)
                }
            default:
                if base.hasPrefix("05-bestaetigung-") {
                    confirmationScreenshot(base: base)
                } else {
                    MainWindowHostView()
                }
            }
        }
    }

    @MainActor
    private static func confirmationScreenshot(base: String) -> some View {
        let spec = confirmationSpec(base: base)
        return ConfirmButton(title: spec.title, tone: spec.tone, screenshotStage: spec.stage)
            .padding(48)
    }

    private static func confirmationSpec(base: String) -> (title: String, tone: ConfirmButton.Tone, stage: ConfirmStage) {
        let parts = base.split(separator: "-")
        let stageNumber = Int(parts.last ?? "1") ?? 1
        let stage: ConfirmStage = switch stageNumber {
        case 2: .armed
        case 3: .confirmed
        default: .idle
        }
        let kind = parts.dropFirst(2).dropLast().joined(separator: "-")
        switch kind {
        case "alle":
            return (LayoutCopy.forgetAll, .destructive, stage)
        case "detail":
            return (LayoutCopy.forget, .destructive, stage)
        case "bereinigen":
            return (LayoutCopy.pruneButton, .neutral, stage)
        case "voreinstellungen":
            return (LayoutCopy.defaultsButton, .muted, stage)
        default:
            return (LayoutCopy.forgetAll, .destructive, stage)
        }
    }

}

@MainActor
private enum ScreenshotFixture {
    private struct ColumnCatalog {
        let entries: [([String], [IndexedItem])]
        let rechnungen2021FolderID: UUID
        let invoiceFileIDs: [UUID]
        let designFolderID: UUID
        let tiefFolderID: UUID
    }

    static func make() -> AppState {
        let app = AppState()
        app.media = media
        app.screenshotFrozenLists = true
        return app
    }

    static func resetForShot(_ app: AppState) {
        app.media = media
        app.indexRepository.invalidateAll()
        app.columnBrowserState = ColumnBrowserState()
        app.appSettings.scanDepth = AppSettings.defaultScanDepth
    }

    static func configureColumnBrowser(_ app: AppState, variant: String) {
        guard let medium = app.indexedMedia.first else { return }
        // Scan-Tiefe VOR dem Seed setzen: AppSettings.didSet invalidiert den Cache bei Scope-Wechsel.
        switch variant {
        case "07-tiefe":
            app.appSettings.scanDepth = 3
            app.updateMedium(id: medium.id, persist: false) { $0.completedDepth = 5 }
        case "07-nicht-erfasst":
            app.appSettings.scanDepth = 2
            app.updateMedium(id: medium.id, persist: false) {
                $0.completedDepth = 5
                $0.indexStatus = .indexed
            }
        case "07-wird-indiziert":
            app.appSettings.scanDepth = 5
            app.updateMedium(id: medium.id, persist: false) {
                $0.indexStatus = .indexing
                $0.completedDepth = 2
                $0.indexingProgress = 0.35
            }
        default:
            break
        }

        let catalog = columnCatalog(
            mediumID: medium.id,
            pendingDesign: variant == "07-wird-indiziert",
            longFileName: variant == "07-spalten-langname" ? Self.columnLongFileName : nil
        )
        app.indexRepository.seedScreenshotCache(mediumID: medium.id, entries: catalog.entries)
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.id

        switch variant {
        case "07-spalten", "08-filter":
            app.columnBrowserState.pathStack = ["Rechnungen"]
            var selection = ColumnSelection()
            selection.replace(id: catalog.rechnungen2021FolderID, column: 1)
            app.columnBrowserState.selection = selection
        case "07-tiefe":
            app.columnBrowserState.pathStack = ["Projekte", "Design"]
            var selection = ColumnSelection()
            selection.replace(id: catalog.designFolderID, column: 2)
            app.columnBrowserState.selection = selection
        case "07-kontext":
            app.columnBrowserState.pathStack = ["Rechnungen", "Rechnungen_2021"]
            if let fileID = catalog.invoiceFileIDs.first {
                var selection = ColumnSelection()
                selection.replace(id: fileID, column: 2)
                app.columnBrowserState.selection = selection
            }
        case "07-mehrfach":
            app.columnBrowserState.pathStack = ["Rechnungen", "Rechnungen_2021"]
            var selection = ColumnSelection()
            if let first = catalog.invoiceFileIDs.first {
                selection.replace(id: first, column: 2)
            }
            if catalog.invoiceFileIDs.count > 1 {
                selection.commandClick(id: catalog.invoiceFileIDs[1], column: 2)
            }
            app.columnBrowserState.selection = selection
        case "07-nicht-erfasst":
            app.columnBrowserState.pathStack = ["Projekte", "Design"]
            var selection = ColumnSelection()
            selection.replace(id: catalog.tiefFolderID, column: 2)
            app.columnBrowserState.selection = selection
            app.columnBrowserState.selectedUncapturedFolderID = catalog.tiefFolderID
        case "07-wird-indiziert":
            app.columnBrowserState.pathStack = ["Projekte", "Design"]
            var selection = ColumnSelection()
            selection.replace(id: catalog.designFolderID, column: 1)
            app.columnBrowserState.selection = selection
        case "07-spalten-langname":
            app.columnBrowserState.pathStack = ["Rechnungen", "Rechnungen_2021"]
            if let fileID = catalog.invoiceFileIDs.first {
                var selection = ColumnSelection()
                selection.replace(id: fileID, column: 2)
                app.columnBrowserState.selection = selection
            }
        case "07-inhalte-geladen":
            break
        default:
            break
        }
    }

    static func contextFolderTarget(_ app: AppState) -> ObjectContextTarget {
        let medium = app.indexedMedia.first
        let mediumID = medium?.id ?? UUID()
        let rowID: Int64 = 4
        return ObjectContextTarget(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: rowID),
            name: "Rechnungen_2021",
            kind: .folder,
            mediumID: mediumID,
            isMediumOnline: true,
            rowID: rowID,
            itemPath: "/Rechnungen/Rechnungen_2021"
        )
    }

    static func contextMultiFileTargets(_ app: AppState) -> [ObjectContextTarget] {
        let medium = app.indexedMedia.first
        let mediumID = medium?.id ?? UUID()
        return [
            (6, "rechnung_q1.pdf"),
            (7, "rechnung_q2.pdf"),
        ].map { rowID, name in
            ObjectContextTarget(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: rowID),
                name: name,
                kind: .file,
                mediumID: mediumID,
                isMediumOnline: true,
                rowID: rowID,
                itemPath: "/Rechnungen/Rechnungen_2021/\(name)"
            )
        }
    }

    /// 80 Zeichen, damit der Verlauf am Spaltenrand im Foto sichtbar ist.
    static let columnLongFileName = "Rechnung_Studio_Backup_Quartal1_Januar_bis_Maerz_2021_Endfassung_freigegeben.pdf"

    private static func columnCatalog(mediumID: UUID, pendingDesign: Bool = false, longFileName: String? = nil) -> ColumnCatalog {
        let listed = Date()
        func item(
            _ rowID: Int64,
            _ name: String,
            _ kind: IndexedItem.Kind,
            _ parentPath: [String],
            listedAt: Date? = listed
        ) -> IndexedItem {
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: rowID),
                rowID: rowID,
                name: name,
                kind: kind,
                parentPath: parentPath,
                modifiedAt: Date(),
                sizeBytes: kind == .file ? 80_000 : nil,
                listedAt: listedAt
            )
        }

        let rechnungen = item(1, "Rechnungen", .folder, [])
        let projekte = item(2, "Projekte", .folder, [])
        let readme = item(3, "readme.txt", .file, [])
        let inv2021 = item(4, "Rechnungen_2021", .folder, ["Rechnungen"])
        let inv2022 = item(5, "Rechnungen_2022.pdf", .file, ["Rechnungen"])
        let q1 = item(6, longFileName ?? "rechnung_q1.pdf", .file, ["Rechnungen", "Rechnungen_2021"])
        let q2 = item(7, "rechnung_q2.pdf", .file, ["Rechnungen", "Rechnungen_2021"])
        let design = item(8, "Design", .folder, ["Projekte"], listedAt: pendingDesign ? nil : listed)
        let code = item(9, "Code", .folder, ["Projekte"])
        let mockups = item(10, "Mockups", .folder, ["Projekte", "Design"])
        let preview = item(11, "preview.sketch", .file, ["Projekte", "Design"])
        let tief = item(13, "Tief", .folder, ["Projekte", "Design"])
        let hero = item(12, "hero.png", .file, ["Projekte", "Design", "Mockups"])

        return ColumnCatalog(
            entries: [
                ([], [rechnungen, projekte, readme]),
                (["Rechnungen"], [inv2021, inv2022]),
                (["Rechnungen", "Rechnungen_2021"], [q1, q2]),
                (["Projekte"], [design, code]),
                (["Projekte", "Design"], [mockups, preview, tief]),
                (["Projekte", "Design", "Mockups"], [hero]),
            ],
            rechnungen2021FolderID: inv2021.id,
            invoiceFileIDs: [q1.id, q2.id],
            designFolderID: design.id,
            tiefFolderID: tief.id
        )
    }

    static func match(_ app: AppState) -> SearchMatch {
        let medium = app.indexedMedia[0]
        let item = IndexedItem(
            id: UUID(),
            rowID: 1,
            name: "rechnung_2021_q1.pdf",
            kind: .file,
            parentPath: ["Rechnungen"],
            modifiedAt: Date(),
            sizeBytes: 120_000
        )
        return SearchMatch(
            media: [medium],
            items: [SearchResultItem(item: item, mediumID: medium.id, isOnline: true)],
            itemCount: 1
        )
    }

    static func favorites(_ app: AppState) -> [SearchResultItem] {
        match(app).items
    }

    private static var media: [Medium] {
        [
            medium("Studio Backup", .hdd, .connected, .indexing, 0.92, files: 238_421, depth: 4),
            medium("Backup SSD", .ssd, .connected, .indexed, 1, files: 89_102, depth: 5),
            medium("Archiv 2019–2021", .hdd, .offline, .indexed, 1, files: 48_210, depth: 5, favorite: true),
            medium("Foto-SSD", .ssd, .offline, .pending, 0.45, files: 12_000, depth: 2),
            medium("NAS Klon", .hdd, .connected, .error, 0.2, files: 40, depth: 1),
            medium("Alter USB-Stick", .usb, .offline, .pending, 0, files: 0, depth: 0, decision: .dontIndex),
            medium("Externe Platte 5", .hdd, .connected, .pending, 0, files: 0, depth: 0, decision: .undecided),
        ]
    }

    private static func medium(
        _ name: String,
        _ type: MediumType,
        _ connection: ConnectionStatus,
        _ status: IndexStatus,
        _ progress: Double,
        files: Int,
        depth: Int,
        favorite: Bool = false,
        decision: StoredIndexDecision = .index
    ) -> Medium {
        Medium(
            id: UUID(),
            name: name,
            type: type,
            connectionStatus: connection,
            indexStatus: status,
            allowIndexing: decision != .dontIndex,
            autoIndexPaused: false,
            decision: decision,
            capacityTotalBytes: 2_000_000_000_000,
            capacityUsedBytes: 700_000_000_000,
            fileCount: files,
            folderCount: files / 20,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            completedDepth: depth,
            isForgotten: false,
            indexingProgress: progress,
            isFavorite: favorite
        )
    }
}
#endif

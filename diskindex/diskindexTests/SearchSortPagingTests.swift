//
//  SearchSortPagingTests.swift
//  diskindexTests
//
//  bug.0.4.038 (REPORT 83, 130, 131): Sortierung über alle Treffer statt nur die erste Seite, Popover-Gruppen je mit
//  eigener Abfrage, Medienkacheln unabhängig von der Seite. Dazu ein echtes Fenster außerhalb des Bildschirms:
//  Klick auf einen Spaltenkopf fragt neu ab, ein deaktivierter Kopf schaltet nicht um (Regel 10/19/21).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

/// 600 Dateien `treffer-000.txt` … `treffer-599.txt` (je höher die Nummer, desto älter) und `zzz-treffer.txt` als
/// neueste. Die erste Seite (500 nach Name) enthält weder `treffer-599` noch `zzz-treffer`.
@MainActor
private func sortRig() async throws -> (app: AppState, store: IndexStoreV3) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-searchsort-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
    let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ARCHIV", type: .usb, decision: .index)
    try await store.upsertMedium(medium)
    let base = Date(timeIntervalSince1970: 1_600_000_000)
    var entries = (0..<600).map { index in
        ScannedEntry(
            name: String(format: "treffer-%03d.txt", index),
            isFolder: false,
            sizeBytes: 1,
            modifiedAt: base.addingTimeInterval(TimeInterval(600 - index) * 60)
        )
    }
    entries.append(ScannedEntry(name: "zzz-treffer.txt", isFolder: false, sizeBytes: 1, modifiedAt: base.addingTimeInterval(100_000)))
    try await store.applyDirectories(
        mediumUUID: medium.uuid,
        batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
        seenAt: Date()
    )
    try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
    let app = AppState(store: store)
    await app.loadStoredMedia()
    app.mainWindowDestination = .search
    app.searchState.query = "treffer"
    app.searchState.submittedQuery = "treffer"
    return (app, store)
}

/// 30 Dateien `datei 1.txt` … `datei 30.txt` (eine Seite): natürlich steht „datei 2“ vor „datei 10“, binär nicht.
@MainActor
private func naturalRig(media names: [String] = ["ARCHIV"]) async throws -> AppState {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-searchnatural-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
    for name in names {
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: name, type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let entries = (1...30).map { ScannedEntry(name: "datei \($0).txt", isFolder: false, sizeBytes: 1) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
    }
    let app = AppState(store: store)
    await app.loadStoredMedia()
    app.mainWindowDestination = .search
    app.searchState.query = "datei"
    app.searchState.submittedQuery = "datei"
    return app
}

extension MeasurementTestGroup {
@Suite(.serialized) @MainActor
struct SearchSortPagingTests {
    /// Review 038: Die Abfrage wählt die Seite nach Name (binär), die Tabelle sortiert sie natürlich nach, wie vor
    /// bug.0.4.038 (`localizedStandardCompare`). Gleiche Parameter wie `SearchView`.
    private func displayedNames(_ app: AppState) -> [String] {
        ObjectResultsOrdering.rows(
            app.searchMatch.items,
            sort: app.searchState.sort,
            serverSortedColumns: SearchSort.pageOrderedColumns,
            clientSortAvailable: app.searchMatch.allItemsOnPage,
            mediumNames: [:]
        ).map(\.name)
    }

    @Test func nameAscendingIsNaturalWithinThePage() async throws {
        let app = try await naturalRig()
        defer { app.prepareForTermination() }
        await app.runSearch()
        let names = displayedNames(app)
        #expect(names == (1...30).map { "datei \($0).txt" }, "Anfang: \(names.prefix(4))")
    }

    @Test func nameDescendingIsNaturalWithinThePage() async throws {
        let app = try await naturalRig()
        defer { app.prepareForTermination() }
        app.searchState.sort = SearchSort(column: .name, direction: .descending)
        await app.runSearch()
        let names = displayedNames(app)
        #expect(names == (1...30).reversed().map { "datei \($0).txt" }, "Anfang: \(names.prefix(4))")
    }

    /// bug.0.3.9.007 d: Nach Medium sortiert bleibt die Reihenfolge der Medien aus der Datenbank, innerhalb eines
    /// Mediums natürlich nach Name („datei 2“ vor „datei 10“), auch absteigend.
    @Test func mediumSortIsNaturalWithinEachMedium() async throws {
        let app = try await naturalRig(media: ["ARCHIV", "BACKUP"])
        defer { app.prepareForTermination() }
        for direction in [SortDirection.ascending, .descending] {
            app.searchState.sort = SearchSort(column: .medium, direction: direction)
            await app.runSearch()
            let rows = ObjectResultsOrdering.rows(
                app.searchMatch.items,
                sort: app.searchState.sort,
                serverSortedColumns: SearchSort.pageOrderedColumns,
                clientSortAvailable: app.searchMatch.allItemsOnPage,
                mediumNames: [:]
            )
            let expected = (1...30).map { "datei \($0).txt" }
            #expect(rows.map(\.name) == expected + expected, "\(direction): \(rows.prefix(4).map(\.name))")
            let firstMedium = try #require(rows.first?.mediumID)
            #expect(rows.prefix(30).allSatisfy { $0.mediumID == firstMedium })
            #expect(rows.dropFirst(30).allSatisfy { $0.mediumID != firstMedium })
        }
    }

    /// Über 500 Treffer bleibt der Kopf „Name“ klickbar, Pfad und Status nicht.
    @Test func nameStaysSortableBeyondOnePage() {
        let server = SearchSort.pageOrderedColumns
        #expect(ObjectResultsOrdering.isSortable(.name, serverSortedColumns: server, clientSortAvailable: false))
        #expect(ObjectResultsOrdering.isSortable(.date, serverSortedColumns: server, clientSortAvailable: false))
        #expect(!ObjectResultsOrdering.isSortable(.path, serverSortedColumns: server, clientSortAvailable: false))
        #expect(!ObjectResultsOrdering.isSortable(.status, serverSortedColumns: server, clientSortAvailable: false))
    }

    /// Review 038 (5): ein reiner Sortierklick zählt nicht neu; die Zahl bleibt stehen.
    @Test func aSortOnlyChangeDoesNotCountAgain() async throws {
        let (app, store) = try await sortRig()
        defer { app.prepareForTermination() }
        await app.runSearch()
        await app.waitForSearchCount()
        try #require(app.searchMatch.itemCount == 601)
        let before = store.searchCountCalls.value
        app.searchState.sort = SearchSort(column: .date, direction: .descending)
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(store.searchCountCalls.value - before == 0, "Sortierklick hat neu gezählt")
        #expect(app.searchMatch.itemCount == 601)
        #expect(app.searchMatch.items.first?.name == "zzz-treffer.txt")
    }

    @Test func dateDescendingShowsTheNewestHitFromBeyondTheFirstPage() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.sort = SearchSort(column: .date, direction: .descending)
        await app.runSearch()
        let first = try #require(app.searchMatch.items.first)
        #expect(first.name == "zzz-treffer.txt", "erste Zeile \(first.name)")
        #expect(app.searchMatch.items.count == SearchIndex.pageLimit)
    }

    @Test func nameDescendingShowsTheAlphabeticallyLastHit() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.sort = SearchSort(column: .name, direction: .descending)
        await app.runSearch()
        let names = displayedNames(app)
        try #require(names.count > 1)
        #expect(names.first == "zzz-treffer.txt", "erste Zeile \(names.first ?? "–")")
        #expect(names.dropFirst().first == "treffer-599.txt")
    }

    @Test func dateAscendingReachesTheOldestHit() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.sort = SearchSort(column: .date, direction: .ascending)
        await app.runSearch()
        #expect(app.searchMatch.items.first?.name == "treffer-599.txt")
    }

    @Test func pathSortFallsBackToNameWhenMoreHitsThanOnePage() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.sort = SearchSort(column: .path, direction: .ascending)
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 601)
        #expect(!app.searchMatch.allItemsOnPage)
        #expect(app.searchState.sort == SearchSort(), "Pfad-Sortierung über 500 Treffer muss auf Name zurückfallen")
    }

    @Test func pathSortStaysWhenAllHitsAreOnThePage() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.query = "treffer-1"
        app.searchState.submittedQuery = "treffer-1"
        app.searchState.sort = SearchSort(column: .path, direction: .descending)
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.allItemsOnPage)
        #expect(app.searchState.sort == SearchSort(column: .path, direction: .descending))
    }

    /// bug.0.4.092 (Nutzer 18.10., ersetzt REPORT 131): Medien erscheinen nur als Namenstreffer eines Suchbegriffs.
    /// Reine Filtersuche (nur „Ordner“, auch mit Medienauswahl) → keine Kacheln, die Tabelle zeigt die Ordner;
    /// Suchbegriff gleich dem Mediennamen → Kachel. Die Trefferzahl zählt nur Objekte.
    @Test func filterOnlySearchShowsNoMediumTiles() async throws {
        let (app, store) = try await sortRig()
        defer { app.prepareForTermination() }
        let second = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ZWEITES", type: .usb, decision: .index)
        try await store.upsertMedium(second)
        try await store.applyDirectories(
            mediumUUID: second.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: [ScannedEntry(name: "Ablage", isFolder: true)], finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: second.uuid, depth: 1)
        await app.loadStoredMedia()
        var folders = SearchFilters()
        folders.fileTypes = [.folder]
        let onlyFilter = await SearchIndex.matching(store: store, query: "", filters: folders, media: app.indexedMedia, maxDepth: nil)
        #expect(onlyFilter.media.isEmpty, "Kacheln bei reiner Filtersuche: \(onlyFilter.media.map(\.name))")
        #expect(onlyFilter.items.map(\.name) == ["Ablage"])
        #expect(onlyFilter.totalCount == 1)

        var chosen = folders
        chosen.selectAllMedia = false
        chosen.mediumIDs = [second.uuid]
        let withMedium = await SearchIndex.matching(store: store, query: "", filters: chosen, media: app.indexedMedia, maxDepth: nil)
        #expect(withMedium.media.isEmpty, "Kacheln bei Medienauswahl ohne Begriff: \(withMedium.media.map(\.name))")

        let byName = await SearchIndex.matching(store: store, query: "zweites", filters: SearchFilters(), media: app.indexedMedia, maxDepth: nil)
        #expect(byName.media.map(\.id) == [second.uuid])
    }

    /// REPORT 130: 600 Dateien `Rechnung_…` füllen die erste Seite; der Ordner „Rechnungen“ erscheint trotzdem.
    @Test func popoverShowsTheFolderGroupBehindManyFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-popovergroups-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "BUERO", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        var entries = (0..<600).map { ScannedEntry(name: String(format: "Rechnung_%03d.pdf", $0), isFolder: false, sizeBytes: 1) }
        entries.append(ScannedEntry(name: "Rechnungen", isFolder: true))
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: store)
        defer { app.prepareForTermination() }
        await app.loadStoredMedia()
        app.popoverSearchDebounce = .zero
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        await app.waitForPopoverSearch()
        let titles = app.popoverResults.groups.map(\.title)
        #expect(titles.contains(LayoutCopy.popoverGroupFolders), "Gruppen: \(titles)")
        #expect(titles.contains(LayoutCopy.popoverGroupFiles))
        let folders = try #require(app.popoverResults.groups.first { $0.title == LayoutCopy.popoverGroupFolders })
        #expect(folders.hits.map(\.title) == ["Rechnungen"])
        #expect(app.popoverResults.totalCount == 601)
        #expect(!app.popoverResults.isCountPending)
    }
}
}

extension WindowTestGroup {
/// Echtes Fenster außerhalb des Bildschirms (Regel 10/19): Klick per `window.sendEvent` auf den Spaltenkopf.
@Suite @MainActor
struct SearchSortHeaderWindowTests {
    private let size = CGSize(width: 1000, height: 500)

    /// bug.0.4.081: Kopfzellen aus der echten Inhaltsbreite (ohne Rollbalken im dauerhaften Stil, wie mit Maus);
    /// vorher aus der Fensterbreite – im dauerhaften Stil lag „Status“ 15 pt weiter links als angenommen.
    private func headerCell(_ column: SearchSortColumn, in window: NSWindow) -> ClosedRange<CGFloat> {
        let contentWidth = Self.tableScroll(in: window)?.contentView.bounds.width ?? size.width
        let widths = ObjectTableColumns.cellWidths(contentWidth: contentWidth - 2 * ObjectTableColumns.horizontalPadding)
        let index: Int
        switch column {
        case .name: index = 1
        case .date: index = 2
        case .medium: index = 3
        case .path: index = 4
        case .status: index = 5
        }
        let left = ObjectTableColumns.horizontalPadding + widths.prefix(index).reduce(0, +)
        // Regel 20: ohne ungeprüften Indexzugriff (es sind immer sechs Zellen).
        let width = widths.indices.contains(index) ? widths[index] : 0
        return left...(left + width)
    }

    /// Klickpunkt wie bisher: 12 pt hinter dem Textanfang, bei „Status“ (rechtsbündig) 12 pt vor dem rechten Rand.
    private func headerPoint(_ column: SearchSortColumn, in window: NSWindow) -> CGPoint {
        let cell = headerCell(column, in: window)
        let x = column == .status ? cell.upperBound - 12 : cell.lowerBound + 12
        // Kopfzeile: 10 pt Innenabstand oben, Schrift 12 pt.
        return CGPoint(x: x, y: 18)
    }

    static func tableScroll(in window: NSWindow) -> NSScrollView? {
        guard let root = window.contentView else { return nil }
        var best: NSScrollView?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView, scroll.frame.width * scroll.frame.height > (best.map { $0.frame.width * $0.frame.height } ?? 0) {
                best = scroll
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return best
    }

    private func open(_ app: AppState, dark: Bool = false, style: NSScroller.Style? = nil) async -> PixelProbe.Session {
        let session = PixelProbe.open(
            SearchView().environment(app).environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.scrollerStyleOverride, style)
                .frame(width: size.width, height: size.height).background(dark ? Color.black : Color.white),
            size: size,
            appearance: dark ? .darkAqua : .aqua
        )
        await PixelProbe.settleOpenWindow(session)
        return session
    }

    @Test func clickingTheDateHeaderQueriesAllHitsAgain() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        let session = await open(app)
        defer { session.close() }
        let loaded = await waitUntil(timeout: 10) { app.searchMatch.items.count == SearchIndex.pageLimit }
        try #require(loaded, "Suche im Fenster lief nicht")
        // todo.0.4.042: Start aus dem Leerzustand – die Tabelle steht erst nach dem Wartescreen (mindestens 1 s).
        try #require(await waitUntil(timeout: 10) { !app.searchLoading.isShowing }, "Wartescreen endet nicht")
        await PixelProbe.settleOpenWindow(session)
        #expect(app.searchMatch.items.first?.name == "treffer-000.txt")
        session.click(at: headerPoint(.date, in: session.window), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .date, direction: .ascending), "Klick hat nicht umgeschaltet")
        // Ältester Treffer liegt jenseits der ersten Namens-Seite: nur eine neue Abfrage bringt ihn nach oben.
        let resorted = await waitUntil(timeout: 10) { app.searchMatch.items.first?.name == "treffer-599.txt" }
        #expect(resorted, "erste Zeile nach Klick: \(app.searchMatch.items.first?.name ?? "–")")
    }

    /// Derselbe Klickpunkt schaltet bei höchstens 500 Treffern um (Beleg, dass er den Kopf trifft) und bei 601 nicht.
    @Test func thePathHeaderTogglesWithAllHitsOnThePageAndNotBeyond() async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.query = "treffer-1"
        app.searchState.submittedQuery = "treffer-1"
        let session = await open(app)
        defer { session.close() }
        let few = await waitUntil(timeout: 10) { app.searchMatch.itemCount == 100 }
        try #require(few, "Trefferzahl für „treffer-1“ kam nicht")
        // todo.0.4.042: Start aus dem Leerzustand – die Tabelle steht erst nach dem Wartescreen (mindestens 1 s).
        try #require(await waitUntil(timeout: 10) { !app.searchLoading.isShowing }, "Wartescreen endet nicht")
        await PixelProbe.settleOpenWindow(session)
        session.click(at: headerPoint(.path, in: session.window), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .path, direction: .ascending), "Klick traf den Kopf „Pfad“ nicht")
        session.click(at: headerPoint(.status, in: session.window), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .status, direction: .ascending), "Klick traf den Kopf „Status“ nicht")

        // Jetzt 601 Treffer: die Sortierung nach Status fällt auf Name zurück, dieselben Klicks schalten nicht um.
        app.searchState.query = "treffer"
        app.searchState.submittedQuery = "treffer"
        let many = await waitUntil(timeout: 10) { app.searchMatch.itemCount == 601 && app.searchState.sort == SearchSort() }
        try #require(many, "601 Treffer bzw. Rückfall auf Name kamen nicht: \(app.searchState.sort)")
        await PixelProbe.settleOpenWindow(session)
        session.click(at: headerPoint(.path, in: session.window), settle: 0.2)
        session.click(at: headerPoint(.status, in: session.window), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(), "deaktivierter Kopf hat umgeschaltet: \(app.searchState.sort)")
        // Gegenprobe am selben Fenster: der Kopf „Name“ bleibt klickbar.
        session.click(at: headerPoint(.name, in: session.window), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .name, direction: .descending))
    }

    /// bug.0.4.081: Jeder sortierbare Kopf schaltet an linkem Rand (+4 pt), Mitte und rechtem Rand (−4 pt) seiner
    /// Spalte (ganze Spaltenbreite klickbar), hell und dunkel; bug.0.4.100 a: im Stil dieses Rechners, dauerhaft und
    /// Overlay (fester Stil über `scrollerStyleOverride`).
    @Test(arguments: [false, true], [ScrollerStyleArgument.system, .legacy, .overlay])
    func everySortableHeaderTogglesAcrossItsWholeWidth(dark: Bool, style: ScrollerStyleArgument) async throws {
        let (app, _) = try await sortRig()
        defer { app.prepareForTermination() }
        app.searchState.query = "treffer-1"
        app.searchState.submittedQuery = "treffer-1"
        let session = await open(app, dark: dark, style: style.style)
        defer { session.close() }
        let few = await waitUntil(timeout: 10) { app.searchMatch.itemCount == 100 }
        try #require(few, "Trefferzahl für „treffer-1“ kam nicht")
        // todo.0.4.042: Start aus dem Leerzustand – die Tabelle steht erst nach dem Wartescreen (mindestens 1 s).
        try #require(await waitUntil(timeout: 10) { !app.searchLoading.isShowing }, "Wartescreen endet nicht")
        await PixelProbe.settleOpenWindow(session)
        var misses: [String] = []
        for column in [SearchSortColumn.name, .date, .medium, .path, .status] {
            let cell = headerCell(column, in: session.window)
            for (label, x) in [("links", cell.lowerBound + 4), ("Mitte", (cell.lowerBound + cell.upperBound) / 2), ("rechts", cell.upperBound - 4)] {
                let before = app.searchState.sort
                session.click(at: CGPoint(x: x, y: 18), settle: 0.15)
                let after = app.searchState.sort
                if after == before || after.column != column { misses.append("\(column) \(label) x=\(Int(x))") }
            }
        }
        #expect(misses.isEmpty, "nicht getroffen: \(misses)")
    }
}
}

extension WindowTestGroup {
/// bug.0.4.100 a: Kopf „Index“ der Speichermedien (rechtsbündig, Breite `RegistryTableLayout.indexingWidth`, gleicher
/// Baustein wie in `SettingsMediaRegistryPanel`) schaltet an linkem Rand (+4), Mitte und rechtem Rand (−4), im Stil
/// dieses Rechners, dauerhaft und Overlay.
@Suite @MainActor
struct RegistryIndexHeaderHitTests {
    @Test(arguments: [ScrollerStyleArgument.system, .legacy, .overlay])
    func indexHeaderTogglesAcrossItsWholeWidth(style: ScrollerStyleArgument) async throws {
        let counter = HitCounter()
        let width = RegistryTableLayout.indexingWidth
        let session = PixelProbe.open(
            HStack(spacing: 0) {
                Color.clear.frame(width: 20, height: 1)
                TableSortHeader(title: LayoutCopy.index, isActive: false, alignment: .trailing) { counter.hits += 1 }
                    .frame(width: width, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .environment(\.scrollerStyleOverride, style.style)
            .frame(width: 240, height: 40, alignment: .leading)
            .background(Color.white),
            size: CGSize(width: 240, height: 40)
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        var misses: [String] = []
        for (label, x) in [("links", 20 + 4), ("Mitte", 20 + width / 2), ("rechts", 20 + width - 4)] {
            let before = counter.hits
            session.click(at: CGPoint(x: x, y: 20), settle: 0.1)
            if counter.hits == before { misses.append("\(label) x=\(Int(x))") }
        }
        #expect(misses.isEmpty, "nicht getroffen: \(misses)")
    }
}
}

@MainActor
private final class HitCounter {
    var hits = 0
}

/// bug.0.4.100 a: Rollbalken-Stil als Testargument (`nil` = Stil dieses Rechners).
enum ScrollerStyleArgument: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case system, legacy, overlay

    var style: NSScroller.Style? {
        switch self {
        case .system: nil
        case .legacy: .legacy
        case .overlay: .overlay
        }
    }

    var testDescription: String { rawValue }
}

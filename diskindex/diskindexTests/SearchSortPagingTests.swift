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
private func naturalRig() async throws -> AppState {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-searchnatural-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
    let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ARCHIV", type: .usb, decision: .index)
    try await store.upsertMedium(medium)
    let entries = (1...30).map { ScannedEntry(name: "datei \($0).txt", isFolder: false, sizeBytes: 1) }
    try await store.applyDirectories(
        mediumUUID: medium.uuid,
        batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
        seenAt: Date()
    )
    try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
    let app = AppState(store: store)
    await app.loadStoredMedia()
    app.mainWindowDestination = .search
    app.searchState.query = "datei"
    app.searchState.submittedQuery = "datei"
    return app
}

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

    /// REPORT 131: ohne Begriff stammen die Kacheln aus allen Treffern, nicht aus der ersten Seite.
    @Test func mediumTilesCoverMediaBeyondTheFirstPage() async throws {
        let (app, store) = try await sortRig()
        defer { app.prepareForTermination() }
        let second = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ZWEITES", type: .usb, decision: .index)
        try await store.upsertMedium(second)
        try await store.applyDirectories(
            mediumUUID: second.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: [ScannedEntry(name: "zzz-ende.txt", isFolder: false, sizeBytes: 1)], finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: second.uuid, depth: 1)
        await app.loadStoredMedia()
        var filters = SearchFilters()
        filters.fileTypes = [.text]
        let match = await SearchIndex.matching(
            store: store, query: "", filters: filters, media: app.indexedMedia, maxDepth: nil, withCount: false
        )
        try #require(match.items.count == SearchIndex.pageLimit)
        #expect(!match.items.contains { $0.mediumID == second.uuid }, "Testvoraussetzung: zweites Medium nicht auf der Seite")
        #expect(match.media.contains { $0.id == second.uuid }, "Kachel des zweiten Mediums fehlt: \(match.media.map(\.name))")
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
        #expect(titles.contains("ORDNER"), "Gruppen: \(titles)")
        #expect(titles.contains("DATEIEN"))
        let folders = try #require(app.popoverResults.groups.first { $0.title == "ORDNER" })
        #expect(folders.hits.map(\.title) == ["Rechnungen"])
        #expect(app.popoverResults.totalCount == 601)
        #expect(!app.popoverResults.isCountPending)
    }
}

extension WindowTestGroup {
/// Echtes Fenster außerhalb des Bildschirms (Regel 10/19): Klick per `window.sendEvent` auf den Spaltenkopf.
@Suite @MainActor
struct SearchSortHeaderWindowTests {
    private let size = CGSize(width: 1000, height: 500)

    private func headerPoint(_ column: SearchSortColumn) -> CGPoint {
        let name = ObjectTableColumns(totalWidth: size.width).name
        let left = ObjectTableColumns.horizontalPadding + ObjectTableColumns.icon
        let x: CGFloat
        switch column {
        case .name: x = left + 12
        case .date: x = left + name + 12
        case .medium: x = left + name + ObjectTableColumns.date + 12
        case .path: x = left + name + ObjectTableColumns.date + ObjectTableColumns.medium + 12
        case .status: x = size.width - ObjectTableColumns.horizontalPadding - 12
        }
        // Kopfzeile: 10 pt Innenabstand oben, Schrift 12 pt.
        return CGPoint(x: x, y: 18)
    }

    private func open(_ app: AppState) async -> PixelProbe.Session {
        let session = PixelProbe.open(
            SearchView().environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height).background(Color.white),
            size: size,
            appearance: .aqua
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
        #expect(app.searchMatch.items.first?.name == "treffer-000.txt")
        session.click(at: headerPoint(.date), settle: 0.2)
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
        await PixelProbe.settleOpenWindow(session)
        session.click(at: headerPoint(.path), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .path, direction: .ascending), "Klick traf den Kopf „Pfad“ nicht")
        session.click(at: headerPoint(.status), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .status, direction: .ascending), "Klick traf den Kopf „Status“ nicht")

        // Jetzt 601 Treffer: die Sortierung nach Status fällt auf Name zurück, dieselben Klicks schalten nicht um.
        app.searchState.query = "treffer"
        app.searchState.submittedQuery = "treffer"
        let many = await waitUntil(timeout: 10) { app.searchMatch.itemCount == 601 && app.searchState.sort == SearchSort() }
        try #require(many, "601 Treffer bzw. Rückfall auf Name kamen nicht: \(app.searchState.sort)")
        await PixelProbe.settleOpenWindow(session)
        session.click(at: headerPoint(.path), settle: 0.2)
        session.click(at: headerPoint(.status), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(), "deaktivierter Kopf hat umgeschaltet: \(app.searchState.sort)")
        // Gegenprobe am selben Fenster: der Kopf „Name“ bleibt klickbar.
        session.click(at: headerPoint(.name), settle: 0.2)
        #expect(app.searchState.sort == SearchSort(column: .name, direction: .descending))
    }
}
}

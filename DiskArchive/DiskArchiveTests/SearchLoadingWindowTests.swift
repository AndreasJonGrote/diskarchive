//
//  SearchLoadingWindowTests.swift
//  DiskArchiveTests
//
//  todo.0.4.042: Start einer Suche aus dem Leerzustand → sofort der Wartescreen (Fläche von Layout 10.1, blauer Spinner
//  an der Stelle der Icons, Titel an der Stelle des Idle-Titels, Umfang der Suche), mindestens 1 s, dann die Treffer.
//  Verfeinern mit sichtbaren Treffern zeigt ihn nicht. Echtes Fenster außerhalb des Bildschirms, Pixel hell und dunkel.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct SearchLoadingWindowTests {
    private static let size = CGSize(width: 900, height: 560)
    /// Mittelstreifen der Fläche (Icons bzw. Spinner und Titel).
    private static let centerBand = CGRect(x: size.width / 2 - 60, y: 40, width: 120, height: size.height - 80)
    /// Breiter Streifen für den Titel.
    private static let titleBand = CGRect(x: 80, y: 40, width: size.width - 160, height: size.height - 80)

    @Test(arguments: [false, true])
    func searchFromTheEmptyStateShowsTheLoadingScreenThenTheHits(dark: Bool) async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = rig.app
        app.mainWindowDestination = .search
        let session = Self.open(app, dark: dark)
        defer { session.close() }

        // Leerzustand: zwei blaue Icons, darunter der Titel.
        let idle = await Self.settledBitmap(session)
        let idleIcons = try #require(ScopeLoadingPixels.bounds(idle, region: Self.centerBand, ScopeLoadingPixels.isBlue), "Icons der leeren Suche fehlen")
        let idleTitle = try #require(ScopeLoadingPixels.firstTextTop(idle, region: Self.titleBand, below: idleIcons.maxY + 2, dark: dark), "Idle-Titel fehlt")

        let started = ContinuousClock.now
        app.openSearch(withQuery: "rechnung")
        #expect(app.searchAwaitsFirstResults || app.searchLoading.isShowing, "Wartescreen nicht sofort")
        // Das nächste gezeichnete Bild (ohne Überblendung der Icons) zeigt den Spinner.
        let drawn = await waitUntil {
            guard let box = ScopeLoadingPixels.bounds(session.bitmap(), region: Self.centerBand, ScopeLoadingPixels.isBlue) else { return false }
            return box.width < 40
        }
        #expect(drawn, "Spinner wird nicht gezeichnet")
        let first = session.bitmap()
        let spinner = try #require(ScopeLoadingPixels.expectSpinner(first, region: Self.centerBand, ScopeLoadingPixels.isBlue, "erstes Bild"))
        #expect(abs(spinner.midY - idleIcons.midY) <= 2, "Spinner nicht an der Stelle der Icons: \(spinner.midY) statt \(idleIcons.midY)")
        let title = try #require(ScopeLoadingPixels.firstTextTop(first, region: Self.titleBand, below: idleIcons.maxY + 2, dark: dark), "Titel fehlt")
        #expect(abs(title - idleTitle) <= 1, "Titel nicht an der Stelle des Idle-Titels: \(title) statt \(idleTitle)")

        // Umfang: beide Medien, Summe ihrer Dateien.
        let expectedFiles = app.indexedMedia.reduce(0) { $0 + $1.fileCount }
        #expect(app.searchLoadingScope.media == 2 && app.searchLoadingScope.files == expectedFiles, "Umfang \(app.searchLoadingScope)")

        // Treffer kommen schnell, der Wartescreen bleibt trotzdem mindestens 1 s.
        let hits = await waitUntil { !app.searchMatch.items.isEmpty }
        try #require(hits, "keine Treffer")
        if started.duration(to: .now) < .milliseconds(900) {
            #expect(app.searchLoading.isShowing, "Wartescreen vor 1 s verschwunden")
        }
        let ended = await waitUntil(timeout: 5) { !app.searchLoading.isShowing }
        #expect(ended, "Wartescreen endet nicht")
        #expect(started.duration(to: .now) >= .seconds(1), "Wartescreen kürzer als 1 s")
        let gone = await waitUntil {
            ScopeLoadingPixels.bounds(session.bitmap(), region: CGRect(x: Self.size.width / 2 - 30, y: spinner.minY, width: 60, height: spinner.height), ScopeLoadingPixels.isBlue) == nil
        }
        #expect(gone, "Spinner nach dem Ende noch sichtbar")
    }

    /// bug.0.4.197 b: Mindestdauer – die Treffer sind da (positives Signal), der Wartescreen steht trotzdem bis zum Ende
    /// der Mindestdauer (hier 5 s, damit die Messung nicht an der Dauer der Prüfung hängt).
    @Test func loadingScreenOutlastsFastHitsUntilTheMinimum() async throws {
        let rig = try await Self.makeRig(loadingMinimum: .seconds(5))
        defer { rig.close() }
        let app = rig.app
        app.mainWindowDestination = .search
        let session = Self.open(app, dark: false)
        defer { session.close() }
        let started = ContinuousClock.now
        app.openSearch(withQuery: "rechnung")
        let hits = await waitUntil(timeout: 4) { !app.searchMatch.items.isEmpty }
        try #require(hits, "keine Treffer")
        try #require(started.duration(to: .now) < .seconds(4), "Treffer zu spät für die Messung")
        #expect(app.searchLoading.isShowing, "Wartescreen vor der Mindestdauer verschwunden")
        app.searchLoading.cancel()
    }

    /// Medienfilter auf ein Medium: Umfang nur dieses Medium (Einzahl), seine Dateien.
    @Test func mediumFilterNarrowsTheScope() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = rig.app
        let one = try #require(app.indexedMedia.first)
        // Filter gehören zur Ansicht (ein Wechsel leert sie): erst die Suche öffnen, dann filtern.
        app.mainWindowDestination = .search
        app.searchState.filters.selectAllMedia = false
        app.searchState.filters.mediumIDs = [one.id]
        app.openSearch(withQuery: "rechnung")
        #expect(app.searchAwaitsFirstResults || app.searchLoading.isShowing)
        #expect(app.searchLoadingScope.media == 1 && app.searchLoadingScope.files == one.fileCount, "Umfang \(app.searchLoadingScope)")
        L10n.$languageOverride.withValue(.german) {
            let title = LayoutCopy.loadingSearchTitle(media: 1, files: one.fileCount)
            #expect(title.hasPrefix("Dein 1 Speichermedium und "), "\(title)")
        }
        _ = await waitUntil(timeout: 5) { !app.searchLoading.isShowing }
    }

    /// Verfeinern bei sichtbaren Treffern: kein Wartescreen, die alten Treffer bleiben bis zu den neuen.
    @Test func refiningWithVisibleHitsShowsNoLoadingScreen() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = rig.app
        app.openSearch(withQuery: "rechnung")
        let session = Self.open(app, dark: false)
        defer { session.close() }
        let shown = await waitUntil(timeout: 5) { !app.searchLoading.isShowing && !app.searchMatch.items.isEmpty }
        try #require(shown, "Voraussetzung: Treffer sichtbar")
        var sawLoading = false
        app.searchState.query = "rech"
        app.searchState.submittedQuery = "rech"
        let refined = await waitUntil(timeout: 5) {
            if app.searchLoading.isShowing || app.searchAwaitsFirstResults { sawLoading = true }
            return app.shownSearch?.query == "rech" && !app.searchState.isSearchInProgress
        }
        try #require(refined, "Verfeinerte Suche nicht abgeschlossen")
        #expect(!sawLoading, "Wartescreen beim Verfeinern")
        #expect(!app.searchMatch.items.isEmpty)
    }

    /// Selbstprüfung 23: Steht „Keine Treffer“, startet eine erneute Suche mit derselben Treffermenge (Live-Meldung,
    /// neues Medium, Sortierklick) keinen Wartescreen.
    @Test func rerunWithTheSameHitsShowsNoLoadingScreen() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = rig.app
        app.openSearch(withQuery: "gibtesnicht")
        await app.runSearch()
        let settled = await waitUntil(timeout: 5) { !app.searchLoading.isShowing }
        try #require(settled && app.searchMatch.items.isEmpty && app.shownSearch?.query == "gibtesnicht", "Voraussetzung: „Keine Treffer“ steht")
        let rerun = Task { await app.runSearch() }
        var sawLoading = false
        let done = await waitUntil(timeout: 5) {
            if app.searchLoading.isShowing || app.searchAwaitsFirstResults { sawLoading = true }
            return !app.searchState.isSearchInProgress
        }
        await rerun.value
        try #require(done)
        #expect(!sawLoading, "Wartescreen bei gleicher Treffermenge")
        #expect(!app.searchLoading.isShowing)
    }

    /// Selbstprüfung 23: X im Suchfeld bei aktivem Filter (Anfrage bleibt gleich, keine neue Suche) → kein endloser
    /// Wartescreen.
    @Test func clearingTheFieldWithActiveFiltersLeavesNoEndlessLoadingScreen() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = rig.app
        app.mainWindowDestination = .search
        app.searchState.filters.age = .last24Hours
        await app.runSearch()
        try #require(app.shownSearch != nil, "Voraussetzung: Suche über den Filter abgeschlossen")
        app.searchState.query = "ungesendet"
        app.clearObjectSearch()
        #expect(!app.searchAwaitsFirstResults, "Wartescreen nach dem Leeren hängt")
        #expect(!app.searchLoading.isShowing)
    }

    // MARK: - Hilfen

    @MainActor
    private struct Rig {
        let app: AppState
        let database: TestDatabase
        let directory: URL
        func close() {
            app.prepareForTermination()
            try? database.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func makeRig(loadingMinimum: Duration = .seconds(1)) async throws -> Rig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-search-loading-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        for (name, files) in [("Archiv", ["rechnung-1.pdf", "rechnung-2.pdf", "brief.txt"]), ("Backup", ["rechnung-3.pdf"])] {
            var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: name, decision: .index, indexStatus: .indexed, completedDepth: 3)
            try await store.upsertMedium(medium)
            medium = try #require(try await store.medium(uuid: medium.uuid))
            let entries = files.map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
            try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        }
        let app = AppState(loadingMinimum: loadingMinimum)
        app.attach(store: store)
        await app.loadStoredMedia()
        try #require(app.indexedMedia.count == 2, "Voraussetzung: zwei erfasste Medien")
        // Dateizahlen fest setzen (die Zähler des Speichers sind hier nicht Gegenstand).
        for (index, medium) in app.indexedMedia.enumerated() {
            app.updateMedium(id: medium.id) { $0.fileCount = index == 0 ? 3 : 1 }
        }
        return Rig(app: app, database: database, directory: directory)
    }

    private static func open(_ app: AppState, dark: Bool) -> PixelProbe.Session {
        PixelProbe.open(
            SearchView()
                .environment(app)
                .environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.spinnerFrozenAngle, 0)
                .frame(width: size.width, height: size.height)
                .background(DesignColor.bg),
            size: size,
            appearance: dark ? .darkAqua : .aqua
        )
    }

    private static func settledBitmap(_ session: PixelProbe.Session) async -> NSBitmapImageRep {
        _ = await waitUntil {
            ScopeLoadingPixels.bounds(session.bitmap(), region: centerBand, ScopeLoadingPixels.isBlue) != nil
        }
        return session.bitmap()
    }
}
}

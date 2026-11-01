//
//  SearchBehaviorTests.swift
//  DiskArchiveTests
//
//  Aufgabe 211 b/c — kein Flackern, gedrosselte Live-Suche, X leert Feld und Suche.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite @MainActor
struct SearchBehaviorTests {
    private func appWithResults() async throws -> (AppState, StoredMedium) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-searchbehavior-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "SUCHE", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let entries = (0..<30).map { ScannedEntry(name: "bericht-\($0).pdf", isFolder: false, sizeBytes: 1) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.mainWindowDestination = .search
        app.searchState.query = "bericht"
        app.searchState.submittedQuery = "bericht"
        return (app, medium)
    }

    @Test func supersededSearchClearsProgressFlag() async throws {
        let (app, _) = try await appWithResults()
        await app.indexStore?.setSearchQueryDelay(.milliseconds(200))
        let slow = Task { await app.runSearch() }
        // bug.0.3.8.007: statt fester 30 ms warten, bis die langsame Suche läuft (Abfrage hält 200 ms).
        let inProgress = await waitUntil { app.searchState.isSearchInProgress }
        #expect(inProgress)
        await app.runSearch()
        await slow.value
        #expect(!app.searchState.isSearchInProgress)
        await app.indexStore?.setSearchQueryDelay(nil)
    }

    @Test func oldResultsStayVisibleWhileTheNextSearchRuns() async throws {
        let (app, _) = try await appWithResults()
        await app.runSearch()
        try #require(!app.searchMatch.items.isEmpty)
        let task = Task { await app.runSearch() }
        await Task.yield()
        #expect(!app.searchMatch.items.isEmpty, "die alten Ergebnisse wurden vor der neuen Suche geleert")
        await task.value
        #expect(!app.searchMatch.items.isEmpty)
    }

    @Test func liveMessagesRestartTheSearchAtMostEveryTwoSeconds() async throws {
        let (app, medium) = try await appWithResults()
        app.updateMedium(id: medium.uuid) { $0.indexStatus = .indexing }
        try #require(app.media.contains { $0.indexStatus == .indexing })
        let before = app.searchGeneration
        let started = ContinuousClock.now
        for _ in 0..<20 {
            await app.runSearchAfterLiveChange()
            try await Task.sleep(for: .milliseconds(40))
        }
        let restarts = app.searchGeneration - before
        // bug.0.3.8.007: Die erlaubte Zahl folgt aus der gemessenen Dauer der Schleife statt aus „unter 1 s“:
        // der erste Neustart sofort, danach höchstens einer je volle 2 s. Erst nach `restarts` messen, damit ein
        // gerade feuernder Nachlauf nie mehr Neustarts als erlaubt ergibt.
        let elapsed = started.duration(to: .now)
        let allowed = 1 + Int(elapsed / .seconds(2))
        #expect(restarts >= 1, "die erste Live-Meldung muss die Suche sofort neu starten")
        #expect(restarts <= allowed, "\(restarts) Neustarts in \(elapsed), erlaubt \(allowed)")
        app.prepareForTermination()
    }

    /// bug.0.3.9.003: Eine direkte Suche bricht den ausstehenden Nachlauf der Live-Suche ab (keine zweite Suche),
    /// bug.0.3.9.014 b: schon beim Start, nicht erst nach den Ergebnissen. Der Abstand (3 s) misst keine Laufzeit,
    /// er ist nur das Fenster, in dem der Nachlauf aussteht; groß gewählt, damit eine Suche unter Last ihn nicht
    /// überholt.
    @Test func directSearchCancelsThePendingLiveSearch() async throws {
        let (app, medium) = try await appWithResults()
        app.updateMedium(id: medium.uuid) { $0.indexStatus = .indexing }
        try #require(app.media.contains { $0.indexStatus == .indexing })
        let interval = Duration.seconds(3)
        try await AppState.$liveSearchIntervalForTesting.withValue(interval) {
            // Letzte Live-Suche „eben“: die nächste Live-Meldung plant den Nachlauf (unabhängig von der Suchdauer).
            app.lastLiveSearchAt = .now
            await app.runSearchAfterLiveChange()
            try #require(app.trailingLiveSearch != nil, "Live-Meldung innerhalb des Abstands plant den Nachlauf")
            let before = app.searchGeneration
            // Langsame Abfrage: solange die Direktsuche läuft, ist der Nachlauf schon abgebrochen.
            await app.indexStore?.setSearchQueryDelay(.seconds(1))
            let direct = Task { await app.runSearch() }
            let running = await waitUntil(timeout: 3) { app.searchState.isSearchInProgress }
            #expect(running, "Direktsuche lief nicht an")
            #expect(app.trailingLiveSearch == nil, "Direktsuche bricht den Nachlauf erst nach den Ergebnissen ab")
            await direct.value
            await app.indexStore?.setSearchQueryDelay(nil)
            #expect(app.searchGeneration == before + 1)
            #expect(app.trailingLiveSearch == nil, "Direktsuche bricht den Nachlauf ab")
            // Über die Nachlaufzeit hinaus warten (Abstand + 1 s; die Suche selbst lief schon 1 s davon) und erneut
            // zählen.
            try await Task.sleep(for: interval + .seconds(1))
            #expect(app.searchGeneration == before + 1, "Nachlauf lief trotzdem: \(app.searchGeneration - before) Suchen")
        }
        app.prepareForTermination()
    }

    /// bug.0.3.9.003 (Nachprüfung): Ein reiner Sortierklick zählt nicht neu und lässt den Nachlauf stehen, damit die
    /// Zahl nach der Live-Änderung nachkommt.
    @Test func sortOnlyClickKeepsThePendingLiveSearch() async throws {
        let (app, medium) = try await appWithResults()
        await app.runSearch()
        await app.waitForSearchCount()
        try #require(app.searchMatch.itemCount != nil)
        app.updateMedium(id: medium.uuid) { $0.indexStatus = .indexing }
        let interval = Duration.milliseconds(500)
        try await AppState.$liveSearchIntervalForTesting.withValue(interval) {
            app.lastLiveSearchAt = .now
            await app.runSearchAfterLiveChange()
            try #require(app.trailingLiveSearch != nil)
            let before = app.searchGeneration
            app.searchState.sort = SearchSort(column: .date)
            await app.runSearch()
            #expect(app.searchGeneration == before + 1)
            #expect(app.trailingLiveSearch != nil, "Sortierklick darf den Nachlauf nicht abbrechen")
            let trailed = await waitUntil(timeout: 10) { app.searchGeneration >= before + 2 }
            #expect(trailed, "Nachlauf lief nach dem Sortierklick nicht")
        }
        app.prepareForTermination()
    }

    @Test func emptyPopoverFieldShowsNoResultsEvenWithMainSearchFilters() async throws {
        let (app, _) = try await appWithResults()
        app.popoverSearchText = "bericht"
        app.schedulePopoverSearch()
        let found = await waitUntil(timeout: 5) { app.popoverResults.totalCount > 0 }
        #expect(found)
        app.searchState.filters.fileTypes = [.pdf]
        app.popoverSearchText = ""
        app.schedulePopoverSearch()
        #expect(app.popoverResults.totalCount == 0)
        #expect(app.popoverResults.groups.isEmpty)
    }

    @Test func clearButtonEmptiesFieldAndSearch() async throws {
        let (app, _) = try await appWithResults()
        await app.runSearch()
        try #require(!app.searchMatch.items.isEmpty)

        struct Host: View {
            @FocusState private var focused: Bool
            var body: some View {
                MainWindowToolbar(
                    searchQuery: AppStateBindingBox.binding,
                    isSearchFocused: $focused,
                    onSearchSubmit: {}
                )
            }
        }
        AppStateBindingBox.app = app
        let size = CGSize(width: 900, height: 52)
        let session = PixelProbe.open(
            Host().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        // X: rechts im Suchfeld (Toolbar-Rand 16 + Feldrand 6 + halbe Knopfbreite 7).
        let point = CGPoint(x: size.width - 16 - 6 - 7, y: size.height / 2)
        session.clickThroughHitTest(at: point, settle: 0.3)
        #expect(app.searchState.query.isEmpty)
        #expect(app.searchState.submittedQuery.isEmpty)
        #expect(app.searchMatch.items.isEmpty)
    }
}
}

@MainActor
private enum AppStateBindingBox {
    static var app: AppState?
    static var binding: Binding<String> {
        Binding(
            get: { app?.searchState.query ?? "" },
            set: { app?.searchState.query = $0 }
        )
    }
}

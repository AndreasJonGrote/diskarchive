//
//  SearchBehaviorTests.swift
//  diskindexTests
//
//  Aufgabe 211 b/c — kein Flackern, gedrosselte Live-Suche, X leert Feld und Suche.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct SearchBehaviorTests {
    private func appWithResults() async throws -> (AppState, StoredMedium) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-searchbehavior-\(UUID().uuidString)", isDirectory: true)
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
        try await Task.sleep(for: .milliseconds(30))
        #expect(app.searchState.isSearchInProgress)
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
        for _ in 0..<20 {
            await app.runSearchAfterLiveChange()
            try await Task.sleep(for: .milliseconds(40))
        }
        let restarts = app.searchGeneration - before
        #expect(restarts <= 1, "\(restarts) Neustarts in unter 1 s")
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

//
//  ColumnAndSearchTests.swift
//  DiskArchiveTests
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor struct ColumnAndSearchTests {
    @Test func rootColumnOrdersFoldersBeforeFiles() async throws {
        let rig = try await seededTree()
        let names = await rig.app.indexRepository.loadChildren(mediumID: rig.medium.uuid, path: []).map(\.name)
        #expect(names == ["Alpha", "Beta", "readme.txt"])
    }

    @Test func openingAFolderShowsItsChildren() async throws {
        let rig = try await seededTree()
        let names = await rig.app.indexRepository.loadChildren(mediumID: rig.medium.uuid, path: ["Alpha"]).map(\.name)
        #expect(names == ["a.txt", "Inner"]) // Spalten sind gemischt natürlich sortiert (Aufgabe 232)
    }

    @Test func folderAtScanBoundaryIsUncapturedWhileRowsRemain() async throws {
        let rig = try await seededTree()
        // Vor Scope-Wechsel: Zeile muss existieren (scanDepth löst Rule-Reconcile aus → status kann wechseln).
        #expect(try await rig.store.storedNames().contains("deep.txt"))
        rig.app.appSettings.scanDepth = 2
        #expect(rig.app.appSettings.isFolderContentUncaptured(columnIndex: 1, completedDepth: rig.medium.completedDepth))
        #expect(!rig.app.appSettings.isFolderContentUncaptured(columnIndex: 0, completedDepth: 3))
        let deep = await rig.app.indexRepository.loadChildren(mediumID: rig.medium.uuid, path: ["Alpha", "Inner"]).map(\.name)
        #expect(deep.isEmpty)
        // Zeilen bleiben (sichtbar oder toDelete nach Reconcile) — bug.0.4.044 Parallel-Race.
        let stillPresent = try await rig.store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE name = ?", arguments: ["deep.txt"]) ?? 0
        }
        #expect(stillPresent >= 1)
    }

    @Test func aNewBatchAppearsWithoutReopening() async throws {
        let rig = try await seededTree()
        defer { rig.app.prepareForTermination() }
        rig.app.startChangeLoop()
        let session = openColumnWindow(app: rig.app, mediumID: rig.medium.uuid)
        defer { session.close() }
        // Die offene Spalte lädt selbst; erst wenn sie gefüllt ist, kommt die Änderung über den Store.
        let first = await waitUntil {
            rig.app.indexRepository.children(mediumID: rig.medium.uuid, path: []).map(\.name).contains("readme.txt")
        }
        try #require(first)
        let root = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let alpha = try #require(root.first { $0.name == "Alpha" })
        let beta = try #require(root.first { $0.name == "Beta" })
        try await rig.store.applyDirectory(
            mediumUUID: rig.medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "Alpha", isFolder: true),
                ScannedEntry(name: "Beta", isFolder: true),
                ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4),
                ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 2),
            ],
            seenAt: Date()
        )
        _ = alpha
        _ = beta
        let appeared = await waitUntil(timeout: 30) {
            rig.app.indexRepository.children(mediumID: rig.medium.uuid, path: []).map(\.name).contains("neu.txt")
        }
        #expect(appeared)
    }

    @Test func objectFavoriteSurvivesRestart() async throws {
        let rig = try await seededTree()
        let root = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let file = try #require(root.first { $0.name == "readme.txt" })
        try await rig.store.setFavorite(itemID: file.id, true)
        let reopened = IndexStoreV3(database: rig.database)
        let favorites = try await reopened.favorites()
        #expect(favorites.contains { $0.name == "readme.txt" && $0.isFavorite })
    }

    @Test func searchFindsRechnungAndSkipsRemoved() async throws {
        let rig = try await searchFixture()
        let match = await SearchIndex.matching(
            store: rig.store,
            query: "rechn",
            filters: SearchFilters(),
            media: rig.app.registryMedia,
            maxDepth: nil
        )
        let names = Set(match.items.map(\.name))
        #expect(names.contains("Rechnung.pdf"))
        #expect(!names.contains("weg.pdf"))
        #expect(match.itemCount == names.count)
    }

    @Test func swiftAndSQLFiltersAgree() async throws {
        let rig = try await searchFixture()
        var filters = SearchFilters()
        filters.fileTypes = [.pdf]
        filters.age = .lastYear
        filters.combineWithAnd = true
        let andIDs = try await ids(store: rig.store, query: "", filters: filters, maxDepth: nil)
        let andSwift = try await swiftIDs(store: rig.store, medium: rig.medium.uuid, query: "", filters: filters, maxDepth: nil)
        #expect(andIDs == andSwift)
        filters.combineWithAnd = false
        let orIDs = try await ids(store: rig.store, query: "", filters: filters, maxDepth: nil)
        let orSwift = try await swiftIDs(store: rig.store, medium: rig.medium.uuid, query: "", filters: filters, maxDepth: nil)
        #expect(orIDs == orSwift)
        #expect(andIDs.isSubset(of: orIDs))
        #expect(andIDs != orIDs)
    }

    @Test func loweredScanDepthHidesDeeperHits() async throws {
        let rig = try await searchFixture()
        let deep = await SearchIndex.matching(store: rig.store, query: "deep", filters: SearchFilters(), media: rig.app.registryMedia, maxDepth: 2)
        #expect(deep.items.isEmpty)
        let all = await SearchIndex.matching(store: rig.store, query: "deep", filters: SearchFilters(), media: rig.app.registryMedia, maxDepth: nil)
        #expect(all.items.map(\.name) == ["deep.txt"])
    }

    @Test func popoverCountMatchesSearch() async throws {
        let rig = try await searchFixture()
        let match = await SearchIndex.matching(store: rig.store, query: "rechn", filters: SearchFilters(), media: rig.app.registryMedia, maxDepth: nil)
        let popover = PopoverSearch.grouped(match: match, media: rig.app.registryMedia)
        #expect(popover.totalCount == match.totalCount)
        #expect(popover.groups.contains { $0.title == LayoutCopy.popoverGroupFiles })
        // bug.0.4.038/039: der Popover-Weg (eigene Abfragen je Gruppe, Zahl nachgereicht) kommt auf dieselbe Zahl.
        rig.app.popoverSearchDebounce = .zero
        rig.app.popoverSearchText = "rechn"
        rig.app.schedulePopoverSearch()
        await rig.app.waitForPopoverSearch()
        #expect(rig.app.popoverResults.totalCount == match.totalCount)
        #expect(!rig.app.popoverResults.isCountPending)
    }

    @Test func favoritesSurviveANewStore() async throws {
        let rig = try await searchFixture()
        let rows = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let file = try #require(rows.first { $0.name == "Rechnung.pdf" })
        try await rig.store.setFavorite(itemID: file.id, true)
        let again = IndexStoreV3(database: rig.database)
        rig.app.attach(store: again)
        await rig.app.reloadFavorites()
        #expect(rig.app.favoriteObjects.contains { $0.name == "Rechnung.pdf" })
    }
}
}

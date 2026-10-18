//
//  NaturalSearchOrderTests.swift
//  diskindexTests
//
//  bug.0.4.077: Die Datenbank wählt die Trefferseiten nach Name natürlich aus (Suchhilfe `items_search_natural`,
//  eigene Migration), nicht mehr binär mit Nachsortieren nur innerhalb der Seite. Bei 600 Treffern `Rechnung 1` …
//  `Rechnung 600` beginnt die erste Seite mit 1, 2, 3 … (nicht 1, 10, 100), absteigend mit 600, 599 …; nach Medium
//  sortiert auch innerhalb eines Mediums über die Seitengrenze. Folgeseiten (Cursor) passen zur ersten Seite.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

/// Ein Speicher mit je `count` Dateien `Rechnung 1.pdf` … `Rechnung <count>.pdf` je Medium, eingefügt in
/// gemischter Reihenfolge (damit die Kennung nichts über die Ordnung verrät).
@MainActor
private func invoiceRig(media names: [String], count: Int, hidden: [Int] = []) async throws -> (app: AppState, store: IndexStoreV3, media: [StoredMedium]) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-natural-order-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
    var media: [StoredMedium] = []
    for (index, name) in names.enumerated() {
        let hiddenCount = index < hidden.count ? hidden[index] : 0
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: name, type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        var entries = (1...count).map { ScannedEntry(name: "Rechnung \($0).pdf", isFolder: false, sizeBytes: 1) }
        if hiddenCount > 0 {
            entries += (1...hiddenCount).map { ScannedEntry(name: ".Rechnung \($0).pdf", isFolder: false, sizeBytes: 1) }
        }
        entries.shuffle()
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        media.append(medium)
    }
    let app = AppState(store: store)
    await app.loadStoredMedia()
    app.mainWindowDestination = .search
    app.searchState.query = "rechnung"
    app.searchState.submittedQuery = "rechnung"
    return (app, store, media)
}

private func invoices(_ numbers: some Sequence<Int>) -> [String] {
    numbers.map { "Rechnung \($0).pdf" }
}

/// Genaue Indexnamen aus `EXPLAIN QUERY PLAN` (Wort nach „INDEX“), damit `items_search` nicht auch
/// `items_search_natural` trifft (bug.0.4.077).
func planIndexNames(_ detail: String) -> Set<String> {
    let words = detail.split { $0 == " " || $0 == "|" || $0 == "(" || $0 == ")" }.map(String.init)
    var names = Set<String>()
    for (index, word) in words.enumerated() where word == "INDEX" && index + 1 < words.count {
        names.insert(words[index + 1])
    }
    return names
}

extension MeasurementTestGroup {
@Suite(.serialized) @MainActor
struct NaturalSearchOrderTests {
    /// Angezeigte Reihenfolge wie in `SearchView`.
    private func displayedRows(_ app: AppState) -> [SearchResultItem] {
        ObjectResultsOrdering.rows(
            app.searchMatch.items,
            sort: app.searchState.sort,
            serverSortedColumns: SearchSort.pageOrderedColumns,
            clientSortAvailable: app.searchMatch.allItemsOnPage,
            mediumNames: [:]
        )
    }

    @Test func nameAscendingFirstPageStartsWithOneTwoThree() async throws {
        let (app, store, _) = try await invoiceRig(media: ["ARCHIV"], count: 600)
        defer { app.prepareForTermination() }
        // Datenbank: genau die natürlich ersten 500.
        let hits = try await store.search(query: "rechnung", filters: SearchFilters(), limit: SearchIndex.pageLimit)
        #expect(hits.map(\.name) == invoices(1...500), "Anfang: \(hits.prefix(4).map(\.name))")
        // Anzeige: dieselbe Reihenfolge.
        await app.runSearch()
        let names = displayedRows(app).map(\.name)
        #expect(names == invoices(1...500), "Anfang: \(names.prefix(4))")
    }

    @Test func nameDescendingFirstPageStartsWithSixHundred() async throws {
        let (app, store, _) = try await invoiceRig(media: ["ARCHIV"], count: 600)
        defer { app.prepareForTermination() }
        let sort = SearchSort(column: .name, direction: .descending)
        let hits = try await store.search(query: "rechnung", filters: SearchFilters(), limit: SearchIndex.pageLimit, sort: sort)
        #expect(hits.map(\.name) == invoices((101...600).reversed()), "Anfang: \(hits.prefix(4).map(\.name))")
        app.searchState.sort = sort
        await app.runSearch()
        let names = displayedRows(app).map(\.name)
        #expect(names == invoices((101...600).reversed()), "Anfang: \(names.prefix(4))")
    }

    /// Zwei Medien mit je 300 Treffern: Die Seite (500) endet im zweiten Medium bei „Rechnung 200“, nicht bei einer
    /// binär ausgewählten Menge („1, 10, 100 …“).
    @Test func mediumSortIsNaturalAcrossThePageBoundary() async throws {
        let (app, _, media) = try await invoiceRig(media: ["ARCHIV", "BACKUP"], count: 300)
        defer { app.prepareForTermination() }
        let archive = try #require(media.first?.uuid)
        let backup = try #require(media.last?.uuid)
        for (direction, first, second) in [(SortDirection.ascending, archive, backup), (.descending, backup, archive)] {
            app.searchState.sort = SearchSort(column: .medium, direction: direction)
            await app.runSearch()
            let rows = displayedRows(app)
            try #require(rows.count == SearchIndex.pageLimit, "\(direction): \(rows.count) Zeilen")
            #expect(rows.prefix(300).allSatisfy { $0.mediumID == first }, "\(direction)")
            #expect(rows.dropFirst(300).allSatisfy { $0.mediumID == second }, "\(direction)")
            #expect(rows.prefix(300).map(\.name) == invoices(1...300), "\(direction): \(rows.prefix(4).map(\.name))")
            #expect(rows.dropFirst(300).map(\.name) == invoices(1...200), "\(direction): \(rows.dropFirst(300).prefix(4).map(\.name))")
        }
    }

    /// Ausstehende Bereinigung (`checksNames`): versteckte Treffer stehen natürlich vorn, die sichtbaren kommen über
    /// den Cursor der Folgeseiten. Ohne Lücken und Doppelte genau `Rechnung 1` … `Rechnung 500`.
    @Test func cursorPagesFollowTheNaturalOrder() async throws {
        let (app, store, _) = try await invoiceRig(media: ["ARCHIV"], count: 600, hidden: [150])
        defer { app.prepareForTermination() }
        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: false),
            checksNames: true
        )
        let hits = try await store.search(query: "rechnung", filters: SearchFilters(), limit: SearchIndex.pageLimit, scope: scope)
        let names = hits.map(\.name)
        #expect(Set(names).count == names.count, "Doppelte")
        #expect(names == invoices(1...500), "Anfang: \(names.prefix(4)), Ende: \(names.suffix(2))")
    }

    /// Gleiche Namen in zwei Medien genau an der Seitengrenze: 151 versteckte + 2 × 174 sichtbare + das erste
    /// „Rechnung 175“ füllen die erste Cursor-Seite (500). Das zweite „Rechnung 175“ kommt nur über den Zweig
    /// `slug = ? AND id > ?`; danach geht es mit „Rechnung 176“ weiter.
    @Test func cursorKeepsEqualNamesAtThePageBoundary() async throws {
        let (app, store, media) = try await invoiceRig(media: ["ARCHIV", "BACKUP"], count: 300, hidden: [151, 0])
        defer { app.prepareForTermination() }
        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: false),
            checksNames: true
        )
        let hits = try await store.search(query: "rechnung", filters: SearchFilters(), limit: SearchIndex.pageLimit, scope: scope)
        #expect(Set(hits.map(\.id)).count == hits.count, "Doppelte")
        #expect(hits.map(\.name) == (1...250).flatMap { invoices([$0, $0]) }, "um 175: \(hits.dropFirst(346).prefix(6).map(\.name))")
        let mediaAt175 = Set(hits.filter { $0.name == "Rechnung 175.pdf" }.map(\.mediumUUID))
        #expect(mediaAt175 == Set(media.map(\.uuid)), "Rechnung 175 nicht aus beiden Medien")
    }

    @Test func nameQueriesUseTheNaturalIndexWithoutSorting() async throws {
        let (app, store, _) = try await invoiceRig(media: ["ARCHIV"], count: 20)
        defer { app.prepareForTermination() }
        let natural = IndexStoreV3.naturalCollation
        let plans: [(String, String)] = try await store.pool.read { db in
            let plan = try SearchPlanV3.make(db, query: "rechnung", filters: SearchFilters(), maxDepth: nil)
            func detail(_ sql: String, _ extra: [DatabaseValue]) throws -> String {
                try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN " + sql, arguments: plan.statementArguments(extra: extra))
                    .map { (row: Row) -> String in row["detail"] }.joined(separator: " | ")
            }
            let page = [500.databaseValue, 0.databaseValue]
            return [
                ("erste Seite", try detail(IndexStoreV3.searchHitsSQL(whereClause: plan.whereClause), [500.databaseValue])),
                ("Name auf", try detail(IndexStoreV3.searchSortedHitsSQL(whereClause: plan.whereClause, sort: SearchSort()), page)),
                (
                    "Name ab",
                    try detail(IndexStoreV3.searchSortedHitsSQL(whereClause: plan.whereClause, sort: SearchSort(column: .name, direction: .descending)), page)
                ),
                (
                    "Folgeseite",
                    try detail(
                        "SELECT i.id, i.slug FROM items i WHERE \(plan.whereClause) AND i.slug COLLATE \(natural) > ? ORDER BY i.slug COLLATE \(natural), i.id LIMIT ?",
                        ["rechnung 1.pdf".databaseValue, 500.databaseValue]
                    )
                ),
            ]
        }
        for (label, detail) in plans {
            #expect(planIndexNames(detail).contains("items_search_natural"), "\(label): \(detail)")
            #expect(!detail.contains("TEMP B-TREE FOR ORDER BY"), "\(label): \(detail)")
        }
    }

    /// Eigene Migration (Regel 27, nur Erweiterung): Index auf `slug` mit Sortierfolge „natural“ und `status`.
    @Test func migrationAddsTheNaturalSearchIndex() async throws {
        let (app, store, _) = try await invoiceRig(media: ["ARCHIV"], count: 1)
        defer { app.prepareForTermination() }
        let (applied, columns): ([String], [String]) = try await store.pool.read { db in
            let applied = try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
            let columns = try Row.fetchAll(db, sql: "PRAGMA index_xinfo(items_search_natural)")
                .filter { ($0["key"] as Int) == 1 }
                .map { "\($0["name"] as String? ?? "-") \($0["coll"] as String? ?? "-")" }
            return (applied, columns)
        }
        #expect(applied.last == SchemaV3.itemsSearchNaturalMigration, "\(applied)")
        #expect(applied.contains(SchemaV3.itemsGoneMigration) && applied.contains(SchemaV3.firstMigration))
        #expect(columns == ["slug natural", "status BINARY"], "\(columns)")
        #expect(SchemaV3.indexNames.contains("items_search_natural"))
    }
}
}

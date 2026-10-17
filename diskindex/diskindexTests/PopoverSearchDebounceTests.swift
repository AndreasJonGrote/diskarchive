//
//  PopoverSearchDebounceTests.swift
//  diskindexTests
//
//  bug.0.4.039 (REPORT 85): Popover-Suche entprellt (150 ms), jede neue Eingabe bricht die vorige ab, die Seite kommt
//  ohne Zahl und die Zahl getrennt. Zähler je Store (`searchCountCalls`), keine prozessweiten Schalter (Regel 20).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct PopoverSearchDebounceTests {
    /// 600 Dateien `Rechnung_…`: die Dateigruppe ist voll, die Zahl muss also nachgereicht werden.
    private func rig() async throws -> (app: AppState, store: IndexStoreV3) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-popoverdebounce-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "BUERO", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let entries = (0..<600).map { ScannedEntry(name: String(format: "Rechnung_%03d.pdf", $0), isFolder: false, sizeBytes: 1) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        return (app, store)
    }

    @Test func fiveQuickInputsRunAtMostOneCountQuery() async throws {
        let (app, store) = try await rig()
        defer { app.prepareForTermination() }
        // Testeinstellung: Entprellung weit über dem Tippabstand, damit Last den Abstand nicht über die Grenze schiebt.
        app.popoverSearchDebounce = .seconds(2)
        let before = store.searchCountCalls.value
        for text in ["r", "re", "rec", "rech", "rechn"] {
            app.popoverSearchText = text
            app.schedulePopoverSearch()
            // Schnelles Tippen: weit unter der Entprellung.
            try await Task.sleep(for: .milliseconds(20))
        }
        await app.waitForPopoverSearch()
        let counts = store.searchCountCalls.value - before
        #expect(counts <= 1, "\(counts) Zählabfragen für 5 Eingaben")
        #expect(app.popoverResults.totalCount == 600)
        #expect(!app.popoverResults.isCountPending)
        #expect(app.popoverResults.groups.contains { $0.title == "DATEIEN" })
    }

    /// Erste Suche nach leerem Feld: keine Zahl bekannt → die Seite erscheint erst mit der Zahl, nie mit „6“.
    @Test func theFirstSearchNeverShowsAMadeUpCount() async throws {
        let (app, store) = try await rig()
        defer { app.prepareForTermination() }
        app.popoverSearchDebounce = .zero
        await store.setSearchCountDelay(.milliseconds(400))
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        var seen = Set<Int>()
        let counted = await waitUntil(timeout: 5) {
            seen.insert(app.popoverResults.totalCount)
            if app.popoverResults.totalCount == 0 { #expect(app.popoverResults.groups.isEmpty) }
            return app.popoverResults.totalCount == 600
        }
        #expect(counted)
        #expect(seen.isSubset(of: [0, 600]), "gezeigte Zahlen: \(seen.sorted())")
        await store.setSearchCountDelay(nil)
    }

    /// Folgeeingabe: die neue Seite erscheint sofort, die Fußzeile behält bis zur neuen Zählung die letzte Zahl.
    @Test func aFollowUpInputKeepsTheLastKnownCountUntilCounted() async throws {
        let (app, store) = try await rig()
        defer { app.prepareForTermination() }
        app.popoverSearchDebounce = .zero
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        await app.waitForPopoverSearch()
        try #require(app.popoverResults.totalCount == 600)
        await store.setSearchCountDelay(.milliseconds(400))
        app.popoverSearchText = "rechnung_1"
        app.schedulePopoverSearch()
        let early = await waitUntil(timeout: 5) { app.popoverResults.isCountPending }
        try #require(early, "Seite kam nicht vor der Zahl")
        #expect(app.popoverResults.totalCount == 600, "Fußzeile während der Zählung: \(app.popoverResults.totalCount)")
        #expect(app.popoverResults.groups.first { $0.title == "DATEIEN" }?.hits.first?.title == "Rechnung_100.pdf")
        await app.waitForPopoverSearch()
        #expect(app.popoverResults.totalCount == 100)
        #expect(!app.popoverResults.isCountPending)
        await store.setSearchCountDelay(nil)
    }

    @Test func aNewInputDropsThePendingCount() async throws {
        let (app, store) = try await rig()
        defer { app.prepareForTermination() }
        app.popoverSearchDebounce = .zero
        await store.setSearchCountDelay(.milliseconds(300))
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        let pending = await waitUntil(timeout: 5) { app.popoverCountTask != nil }
        try #require(pending, "Zählung lief nicht an")
        app.popoverSearchText = "rechnung_00"
        app.schedulePopoverSearch()
        await app.waitForPopoverSearch()
        // „rechnung_00“ trifft 10 Dateien; die alte Zahl 600 darf nicht mehr ankommen.
        #expect(app.popoverResults.totalCount == 10, "Zahl \(app.popoverResults.totalCount)")
        await store.setSearchCountDelay(nil)
    }

    @Test func teardownCancelsThePopoverSearch() async throws {
        let (app, _) = try await rig()
        app.popoverSearchText = "rechnung"
        app.schedulePopoverSearch()
        #expect(app.popoverSearchTask != nil)
        app.prepareForTermination()
        #expect(app.popoverSearchTask == nil)
        #expect(app.popoverCountTask == nil)
    }
}

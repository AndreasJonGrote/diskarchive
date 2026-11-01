//
//  PendingRuleResultsTests.swift
//  DiskArchiveTests
//
//  bug.0.4.146: Favoriten und Suche während der Regel-Warteschlange (Rest von 096). Solange die Warteschlange läuft,
//  steht in der Datenbank noch `status = 0` für Einträge, die die neue Regel ausblendet.
//  (a) Die Favoritenzahl zählt sie nicht mit (bei voller Seite „–“ bis nach der Warteschlange).
//  (b) Die Suche im Fenster liest erst nach der Warteschlange – auch eine neue Seite (anderer Sortierklick).
//  (c) Die Popover-Suche der Menüleiste wartet und blendet genauso aus.
//  Ohne Fenster (Regel 19); kein Ändern der Kette selbst, nur Auslösen wie die Bedienung und Warten.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct PendingRuleResultsTests {
    @MainActor
    private struct Rig {
        let app: AppState
        let store: IndexStoreV3
        let database: TestDatabase
        let directory: URL
        let mediumID: UUID

        func close() {
            app.prepareForTermination()
            try? database.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// Ein Medium mit `names` als Dateien in der Wurzel; `favorites` davon als Favorit markiert.
    private static func makeRig(names: [String], favorites: Bool) async throws -> Rig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-pending-rule-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Daten", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        let entries = names.map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        if favorites {
            let rows = try await store.children(mediumUUID: medium.uuid, parentID: nil)
            try await store.setFavorites(itemIDs: rows.map(\.id), true)
        }
        let app = AppState()
        app.attach(store: store)
        await app.loadStoredMedia()
        return Rig(app: app, store: store, database: database, directory: directory, mediumID: medium.uuid)
    }

    /// (a) 600 Favoriten plus 40, die die Regel ausblendet (hinter der ersten Seite). Während der Warteschlange zeigt
    /// die Zahl nie 640 – weder direkt nach dem Ignorieren noch nach einem Neuladen der Seite; danach 600.
    @Test func favoriteCountNeverIncludesHiddenDuringQueue() async throws {
        let kept = (0..<600).map { String(format: "datei-%04d.txt", $0) }
        let hidden = (0..<40).map { String(format: "zz-%02d.tmp", $0) }
        let rig = try await Self.makeRig(names: kept + hidden, favorites: true)
        defer { rig.close() }
        let app = rig.app
        await app.reloadFavorites()
        try #require(app.favoriteObjects.count == SearchIndex.pageLimit)
        try #require(app.favoriteItemCount == 640)
        await rig.store.setReconcileBatchDelay(.milliseconds(600))
        app.requestIgnore(hidden, targetCount: 1)
        try #require(app.isRuleReconcileQueueActive)
        var seen: [Int?] = [app.favoriteItemCount]
        // Neuladen der Seite während der Warteschlange (wie nach einem Favoriten-Umschalten).
        await app.reloadFavorites()
        let reloadedDuringQueue = app.isRuleReconcileQueueActive
        seen.append(app.favoriteItemCount)
        #expect(reloadedDuringQueue, "Warteschlange vor dem Neuladen schon fertig – Test prüfte nichts")
        #expect(!seen.contains(640), "Zahl enthält ausgeblendete Favoriten: \(seen)")
        await app.waitForRuleReconcileIdle()
        await app.reloadFavorites()
        #expect(app.favoriteItemCount == 600)
        #expect(!app.favoriteObjects.contains { $0.name.hasSuffix(".tmp") })
    }

    /// (a) Kleine Seite: die Zahl sinkt sofort um die ausgeblendeten (exakt, alle Favoriten auf der Seite).
    @Test func favoriteCountOfACompletePageDropsInPlace() async throws {
        let rig = try await Self.makeRig(names: ["a.txt", "b.txt", "weg.tmp"], favorites: true)
        defer { rig.close() }
        let app = rig.app
        await app.reloadFavorites()
        try #require(app.favoriteItemCount == 3)
        await rig.store.setReconcileBatchDelay(.milliseconds(300))
        app.requestIgnore(["weg.tmp"], targetCount: 1)
        #expect(app.favoriteItemCount == 2)
        await app.reloadFavorites()
        #expect(app.favoriteItemCount == 2)
        await app.waitForRuleReconcileIdle()
    }

    /// (b) Eine Suche, die während der Warteschlange startet (z. B. Sortierklick → neue Seite), liest erst danach:
    /// zu keinem Zeitpunkt ein ausgeblendeter Treffer.
    @Test func searchDuringQueueNeverShowsHiddenHits() async throws {
        let rig = try await Self.makeRig(names: ["weg-1.tmp", "weg-2.txt", "weg-3.txt"], favorites: false)
        defer { rig.close() }
        let app = rig.app
        app.searchState.submittedQuery = "weg"
        await app.runSearch()
        try #require(app.searchMatch.items.count == 3)
        await rig.store.setReconcileBatchDelay(.milliseconds(300))
        app.requestIgnore(["weg-1.tmp"], targetCount: 1)
        try #require(app.isRuleReconcileQueueActive)
        #expect(!app.searchMatch.items.contains { $0.name == "weg-1.tmp" }, "nicht an Ort und Stelle ausgeblendet")
        // Neue Seite (anderer Sortierklick) während der Warteschlange.
        app.searchState.sort = SearchSort(column: .name, direction: .descending)
        var violations = 0
        let search = Task { await app.runSearch() }
        while app.isRuleReconcileQueueActive {
            if app.searchMatch.items.contains(where: { $0.name == "weg-1.tmp" }) { violations += 1 }
            try await Task.sleep(for: .milliseconds(10))
        }
        await search.value
        #expect(violations == 0)
        #expect(app.searchMatch.items.map(\.name).sorted() == ["weg-2.txt", "weg-3.txt"])
    }

    /// (c) Popover-Suche: gezeigte Treffer verschwinden sofort; eine Popover-Suche während der Warteschlange liest
    /// erst danach (nie ein ausgeblendeter Treffer), Zahl danach ohne ihn.
    @Test func popoverSearchWaitsAndHidesDuringQueue() async throws {
        let rig = try await Self.makeRig(names: ["weg-1.tmp", "weg-2.txt"], favorites: false)
        defer { rig.close() }
        let app = rig.app
        app.popoverSearchDebounce = .zero
        app.popoverSearchText = "weg"
        app.schedulePopoverSearch()
        let names = { app.popoverResults.groups.flatMap(\.hits).map(\.title) }
        try #require(await waitUntil { names().count == 2 }, "Popover-Treffer: \(names())")
        await rig.store.setReconcileBatchDelay(.milliseconds(400))
        app.requestIgnore(["weg-1.tmp"], targetCount: 1)
        try #require(app.isRuleReconcileQueueActive)
        #expect(!names().contains("weg-1.tmp"), "Popover-Treffer nicht an Ort und Stelle ausgeblendet")
        // Neue Eingabe während der Warteschlange.
        app.popoverSearchText = "weg-"
        app.schedulePopoverSearch()
        var violations = 0
        while app.isRuleReconcileQueueActive {
            if names().contains("weg-1.tmp") { violations += 1 }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(violations == 0, "ausgeblendeter Treffer im Popover während der Warteschlange")
        let settled = await waitUntil { names() == ["weg-2.txt"] && !app.popoverResults.isCountPending }
        #expect(settled, "Popover nach der Warteschlange: \(names())")
        #expect(app.popoverResults.totalCount == 1)
    }
}

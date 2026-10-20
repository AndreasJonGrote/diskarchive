//
//  RuleReconcileQueueTests.swift
//  diskindexTests
//
//  Regel-Warteschlange und Status-Flags (234).
//

import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct RuleReconcileQueueTests {
    private func appWithHiddenFile() async throws -> (AppState, IndexStoreV3, StoredMedium) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-rulequeue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "RULE", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        var entries = (0..<20).map { ScannedEntry(name: "bericht-\($0).pdf", isFolder: false, sizeBytes: 1) }
        entries.append(ScannedEntry(name: ".bericht-versteckt.pdf", isFolder: false, sizeBytes: 1))
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.mainWindowDestination = .search
        app.searchState.submittedQuery = "bericht"
        app.appSettings.ignoreHiddenFiles = false
        await app.waitForRuleReconcileIdle()
        return (app, store, medium)
    }

    @Test func searchDuringQueueCompletesAfterIdle() async throws {
        let (app, store, _) = try await appWithHiddenFile()
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 21)

        await store.setReconcileBatchDelay(.milliseconds(120))
        app.appSettings.ignoreHiddenFiles = true
        try #require(app.isRuleReconcileQueueActive || app.pruneAt != nil)

        let searchTask = Task { await app.runSearch() }
        // bug.0.3.8.007: statt fester 30 ms warten, bis die Suche läuft (sie wartet auf das Ende der Warteschlange).
        let inProgress = await waitUntil { app.searchState.isSearchInProgress }
        #expect(inProgress)

        await app.waitForRuleReconcileIdle()
        await searchTask.value
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 20)
        #expect(!app.searchMatch.items.contains { $0.name.hasPrefix(".") })
    }

    @Test func waitForIdleWaitsThroughErrorRestart() async throws {
        let (app, store, _) = try await appWithHiddenFile()
        await store.setReconcileShouldFail(true)
        await store.setReconcileBatchDelay(.milliseconds(150))
        app.appSettings.ignoreHiddenFiles = true
        #expect(app.isRuleReconcileQueueActive)
        try await Task.sleep(for: .milliseconds(10))
        let idleWait = Task { @MainActor in
            await app.waitForRuleReconcileIdle()
        }
        app.enqueueRuleReconcile()
        // bug.0.3.8.007: die frühere Prüfung „aktiv nach 25 ms“ entfällt (direkt nach `enqueue` immer wahr, mit
        // Schlaf zeitabhängig). Den Beweis führen `idleWait` (endet erst nach dem Fehler-Neustart) und die 20 Treffer.
        await idleWait.value
        #expect(!app.isRuleReconcileQueueActive)
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 20)
    }

    @Test func needsRerunAfterReconcileErrorRestartsWorker() async throws {
        let (app, store, _) = try await appWithHiddenFile()
        await store.setReconcileShouldFail(true)
        app.appSettings.ignoreHiddenFiles = true
        try await Task.sleep(for: .milliseconds(40))
        app.enqueueRuleReconcile()
        await app.waitForRuleReconcileIdle()
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 20)
        #expect(!app.isRuleReconcileQueueActive)
    }

    @Test func queueErrorDoesNotHangSearch() async throws {
        let (app, store, _) = try await appWithHiddenFile()
        await store.setReconcileShouldFail(true)
        app.appSettings.ignoreHiddenFiles = true
        await app.waitForRuleReconcileIdle()
        #expect(!app.isRuleReconcileQueueActive)

        await app.runSearch()
        #expect(!app.searchState.isSearchInProgress)
        #expect(!app.isRuleReconcileQueueActive)
    }

    @Test func noSwiftNameChecksAfterReconcile() async throws {
        let (app, store, medium) = try await appWithHiddenFile()
        app.appSettings.ignoreHiddenFiles = false
        await app.runSearch()
        let baseline = store.nameChecks.value

        app.appSettings.ignoreHiddenFiles = true
        await app.waitForRuleReconcileIdle()
        #expect(!app.indexScope.checksNames)

        await app.runSearch()
        await app.waitForSearchCount()
        _ = try await store.children(mediumUUID: medium.uuid, parentID: nil, scope: app.indexScope)
        #expect(store.nameChecks.value == baseline)
    }

    /// bug.0.4.088 (README „Ausblenden an Ort und Stelle“, Nutzer 18.10.; vorher: Warteschlange leerte die Spalten):
    /// Während der Warteschlange bleibt die Spalte stehen, nur der jetzt ausgeschlossene Eintrag ist sofort weg.
    @Test func ruleReconcileHidesInPlaceWhileActive() async throws {
        let (app, store, medium) = try await appWithHiddenFile()
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.uuid
        app.indexRepository.requestLoad(mediumID: medium.uuid, path: [])
        // bug.0.3.8.007: statt fester 80 ms warten, bis die Spalte geladen ist.
        let loaded = await waitUntil { !app.indexRepository.children(mediumID: medium.uuid, path: []).isEmpty }
        try #require(loaded)

        await store.setReconcileBatchDelay(.milliseconds(200))
        let before = app.indexRepository.children(mediumID: medium.uuid, path: []).map(\.name)
        try #require(before.contains(".bericht-versteckt.pdf"))
        app.appSettings.ignoreHiddenFiles = true
        try #require(app.isRuleReconcileQueueActive)
        let during = app.indexRepository.children(mediumID: medium.uuid, path: []).map(\.name)
        #expect(during == before.filter { $0 != ".bericht-versteckt.pdf" }, "Spalte während der Warteschlange: \(during)")
        #expect(!app.indexRepository.isLoading(mediumID: medium.uuid, path: []))
        await app.waitForRuleReconcileIdle()
    }

    /// bug.0.4.088: Suchtreffer, die die neue Regel ausschließt, verschwinden sofort (Warteschlange läuft noch).
    @Test func searchHitHiddenInPlaceWhileQueueActive() async throws {
        let (app, store, _) = try await appWithHiddenFile()
        await app.runSearch()
        await app.waitForSearchCount()
        let before = app.searchMatch.items.map(\.name)
        try #require(before.contains(".bericht-versteckt.pdf"), "Treffer: \(before)")
        let countBefore = try #require(app.searchMatch.itemCount)
        await store.setReconcileBatchDelay(.milliseconds(200))
        app.appSettings.ignoreHiddenFiles = true
        try #require(app.isRuleReconcileQueueActive)
        #expect(app.searchMatch.items.map(\.name) == before.filter { $0 != ".bericht-versteckt.pdf" })
        #expect(app.searchMatch.itemCount == countBefore - 1)
        await app.waitForRuleReconcileIdle()
    }

    /// bug.0.4.097 (README „sofort“): Ordner „X“ ignorieren → Treffer und Favoriten in `X/…` sofort weg (Warteschlange
    /// läuft noch, kein Ladezustand); Ausschluss entfernen → wieder da.
    @Test func hitsAndFavoritesBelowIgnoredFolderHideAtOnce() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-rulequeue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "RULE", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "X", isFolder: true), ScannedEntry(name: "bericht-oben.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        let x = try await store.folderID(mediumUUID: medium.uuid, path: ["X"])
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: x,
            entries: [ScannedEntry(name: "bericht-unten.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 2)
        let below = try #require(try await store.children(mediumUUID: medium.uuid, parentID: x).first)
        try await store.setFavorites(itemIDs: [below.id], true)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        // Wie in der App: die Änderungsschleife sucht nach dem Ende der Warteschlange neu.
        app.startChangeLoop()
        app.mainWindowDestination = .search
        app.searchState.submittedQuery = "bericht"
        app.appSettings.ignoreHiddenFiles = false
        await app.waitForRuleReconcileIdle()
        await app.runSearch()
        await app.reloadFavorites()
        try #require(app.searchMatch.items.map(\.name).contains("bericht-unten.txt"), "Treffer: \(app.searchMatch.items.map(\.name))")
        try #require(app.favoriteObjects.map(\.name) == ["bericht-unten.txt"])

        await store.setReconcileBatchDelay(.milliseconds(200))
        app.toggleIgnoredPatterns(["X"])
        try #require(app.isRuleReconcileQueueActive)
        #expect(!app.searchMatch.items.map(\.name).contains("bericht-unten.txt"), "Treffer unter X noch sichtbar")
        #expect(app.searchMatch.items.map(\.name).contains("bericht-oben.txt"))
        #expect(app.favoriteObjects.isEmpty, "Favorit unter X noch sichtbar")
        await app.waitForRuleReconcileIdle()

        await store.setReconcileBatchDelay(nil)
        app.toggleIgnoredPatterns(["X"])
        await app.waitForRuleReconcileIdle()
        let back = await waitUntil { app.searchMatch.items.map(\.name).contains("bericht-unten.txt") }
        #expect(back, "Treffer nach Entfernen des Ausschlusses nicht zurück: \(app.searchMatch.items.map(\.name))")
        await app.reloadFavorites()
        #expect(app.favoriteObjects.map(\.name) == ["bericht-unten.txt"])
    }

    @Test func sabotageChecksNamesWouldIncrementCounter() async throws {
        let (app, store, medium) = try await appWithHiddenFile()
        app.appSettings.ignoreHiddenFiles = true
        await app.waitForRuleReconcileIdle()
        let baseline = store.nameChecks.value
        var sabotage = app.indexScope
        sabotage.checksNames = true
        _ = try await store.children(mediumUUID: medium.uuid, parentID: nil, scope: sabotage)
        #expect(store.nameChecks.value > baseline, "Sabotage: checksNames darf nach Reconcile nicht aktiv sein")
    }
}
}

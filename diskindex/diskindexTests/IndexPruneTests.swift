//
//  IndexPruneTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct IndexPruneTests {
    @Test func depthHidesAtOnceAndRowsStayUntilTheDeadline() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let tree = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        let narrow = SampleTree.depth(2)
        let wide = SampleTree.open

        let hidden = try await harness.store.children(mediumUUID: medium.uuid, parentID: tree.edgeID, scope: narrow)
        let shown = try await harness.store.children(mediumUUID: medium.uuid, parentID: tree.edgeID, scope: wide)
        #expect(hidden.isEmpty)
        #expect(shown.contains { $0.name == "deep.txt" })
        #expect(try await harness.store.storedNames().contains("deep.txt"))

        let found = try await harness.store.search(query: "deep", filters: SearchFilters(), scope: narrow)
        #expect(found.isEmpty)
        let counts = try await harness.store.counts(mediumUUID: medium.uuid, scope: narrow)
        let all = try await harness.store.counts(mediumUUID: medium.uuid, scope: wide)
        #expect(counts.files < all.files)

        _ = try await harness.store.pruneToMatch(narrow)
        #expect(!(try await harness.store.storedNames().contains("deep.txt")))
    }

    @Test func raisingDepthBeforeTheDeadlineShowsTheRowsAgain() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let tree = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 4)
        let before = try await harness.store.medium(uuid: medium.uuid)

        let shown = try await harness.store.children(mediumUUID: medium.uuid, parentID: tree.edgeID, scope: SampleTree.open)
        #expect(shown.contains { $0.name == "deep.txt" })
        #expect(before?.completedDepth == 4)
        let stamp = try await harness.store.contentStamp(mediumUUID: medium.uuid, path: ["a", "b"])
        #expect(stamp != nil)
    }

    @Test func pruneResetsTheBoundaryStampAndCompletedDepth() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        _ = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 4)

        _ = try await harness.store.pruneToMatch(SampleTree.depth(2))
        let stored = try await harness.store.medium(uuid: medium.uuid)
        #expect(stored?.completedDepth == 2)
        let stamp = try await harness.store.contentStamp(mediumUUID: medium.uuid, path: ["a", "b"])
        #expect(stamp == nil)
        let hits = try await harness.store.search(query: "deep", filters: SearchFilters())
        #expect(hits.isEmpty)
    }

    @Test func aSecondShrinkRestartsTheHourAndGrowingDoesNotCancelIt() async throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = UserDefaults(suiteName: "diskindex-prune-hour-\(UUID().uuidString)")!
        let app = AppState(defaults: defaults)
        app.armPrune(now: start)
        let first = app.pruneAt
        app.armPrune(now: start.addingTimeInterval(120))
        #expect(app.pruneAt == start.addingTimeInterval(3_720))
        #expect(app.pruneAt != first)

        app.appSettings.scanDepth = 2
        let due = app.pruneAt
        app.appSettings.scanDepth = 5
        #expect(app.pruneAt == due)
        #expect(IndexSchedule.shrinks(from: AppSettings(), to: {
            var next = AppSettings()
            next.scanDepth = 2
            return next
        }()))
    }

    @Test func theDeadlineSurvivesARestartAndAnOverduePruneRuns() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        _ = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let suite = "diskindex-prune-restart-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let app = AppState(store: harness.store, defaults: defaults)
        app.appSettings.scanDepth = 2
        app.flushSettings()
        app.armPrune(now: start)

        let restored = AppState(store: harness.store, defaults: defaults)
        #expect(restored.appSettings.indexedMaxDepth == 2)
        #expect(restored.pruneAt == start.addingTimeInterval(3_600))
        await restored.pruneIfDue(now: start.addingTimeInterval(10))
        #expect(try await harness.store.storedNames().contains("deep.txt"))

        await restored.pruneIfDue(now: start.addingTimeInterval(3_600))
        #expect(!(try await harness.store.storedNames().contains("deep.txt")))
        #expect(restored.pruneAt == nil)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func aFavoriteBeyondTheDepthIsDeleted() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let tree = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        let deep = try await harness.store.children(mediumUUID: medium.uuid, parentID: tree.edgeID)
        let row = try #require(deep.first { $0.name == "deep.txt" })
        try await harness.store.setFavorite(itemID: row.id, true)
        let marked = try await harness.store.favorites(scope: SampleTree.depth(2))
        #expect(!marked.contains { $0.name == "deep.txt" })
        let kept = try await harness.store.favorites()
        #expect(kept.contains { $0.name == "deep.txt" })

        _ = try await harness.store.pruneToMatch(SampleTree.depth(2))
        let after = try await harness.store.favorites()
        #expect(!after.contains { $0.name == "deep.txt" })
    }

    @Test func everyMediumIsPrunedIncludingOnesThatAreOffline() async throws {
        let harness = try StoreHarness.make()
        let online = try await harness.insert(name: "Online", fsType: "apfs", bytes: 1_000)
        let offline = try await harness.insert(name: "Offline", fsType: "apfs", bytes: 1_000)
        _ = try await SampleTree.plant(in: harness.store, medium: online.uuid)
        _ = try await SampleTree.plant(in: harness.store, medium: offline.uuid)
        _ = try await harness.store.pruneToMatch(SampleTree.depth(2))
        let names = try await harness.store.storedNames()
        #expect(!names.contains("deep.txt"))
        #expect(names.filter { $0 == "b" }.count == 2)
    }

    @Test func cleanNowRemovesDepthHiddenArtifactsAndExclusions() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let suite = "diskindex-prune-button-\(UUID().uuidString)"
        let app = AppState(store: harness.store, defaults: UserDefaults(suiteName: suite)!)
        var settings = app.appSettings
        settings.scanDepth = 1
        settings.ignoreHiddenFiles = true
        settings.artifactsIgnored = true
        settings.excludedPatterns = ["*.pdf"]
        app.appSettings = settings

        let root = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        #expect(root.isEmpty)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "readme.txt", isFolder: false),
                ScannedEntry(name: ".secret", isFolder: false),
                ScannedEntry(name: "thumbs.db", isFolder: false),
                ScannedEntry(name: "report.pdf", isFolder: false),
                ScannedEntry(name: "docs", isFolder: true),
            ],
            seenAt: Date()
        )
        let docs = try await harness.store.folderID(mediumUUID: medium.uuid, path: ["docs"])
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: docs,
            entries: [ScannedEntry(name: "inside.txt", isFolder: false)],
            seenAt: Date()
        )
        let visible = try await harness.store.children(
            mediumUUID: medium.uuid,
            parentID: nil,
            scope: IndexScope.from(app.appSettings)
        )
        #expect(visible.map(\.name) == ["docs", "readme.txt"] || Set(visible.map(\.name)) == ["docs", "readme.txt"])

        await app.pruneNow()
        let names = Set(try await harness.store.storedNames())
        #expect(names == ["docs", "readme.txt"])
        #expect(app.pruneAt == nil)
        defaultsCleanup(suite)
    }

    @Test func switchesAndPatternsHideAndShowWithoutDeleting() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "keep.txt", isFolder: false),
                ScannedEntry(name: ".secret", isFolder: false),
                ScannedEntry(name: "thumbs.db", isFolder: false),
                ScannedEntry(name: "note.pdf", isFolder: false),
            ],
            seenAt: Date()
        )
        let hidden = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: ["*.pdf"], artifactsIgnored: true)
        )
        let open = SampleTree.open
        let concealed = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil, scope: hidden)
        let revealed = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil, scope: open)
        #expect(concealed.map(\.name) == ["keep.txt"])
        #expect(revealed.count == 4)
        #expect(try await harness.store.storedNames().count == 4)
    }

    @Test func aStoppedPruneContinuesWithoutOrphans() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "gone.tmp", isFolder: false),
                ScannedEntry(name: "keep", isFolder: true),
            ],
            seenAt: Date()
        )
        let keep = try await harness.store.folderID(mediumUUID: medium.uuid, path: ["keep"])
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: keep,
            entries: [ScannedEntry(name: "also.tmp", isFolder: false)],
            seenAt: Date()
        )
        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: ["*.tmp"], artifactsIgnored: false)
        )
        _ = try await harness.store.pruneToMatch(scope, batchSize: 1, maxBatches: 1)
        #expect(try await harness.store.storedNames().contains("also.tmp"))
        #expect(try await harness.store.orphanCount() == 0)
        _ = try await harness.store.pruneToMatch(scope, batchSize: 1)
        let names = try await harness.store.storedNames()
        #expect(!names.contains("gone.tmp"))
        #expect(!names.contains("also.tmp"))
        #expect(names.contains("keep"))
        #expect(try await harness.store.orphanCount() == 0)
    }

    @Test func pruningShrinksTheDatabaseFile() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        var entries: [ScannedEntry] = []
        for index in 0..<2_500 {
            entries.append(ScannedEntry(name: "gone-\(index).dat", isFolder: false))
        }
        entries.append(ScannedEntry(name: "keep.txt", isFolder: false))
        try await harness.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        let before = await harness.store.databaseFileBytes()
        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: ["gone-*"], artifactsIgnored: false)
        )
        let removed = try await harness.store.pruneToMatch(scope)
        let after = await harness.store.databaseFileBytes()
        #expect(removed >= 2_500)
        #expect(after < before)
        #expect(try await harness.store.storedNames() == ["keep.txt"])
    }

    private func defaultsCleanup(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

private enum SampleTree {
    struct Planted {
        var edgeID: Int64
    }

    static var open: IndexScope {
        IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
        )
    }

    static func depth(_ maxDepth: Int) -> IndexScope {
        IndexScope(
            maxDepth: maxDepth,
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
        )
    }

    static func plant(in store: IndexStoreV3, medium: UUID) async throws -> Planted {
        try await store.applyDirectory(
            mediumUUID: medium,
            parentID: nil,
            entries: [ScannedEntry(name: "a", isFolder: true)],
            seenAt: Date()
        )
        let a = try await store.folderID(mediumUUID: medium, path: ["a"])
        try await store.applyDirectory(
            mediumUUID: medium,
            parentID: a,
            entries: [ScannedEntry(name: "b", isFolder: true)],
            seenAt: Date()
        )
        let b = try #require(try await store.folderID(mediumUUID: medium, path: ["a", "b"]))
        try await store.applyDirectory(
            mediumUUID: medium,
            parentID: b,
            entries: [ScannedEntry(name: "deep.txt", isFolder: false)],
            seenAt: Date()
        )
        return Planted(edgeID: b)
    }
}

//
//  IndexPruneTests.swift
//  diskindexTests
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
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

    @Test func depthPruneCapsCompletedDepthOnlyOnTouchedStorages() async throws {
        let harness = try StoreHarness.make()
        let deep = try await harness.insert(name: "Deep", fsType: "apfs", bytes: 1_000)
        let shallow = try await harness.insert(name: "Shallow", fsType: "apfs", bytes: 1_000)
        _ = try await SampleTree.plant(in: harness.store, medium: deep.uuid)
        try await harness.store.applyDirectory(
            mediumUUID: shallow.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "only.txt", isFolder: false)],
            seenAt: Date()
        )
        for depth in 1...4 {
            try await harness.store.completeLayer(mediumUUID: deep.uuid, depth: depth)
            try await harness.store.completeLayer(mediumUUID: shallow.uuid, depth: depth)
        }
        _ = try await harness.store.pruneToMatch(SampleTree.depth(2))
        let deepStored = try #require(try await harness.store.medium(uuid: deep.uuid))
        let shallowStored = try #require(try await harness.store.medium(uuid: shallow.uuid))
        #expect(deepStored.completedDepth == 2)
        #expect(shallowStored.completedDepth == 4)
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

    @Test func scheduledTaskPrunesWithoutDidWake() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        _ = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        let suite = "diskindex-prune-task-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        var persisted = PersistedAppSettings()
        persisted.scanDepth = 2
        try await harness.store.savePersistedAppSettings(persisted)
        let due = Date().addingTimeInterval(0.3)
        defaults.set(due.timeIntervalSince1970, forKey: AppState.pruneAtKey)
        let app = AppState(store: harness.store, defaults: defaults)
        app.pruneClock = { Date() }
        await app.hydrateSettingsFromStore()
        app.loadPruneDeadline()
        let pruned = await waitUntil(timeout: 5) {
            (try? await harness.store.storedNames().contains("deep.txt")) == false
        }
        #expect(pruned)
        defaults.removePersistentDomain(forName: suite)
    }

    /// Nacharbeit 3: `pruneAt` in der Vergangenheit → `MediumRecognitionStartup.bootstrap` → bereinigt
    /// (kein Aufruf von `pruneIfDue`/`pruneNow`/`loadPruneDeadline` im Test, Regel 18).
    @Test func overduePruneOnBootstrapWithoutManualCall() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        _ = try await SampleTree.plant(in: harness.store, medium: medium.uuid)
        let suite = "diskindex-prune-bootstrap-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Date().addingTimeInterval(-60).timeIntervalSince1970, forKey: AppState.pruneAtKey)
        var persisted = PersistedAppSettings()
        persisted.scanDepth = 2
        try await harness.store.savePersistedAppSettings(persisted)
        #expect(try await harness.store.storedNames().contains("deep.txt"))

        let app = AppState(store: harness.store, defaults: defaults)
        let coordinator = MediumCoordinator(store: harness.store, access: GrantedAccess(), appState: app)
        MediumRecognitionStartup.bootstrap(
            appState: app,
            store: harness.store,
            coordinator: coordinator,
            startChangeLoop: {},
            makeMonitor: { MediumMonitor(mountedVolumes: { [] }, wakeEvents: { AsyncStream { _ in } }) }
        )
        defer { coordinator.stop() }
        let pruned = await waitUntil(timeout: 5) {
            (try? await harness.store.storedNames().contains("deep.txt")) == false
        }
        #expect(pruned)
        // bug.0.3.9.004: Die Zeilen sind weg, sobald `pruneToMatch` schreibt; `clearPruneDeadline` läuft erst danach,
        // wenn `pruneNow` auf dem Haupt-Actor weiterläuft. Auf den Termin warten statt direkt zu lesen.
        let cleared = await waitUntil(timeout: 5) { app.pruneAt == nil }
        #expect(cleared)
        #expect(app.pruneAt == nil)
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
        var persisted = PersistedAppSettings()
        persisted.scanDepth = 2
        try await harness.store.savePersistedAppSettings(persisted)
        let app = AppState(store: harness.store, defaults: defaults)
        await app.hydrateSettingsFromStore()
        app.armPrune(now: start)

        let restored = AppState(store: harness.store, defaults: defaults)
        await restored.hydrateSettingsFromStore()
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
        var settings = app.appSettings
        settings.scanDepth = 1
        settings.ignoreHiddenFiles = true
        settings.artifactsIgnored = true
        settings.excludedPatterns = ["*.pdf"]
        app.appSettings = settings
        await app.waitForRuleReconcileIdle()
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

    /// bug.0.4.103: Nachfahren eines ignorierten Ordners werden von der Warteschlange nicht wieder sichtbar,
    /// auch nicht in späteren Seiten oder weiteren Läufen; ohne Muster wird alles wieder sichtbar.
    @Test func descendantsOfIgnoredFolderStayHidden() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "X", isFolder: true), ScannedEntry(name: "keep.txt", isFolder: false)],
            seenAt: Date()
        )
        let x = try await harness.store.folderID(mediumUUID: medium.uuid, path: ["X"])
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: x,
            entries: [ScannedEntry(name: "sub", isFolder: true)],
            seenAt: Date()
        )
        let sub = try await harness.store.folderID(mediumUUID: medium.uuid, path: ["X", "sub"])
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: sub,
            entries: [ScannedEntry(name: "a.txt", isFolder: false)],
            seenAt: Date()
        )
        let ignoreX = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: ["X"], artifactsIgnored: false)
        )
        _ = try await harness.store.reconcileScopeToStatus(ignoreX, batchSize: 1)
        _ = try await harness.store.reconcileScopeToStatus(ignoreX, batchSize: 1)
        let hidden = try await statuses(harness)
        #expect(hidden["X"] == ItemStatus.toDelete.rawValue)
        #expect(hidden["sub"] == ItemStatus.toDelete.rawValue)
        #expect(hidden["a.txt"] == ItemStatus.toDelete.rawValue)
        #expect(hidden["keep.txt"] == ItemStatus.visible.rawValue)
        _ = try await harness.store.reconcileScopeToStatus(SampleTree.open, batchSize: 1)
        let shown = try await statuses(harness)
        #expect(shown.values.allSatisfy { $0 == ItemStatus.visible.rawValue }, "\(shown)")
        #expect(shown.count == 4)
    }

    private func statuses(_ harness: StoreHarness) async throws -> [String: Int] {
        try await harness.store.pool.read { db in
            var result: [String: Int] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT name, status FROM items") {
                result[row["name"]] = row["status"]
            }
            return result
        }
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

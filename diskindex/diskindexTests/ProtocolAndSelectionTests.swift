//
//  ProtocolAndSelectionTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

// bug.0.3.9.004 c: enthält die Laufzeitgrenze `recordOnMainStaysFast` → nacheinander mit den Messtests.
extension MeasurementTestGroup {
@Suite struct DiskIndexLogTests {
    @Test func manyRecordsCallRestrictAtMostOncePerLogFile() throws {
        let tracker = FilePrivacy.RestrictCountTracker()
        FilePrivacy.$restrictCountTracker.withValue(tracker) {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let log = DiskIndexLog(directory: directory)
            log.start(installHandlers: false)
            for index in 0..<500 {
                log.record(.app, .info, "zeile-\(index)")
            }
            log.flushPendingWritesForTesting()
            #expect(tracker.count <= 1)
        }
    }

    @Test func recordOnMainStaysFast() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        let samples = 200
        var totalSeconds = 0.0
        for index in 0..<samples {
            let started = CFAbsoluteTimeGetCurrent()
            log.record(.app, .info, "latenz-\(index)")
            totalSeconds += CFAbsoluteTimeGetCurrent() - started
        }
        log.flushPendingWritesForTesting()
        let averageMs = (totalSeconds / Double(samples)) * 1_000
        #expect(averageMs < 1.0)
    }

    @Test func lineIsOnDiskImmediately() throws {
        let log = try makeLog()
        log.record(.app, .info, "sofort")
        log.flushPendingWritesForTesting()
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        #expect(text.contains("app info sofort"))
    }

    @Test func rotatesWhenTheFileReachesTheLimit() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = DiskIndexLog(directory: directory, byteLimit: 80)
        log.record(.app, .info, String(repeating: "a", count: 60))
        log.record(.app, .info, String(repeating: "b", count: 60))
        log.flushPendingWritesForTesting()
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("diskindex.1.log").path))
        let current = try String(contentsOf: log.fileURL, encoding: .utf8)
        #expect(current.contains("bbbb"))
        #expect(!current.contains("aaaa"))
    }

    @Test func breadcrumbsKeepTheLastFiftyInOrder() throws {
        let log = try makeLog()
        for index in 0..<60 {
            log.ui("n=\(index)")
        }
        let trail = log.recentBreadcrumbs()
        #expect(trail.count == 50)
        #expect(trail.first?.contains("n=10") == true)
        #expect(trail.last?.contains("n=59") == true)
    }

    @Test func crashRecordWritesSignalAndTrail() throws {
        let log = try makeLog()
        log.ui("step-1")
        log.ui("step-2")
        log.recordCrash(signal: "SIGTRAP", symbols: ["frame"])
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        #expect(text.contains("CRASH signal=SIGTRAP"))
        #expect(text.contains("step-1"))
        #expect(text.contains("step-2"))
        let crash = text.range(of: "CRASH signal=SIGTRAP")
        let step = text.range(of: "step-1")
        if let crash, let step {
            #expect(step.lowerBound < crash.lowerBound)
        }
    }

    @Test func missingTerminateMarksTheNextStart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let previous = directory.appendingPathComponent("diskindex.log")
        try Data("app info start\n".utf8).write(to: previous)
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        log.flushPendingWritesForTesting()
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        #expect(text.contains("previous run ended without clean exit"))
        #expect(!log.shouldShowCrashDialog)
    }

    @Test func reportContainsHeaderCrashAndActions() {
        let actions = (0..<50).map { "ui info n=\($0)" }
        let text = CrashReportText.make(
            version: "1", build: "2", config: "Debug", macOS: "15", model: "Mac",
            started: "t0", runtime: "1 s",
            crashSection: "CRASH signal=SIGTRAP\nframe",
            actions: actions,
            logLines: ["zeile"],
            databaseBytes: 10, media: "1", objects: "2",
            diagnosticHead: nil
        )
        #expect(text.contains("media=1"))
        #expect(text.contains("objects=2"))
        #expect(text.contains("version=1"))
        #expect(text.contains("CRASH signal=SIGTRAP"))
        #expect(text.contains("n=0"))
        #expect(text.contains("n=49"))
    }

    @Test func crashExcerptPrefersCrashLastFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("app info\nCRASH signal=SIGTRAP\nold\n".utf8).write(to: directory.appendingPathComponent("diskindex.log"))
        try Data("CRASH signal=SIGSEGV\nframe\n".utf8).write(to: directory.appendingPathComponent("crash-last.txt"))
        let log = DiskIndexLog(directory: directory)
        let excerpt = log.crashExcerpt()
        #expect(excerpt.signal == "SIGSEGV")
        #expect(excerpt.stack.contains("frame"))
    }

    @Test func crashFileShowsTheDialogOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("app info start\n".utf8).write(to: directory.appendingPathComponent("diskindex.log"))
        try Data("CRASH signal=SIGSEGV\nframe\n".utf8).write(to: directory.appendingPathComponent("crash-last.txt"))
        let first = DiskIndexLog(directory: directory)
        first.start(installHandlers: false)
        #expect(first.shouldShowCrashDialog)
        first.acknowledgeCrashDialog()
        let second = DiskIndexLog(directory: directory)
        second.start(installHandlers: false)
        #expect(!second.shouldShowCrashDialog)
    }

    @Test func hardStopWithoutCrashFileShowsNoDialog() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("app info start\n".utf8).write(to: directory.appendingPathComponent("diskindex.log"))
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        #expect(!log.shouldShowCrashDialog)
        log.flushPendingWritesForTesting()
        let text = try String(contentsOf: directory.appendingPathComponent("diskindex.log"), encoding: .utf8)
        #expect(text.contains("previous run ended without clean exit"))
    }

    @Test func diagnosticReportOmitsTheCrashSection() throws {
        let log = try makeLog()
        log.ui("nur-aktion")
        log.recordCrash(signal: "SIGTRAP", symbols: ["frame"])
        let report = log.report(includeCrash: false, logLineLimit: 300, actionLimit: 50)
        let head = report.split(separator: "AKTIONEN").first.map(String.init) ?? ""
        #expect(!head.contains("CRASH"))
        #expect(report.contains("nur-aktion"))
    }

    @Test func crashSnapshotWritesWhileTheLockIsHeld() throws {
        let log = try makeLog()
        // bug.0.4.041: writeRing öffnet nie selbst, die Absturzdatei kommt aus start.
        log.start(installHandlers: false)
        log.ui("vor-der-sperre")
        log.holdLockForTest()
        log.writeCrashSnapshot(signal: SIGSEGV)
        log.releaseLockForTest()
        let crash = try String(contentsOf: log.fileURL.deletingLastPathComponent().appendingPathComponent("crash-last.txt"), encoding: .utf8)
        #expect(crash.contains("CRASH signal=SIGSEGV"))
        #expect(crash.contains("vor-der-sperre"))
    }

    @Test func logDirectoryIsPrivate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("diskindex.log")
        try Data("alt\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let log = DiskIndexLog(directory: directory)
        log.start(installHandlers: false)
        let folder = try #require(try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)
        let mode = try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)
        #expect(folder.intValue == 0o700)
        #expect(mode.intValue == 0o600)
    }
}
}

@Suite struct FinderRevealTests {
    @Test func joinsMountAndRelativePath() {
        let url = FinderReveal.url(mountPath: "/Volumes/STICK", itemPath: "/Musik/Grüße Ordner/lied.mp3", kindIsMedium: false)
        #expect(url?.path == "/Volumes/STICK/Musik/Grüße Ordner/lied.mp3")
    }

    @Test func offlineHasNoURL() {
        #expect(FinderReveal.url(mountPath: nil, itemPath: "/a.txt", kindIsMedium: false) == nil)
        #expect(FinderReveal.url(mountPath: "", itemPath: "/a.txt", kindIsMedium: false) == nil)
    }

    @Test func mediumUsesTheMount() {
        #expect(FinderReveal.url(mountPath: "/Volumes/STICK", itemPath: nil, kindIsMedium: true)?.path == "/Volumes/STICK")
    }
}

@Suite @MainActor struct FavoriteHardeningTests {
    @Test func duplicateMediaIDsDoNotTrap() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "A", fsType: "apfs", bytes: 10)
        let copy = medium.asMedium(connection: .connected)
        let app = AppState(store: harness.store)
        app.media = [copy, copy]
        await app.loadStoredMedia()
        #expect(app.media.count == 1)
        let favorites = await SearchIndex.favoriteObjects(store: harness.store, media: [copy, copy], maxDepth: nil)
        #expect(favorites.isEmpty)
    }

    @Test func favoriteFileFolderAndMediumRoundTrip() async throws {
        let harness = try StoreHarness.make()
        let stored = try await harness.insert(name: "A", fsType: "apfs", bytes: 10)
        let children = try await harness.addRoot(medium: stored, entries: [
            ScannedEntry(name: "Ordner", isFolder: true),
            ScannedEntry(name: "note.txt", isFolder: false, sizeBytes: 4),
        ])
        let file = try #require(children.first { $0.name == "note.txt" })
        let folder = try #require(children.first { $0.name == "Ordner" })
        try await harness.store.setFavorite(itemID: file.id, true)
        try await harness.store.setFavorite(itemID: folder.id, false)
        try await harness.store.setFavorites(itemIDs: [file.id, folder.id], true)
        let rows = try await harness.store.favorites()
        #expect(Set(rows.map(\.name)) == ["Ordner", "note.txt"])
        var medium = try #require(try await harness.store.medium(uuid: stored.uuid))
        medium.isFavorite = true
        try await harness.store.updateMedium(uuid: medium.uuid, medium)
        let saved = try #require(try await harness.store.medium(uuid: stored.uuid))
        #expect(saved.isFavorite)
    }

    @Test func removedItemCanStillBeMarkedFavorite() async throws {
        let harness = try StoreHarness.make()
        let stored = try await harness.insert(name: "A", fsType: "apfs", bytes: 10)
        let children = try await harness.addRoot(medium: stored, entries: [
            ScannedEntry(name: "weg.txt", isFolder: false, sizeBytes: 1),
        ])
        let file = try #require(children.first)
        try await harness.store.applyDirectory(
            mediumUUID: stored.uuid,
            parentID: nil,
            entries: [],
            seenAt: Date()
        )
        try await harness.store.setFavorite(itemID: file.id, true)
        let gone = try await harness.store.favorites()
        #expect(gone.isEmpty)
    }
}

@Suite @MainActor struct ColumnSelectionTests {
    @Test func commandClickAddsAndRemoves() {
        var selection = ColumnSelection()
        let a = UUID(), b = UUID()
        selection.commandClick(id: a, column: 0)
        selection.commandClick(id: b, column: 0)
        #expect(selection.ids == [a, b])
        selection.commandClick(id: a, column: 0)
        #expect(selection.ids == [b])
        #expect(selection.anchorID == b)
    }

    @Test func shiftClickSelectsTheRangeAndKeepsTheAnchor() {
        var selection = ColumnSelection()
        let ids = (0..<4).map { _ in UUID() }
        selection.replace(id: ids[0], column: 1)
        selection.shiftClick(id: ids[2], column: 1, visible: ids)
        #expect(selection.ids == Array(ids[0...2]))
        #expect(selection.anchorID == ids[0])
    }

    @Test func clickInAnotherColumnReplaces() {
        var selection = ColumnSelection()
        let first = UUID(), second = UUID()
        selection.replace(id: first, column: 2)
        selection.commandClick(id: second, column: 1)
        #expect(selection.ids == [second])
        #expect(selection.focusColumnIndex == 1)
    }

    @Test func uncapturedReasonsForDepthExclusionAndUnreadable() {
        var medium = Medium(
            id: UUID(),
            name: "Stick",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 500,
            fileCount: 10,
            folderCount: 5,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            completedDepth: 5,
            isForgotten: false,
            indexingProgress: 1
        )
        var settings = AppSettings()
        settings.scanDepth = 2
        // bug.0.4.034: der Indexer öffnet Ordner auf Tiefe = Scan-Tiefe nicht.
        if case .uncaptured(.scanDepth) = ColumnFolderOpenState.resolve(columnIndex: 1, medium: medium, settings: settings) {
        } else {
            Issue.record("Tiefe 2 bei Scan-Tiefe 2 muss uncaptured scanDepth sein")
        }
        settings = AppSettings()
        settings.excludedPatterns = ["*.tmp"]
        if case .uncaptured(.excluded) = ColumnFolderOpenState.resolve(
            columnIndex: 0,
            medium: medium,
            settings: settings,
            folderName: "note.tmp"
        ) {
        } else {
            Issue.record("Ausgeschlossener Name muss uncaptured excluded sein")
        }
        if case .uncaptured(.unreadable) = ColumnFolderOpenState.resolve(
            columnIndex: 1,
            medium: medium,
            settings: settings,
            folderUnreadable: true
        ) {
        } else {
            Issue.record("Unreadable muss uncaptured unreadable sein")
        }
        medium.indexStatus = .indexing
        medium.completedDepth = 1
        #expect(ColumnFolderOpenState.resolve(columnIndex: 2, medium: medium, settings: AppSettings()) == .pendingIndex)
    }

    @Test @MainActor func scanDepthLinkOpensFilesTabWithScrollTarget() {
        let app = AppState()
        MediumNavigation.openSettings(appState: app, tab: .files, scrollTarget: .scanDepth)
        #expect(app.mainWindowDestination == .settings)
        #expect(app.settingsTab == .files)
        #expect(app.settingsScrollTarget == .scanDepth)
    }

    @Test func listedAtKeepsNormalEvenWhenReindexing() {
        let medium = Medium(
            id: UUID(),
            name: "Stick",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 500,
            fileCount: 1,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: nil,
            completedDepth: 0,
            isForgotten: false,
            indexingProgress: 0.1
        )
        let settings = AppSettings()
        #expect(ColumnFolderOpenState.resolve(columnIndex: 0, medium: medium, settings: settings, folderListedAt: Date()) == .normal)
    }

    @Test func indexingFrontierIsPendingNotUncaptured() {
        var medium = Medium(
            id: UUID(),
            name: "Stick",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 500,
            fileCount: 1,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            completedDepth: 2,
            isForgotten: false,
            indexingProgress: 0.4
        )
        let settings = AppSettings()
        #expect(ColumnFolderOpenState.resolve(columnIndex: 2, medium: medium, settings: settings) == .pendingIndex)
        medium.indexStatus = IndexStatus.indexed
        #expect(ColumnFolderOpenState.resolve(columnIndex: 2, medium: medium, settings: settings) == .pendingIndex)
        #expect(ColumnFolderOpenState.resolve(columnIndex: 2, medium: medium, settings: settings, folderListedAt: Date()) == .normal)
    }

    @Test func pathStackFoldersStaySelectedInTheirColumn() {
        let ceres = item("Ceres", .folder)
        let stage = item("Stage 1", .folder)
        let month = item("2026-06", .folder)
        let path = ["Ceres", "Stage 1", "2026-06"]
        var selection = ColumnSelection()
        selection.replace(id: month.id, column: 2)
        let highlight = ColumnBrowserSelectionHighlight.isRowSelected
        #expect(highlight(ceres, 0, path, selection, nil))
        #expect(highlight(stage, 1, path, selection, nil))
        #expect(highlight(month, 2, path, selection, nil))
        #expect(!highlight(ceres, 1, path, selection, nil))
    }

    @Test func twoItemsCloseTheNextColumnAndOneFolderOpensIt() {
        let folder = item("HipHop", .folder)
        let file = item("a.mp3", .file)
        let closed = ColumnPathEffect.make(columnIndex: 0, existingPath: ["Alt"], selected: [folder, file], uncapturedFolder: false)
        #expect(closed.path == [])
        let opened = ColumnPathEffect.make(columnIndex: 0, existingPath: [], selected: [folder], uncapturedFolder: false)
        #expect(opened.path == ["HipHop"])
    }

    @Test func commandAUsesOnlyVisibleRows() {
        var selection = ColumnSelection()
        let visible = [UUID(), UUID()]
        selection.selectAll(visible: visible, column: 0)
        #expect(selection.ids == visible)
    }

    @Test func favoriteBatchTurnsAllOnThenAllOff() {
        #expect(FavoriteBatch.nextValue(current: [false, true]) == true)
        #expect(FavoriteBatch.nextValue(current: [true, true]) == false)
        #expect(FavoriteBatch.nextValue(current: [false, false]) == true)
    }

    @Test func multipleMenuDisablesFinderAndSearch() {
        let targets = [target("a.mp3", .file), target("b.txt", .file)]
        let plan = ContextMenuPlan.multiple(targets: targets, favorites: [false, false], ignored: [])
        // Einträge des echten Menüs (nicht eine zweite Titelliste im Plan).
        let entries = multipleContextMenuGroups(targets, appState: AppState()).flatMap { $0 }
        #expect(entries.map(\.id) == ["finder", "favorite", "searchName", "searchExtension", "ignoreName", "ignoreType"])
        #expect(entries.map(\.title) == [
            "Im Finder anzeigen", "Als Favorit markieren", "Nach Namen suchen",
            "Nach Dateiendung suchen", "Dateinamen ignorieren", "Dateitypen ignorieren",
        ])
        #expect(!plan.finderEnabled)
        #expect(!plan.searchNameEnabled)
        #expect(!plan.searchExtensionEnabled)
        #expect(plan.favoriteEnabled)
        #expect(plan.ignoreNameEnabled)
    }

    @Test func ignoringThreeNamesAddsThenRemovesThem() {
        let added = IgnoreBatch.applying(["a", "b", "c"], to: ["x"])
        #expect(added == ["x", "a", "b", "c"])
        let removed = IgnoreBatch.applying(["a", "b", "c"], to: added)
        #expect(removed == ["x"])
    }

    @Test func extensionsCollapseToTwoPatterns() {
        let targets = [target("a.mp3", .file), target("b.mp3", .file), target("c.flac", .file)]
        #expect(IgnoreBatch.extensionPatterns(of: targets) == ["*.mp3", "*.flac"])
    }

    @Test func sizeSummarySkipsFolders() {
        let items = [item("dir", .folder), item("a.mp3", .file, size: 100), item("b.mp3", .file, size: 50)]
        #expect(ColumnSizeSummary.totalBytes(items) == 150)
        // bug.0.4.058: Text und Zahl folgen der App-Sprache; Erwartung für Deutsch fest.
        L10n.$languageOverride.withValue(.german) {
            #expect(ColumnSizeSummary.objectLine(count: 3) == "3 Objekte")
        }
    }

    @Test func footerPrefersTheSelectionCount() {
        #expect(ColumnFooterLabel.text(selectedCount: 2, visibleCount: 3, filteredCount: 1, totalCount: 3) == "2 von 3 ausgewählt")
        #expect(ColumnFooterLabel.text(selectedCount: 1, visibleCount: 3, filteredCount: 3, totalCount: 3) == "3 Objekte")
    }
}

private func makeLog() throws -> DiskIndexLog {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    return DiskIndexLog(directory: directory, byteLimit: 1024)
}

private func item(_ name: String, _ kind: IndexedItem.Kind, size: Int64? = nil) -> IndexedItem {
    IndexedItem(id: UUID(), name: name, kind: kind, parentPath: [], modifiedAt: nil, sizeBytes: size)
}

@MainActor
private func target(_ name: String, _ kind: ObjectContextTarget.Kind) -> ObjectContextTarget {
    ObjectContextTarget(id: UUID(), name: name, kind: kind, mediumID: UUID())
}

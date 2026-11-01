//
//  ColumnAutoScrollTests.swift
//  DiskArchiveTests
//
//  Aufgabe 188 b / 192 d — Scroll nach Auswahl (ohne Maus/Tinte).
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnAutoScrollTests {
    @Test func selectingFileScrollsDetailColumnIntoView() async throws {
        try await ColumnAutoScrollTestSupport.runOverflowSelectionScrollsTrailing()
    }

    @Test func selectingFileDoesNotScrollWhenColumnsAlreadyFit() async throws {
        try await ColumnAutoScrollTestSupport.runSelectionWhenAlreadyFitKeepsLeadingEdge()
    }

    @Test func liveInvalidateDoesNotScrollDetailColumn() async throws {
        try await ColumnAutoScrollTestSupport.runLiveInvalidatePreservesScrollOffset()
    }

    /// bug.0.4.087: wie in der App mit echtem Store (die Ansicht lädt ihre Spalten selbst, Regel 18).
    @Test func selectingFileScrollsDetailColumnIntoViewWithStore() async throws {
        try await ColumnAutoScrollTestSupport.runStoreSelectionScrollsTrailing(byClick: false)
    }

    /// bug.0.4.087: Klick in die Zeile (echter Weg mit Fokus der Spalte) → Details-Spalte ganz sichtbar.
    @Test func clickingFileScrollsDetailColumnIntoView() async throws {
        try await ColumnAutoScrollTestSupport.runStoreSelectionScrollsTrailing(byClick: true)
    }

    /// bug.0.4.087/090: Eine andere Spalte (Wurzel) hängt im Ladehinweis wie beim Nutzer nach Ignorieren/Freigeben.
    /// Die Details-Spalte richtet sich nur nach der Spalte der Auswahl: sie erscheint und wird eingescrollt.
    @Test func clickingFileShowsDetailEvenIfAnotherColumnShowsLoadingHint() async throws {
        try await ColumnAutoScrollTestSupport.runStoreSelectionScrollsTrailing(byClick: true, stuckRootHint: true)
    }

    /// bug.0.4.087: dauerhafte Rollbalken (Maus angeschlossen, wie beim Nutzer) – Klick scrollt trotzdem.
    @Test func clickingFileScrollsDetailColumnIntoViewWithLegacyScrollers() async throws {
        try await ColumnAutoScrollTestSupport.runStoreSelectionScrollsTrailing(byClick: true, legacyScrollers: true)
    }
}
}

@MainActor
enum ColumnAutoScrollTestSupport {
    static func runOverflowSelectionScrollsTrailing() async throws {
        let app = deepColumnApp()
        // 4 Ordnerspalten à 230 pt = 920 pt: 1040 − 200 (Seitenleiste) lässt echten Überlauf ohne Detail-Spalte (199).
        let size = CGSize(width: 1040, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["A", "B", "C"])
        scrollMainHorizontalToLeading(in: session.window)
        // bug.0.3.8.007: auf den linken Rand warten statt fester 200 ms (Last bei Parallel-Lauf).
        let atLeading = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return scroll.documentVisibleRect.minX <= 1.5
        }
        #expect(atLeading)
        let scroll = try #require(mainColumnHorizontalScroll(in: session.window))
        #expect(scroll.documentVisibleRect.minX <= 1.5)
        #expect(!detailTrailingFlushWithViewport(scroll))
        let file = try #require(app.indexRepository.children(mediumID: mediumID, path: ["A", "B", "C"]).first { !$0.isFolder })
        // bug.0.4.148 (e): derselbe Weg wie Klick/Taste (`commitColumnSelection` erhöht den Auftrag), Regel 18.
        try ColumnAutoScrollTestSupport.commitAsUser(app, fileID: file.id, column: 3)
        // bug.0.3.8.007: Standard-Zeitgrenze (10 s) statt 0,5 s — positives Warten bricht beim Eintreten ab.
        let aligned = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return detailTrailingFlushWithViewport(scroll)
        }
        #expect(aligned)
    }

    /// Baum A/B/C mit Dateien im Store; Ansicht lädt selbst. Datei wählen → Details-Spalte ganz sichtbar.
    static func runStoreSelectionScrollsTrailing(
        byClick: Bool, legacyScrollers: Bool = false, stuckRootHint: Bool = false
    ) async throws {
        let fileCount = 5
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-autoscroll-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Tief", decision: .index, indexStatus: .indexed, completedDepth: 5)
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))
        var parent: Int64?
        for (depth, name) in ["A", "B", "C"].enumerated() {
            try await store.applyDirectory(
                mediumUUID: stored.uuid, parentID: parent,
                entries: [ScannedEntry(name: name, isFolder: true)] + (depth == 0 ? [] : [ScannedEntry(name: "x\(depth).txt", isFolder: false, sizeBytes: 1)]),
                seenAt: Date()
            )
            let rows = try await store.children(mediumUUID: stored.uuid, parentID: parent)
            parent = try #require(rows.first { $0.name == name }).id
        }
        try await store.applyDirectory(
            mediumUUID: stored.uuid, parentID: parent,
            entries: (1...fileCount).map { ScannedEntry(name: "ziel\($0).txt", isFolder: false, sizeBytes: 1, modifiedAt: Date()) },
            seenAt: Date()
        )
        let app = AppState()
        app.attach(store: store)
        defer { app.prepareForTermination() }
        await app.loadStoredMedia()
        app.columnBrowserState.selectedMediumID = stored.uuid
        app.columnBrowserState.pathStack = ["A", "B", "C"]
        let size = CGSize(width: 1040, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let loaded = await waitUntil {
            !app.indexRepository.children(mediumID: stored.uuid, path: ["A", "B", "C"]).isEmpty
        }
        try #require(loaded, "Spalte C nicht geladen")
        try await Task.sleep(for: .milliseconds(600))
        if legacyScrollers {
            for scroll in allViews(of: NSScrollView.self, in: session.window.contentView) { scroll.scrollerStyle = .legacy }
            session.window.contentView?.layoutSubtreeIfNeeded()
        }
        if stuckRootHint {
            // Zustand des Nutzers: der Ladehinweis der Wurzelspalte wurde nie zurückgenommen.
            app.columnBrowserState.setLoadingHintVisible(true, mediumID: stored.uuid, path: [])
        }
        scrollMainHorizontalToLeading(in: session.window)
        let atLeading = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return scroll.documentVisibleRect.minX <= 1.5
        }
        try #require(atLeading, "nicht am linken Rand")
        let file = try #require(app.indexRepository.children(mediumID: stored.uuid, path: ["A", "B", "C"]).first { !$0.isFolder })
        if byClick {
            // Erste Zeile der Spalte C (Index 3, links sichtbar bis zum Fensterrand): Kopf, dann Zeilen ab oben.
            let columnLeft = DesignSpacing.columnBrowserSidebarWidth + 3 * DesignSpacing.columnBrowserColumnWidth
            let point = CGPoint(x: min(columnLeft + 40, size.width - 20), y: firstRowY)
            session.click(at: point, settle: 0.05)
            let selected = await waitUntil(timeout: 3) { app.columnBrowserState.selection.ids == [file.id] }
            try #require(selected, "Klick bei \(point) wählte die Datei nicht: \(app.columnBrowserState.selection.ids)")
        } else {
            // bug.0.4.148 (e): derselbe Weg wie Klick/Taste (`commitColumnSelection` erhöht den Auftrag), Regel 18.
            try ColumnAutoScrollTestSupport.commitAsUser(app, fileID: file.id, column: 3)
        }
        let aligned = await waitUntil(timeout: 3) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return detailTrailingFlushWithViewport(scroll) && scroll.documentVisibleRect.minX > 1.5
        }
        let scroll = mainColumnHorizontalScroll(in: session.window)
        #expect(aligned, "Details-Spalte nicht in die Sicht gescrollt: sichtbar \(String(describing: scroll?.documentVisibleRect)), Dokument \(String(describing: scroll?.documentView?.frame.width))")
    }

    static func runSelectionWhenAlreadyFitKeepsLeadingEdge() async throws {
        let app = shallowColumnApp()
        let size = CGSize(width: 1800, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["A"])
        let file = try #require(app.indexRepository.children(mediumID: mediumID, path: ["A"]).first { !$0.isFolder })
        let before = horizontalScrollLeadingOffset(in: session.window)
        // bug.0.4.148 (e): derselbe Weg wie Klick/Taste (`commitColumnSelection` erhöht den Auftrag), Regel 18.
        try ColumnAutoScrollTestSupport.commitAsUser(app, fileID: file.id, column: 1)
        try await Task.sleep(for: .milliseconds(450))
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let after = horizontalScrollLeadingOffset(in: session.window)
        #expect(abs(before - after) <= 1)
    }

    static func runLiveInvalidatePreservesScrollOffset() async throws {
        let app = deepColumnApp()
        let size = CGSize(width: 1120, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["A", "B", "C"])
        let file = try #require(app.indexRepository.children(mediumID: mediumID, path: ["A", "B", "C"]).first { !$0.isFolder })
        // bug.0.4.148 (e): derselbe Weg wie Klick/Taste (`commitColumnSelection` erhöht den Auftrag), Regel 18.
        try ColumnAutoScrollTestSupport.commitAsUser(app, fileID: file.id, column: 3)
        // bug.0.3.8.007: Standard-Zeitgrenze (10 s) statt 0,5 s — positives Warten bricht beim Eintreten ab.
        let aligned = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = mainColumnHorizontalScroll(in: session.window) else { return false }
            return detailTrailingFlushWithViewport(scroll)
        }
        #expect(aligned)
        let scroll = try #require(mainColumnHorizontalScroll(in: session.window))
        let anchor = scroll.documentVisibleRect.minX
        app.indexRepository.invalidate(mediumID)
        try await Task.sleep(for: .milliseconds(300))
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let after = scroll.documentVisibleRect.minX
        #expect(abs(anchor - after) <= 1)
    }

    /// Mitte der ersten Zeile einer Spalte (pt von oben, im Fenster abgetastet: Zeile ab 56 pt).
    static let firstRowY: CGFloat = 62

    static func allViews<T: NSView>(of type: T.Type, in root: NSView?) -> [T] {
        guard let root else { return [] }
        var found: [T] = []
        func walk(_ view: NSView) {
            if let match = view as? T { found.append(match) }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return found
    }

    /// bug.0.4.148 (e): Auswahl wie ein Klick auf die Zeile setzen (`commitColumnSelection`, neuer Scroll-Auftrag).
    @MainActor
    static func commitAsUser(_ app: AppState, fileID: UUID, column: Int) throws {
        let mediumID = try #require(app.columnBrowserState.selectedMediumID)
        let medium = try #require(app.media.first { $0.id == mediumID })
        let path = Array(app.columnBrowserState.pathStack.prefix(column))
        let items = app.indexRepository.children(mediumID: mediumID, path: path)
        app.commitColumnSelection(
            ColumnSelection(ids: [fileID], anchorID: fileID, focusColumnIndex: column, lastClickedID: fileID),
            items: items, columnIndex: column, medium: medium
        )
    }

    static func detailTrailingFlushWithViewport(_ scroll: NSScrollView) -> Bool {
        let docWidth = scroll.documentView?.frame.width ?? 0
        guard docWidth > scroll.bounds.width + 1 else { return true }
        let visible = scroll.documentVisibleRect
        return docWidth - visible.maxX <= 1
    }

    static func horizontalScrollLeadingOffset(in window: NSWindow) -> CGFloat {
        mainColumnHorizontalScroll(in: window)?.documentVisibleRect.minX ?? 0
    }

    static func mainColumnHorizontalScroll(in window: NSWindow) -> NSScrollView? {
        guard let root = window.contentView else { return nil }
        var best: (scroll: NSScrollView, docWidth: CGFloat)?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let docW = scroll.documentView?.frame.width ?? 0
                if docW > scroll.bounds.width + 20 {
                    // bug.0.3.8.007: ohne `!` (Regel 20).
                    if docW > (best?.docWidth ?? -1) {
                        best = (scroll, docW)
                    }
                }
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return best?.scroll
    }

    static func scrollMainHorizontalToLeading(in window: NSWindow) {
        guard let scroll = mainColumnHorizontalScroll(in: window) else { return }
        let clip = scroll.contentView
        var origin = clip.bounds.origin
        origin.x = 0
        clip.scroll(to: origin)
        scroll.reflectScrolledClipView(clip)
        window.display()
    }

    static func deepColumnApp() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID,
            name: "Deep",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 1,
            folderCount: 3,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 5
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["A", "B", "C"]
        seedDeep(app: app, mediumID: mediumID)
        return app
    }

    static func shallowColumnApp() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        let medium = Medium(
            id: mediumID,
            name: "Shallow",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 1,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["A"]
        app.indexRepository.seedScreenshotCache(
            mediumID: mediumID,
            entries: [([], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 1), rowID: 1, name: "A", kind: .folder, parentPath: [], modifiedAt: Date(), sizeBytes: 0, listedAt: Date()),
            ]), (["A"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 2), rowID: 2, name: "eins.txt", kind: .file, parentPath: ["A"], modifiedAt: Date(), sizeBytes: 1, listedAt: Date()),
            ])]
        )
        return app
    }

    static func seedDeep(app: AppState, mediumID: UUID) {
        let root: [( [String], [IndexedItem])] = [
            ([], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 1), rowID: 1, name: "A", kind: .folder, parentPath: [], modifiedAt: Date(), sizeBytes: 0, listedAt: Date()),
            ]),
            (["A"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 2), rowID: 2, name: "B", kind: .folder, parentPath: ["A"], modifiedAt: Date(), sizeBytes: 0, listedAt: Date()),
            ]),
            (["A", "B"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 3), rowID: 3, name: "C", kind: .folder, parentPath: ["A", "B"], modifiedAt: Date(), sizeBytes: 0, listedAt: Date()),
            ]),
            (["A", "B", "C"], [
                IndexedItem(id: IndexedItem.stableID(mediumID: mediumID, rowID: 4), rowID: 4, name: "ziel.txt", kind: .file, parentPath: ["A", "B", "C"], modifiedAt: Date(), sizeBytes: 1, listedAt: Date()),
            ]),
        ]
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: root)
    }
}

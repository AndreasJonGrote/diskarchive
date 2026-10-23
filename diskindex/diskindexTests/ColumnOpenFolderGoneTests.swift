//
//  ColumnOpenFolderGoneTests.swift
//  diskindexTests
//
//  bug.0.4.131: Gelöschter oder umbenannter offener Ordner. Löschen → `pathStack` ab dieser Ebene gekürzt, Auswahl auf
//  den Elternordner; Umbenennung → Pfad folgt dem neuen Namen, Auswahl bleibt. Regel 18: nur die Store-Änderung über
//  den echten Änderungsweg (`applyDirectory` bzw. `applyLiveRename` wie die Überwachung), dann warten und lesen.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private func openFolderFixture(mount: URL) async throws -> (app: AppState, store: IndexStoreV3, medium: StoredMedium) {
    let database = try TestDatabase(fileURL: mount.deletingLastPathComponent().appendingPathComponent("archive.sqlite"))
    let store = IndexStoreV3(database: database)
    let app = AppState(store: store)
    app.startChangeLoop()
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await store.upsertMedium(medium)
    medium = try #require(try await store.medium(uuid: medium.uuid))
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4),
        ],
        seenAt: Date()
    )
    let alpha = try #require(try await store.children(mediumUUID: medium.uuid, parentID: nil).first { $0.name == "Alpha" })
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: alpha.id,
        entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1)],
        seenAt: Date()
    )
    await app.loadStoredMedia()
    return (app, store, medium)
}

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnOpenFolderGoneTests {
    private static let size = CGSize(width: 1280, height: 800)

    private func makeMount() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-open-gone-\(UUID().uuidString)", isDirectory: true)
        let mount = base.appendingPathComponent("BAUM", isDirectory: true)
        try FileManager.default.createDirectory(at: mount.appendingPathComponent("Alpha"), withIntermediateDirectories: true)
        return mount
    }

    private func openAlpha(_ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium)) async throws -> PixelProbe.Session {
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = tree.medium.uuid
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(tree.app)
                .environment(\.colorScheme, .light)
                .frame(width: Self.size.width, height: Self.size.height),
            size: Self.size
        )
        let rootLoaded = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).contains { $0.name == "Alpha" }
        }
        try #require(rootLoaded)
        let alpha = try #require(tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).first { $0.name == "Alpha" })
        var state = tree.app.columnBrowserState
        state.pathStack = ["Alpha"]
        state.selection = ColumnSelection(ids: [alpha.id], anchorID: alpha.id, focusColumnIndex: 0, lastClickedID: alpha.id)
        tree.app.columnBrowserState = state
        let alphaLoaded = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"]).contains { $0.name == "a.txt" }
        }
        try #require(alphaLoaded)
        return session
    }

    @Test func deletedOpenFolderTruncatesThePath() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        // Wie die Überwachung: Wurzel neu gelesen, „Alpha“ fehlt.
        try await tree.store.applyDirectory(
            mediumUUID: tree.medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4)],
            seenAt: Date()
        )
        let truncated = await waitUntil { tree.app.columnBrowserState.pathStack.isEmpty }
        #expect(truncated, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        #expect(tree.app.columnBrowserState.selection.ids.isEmpty)
    }

    // MARK: - bug.0.4.134: Live-Änderungen scrollen nicht waagerecht

    private static let narrow = CGSize(width: 560, height: 600)

    /// Schmales Fenster (waagerechter Überlauf), „Alpha“ offen, `a.txt` per Nutzeraktion gewählt → Details-Spalte bündig
    /// rechts; liefert das Fenster und die Scrollansicht.
    private func openAlphaFileNarrow(
        _ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium)
    ) async throws -> (PixelProbe.Session, NSScrollView) {
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = tree.medium.uuid
        tree.app.columnBrowserState.pathStack = ["Alpha"]
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(tree.app)
                .environment(\.colorScheme, .light)
                .frame(width: Self.narrow.width, height: Self.narrow.height),
            size: Self.narrow
        )
        let loaded = await waitUntil {
            tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
        }
        try #require(loaded)
        let items = tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"])
        let file = try #require(items.first { $0.name == "a.txt" })
        let medium = try #require(tree.app.media.first { $0.id == tree.medium.uuid })
        // Wie ein Klick auf die Zeile (Nutzeraktion, neuer Scroll-Auftrag).
        tree.app.commitColumnSelection(
            ColumnSelection(ids: [file.id], anchorID: file.id, focusColumnIndex: 1, lastClickedID: file.id),
            items: items, columnIndex: 1, medium: medium
        )
        let flush = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) else { return false }
            return scroll.documentVisibleRect.minX > 1 && ColumnAutoScrollTestSupport.detailTrailingFlushWithViewport(scroll)
        }
        try #require(flush, "Details-Spalte nach der Auswahl nicht bündig (kein Überlauf?)")
        let scroll = try #require(ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window))
        // Auftrag erledigt erst, wenn die Spalte der Auswahl geladen ist und keinen Ladehinweis mehr zeigt – darauf
        // warten (positives Signal), dann die Ruhezeit des Auftrags (300 ms) mit Reserve.
        let settled = await waitUntil {
            tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
                && !tree.app.columnBrowserState.loadingHintVisible(mediumID: tree.medium.uuid, path: ["Alpha"])
        }
        try #require(settled, "Spalte „Alpha“ nicht fertig")
        try await Task.sleep(for: .milliseconds(700))
        return (session, scroll)
    }

    private func renameAlphaToBeta(_ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium), mount: URL) async throws {
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("Beta"))
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("Beta").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
    }

    /// bug.0.4.134 (d): Der offene Ordner wird über den Store umbenannt (Live-Änderung) → die Ansicht bleibt stehen.
    @Test func liveRenameOfTheOpenFolderDoesNotScrollHorizontally() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let (session, scroll) = try await openAlphaFileNarrow(tree)
        defer { session.close() }
        // Etwas nach links (wie der Nutzer), damit ein Scroll nach rechts sichtbar würde.
        ColumnAutoScrollTestSupport.scrollMainHorizontalToLeading(in: session.window)
        let before = scroll.documentVisibleRect.minX
        try await renameAlphaToBeta(tree, mount: mount)
        let followed = await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] }
        try #require(followed, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        // Positives Signal: neue Spalte geladen; danach die Scroll-Animation (0,2 s) abwarten.
        try #require(await waitUntil { tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Beta"]) })
        try await Task.sleep(for: .milliseconds(500))
        session.window.contentView?.layoutSubtreeIfNeeded()
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "Live-Änderung scrollte: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    /// bug.0.4.148 (b)/134 (d): Klick auf die schon gewählte Zeile (neuer Auftrag ohne Pfad-/Auswahländerung), danach
    /// scrollt der Nutzer nach links; die nächste Live-Änderung scrollt nicht nach rechts.
    @Test func clickOnTheSelectedRowThenLiveChangeDoesNotScroll() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let (session, scroll) = try await openAlphaFileNarrow(tree)
        defer { session.close() }
        let items = tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"])
        let medium = try #require(tree.app.media.first { $0.id == tree.medium.uuid })
        let tokenBefore = tree.app.columnScrollToken
        tree.app.commitColumnSelection(tree.app.columnBrowserState.selection, items: items, columnIndex: 1, medium: medium)
        try #require(tree.app.columnScrollToken == tokenBefore + 1, "Klick erzeugte keinen Auftrag")
        try await Task.sleep(for: .milliseconds(600))
        ColumnAutoScrollTestSupport.scrollMainHorizontalToLeading(in: session.window)
        let before = scroll.documentVisibleRect.minX
        try await renameAlphaToBeta(tree, mount: mount)
        try #require(await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] })
        try #require(await waitUntil { tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Beta"]) })
        try await Task.sleep(for: .milliseconds(500))
        session.window.contentView?.layoutSubtreeIfNeeded()
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "Live-Änderung nach Klick scrollte: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    /// bug.0.4.147 / 163 (a): Pixel-Nachweis im echten Fenster – nach dem Umbenennen des offenen Ordners zeigt der Kopf
    /// seiner Spalte den neuen (viel kürzeren) Namen ohne Reste des alten, und die Spalte zeigt ihren Inhalt.
    @Test func renamedOpenFolderHeaderShowsOnlyTheNewName() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        let left = DesignSpacing.columnBrowserSidebarWidth + DesignSpacing.columnBrowserColumnWidth
        // Unter dem Offline-Hinweis (≈ 26 pt): Spaltenkopf bei ≈ 40 pt, erste Zeile bei ≈ 70 pt.
        let header = CGRect(x: left + 4, y: 32, width: DesignSpacing.columnBrowserColumnWidth - 12, height: 16)
        func headerInk() -> CGRect? {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return PixelProbe.inkBounds(in: session.bitmap(), rect: header, background: CGPoint(x: header.maxX - 2, y: 40))
        }
        let rowRect = CGRect(x: left + 4, y: 58, width: DesignSpacing.columnBrowserColumnWidth - 12, height: 24)
        let before = try #require(await waitUntil { (headerInk()?.width ?? 0) > 20 } ? headerInk() : nil, "Kopf „Alpha“ ohne Tinte")
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("B"))
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("B").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
        try #require(await waitUntil { tree.app.columnBrowserState.pathStack == ["B"] })
        // Kopf: nur noch „B“ (schmale Tinte, deutlich schmaler als „Alpha“), keine alte Tinte daneben.
        let narrowed = await waitUntil {
            guard let ink = headerInk() else { return false }
            return ink.width > 2 && ink.width < before.width * 0.6
        }
        #expect(narrowed, "Kopf zeigt nicht nur den neuen Namen: vorher \(before.width), jetzt \(headerInk()?.width ?? -1)")
        // Inhalt der Spalte (a.txt) gezeichnet.
        let rowInk = await waitUntil {
            PixelProbe.inkBounds(in: session.bitmap(), rect: rowRect, background: CGPoint(x: rowRect.maxX - 2, y: 60)) != nil
        }
        #expect(rowInk, "Spalte „B“ ohne Inhalt")
    }

    @Test func renamedOpenFolderFollowsTheNewName() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        let selected = tree.app.columnBrowserState.selection.ids
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("Beta"))
        // Wie die Überwachung bei einem Umbenennen-Paar.
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("Beta").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
        let followed = await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] }
        #expect(followed, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        #expect(tree.app.columnBrowserState.selection.ids == selected, "Auswahl verloren")
        let contents = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Beta"]).contains { $0.name == "a.txt" }
        }
        #expect(contents, "Spalte „Beta“ zeigt den Inhalt nicht")
    }
}
}

//
//  ColumnOpenAtSelectionTests.swift
//  diskindexTests
//
//  bug.0.4.132 (README 1 und „Automatisch nach rechts“): Ein Treffer öffnet die Spaltenansicht an der Stelle
//  (waagerecht: Details-Spalte bündig rechts; senkrecht: gewählte Zeile sichtbar), Pfeiltasten scrollen mit.
//  Fenster außerhalb des Bildschirms (Regel 19), Tasten über `window.sendEvent` an das eigene Fenster (Regel 21).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private struct DeepFolder {
    let app: AppState
    let mediumID: UUID
    let files: [StoredItem]
    let store: IndexStoreV3

    /// Pfad A/B/C/D, in D 300 Dateien.
    static func make() async throws -> DeepFolder {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-open-at-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Tief", decision: .index, indexStatus: .indexed, completedDepth: 5)
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))
        var parent: Int64?
        for name in ["A", "B", "C", "D"] {
            try await store.applyDirectory(mediumUUID: stored.uuid, parentID: parent, entries: [ScannedEntry(name: name, isFolder: true)], seenAt: Date())
            parent = try #require(try await store.children(mediumUUID: stored.uuid, parentID: parent).first { $0.name == name }).id
        }
        try await store.applyDirectory(
            mediumUUID: stored.uuid,
            parentID: parent,
            entries: (1...300).map { ScannedEntry(name: String(format: "datei-%03d.txt", $0), isFolder: false, sizeBytes: 1, modifiedAt: Date()) },
            seenAt: Date()
        )
        let files = try await store.children(mediumUUID: stored.uuid, parentID: parent).sorted { $0.name < $1.name }
        let app = AppState()
        app.attach(store: store)
        await app.loadStoredMedia()
        return DeepFolder(app: app, mediumID: stored.uuid, files: files, store: store)
    }
}

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnOpenAtSelectionTests {
    private static let size = CGSize(width: 1040, height: 600)

    private func open(_ app: AppState, tableMinimum: Int?, settle: Duration = .milliseconds(300)) -> PixelProbe.Session {
        let view = ColumnBrowserView()
            .environment(app)
            .environment(\.columnScrollSettleDelay, settle)
            .environment(\.columnTableViewMinimum, tableMinimum ?? ColumnFolderListThreshold.tableViewMinimum)
            .environment(\.colorScheme, .light)
            .frame(width: Self.size.width, height: Self.size.height)
        return PixelProbe.open(view, size: Self.size, appearance: .aqua)
    }

    @Test func openObjectScrollsToTheFileInList() async throws {
        try await runOpenObject(tableMinimum: nil)
    }

    @Test func openObjectScrollsToTheFileInTable() async throws {
        try await runOpenObject(tableMinimum: 10)
    }

    @Test func arrowKeysKeepTheSelectionVisibleInList() async throws {
        try await runArrowKeys(tableMinimum: nil)
    }

    @Test func arrowKeysKeepTheSelectionVisibleInTable() async throws {
        try await runArrowKeys(tableMinimum: 10)
    }

    private func runOpenObject(tableMinimum: Int?) async throws {
        let tree = try await DeepFolder.make()
        try #require(tree.files.count == 300)
        let target = tree.files[249]
        let result = SearchResultItem(item: IndexedItem(stored: target, parentPath: ["A", "B", "C", "D"]), mediumID: tree.mediumID)
        // Wie aus der Suche: Pfad und Auswahl stehen, bevor die Spaltenansicht entsteht.
        MediumNavigation.openObject(result, appState: tree.app)
        let session = open(tree.app, tableMinimum: tableMinimum)
        defer { session.close() }
        let shown = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) else { return false }
            return ColumnAutoScrollTestSupport.detailTrailingFlushWithViewport(main)
                && main.documentVisibleRect.minX > 1.5
                && Self.rowVisible(index: 249, of: 300, in: session.window)
        }
        let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window)
        #expect(shown, "nicht an der Stelle: waagerecht \(String(describing: main?.documentVisibleRect)) von Breite \(main?.documentView?.frame.width ?? -1), Zeile sichtbar \(Self.rowVisible(index: 249, of: 300, in: session.window))")
    }

    /// bug.0.4.168: Ein anderes Medium schreibt fortlaufend Stapel (laufende Indizierung, Meldungen kommen in der App an);
    /// ein Treffer öffnet die Spaltenansicht → der Auftrag bleibt offen, bis die Spalte steht: Details-Spalte bündig,
    /// Zeile sichtbar. Fremde Meldungen beenden den Auftrag nicht.
    @Test func openObjectWhileAnotherMediumIndexesScrollsToTheFile() async throws {
        let tree = try await DeepFolder.make()
        try #require(tree.files.count == 300)
        tree.app.startChangeLoop()
        let other = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Andere", decision: .index, indexStatus: .indexing, completedDepth: 0)
        try await tree.store.upsertMedium(other)
        let store = tree.store
        let otherID = other.uuid
        let writer = Task {
            var batch = 0
            while !Task.isCancelled {
                batch += 1
                try? await store.applyDirectory(
                    mediumUUID: otherID, parentID: nil,
                    entries: [ScannedEntry(name: "stapel-\(batch).txt", isFolder: false, sizeBytes: 1)], seenAt: Date()
                )
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        defer { writer.cancel() }
        // Positives Signal: die Meldungen des anderen Mediums kommen in der App an.
        let start = tree.app.lastChangeGeneration
        try #require(await waitUntil { tree.app.lastChangeGeneration > start + 2 }, "keine Meldungen des anderen Mediums")
        let target = tree.files[249]
        let result = SearchResultItem(item: IndexedItem(stored: target, parentPath: ["A", "B", "C", "D"]), mediumID: tree.mediumID)
        MediumNavigation.openObject(result, appState: tree.app)
        let session = open(tree.app, tableMinimum: 10)
        defer { session.close() }
        let shown = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) else { return false }
            return ColumnAutoScrollTestSupport.detailTrailingFlushWithViewport(main)
                && main.documentVisibleRect.minX > 1.5
                && Self.rowVisible(index: 249, of: 300, in: session.window)
        }
        let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window)
        #expect(shown, "Auftrag brach während fremder Schreibvorgänge ab: waagerecht \(String(describing: main?.documentVisibleRect)) von Breite \(main?.documentView?.frame.width ?? -1)")
    }

    /// bug.0.4.173: Der Ordner D liegt schon im Cache, die Datei des Treffers kam erst danach hinzu (laufende Indizierung)
    /// → beim Öffnen fehlt sie in der zwischengespeicherten Spalte. D lädt neu und enthält sie → Details-Spalte bündig,
    /// Zeile sichtbar (der Auftrag merkt sich keine leere Namensliste).
    @Test func openObjectOfAFileMissingInTheCachedColumnScrollsAfterReload() async throws {
        let tree = try await DeepFolder.make()
        try #require(tree.files.count == 300)
        let path = ["A", "B", "C", "D"]
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.mediumID, path: path)
        try #require(tree.app.indexRepository.hasLoadedChildren(mediumID: tree.mediumID, path: path), "D nicht im Cache")
        let folderD = try #require(try await tree.store.folderID(mediumUUID: tree.mediumID, path: path))
        let names = (1...300).map { String(format: "datei-%03d.txt", $0) } + ["datei-301.txt"]
        try await tree.store.applyDirectory(
            mediumUUID: tree.mediumID, parentID: folderD,
            entries: names.map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }, seenAt: Date()
        )
        let added = try #require(try await tree.store.children(mediumUUID: tree.mediumID, parentID: folderD).first { $0.name == "datei-301.txt" })
        try #require(!tree.app.indexRepository.children(mediumID: tree.mediumID, path: path).contains { $0.name == "datei-301.txt" },
                     "Voraussetzung: Datei fehlt im Cache")
        let result = SearchResultItem(item: IndexedItem(stored: added, parentPath: path), mediumID: tree.mediumID)
        MediumNavigation.openObject(result, appState: tree.app)
        // bug.0.4.180 (a): Ruhezeit großzügig – das Neuladen unten fällt sicher in den offenen Auftrag.
        let session = open(tree.app, tableMinimum: 10, settle: .seconds(5))
        defer { session.close() }
        // Positives Signal: die Ansicht steht mit der alten Spalte (Auftrag läuft), dann lädt D neu.
        try #require(await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            return ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) != nil
        })
        tree.app.indexRepository.invalidate(mediumID: tree.mediumID, path: path)
        let shown = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) else { return false }
            return ColumnAutoScrollTestSupport.detailTrailingFlushWithViewport(main)
                && main.documentVisibleRect.minX > 1.5
                && Self.rowVisible(index: 300, of: 301, in: session.window)
        }
        let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window)
        #expect(shown, "nach dem Neuladen nicht an der Stelle: waagerecht \(String(describing: main?.documentVisibleRect)) von Breite \(main?.documentView?.frame.width ?? -1)")
    }

    /// bug.0.4.180 (b): Mehrfachauswahl, von der nur ein Teil in der zwischengespeicherten Spalte steht – der Auftrag
    /// merkt sich die unvollständige Namensliste nicht; nach dem Neuladen (beide da) wird zur Stelle gescrollt.
    @Test func multiSelectionPartlyMissingInTheCachedColumnScrollsAfterReload() async throws {
        let tree = try await DeepFolder.make()
        try #require(tree.files.count == 300)
        let path = ["A", "B", "C", "D"]
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.mediumID, path: path)
        let folderD = try #require(try await tree.store.folderID(mediumUUID: tree.mediumID, path: path))
        let names = (1...300).map { String(format: "datei-%03d.txt", $0) } + ["datei-301.txt"]
        try await tree.store.applyDirectory(
            mediumUUID: tree.mediumID, parentID: folderD,
            entries: names.map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }, seenAt: Date()
        )
        let added = try #require(try await tree.store.children(mediumUUID: tree.mediumID, parentID: folderD).first { $0.name == "datei-301.txt" })
        let present = try #require(tree.files.last)
        let result = SearchResultItem(item: IndexedItem(stored: added, parentPath: path), mediumID: tree.mediumID)
        MediumNavigation.openObject(result, appState: tree.app)
        // Zweite Datei (im Cache vorhanden) dazu: Auswahl aus einer fehlenden und einer vorhandenen Zeile.
        let addedID = IndexedItem(stored: added, parentPath: path).id
        let presentID = IndexedItem(stored: present, parentPath: path).id
        tree.app.columnBrowserState.selection = ColumnSelection(
            ids: [presentID, addedID], anchorID: presentID, focusColumnIndex: path.count, lastClickedID: addedID
        )
        let session = open(tree.app, tableMinimum: 10, settle: .seconds(5))
        defer { session.close() }
        try #require(await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            return ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) != nil
        })
        tree.app.indexRepository.invalidate(mediumID: tree.mediumID, path: path)
        let shown = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            guard let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) else { return false }
            return ColumnAutoScrollTestSupport.detailTrailingFlushWithViewport(main) && main.documentVisibleRect.minX > 1.5
        }
        let main = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window)
        #expect(shown, "Mehrfachauswahl: nach dem Neuladen nicht an der Stelle: \(String(describing: main?.documentVisibleRect)) von Breite \(main?.documentView?.frame.width ?? -1)")
    }

    /// Pfeiltasten: `onKeyPress` braucht ein Key-Fenster (Regel 19/21 verbieten das, „Frage:“ im Status). Geprüft wird
    /// der Weg dahinter wie in `commit`: neue Auswahl in der Spalte + Scroll-Auftrag → Zeile 40 sichtbar.
    private func runArrowKeys(tableMinimum: Int?) async throws {
        let tree = try await DeepFolder.make()
        try #require(tree.files.count == 300)
        let first = try #require(tree.files.first)
        let result = SearchResultItem(item: IndexedItem(stored: first, parentPath: ["A", "B", "C", "D"]), mediumID: tree.mediumID)
        MediumNavigation.openObject(result, appState: tree.app)
        let session = open(tree.app, tableMinimum: tableMinimum)
        defer { session.close() }
        let ready = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            return Self.rowVisible(index: 0, of: 300, in: session.window)
        }
        try #require(ready, "Spalte D nicht geladen")
        // bug.0.4.148 (e): 40× Pfeil nach unten über die Tastenlogik in `AppState` (erhöht je Schritt den Auftrag).
        let items = tree.app.indexRepository.children(mediumID: tree.mediumID, path: ["A", "B", "C", "D"])
        let medium = try #require(tree.app.media.first { $0.id == tree.mediumID })
        for _ in 0..<40 {
            tree.app.moveColumnSelection(step: 1, extend: false, items: items, visible: items, columnIndex: 4, medium: medium)
        }
        try #require(tree.files.count > 40)
        try #require(tree.app.columnBrowserState.selection.ids == [IndexedItem(stored: tree.files[40]).id])
        let visible = await waitUntil(timeout: 5) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return Self.rowVisible(index: 40, of: 300, in: session.window)
        }
        #expect(visible, "Auswahl wanderte aus der Sicht")
    }

    /// Zeile `index` von `count` in der längsten senkrechten Liste (Spalte D) sichtbar: Tabelle über
    /// `rows(in:)`, Liste über die Lage im Dokument (gleich hohe Zeilen).
    private static func rowVisible(index: Int, of count: Int, in window: NSWindow) -> Bool {
        let tables = ColumnAutoScrollTestSupport.allViews(of: NSTableView.self, in: window.contentView)
        if let table = tables.max(by: { $0.numberOfRows < $1.numberOfRows }), table.numberOfRows == count {
            let range = table.rows(in: table.visibleRect)
            return range.location <= index && index < range.location + range.length
        }
        let scrolls = ColumnAutoScrollTestSupport.allViews(of: NSScrollView.self, in: window.contentView)
        guard let list = scrolls.max(by: { ($0.documentView?.frame.height ?? 0) < ($1.documentView?.frame.height ?? 0) }),
              let document = list.documentView, document.frame.height > list.bounds.height + 20 else { return false }
        let pitch = document.frame.height / CGFloat(count)
        let top = CGFloat(index) * pitch
        let visible = list.documentVisibleRect
        let minY = document.isFlipped ? visible.minY : document.frame.height - visible.maxY
        return minY <= top && top + pitch * 0.8 <= minY + visible.height
    }
}
}


//
//  ColumnArrowNavigationTests.swift
//  DiskArchiveTests
//
//  bug.0.4.213 — ← und → in der Spaltenansicht wie im Finder (Konzept `suche-navigation.md`, „Navigation wie im Finder“):
//  → öffnet den einzeln gewählten Ordner und wählt dessen ersten Eintrag; ← wählt den Elternordner und schließt die
//  Spalten rechts davon. Datei und Mehrfachauswahl: → tut nichts. Derselbe Weg wie ↑/↓ (`AppState`, die Ansicht ruft ihn
//  aus `onKeyPress` auf), Spalten aus dem echten Store geladen.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
@Suite(.serialized)
struct ColumnArrowNavigationTests {
    @MainActor
    private struct Tree {
        let app: AppState
        let medium: Medium

        var state: ColumnBrowserState { app.columnBrowserState }

        func items(_ path: [String]) -> [IndexedItem] {
            app.indexRepository.children(mediumID: medium.id, path: path)
        }

        func id(_ name: String, in path: [String]) throws -> UUID {
            try #require(items(path).first { $0.name == name }, "\(name) fehlt in \(path)").id
        }

        func select(_ names: [String], in path: [String]) throws {
            var selection = ColumnSelection()
            for (index, name) in names.enumerated() {
                let id = try id(name, in: path)
                if index == 0 { selection.replace(id: id, column: path.count) } else { selection.commandClick(id: id, column: path.count) }
            }
            app.commitColumnSelection(selection, items: items(path), columnIndex: path.count, medium: medium)
        }

        func right(_ column: Int) -> Int? {
            app.openColumnSelection(columnIndex: column, items: items(Array(state.pathStack.prefix(column))), medium: medium)
        }

        func left(_ column: Int) -> Int? {
            app.selectColumnParent(columnIndex: column, medium: medium)
        }

        func down(_ column: Int) {
            let path = Array(state.pathStack.prefix(column))
            app.moveColumnSelection(step: 1, extend: false, items: items(path), visible: items(path), columnIndex: column, medium: medium)
        }
    }

    /// Wurzel: Alpha/ (a.txt, Sub/ mit Deep/ (d.txt) und s.txt), z.txt. Alle Spalten geladen.
    private static func tree() async throws -> Tree {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-arrows-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 6)
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))
        func apply(_ parent: Int64?, _ entries: [ScannedEntry]) async throws -> [StoredItem] {
            try await store.applyDirectory(mediumUUID: stored.uuid, parentID: parent, entries: entries, seenAt: Date())
            return try await store.children(mediumUUID: stored.uuid, parentID: parent)
        }
        let root = try await apply(nil, [ScannedEntry(name: "Alpha", isFolder: true), ScannedEntry(name: "z.txt", isFolder: false, sizeBytes: 1)])
        let alpha = try await apply(try #require(root.first { $0.name == "Alpha" }).id, [
            ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1), ScannedEntry(name: "Sub", isFolder: true),
        ])
        let sub = try await apply(try #require(alpha.first { $0.name == "Sub" }).id, [
            ScannedEntry(name: "Deep", isFolder: true), ScannedEntry(name: "s.txt", isFolder: false, sizeBytes: 1),
        ])
        _ = try await apply(try #require(sub.first { $0.name == "Deep" }).id, [ScannedEntry(name: "d.txt", isFolder: false, sizeBytes: 1)])
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.columnBrowserState.selectedMediumID = stored.uuid
        for path in [[], ["Alpha"], ["Alpha", "Sub"], ["Alpha", "Sub", "Deep"]] {
            _ = await app.indexRepository.loadChildren(mediumID: stored.uuid, path: path)
        }
        let medium = try #require(app.media.first { $0.id == stored.uuid })
        return Tree(app: app, medium: medium)
    }

    /// → auf Ordner, ↓, → tiefer, ← zurück (rechte Spalten zu), ← bis zur Wurzel.
    @Test func rightOpensAndLeftGoesBack() async throws {
        let tree = try await Self.tree()
        defer { tree.app.prepareForTermination() }
        try tree.select(["Alpha"], in: [])
        #expect(tree.state.pathStack == ["Alpha"])

        #expect(tree.right(0) == 1, "→ öffnet den Ordner nicht")
        #expect(tree.state.selection.ids == [try tree.id("a.txt", in: ["Alpha"])], "erster Eintrag nicht gewählt")
        #expect(tree.state.selection.focusColumnIndex == 1)
        #expect(tree.state.pathStack == ["Alpha"])

        tree.down(1)
        #expect(tree.state.selection.ids == [try tree.id("Sub", in: ["Alpha"])], "Gegenprobe: ↓ bewegt die Auswahl nicht")
        #expect(tree.state.pathStack == ["Alpha", "Sub"])

        #expect(tree.right(1) == 2)
        #expect(tree.state.selection.ids == [try tree.id("Deep", in: ["Alpha", "Sub"])])
        #expect(tree.state.pathStack == ["Alpha", "Sub", "Deep"])

        #expect(tree.left(2) == 1, "← geht nicht zurück")
        #expect(tree.state.selection.ids == [try tree.id("Sub", in: ["Alpha"])], "Elternordner nicht gewählt")
        #expect(tree.state.selection.focusColumnIndex == 1)
        #expect(tree.state.pathStack == ["Alpha", "Sub"], "← schließt die Spalten rechts nicht: \(tree.state.pathStack)")

        #expect(tree.left(1) == 0)
        #expect(tree.state.selection.ids == [try tree.id("Alpha", in: [])])
        #expect(tree.state.pathStack == ["Alpha"])

        #expect(tree.left(0) == nil, "← in der ersten Spalte tut etwas")
        #expect(tree.state.pathStack == ["Alpha"])
    }

    /// → auf einer Datei und bei Mehrfachauswahl: nichts.
    @Test func rightOnFileOrMultipleSelectionDoesNothing() async throws {
        let tree = try await Self.tree()
        defer { tree.app.prepareForTermination() }
        try tree.select(["Alpha"], in: [])
        try tree.select(["a.txt"], in: ["Alpha"])
        let file = tree.state
        #expect(tree.right(1) == nil)
        #expect(tree.state == file, "→ auf einer Datei ändert etwas")

        try tree.select(["a.txt", "Sub"], in: ["Alpha"])
        let multiple = tree.state
        #expect(multiple.selection.ids.count == 2, "Voraussetzung: Mehrfachauswahl")
        #expect(multiple.pathStack == ["Alpha"], "Voraussetzung: rechts zu")
        #expect(tree.right(1) == nil)
        #expect(tree.state == multiple, "→ bei Mehrfachauswahl ändert etwas")
    }
}

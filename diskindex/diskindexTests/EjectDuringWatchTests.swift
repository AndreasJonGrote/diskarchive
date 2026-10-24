//
//  EjectDuringWatchTests.swift
//  diskindexTests
//
//  bug.0.4.181: Kommt nach dem Auswerfen ein Ereignis vor dem Aushängen-Ereignis, liest der stehengebliebene
//  Einhängeordner leer. Die Live-Überwachung darf dann nichts als entfernt markieren (gleiche Regel wie der Lauf,
//  bug.0.4.177); der normale Weg (wirklich geleerter Ordner auf dem eingehängten Medium) bleibt.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct EjectDuringWatchTests {
    private static let matcher = IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)

    private static func entry(_ name: String) -> ListedDirectoryEntry {
        ListedDirectoryEntry(name: name, isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil)
    }

    private static func folder(_ name: String) -> ListedDirectoryEntry {
        ListedDirectoryEntry(name: name, isDirectory: true, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: nil, modifiedAt: nil)
    }

    /// Medium „DISK“ mit A/a.txt (Favorit) und B/b.txt im Speicher; die Zugriffsliste spiegelt das.
    private func seeded() async throws -> (rig: WatchRig, engine: ChangeWatcherEngine, favorite: StoredItem) {
        let rig = try await watchRig()
        let a = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["A"]))
        let b = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["B"]))
        try await rig.store.applyDirectory(mediumUUID: rig.medium.uuid, parentID: a, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1)], seenAt: Date())
        try await rig.store.applyDirectory(mediumUUID: rig.medium.uuid, parentID: b, entries: [ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 1)], seenAt: Date())
        let favorite = try #require(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: a).first)
        try await rig.store.setFavorite(itemID: favorite.id, true)
        return (rig, ChangeWatcherEngine(store: rig.store, access: rig.access), favorite)
    }

    private func visibleNames(_ rig: WatchRig) async throws -> Set<String> {
        var names = Set<String>()
        for path in [[], ["A"], ["B"]] as [[String]] {
            let parent: Int64? = path.isEmpty ? nil : try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: path)
            names.formUnion(try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: parent).map(\.name))
        }
        return names
    }

    private func process(_ engine: ChangeWatcherEngine, _ rig: WatchRig, _ directory: String) async -> ChangeWatcherEngine.Outcome {
        await engine.processPending(
            mediumID: rig.medium.uuid, mount: "/Volumes/DISK", directories: [directory], matcher: Self.matcher, maxDepth: nil
        )
    }

    /// (1) Ereignis für die Wurzel nach dem „Auswerfen“: die Wurzel liest leer → nichts entfernt, Favorit sichtbar.
    @Test func rootEventAfterEjectRemovesNothing() async throws {
        let (rig, engine, favorite) = try await seeded()
        rig.access.mounted = false
        let outcome = await process(engine, rig, "/Volumes/DISK")
        #expect(outcome == .deferred)
        #expect(try await visibleNames(rig).isSuperset(of: ["A", "B", "a.txt", "b.txt"]), "Einträge nach Auswurf entfernt")
        #expect(try await rig.store.favoriteItemIDs().contains(favorite.id))
        #expect(rig.access.mountChecks >= 1, "Positives Signal: die Prüfung lief")
    }

    /// (2) Dasselbe für einen Unterordner.
    @Test func folderEventAfterEjectRemovesNothing() async throws {
        let (rig, engine, favorite) = try await seeded()
        rig.access.mounted = false
        let outcome = await process(engine, rig, "/Volumes/DISK/A")
        #expect(outcome == .deferred)
        #expect(try await visibleNames(rig).contains("a.txt"), "Datei nach Auswurf entfernt")
        #expect(try await rig.store.favoriteItemIDs().contains(favorite.id))
    }

    /// (3) Gegenprobe: wirklich geleerter Ordner auf dem eingehängten Medium → Einträge werden entfernt.
    @Test func reallyEmptiedFolderOnTheMountedMediumIsRemoved() async throws {
        let (rig, engine, _) = try await seeded()
        let outcome = await process(engine, rig, "/Volumes/DISK/B")
        #expect(outcome == .ok)
        #expect(!(try await visibleNames(rig)).contains("b.txt"), "geleerter Ordner behielt seinen Inhalt")
    }

    /// (4) Ereignis nach dem Auswerfen, dann Wiedereinhängen und erneutes Lesen → nichts gelöscht, Favorit bleibt.
    @Test func remountAfterTheEventKeepsEverything() async throws {
        let (rig, engine, favorite) = try await seeded()
        rig.access.mounted = false
        _ = await process(engine, rig, "/Volumes/DISK")
        rig.access.mounted = true
        rig.access.listings["/Volumes/DISK"] = [Self.folder("A"), Self.folder("B")]
        rig.access.listings["/Volumes/DISK/A"] = [Self.entry("a.txt")]
        rig.access.listings["/Volumes/DISK/B"] = [Self.entry("b.txt")]
        let outcome = await process(engine, rig, "/Volumes/DISK")
        #expect(outcome == .ok)
        #expect(try await visibleNames(rig).isSuperset(of: ["A", "B", "a.txt", "b.txt"]))
        #expect(try await rig.store.favoriteItemIDs().contains(favorite.id))
    }

    /// bug.0.4.191 (c) (zu 187 b/189 für die Live-Überwachung): Teilt ein fremdes Medium unter dem Pfad nur einen
    /// Verwaltungsnamen mit dem bisherigen Index, wird nichts übernommen und nichts entfernt.
    @Test func foreignMediumSharingOnlyAdministrativeNamesChangesNothing() async throws {
        for shared in [".DS_Store", ".ds_store", "$RECYCLE.BIN", "Thumbs.db"] {
            let (rig, engine, favorite) = try await seeded()
            try await rig.store.applyDirectory(
                mediumUUID: rig.medium.uuid, parentID: nil,
                entries: [ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true), ScannedEntry(name: shared, isFolder: false, sizeBytes: 1)],
                seenAt: Date()
            )
            rig.access.mounted = false
            rig.access.listings["/Volumes/DISK"] = [Self.entry(shared), Self.folder("X")]
            rig.access.listings["/Volumes/DISK/X"] = [Self.entry("fremd.txt")]
            let outcome = await process(engine, rig, "/Volumes/DISK")
            #expect(outcome == .deferred, "\(shared): Ereignis des fremden Mediums nicht zurückgestellt")
            let names = try await visibleNames(rig)
            #expect(names.isSuperset(of: ["A", "B", "a.txt", "b.txt"]), "\(shared): Einträge entfernt")
            #expect(!names.contains("X"), "\(shared): Inhalt des fremden Mediums im Index")
            #expect(try await rig.store.favoriteItemIDs().contains(favorite.id))
            #expect(rig.access.mountChecks >= 1, "\(shared): Positives Signal: die Prüfung lief")
        }
    }
}

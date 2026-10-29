//
//  MovedFolderFatTests.swift
//  diskindexTests
//
//  bug.0.4.229: Ein auf FAT/exFAT verschobener Ordner behält beim Abgleich seine Kennung, und alles darin behält seine
//  (Favoriten bleiben). Echte Dateien im Testordner, verschoben während die App nicht zusieht, dann ein Abgleich.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct MovedFolderFatTests {
    private struct Medium {
        let root: URL
        let harness: ScanHarness
        let access: DirectMediumAccess
        let volume: VolumeInfo

        func cleanUp() {
            harness.closeDatabase()
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// FAT32 wie die H4-Karte des Nutzers (`trustsFileID == false`). `files`: relativer Pfad → Größe in Bytes.
    private func makeMedium(files: [String: Int], folders: [String] = []) async throws -> Medium {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-moved-folder-\(UUID().uuidString)", isDirectory: true)
        for folder in folders {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for (path, size) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: UInt8(truncatingIfNeeded: size), count: size).write(to: url)
        }
        let harness = try await ScanHarness.make(fsType: "msdos")
        #expect(!(try await DirectoryWriterTrust.trustsFileID(harness)), "Testmedium vertraut der fileID")
        await harness.store.setMountCheckForTesting { _, _ in true }
        var access = DirectMediumAccess()
        access.mountCheck = { _, _ in true }
        return Medium(root: root, harness: harness, access: access, volume: harness.volume(at: root.path))
    }

    private func run(_ medium: Medium, fromScratch: Bool) async throws {
        let outcome = try await medium.harness.run(
            access: medium.access, maxDepth: nil, fromScratch: fromScratch, volume: medium.volume
        )
        #expect(!outcome.interrupted)
    }

    private func move(_ medium: Medium, _ from: String, to: String) throws {
        let target = medium.root.appendingPathComponent(to)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: medium.root.appendingPathComponent(from), to: target)
    }

    /// Sichtbare Einträge nach Pfad (`A/X/a.txt`).
    private func items(_ medium: Medium) async throws -> [String: StoredItem] {
        var found: [String: StoredItem] = [:]
        func walk(_ parent: Int64?, _ prefix: String) async throws {
            for child in try await medium.harness.store.children(mediumUUID: medium.harness.mediumID, parentID: parent) {
                let path = prefix.isEmpty ? child.name : prefix + "/" + child.name
                found[path] = child
                if child.isFolder { try await walk(child.id, path) }
            }
        }
        try await walk(nil, "")
        return found
    }

    private func favorite(_ medium: Medium, _ path: String, storePartial: Bool = false) async throws -> Int64 {
        let item = try #require(try await items(medium)[path], "\(path) fehlt")
        try await medium.harness.store.setFavorite(itemID: item.id, true)
        if storePartial {
            try await medium.harness.store.storePartialChecksum(itemID: item.id, mountPath: medium.root.path)
        }
        return item.id
    }

    /// Keine verschwundenen, doppelten oder verwaisten Zeilen; die Zähler des Mediums stimmen mit dem Baum überein.
    private func expectConsistent(_ medium: Medium, _ visible: [String: StoredItem]) async throws {
        let mediumUUID = medium.harness.mediumID
        let counts = try await medium.harness.store.pool.read { db -> (all: Int, gone: Int, files: Int, folders: Int) in
            let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: mediumUUID))
            let all = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE storageID = ?", arguments: [storageID]) ?? -1
            let gone = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM items WHERE storageID = ? AND status = 2", arguments: [storageID]
            ) ?? -1
            let files = try Int.fetchOne(db, sql: "SELECT fileCount FROM storages WHERE id = ?", arguments: [storageID]) ?? -1
            let folders = try Int.fetchOne(db, sql: "SELECT folderCount FROM storages WHERE id = ?", arguments: [storageID]) ?? -1
            return (all, gone, files, folders)
        }
        #expect(counts.gone == 0, "verschwundene Zeilen übrig: \(counts.gone)")
        #expect(counts.all == visible.count, "Zeilen \(counts.all), im Baum \(visible.count)")
        #expect(counts.files == visible.values.filter { !$0.isFolder }.count, "Dateizähler \(counts.files)")
        #expect(counts.folders == visible.values.filter(\.isFolder).count, "Ordnerzähler \(counts.folders)")
    }

    // MARK: - Test 1 und 2: verschoben, alles behält seine Kennung

    /// Test 1: Ordner tiefer verschoben (`A/X` → `B/X`), wie im Beleg des Nutzers: der alte Ort wird zuerst gelesen.
    @Test func folderMovedIntoSiblingKeepsAllIDsAndFavorites() async throws {
        let medium = try await makeMedium(
            files: ["A/X/a.txt": 1_100, "A/X/b.wav": 2_200, "A/X/Sub/c.txt": 3_300, "B/keep.txt": 40]
        )
        defer { medium.cleanUp() }
        try await run(medium, fromScratch: true)
        let before = try await items(medium)
        let folderFavorite = try await favorite(medium, "A/X")
        let fileFavorite = try await favorite(medium, "A/X/Sub/c.txt", storePartial: true)

        try move(medium, "A/X", to: "B/X")
        try await run(medium, fromScratch: false)

        let after = try await items(medium)
        #expect(after["A/X"] == nil)
        for (old, new) in [("A/X", "B/X"), ("A/X/a.txt", "B/X/a.txt"), ("A/X/b.wav", "B/X/b.wav"),
                           ("A/X/Sub", "B/X/Sub"), ("A/X/Sub/c.txt", "B/X/Sub/c.txt")] {
            let moved = try #require(after[new], "\(new) fehlt")
            #expect(moved.id == before[old]?.id, "\(new) hat eine neue Kennung")
        }
        #expect(after["B/X"]?.id == folderFavorite && after["B/X"]?.isFavorite == true, "Favorit auf X weg")
        #expect(after["B/X/Sub/c.txt"]?.id == fileFavorite && after["B/X/Sub/c.txt"]?.isFavorite == true,
                "Favorit auf c.txt weg")
        #expect(after["B/X"]?.parentID == after["B"]?.id)
        #expect(after["B/X/Sub/c.txt"]?.depth == 4)
        try await expectConsistent(medium, after)
    }

    /// Test 2: Ordner höher verschoben (`A/B/X` → `X`): der neue Ort wird gelesen, bevor der alte als verschwunden gilt.
    @Test func folderMovedUpToRootKeepsAllIDsAndFavorites() async throws {
        let medium = try await makeMedium(
            files: ["A/B/X/a.txt": 1_100, "A/B/X/b.wav": 2_200, "A/B/X/Sub/c.txt": 3_300, "A/keep.txt": 40]
        )
        defer { medium.cleanUp() }
        try await run(medium, fromScratch: true)
        let before = try await items(medium)
        let folderFavorite = try await favorite(medium, "A/B/X")
        let fileFavorite = try await favorite(medium, "A/B/X/Sub/c.txt", storePartial: true)

        try move(medium, "A/B/X", to: "X")
        try await run(medium, fromScratch: false)

        let after = try await items(medium)
        #expect(after["A/B/X"] == nil)
        for (old, new) in [("A/B/X", "X"), ("A/B/X/a.txt", "X/a.txt"), ("A/B/X/b.wav", "X/b.wav"),
                           ("A/B/X/Sub", "X/Sub"), ("A/B/X/Sub/c.txt", "X/Sub/c.txt")] {
            let moved = try #require(after[new], "\(new) fehlt")
            #expect(moved.id == before[old]?.id, "\(new) hat eine neue Kennung")
        }
        #expect(after["X"]?.id == folderFavorite && after["X"]?.isFavorite == true, "Favorit auf X weg")
        #expect(after["X/Sub/c.txt"]?.id == fileFavorite && after["X/Sub/c.txt"]?.isFavorite == true,
                "Favorit auf c.txt weg")
        #expect(after["X"]?.parentID == nil)
        #expect(after["X/Sub/c.txt"]?.depth == 3)
        try await expectConsistent(medium, after)
    }

    // MARK: - Test 3 bis 5: im Zweifel neu

    /// Test 3a: zwei verschwundene Ordner `X` mit gleichen Einträgen – beide neu, kein Favorit an einem falschen Ort.
    @Test func twoGoneFoldersWithSameEntriesStayNew() async throws {
        let medium = try await makeMedium(
            files: ["A/X/a.txt": 1_100, "A/X/b.wav": 2_200, "C/X/a.txt": 1_100, "C/X/b.wav": 2_200],
            folders: ["D", "E"]
        )
        defer { medium.cleanUp() }
        try await run(medium, fromScratch: true)
        let before = try await items(medium)
        _ = try await favorite(medium, "A/X")

        try move(medium, "A/X", to: "D/X")
        try move(medium, "C/X", to: "E/X")
        try await run(medium, fromScratch: false)

        let after = try await items(medium)
        let oldIDs: Set<Int64?> = [before["A/X"]?.id, before["C/X"]?.id]
        #expect(!oldIDs.contains(after["D/X"]?.id), "D/X hat die Kennung eines alten X")
        #expect(!oldIDs.contains(after["E/X"]?.id), "E/X hat die Kennung eines alten X")
        #expect(after["D/X"]?.isFavorite == false && after["E/X"]?.isFavorite == false, "Favorit an einem falschen Ort")
        try await expectConsistent(medium, after)
    }

    /// Test 3b: `X` an zwei neuen Orten mit denselben Einträgen (kopiert, Original weg) – beide neu.
    @Test func folderAtTwoNewPlacesStaysNew() async throws {
        let medium = try await makeMedium(files: ["A/X/a.txt": 1_100, "A/X/b.wav": 2_200], folders: ["D", "E"])
        defer { medium.cleanUp() }
        try await run(medium, fromScratch: true)
        let before = try await items(medium)
        _ = try await favorite(medium, "A/X")

        try FileManager.default.copyItem(
            at: medium.root.appendingPathComponent("A/X"), to: medium.root.appendingPathComponent("E/X")
        )
        try move(medium, "A/X", to: "D/X")
        try await run(medium, fromScratch: false)

        let after = try await items(medium)
        #expect(after["D/X"]?.id != before["A/X"]?.id && after["E/X"]?.id != before["A/X"]?.id,
                "ein neues X hat die alte Kennung")
        #expect(after["D/X"]?.isFavorite == false && after["E/X"]?.isFavorite == false, "Favorit an einem falschen Ort")
        try await expectConsistent(medium, after)
    }

    /// Test 4: gleicher Name, aber andere Einträge – neu; leerer Ordner verschoben – neu.
    @Test func folderWithOtherEntriesOrEmptyStaysNew() async throws {
        let medium = try await makeMedium(
            files: ["A/X/a.txt": 1_100, "A/X/b.wav": 2_200, "B/keep.txt": 40], folders: ["A/Leer"]
        )
        defer { medium.cleanUp() }
        try await run(medium, fromScratch: true)
        let before = try await items(medium)
        _ = try await favorite(medium, "A/X")
        _ = try await favorite(medium, "A/Leer")

        try move(medium, "A/X", to: "B/X")
        try Data(repeating: 0x55, count: 5_500).write(to: medium.root.appendingPathComponent("B/X/neu.txt"))
        try move(medium, "A/Leer", to: "B/Leer")
        try await run(medium, fromScratch: false)

        let after = try await items(medium)
        let folder = try #require(after["B/X"])
        #expect(folder.id != before["A/X"]?.id, "X mit anderen Einträgen hat die alte Kennung")
        #expect(!folder.isFavorite)
        let empty = try #require(after["B/Leer"])
        #expect(empty.id != before["A/Leer"]?.id, "leerer Ordner hat die alte Kennung")
        #expect(!empty.isFavorite)
        try await expectConsistent(medium, after)
    }

    /// Test 5: umbenannt und verschoben – neu (wie bisher).
    @Test func folderRenamedAndMovedStaysNew() async throws {
        let medium = try await makeMedium(files: ["A/X/a.txt": 1_100, "A/X/b.wav": 2_200], folders: ["B"])
        defer { medium.cleanUp() }
        try await run(medium, fromScratch: true)
        let before = try await items(medium)
        _ = try await favorite(medium, "A/X")

        try move(medium, "A/X", to: "B/Y")
        try await run(medium, fromScratch: false)

        let after = try await items(medium)
        let renamed = try #require(after["B/Y"])
        #expect(renamed.id != before["A/X"]?.id)
        #expect(!renamed.isFavorite)
        try await expectConsistent(medium, after)
    }
}

/// Ob der Schreiber des Testmediums der `fileID` vertraut (FAT: nein).
private enum DirectoryWriterTrust {
    static func trustsFileID(_ harness: ScanHarness) async throws -> Bool {
        let mediumUUID = harness.mediumID
        return try await harness.store.pool.read { db in
            let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: mediumUUID))
            return try DirectoryWriterV3(db: db, storageID: storageID).trustsFileID
        }
    }
}

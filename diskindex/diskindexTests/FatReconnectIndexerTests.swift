//
//  FatReconnectIndexerTests.swift
//  diskindexTests
//
//  bug.0.4.015: FAT/exFAT reconnect über DirectoryIndexer + MemoryVolume (Regel 18).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct FatReconnectIndexerTests {
    private func fatHarness() async throws -> (ScanHarness, MemoryVolume) {
        let harness = try await ScanHarness.make(fsType: "msdos")
        let volume = MemoryVolume(mountPath: "/Volumes/FAT")
        return (harness, volume)
    }

    @Test func sameFolderRenameKeepsFavoriteID() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("alt.txt", size: 100)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "alt.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("alt.txt")
        _ = volume.file("neu.txt", size: 100)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "neu.txt"))
        #expect(after.id == before.id)
        #expect(after.isFavorite)
    }

    @Test func siblingFolderMoveKeepsFavoriteID() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("P/a.txt", size: 50)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "a.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("P/a.txt")
        _ = volume.file("Q/a.txt", size: 50)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "a.txt"))
        #expect(after.id == before.id)
        #expect(after.isFavorite)
    }

    @Test func moveUpToRootKeepsFavoriteID() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("A/B/x.txt", size: 77)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "x.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("A/B/x.txt")
        _ = volume.file("x.txt", size: 77)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "x.txt"))
        #expect(after.id == before.id)
        #expect(after.isFavorite)
    }

    /// bug.0.4.104: Neuer Ort eingefügt, alter Ort `status = 2`, dann Lauf unterbrochen → der nächste volle Lauf
    /// darf den Favoriten nicht mit der alten Zeile löschen.
    @Test func interruptedRunKeepsFavoriteOfMovedFile() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let volume = MemoryVolume(mountPath: "/Volumes/EXFAT")
        _ = volume.file("B/a.txt", size: 50).file("C/c.txt", size: 9)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "a.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("B/a.txt")
        _ = volume.file("A/a.txt", size: 50)
        let pool = harness.store.pool
        let outcome = try await harness.run(
            access: volume,
            maxDepth: nil,
            fromScratch: false,
            volume: vol,
            shouldHalt: {
                // Anhalten, sobald die alte Zeile als verschwunden markiert ist (neuer Ort ist dann schon eingefügt).
                let gone = (try? await pool.read { db in
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE name = 'a.txt' AND status = 2") ?? 0
                }) ?? 0
                return gone > 0 ? .pause : .none
            }
        )
        #expect(outcome.interrupted)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "a.txt"))
        #expect(after.isFavorite, "Favorit nach unterbrochenem Lauf verloren")
        let folderA = try #require(try await harness.item(named: "A"))
        #expect(after.parentID == folderA.id)
    }

    private func writeReal(_ relative: String, in root: URL, bytes: Int = 50) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    private func moveReal(_ from: String, _ to: String, in root: URL) throws {
        let target = root.appendingPathComponent(to)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: root.appendingPathComponent(from), to: target)
    }

    /// bug.0.4.141 (a) / 165 (b): Favorit mit gespeicherter Teil-Prüfsumme (FAT ohne `fileID`), Datei in anderen Ordner
    /// verschoben. Über die Schritte eines Laufs (neuer Ort zuerst, alter Ordner leer, Laufende mit Einhängepfad): die
    /// Teil-Prüfsumme kommt am Laufende von der Platte → dieselbe Zeile wandert, Favorit bleibt, keine zweite Zeile.
    /// (Ersetzt den Test über `MemoryVolume`, der den alten Ordner nicht neu las und darum nichts bewies.)
    @Test func movedFileWithStoredPartialKeepsFavoriteID() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-reconnect-ok-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeReal("B/a.txt", in: root)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("A"), withIntermediateDirectories: true)
        let (folderA, folderB, before) = try await Self.seedMovedFile(store: store, id: id, root: root)
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try #require(try await store.finishIndexing(
            mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
        ))
        let rows = try await store.children(mediumUUID: id, parentID: folderA)
        let moved = try #require(rows.first { $0.name == "a.txt" }, "a.txt fehlt im neuen Ordner")
        #expect(moved.id == before.id, "neue Zeile statt der alten (Wiederverbinden griff nicht)")
        #expect(try await store.favoriteItemIDs().contains(before.id), "Favorit verloren")
        #expect(try await store.storedNames().filter { $0 == "a.txt" }.count == 1, "doppelte Zeile")
    }

    /// bug.0.4.169: Das Lesen der Teil-Prüfsumme am Laufende läuft außerhalb der Schreibtransaktion – hängt es (langsames
    /// Medium), kommt ein anderer Schreiber (Favorit umschalten) in der Zwischenzeit durch.
    @Test func blockedPartialReadDoesNotBlockOtherWriters() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-read-outside-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeReal("B/a.txt", in: root)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("A"), withIntermediateDirectories: true)
        let (folderA, folderB, _) = try await Self.seedMovedFile(store: store, id: id, root: root)
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [
            ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true),
            ScannedEntry(name: "anderes.txt", isFolder: false, sizeBytes: 3),
        ], seenAt: Date())
        let otherItem = try #require(try await store.children(mediumUUID: id, parentID: nil).first { $0.name == "anderes.txt" })
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        let blocker = ReadBlocker()
        await store.setPartialReadHookForTesting { _ in blocker.blockOnce() }
        let finishing = Task {
            try await store.finishIndexing(
                mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
            )
        }
        let entered = await waitUntil { blocker.entered }
        try #require(entered, "Lesen am Laufende fand nicht statt")
        let done = ReadBlocker()
        let writer = Task {
            try await store.setFavorite(itemID: otherItem.id, true)
            done.markEntered()
        }
        let through = await waitUntil(timeout: 3) { done.entered }
        blocker.release()
        _ = try await finishing.value
        try await writer.value
        #expect(through, "anderer Schreiber wartete auf das Lesen von der Platte (Lesen in der Transaktion)")
    }

    /// Erster Stand: Ordner A (leer) und B mit `a.txt` (Favorit, gespeicherte Teil-Prüfsumme); danach `B/a.txt` → `A/a.txt`.
    private static func seedMovedFile(store: IndexStoreV3, id: UUID, root: URL) async throws -> (Int64, Int64, StoredItem) {
        try await store.applyDirectory(
            mediumUUID: id, parentID: nil,
            entries: [ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true)], seenAt: Date()
        )
        let folderA = try #require(try await store.folderID(mediumUUID: id, path: ["A"]))
        let folderB = try #require(try await store.folderID(mediumUUID: id, path: ["B"]))
        try await store.applyDirectory(
            mediumUUID: id, parentID: folderB, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], seenAt: Date()
        )
        let before = try #require(try await store.children(mediumUUID: id, parentID: folderB).first { $0.name == "a.txt" })
        try await store.setFavorite(itemID: before.id, true)
        try await store.storePartialChecksum(itemID: before.id, mountPath: root.path)
        try FileManager.default.moveItem(at: root.appendingPathComponent("B/a.txt"), to: root.appendingPathComponent("A/a.txt"))
        return (folderA, folderB, before)
    }

    /// bug.0.4.141 (b): Lauf wird unterbrochen, **bevor** der alte Ordner gelesen wurde (neuer Ort eingefügt, alte Zeile
    /// noch sichtbar) → der Folgelauf löscht die alte Zeile nicht samt Favorit.
    @Test func interruptedBeforeOldFolderReadKeepsFavorite() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let volume = MemoryVolume(mountPath: "/Volumes/EXFAT")
        _ = volume.file("B/a.txt", size: 50).file("C/c.txt", size: 9)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let before = try #require(try await harness.item(named: "a.txt"))
        try await harness.store.setFavorite(itemID: before.id, true)
        volume.remove("B/a.txt")
        _ = volume.file("A/a.txt", size: 50)
        let pool = harness.store.pool
        let outcome = try await harness.run(
            access: volume,
            maxDepth: nil,
            fromScratch: false,
            volume: vol,
            shouldHalt: {
                // Anhalten, sobald der neue Ort eingefügt ist, die alte Zeile aber noch sichtbar ist.
                let state = (try? pool.read { db in
                    try Row.fetchOne(db, sql: "SELECT COUNT(*) AS n, SUM(status = 0) AS visible FROM items WHERE name = 'a.txt'")
                }) ?? nil
                let total: Int = state?["n"] ?? 0
                let visible: Int = state?["visible"] ?? 0
                return (total >= 2 && visible == 2) ? .pause : .none
            }
        )
        #expect(outcome.interrupted)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let after = try #require(try await harness.item(named: "a.txt"))
        #expect(after.isFavorite, "Favorit nach Unterbrechung vor dem Lesen des alten Ordners verloren")
        let folderA = try #require(try await harness.item(named: "A"))
        #expect(after.parentID == folderA.id)
    }

    /// bug.0.4.156 (a): Erstindex FAT mit vielen Dateien ohne Kandidaten → keine einzige Segment-Abfrage beim
    /// Wiederverbinden am Laufende (Zähler, kein Zeitmaß).
    @Test func firstIndexWithoutCandidatesQueriesNoSegments() async throws {
        let (harness, volume) = try await fatHarness()
        for index in 0..<300 {
            _ = volume.file(String(format: "D%02d/f-%03d.txt", index % 7, index), size: Int64(index + 1))
        }
        let before = await harness.store.reconnectSegmentLookupsForTesting
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: harness.volume(at: volume.mountPath))
        #expect(!outcome.interrupted)
        let lookups = await harness.store.reconnectSegmentLookupsForTesting - before
        #expect(lookups == 0, "Segment-Abfragen beim Erstindex: \(lookups)")
    }

    /// bug.0.4.156 (b): Die verschobene Datei ist am Laufende nicht lesbar → die alte Zeile wird nicht gelöscht, der
    /// Favorit bleibt; der Merker bleibt für den Folgelauf. Die Schritte eines Laufs über den Store (Beginn, neuer Ort
    /// gelesen, alter Ordner leer gelesen, Laufende) mit echten Dateien für die Teil-Prüfsumme.
    @Test func unreadableMovedFileKeepsTheFavorite() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-unreadable-\(UUID().uuidString)", isDirectory: true)
        let moved = root.appendingPathComponent("A/a.txt")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: moved.path)
            try? FileManager.default.removeItem(at: root)
        }
        try writeReal("B/a.txt", in: root)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("A"), withIntermediateDirectories: true)
        try await store.applyDirectory(
            mediumUUID: id, parentID: nil,
            entries: [ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true)], seenAt: Date()
        )
        let folderA = try #require(try await store.folderID(mediumUUID: id, path: ["A"]))
        let folderB = try #require(try await store.folderID(mediumUUID: id, path: ["B"]))
        try await store.applyDirectory(
            mediumUUID: id, parentID: folderB, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], seenAt: Date()
        )
        let before = try #require(try await store.children(mediumUUID: id, parentID: folderB).first { $0.name == "a.txt" })
        try await store.setFavorite(itemID: before.id, true)
        try await store.storePartialChecksum(itemID: before.id, mountPath: root.path)
        try moveReal("B/a.txt", "A/a.txt", in: root)

        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        // Neuer Ort zuerst (alte Zeile noch sichtbar → kein Kandidat), dann der alte Ordner leer (alte Zeile verschwunden).
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: moved.path)
        let finished = try await store.finishIndexing(
            mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
        )
        try #require(finished)
        let pool = store.pool
        let oldRow: Row? = try pool.read { db in
            try Row.fetchOne(db, sql: "SELECT id FROM items WHERE id = ?", arguments: [before.id])
        }
        #expect(oldRow != nil, "alte Zeile nach Lesefehler gelöscht")
        #expect(try await store.favoriteItemIDs().contains(before.id), "Favorit nach Lesefehler gelöscht")
        let pending = try await store.pendingReconnectIDsForTesting(mediumUUID: id)
        #expect(!pending.isEmpty, "Merker für den Folgelauf fehlt")
    }

    /// bug.0.4.156 (c)/165 (a): Folgelauf eines schon indizierten Mediums, Abbruch **vor** `finishIndexing` (z. B.
    /// Absturz) → die Zuordnung der schon eingefügten Zeilen steht in der Datenbank.
    @Test func insertedRowsArePendingBeforeTheRunEnds() async throws {
        let (harness, volume) = try await fatHarness()
        _ = volume.file("alt.txt")
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: harness.volume(at: volume.mountPath))
        let token = UUID()
        try #require(try await harness.store.beginIndexing(mediumUUID: harness.mediumID, token: token))
        try await harness.store.applyDirectories(
            mediumUUID: harness.mediumID,
            batches: [(parentID: nil, path: "/", depth: 1, entries: [
                ScannedEntry(name: "alt.txt", isFolder: false, sizeBytes: 4),
                ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 3),
                ScannedEntry(name: "auch.txt", isFolder: false, sizeBytes: 4),
            ], finalize: false)],
            seenAt: Date()
        )
        let pending = try await harness.store.pendingReconnectIDsForTesting(mediumUUID: harness.mediumID)
        #expect(pending.count == 2, "Zuordnung vor dem Laufende nicht gespeichert: \(pending)")
    }

    /// bug.0.4.165 (c): Eine veraltete Merker-ID zeigt auf eine Zeile eines **anderen** Mediums (ID wiederverwendet) → sie
    /// wird nicht mit einem verschwundenen Eintrag dieses Mediums verbunden; die fremde Zeile bleibt, wo sie ist.
    @Test func staleMerkerIDOfAnotherMediumIsIgnored() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [ScannedEntry(name: "B", isFolder: true)], seenAt: Date())
        let folderB = try #require(try await store.folderID(mediumUUID: id, path: ["B"]))
        try await store.applyDirectory(
            mediumUUID: id, parentID: folderB, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], seenAt: Date()
        )
        let other = StoredMedium(fsType: "exfat", volumeTotalBytes: 10, name: "ANDERES", type: .usb, decision: .index)
        try await store.upsertMedium(other)
        try await store.applyDirectory(
            mediumUUID: other.uuid, parentID: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], seenAt: Date()
        )
        let foreign = try #require(try await store.children(mediumUUID: other.uuid, parentID: nil).first { $0.name == "a.txt" })
        // Merker dieses Mediums enthält (veraltet) die ID der fremden Zeile.
        let key = IndexStoreV3.pendingReconnectKey
        try await store.pool.write { db in
            let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: id))
            try db.execute(sql: "INSERT OR IGNORE INTO meta_keys (key) VALUES (?)", arguments: [key])
            try db.execute(
                sql: "INSERT OR REPLACE INTO storage_meta (storageID, keyID, value, date) SELECT ?, id, ?, NULL FROM meta_keys WHERE key = ?",
                arguments: [storageID, String(foreign.id), key]
            )
        }
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)], seenAt: Date()
        )
        try #require(try await store.finishIndexing(mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), ranToEnd: true))
        let stillThere = try await store.children(mediumUUID: other.uuid, parentID: nil).first { $0.name == "a.txt" }
        #expect(stillThere?.id == foreign.id, "fremde Zeile verschoben oder gelöscht")
    }

    /// bug.0.4.165 (a): Erstindex FAT mit vielen Stapeln (mehrere Ordner) → der Merker wird nie geschrieben (Zähler).
    @Test func firstIndexWritesNoPendingMerker() async throws {
        let (harness, volume) = try await fatHarness()
        for index in 0..<400 {
            _ = volume.file(String(format: "D%02d/f-%03d.txt", index % 20, index), size: Int64(index + 1))
        }
        let before = await harness.store.pendingReconnectWritesForTesting
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: harness.volume(at: volume.mountPath))
        #expect(!outcome.interrupted)
        #expect(await harness.store.pendingReconnectWritesForTesting - before == 0, "Merker beim Erstindex geschrieben")
        #expect(try await harness.store.storedNames().count >= 400, "Erstindex unvollständig")
    }

    @Test func ambiguousSameSizeDoesNotReconnect() async throws {
        let (harness, volume) = try await fatHarness()
        await harness.store.setPartialMatchingEnabled(false)
        _ = volume.file("a.bin", size: 64).file("b.bin", size: 64)
        let vol = harness.volume(at: volume.mountPath)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        let favA = try #require(try await harness.item(named: "a.bin"))
        try await harness.store.setFavorite(itemID: favA.id, true)
        volume.remove("a.bin")
        volume.remove("b.bin")
        _ = volume.file("c.bin", size: 64).file("d.bin", size: 64)
        _ = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        let c = try #require(try await harness.item(named: "c.bin"))
        #expect(c.id != favA.id)
    }
}

/// bug.0.4.169: hält das erste Lesen an, bis der Test es freigibt (Notfall-Grenze 10 s, dann rot statt Hängen).
private final class ReadBlocker: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var didEnter = false
    private var blocked = false
    var entered: Bool { lock.withLock { didEnter } }
    func markEntered() { lock.withLock { didEnter = true } }
    func blockOnce() {
        let first = lock.withLock { () -> Bool in
            didEnter = true
            defer { blocked = true }
            return !blocked
        }
        if first { _ = semaphore.wait(timeout: .now() + 10) }
    }
    func release() { semaphore.signal() }
}

// MARK: - bug.0.4.169 Nacharbeit: Lesen vor der Transaktion ohne Datenverlust, Hänger, Wiedereintritt

extension FatReconnectIndexerTests {
    /// Echte Dateien unter `root`: je Name `B/<name>` (Größe aus der Liste), im Store als Favorit mit gespeicherter
    /// Teil-Prüfsumme; danach auf der Platte nach `A/<name>` verschoben. Liefert Ordner A, B und die alten Zeilen.
    fileprivate static func seedMovedFiles(
        store: IndexStoreV3, id: UUID, root: URL, files: [(name: String, bytes: Int)]
    ) async throws -> (folderA: Int64, folderB: Int64, rows: [StoredItem]) {
        for file in files {
            let url = root.appendingPathComponent("B/\(file.name)")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 0x41, count: file.bytes).write(to: url)
        }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("A"), withIntermediateDirectories: true)
        try await store.applyDirectory(
            mediumUUID: id, parentID: nil,
            entries: [ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true)], seenAt: Date()
        )
        let folderA = try #require(try await store.folderID(mediumUUID: id, path: ["A"]))
        let folderB = try #require(try await store.folderID(mediumUUID: id, path: ["B"]))
        try await store.applyDirectory(
            mediumUUID: id, parentID: folderB,
            entries: files.map { ScannedEntry(name: $0.name, isFolder: false, sizeBytes: Int64($0.bytes)) }, seenAt: Date()
        )
        let children = try await store.children(mediumUUID: id, parentID: folderB)
        var rows: [StoredItem] = []
        for file in files {
            let row = try #require(children.first { $0.name == file.name })
            try await store.setFavorite(itemID: row.id, true)
            try await store.storePartialChecksum(itemID: row.id, mountPath: root.path)
            try FileManager.default.moveItem(
                at: root.appendingPathComponent("B/\(file.name)"), to: root.appendingPathComponent("A/\(file.name)")
            )
            rows.append(row)
        }
        return (folderA, folderB, rows)
    }

    /// bug.0.4.169 (a): Zum Lesezeitpunkt hat die eingefügte Datei `c.txt` keinen Kandidaten (ihr alter Ordner C ist
    /// noch nicht neu gelesen, die alte Zeile sichtbar). Während das Lesen von `a.txt` hängt, wird C leer gelesen → die
    /// alte Zeile von `c.txt` wird `status = 2` mit Teil-Prüfsumme. In der Transaktion fehlt ihr der vorab gelesene Wert
    /// → wie „unlesbar“: alte Zeile und Favorit bleiben (nicht wie „Datei fehlt“ gelöscht), Merker bleibt.
    @Test func goneRowAppearingDuringTheReadKeepsItsFavorite() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-gone-during-read-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (folderA, folderB, rows) = try await Self.seedMovedFiles(store: store, id: id, root: root, files: [("a.txt", 50)])
        // c.txt lag in C, liegt jetzt (auf der Platte) in A.
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [
            ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true), ScannedEntry(name: "C", isFolder: true),
        ], seenAt: Date())
        let folderC = try #require(try await store.folderID(mediumUUID: id, path: ["C"]))
        let cURL = root.appendingPathComponent("C/c.txt")
        try FileManager.default.createDirectory(at: cURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x43, count: 70).write(to: cURL)
        try await store.applyDirectory(
            mediumUUID: id, parentID: folderC, entries: [ScannedEntry(name: "c.txt", isFolder: false, sizeBytes: 70)], seenAt: Date()
        )
        let oldC = try #require(try await store.children(mediumUUID: id, parentID: folderC).first { $0.name == "c.txt" })
        try await store.setFavorite(itemID: oldC.id, true)
        try await store.storePartialChecksum(itemID: oldC.id, mountPath: root.path)
        try FileManager.default.moveItem(at: cURL, to: root.appendingPathComponent("A/c.txt"))

        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [
                ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50), ScannedEntry(name: "c.txt", isFolder: false, sizeBytes: 70),
            ], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        let blocker = ReadBlocker()
        await store.setPartialReadHookForTesting { _ in blocker.blockOnce() }
        let finishing = Task {
            try await store.finishIndexing(
                mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
            )
        }
        try #require(await waitUntil { blocker.entered }, "Lesen am Laufende fand nicht statt")
        // Während des Lesens: C wird leer gelesen (Live-Änderung) → alte Zeile von c.txt verschwunden.
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderC, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        blocker.release()
        try #require(try await finishing.value)
        let pool = store.pool
        let oldRow: Row? = try pool.read { db in try Row.fetchOne(db, sql: "SELECT id FROM items WHERE id = ?", arguments: [oldC.id]) }
        #expect(oldRow != nil, "alte Zeile von c.txt gelöscht, obwohl ihre Teil-Prüfsumme nie gelesen wurde")
        #expect(try await store.favoriteItemIDs().contains(oldC.id), "Favorit von c.txt verloren")
        #expect(try await store.favoriteItemIDs().contains(try #require(rows.first).id), "Favorit von a.txt verloren")
        #expect(!(try await store.pendingReconnectIDsForTesting(mediumUUID: id)).isEmpty, "Merker für den Folgelauf fehlt")
    }

    /// bug.0.4.169 (b): Drei verschobene Dateien, das erste Lesen hängt (Medium hängt) → nach der Zeitgrenze kein
    /// weiteres Lesen (Zähler der gestarteten Lesevorgänge), `finishIndexing` endet, alle drei alten Zeilen bleiben
    /// (unlesbar = behalten).
    @Test func hangingReadStopsFurtherReadsAndEndsInTime() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-hanging-read-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files: [(name: String, bytes: Int)] = [("a.txt", 50), ("b.txt", 60), ("c.txt", 70)]
        let (folderA, folderB, rows) = try await Self.seedMovedFiles(store: store, id: id, root: root, files: files)
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: files.map {
                ScannedEntry(name: $0.name, isFolder: false, sizeBytes: Int64($0.bytes))
            }, finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        let blocker = ReadBlocker()
        let started = ReadCounter()
        await store.setPartialReadLimitsForTesting(perFile: .milliseconds(300), total: .seconds(20))
        await store.setPartialReadHookForTesting { _ in
            started.increment()
            blocker.blockOnce()
        }
        defer { blocker.release() }
        let clock = ContinuousClock()
        let begin = clock.now
        try #require(try await store.finishIndexing(
            mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
        ))
        let elapsed = clock.now - begin
        #expect(started.value == 1, "nach der Zeitüberschreitung weiter gelesen: \(started.value) Lesevorgänge")
        #expect(elapsed < .seconds(5), "finishIndexing endete erst nach \(elapsed)")
        let favorites = try await store.favoriteItemIDs()
        for row in rows {
            #expect(favorites.contains(row.id), "Favorit von \(row.name) nach hängendem Lesen verloren")
        }
    }

    /// bug.0.4.169 (b): Gesamtgrenze – jedes Lesen dauert 100 ms (hängt nicht), die Grenze für alle reicht für etwa
    /// zwei → danach kein weiteres Lesen, übrige Kandidaten unlesbar (bleiben samt Favorit).
    @Test func readBudgetStopsFurtherReads() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-read-budget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files: [(name: String, bytes: Int)] = [("a.txt", 50), ("b.txt", 60), ("c.txt", 70), ("d.txt", 80), ("e.txt", 90)]
        let (folderA, folderB, rows) = try await Self.seedMovedFiles(store: store, id: id, root: root, files: files)
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: files.map {
                ScannedEntry(name: $0.name, isFolder: false, sizeBytes: Int64($0.bytes))
            }, finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        let started = ReadCounter()
        await store.setPartialReadLimitsForTesting(perFile: .seconds(3), total: .milliseconds(250))
        await store.setPartialReadHookForTesting { _ in
            started.increment()
            Thread.sleep(forTimeInterval: 0.1)
        }
        try #require(try await store.finishIndexing(
            mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
        ))
        #expect(started.value < files.count, "Gesamtgrenze wirkungslos: \(started.value) von \(files.count) gelesen")
        let favorites = try await store.favoriteItemIDs()
        for row in rows {
            #expect(favorites.contains(row.id), "Favorit von \(row.name) verloren")
        }
    }

    /// bug.0.4.169 (Selbstprüfung): Das Medium wird während des Lesens ausgeworfen (Einhängepunkt fehlt) → die Datei
    /// fehlt nicht „wirklich“; die alte Zeile bleibt samt Favorit (unlesbar statt fehlt).
    @Test func ejectedMediumDuringTheReadKeepsTheFavorite() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-ejected-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (folderA, folderB, rows) = try await Self.seedMovedFiles(store: store, id: id, root: root, files: [("a.txt", 50)])
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        // Auswerfen: der ganze Einhängepunkt verschwindet vor dem Lesen am Laufende.
        await store.setPartialReadHookForTesting { _ in try? FileManager.default.removeItem(at: root) }
        try #require(try await store.finishIndexing(
            mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
        ))
        let old = try #require(rows.first)
        #expect(try await store.favoriteItemIDs().contains(old.id), "Favorit nach Auswerfen während des Lesens gelöscht")
    }

    /// bug.0.4.169 (c): Während das Lesen am Laufende hängt, beginnt ein neuer Lauf desselben Mediums → der alte
    /// Abschluss überschreibt ihn nicht: danach ist der neue Lauf aktiv und der Status „indiziert gerade“.
    @Test func beginIndexingDuringTheReadKeepsTheNewRunsStatus() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-begin-during-read-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (folderA, folderB, _) = try await Self.seedMovedFiles(store: store, id: id, root: root, files: [("a.txt", 50)])
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        let blocker = ReadBlocker()
        await store.setPartialReadHookForTesting { _ in blocker.blockOnce() }
        let finishing = Task {
            try await store.finishIndexing(
                mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
            )
        }
        try #require(await waitUntil { blocker.entered }, "Lesen am Laufende fand nicht statt")
        let next = UUID()
        let callsBefore = await store.beginIndexingCallsForTesting
        let beginning = Task { try await store.beginIndexing(mediumUUID: id, token: next) }
        // Positives Signal: der neue Beginn ist im Store angekommen (während das Lesen noch hängt).
        try #require(await waitUntil { await store.beginIndexingCallsForTesting > callsBefore }, "Beginn kam nicht an")
        blocker.release()
        _ = try await finishing.value
        let begun = try await beginning.value
        #expect(begun, "neuer Lauf abgewiesen")
        #expect(await store.indexingIsActive(mediumUUID: id, token: next), "neuer Lauf nicht aktiv")
        let status = try #require(try await store.medium(uuid: id)).indexStatus
        #expect(status == .indexing, "Status \(status) statt „indiziert gerade“ – alter Abschluss überschrieb den neuen Lauf")
    }
}

/// bug.0.4.169 (b): zählt gestartete Lesevorgänge (auf dem lesenden Faden).
private final class ReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

// MARK: - bug.0.4.171: Datenbankfehler beim Wiederverbinden, Merker an der Grenze

extension FatReconnectIndexerTests {
    /// bug.0.4.171: Ein Datenbankfehler im Rückfall der Teil-Prüfsumme (Nachschlagen in der Transaktion) ist kein
    /// „unlesbar“ → `finishIndexing` gibt ihn weiter, nichts wird gelöscht, der Merker bleibt.
    @Test func databaseErrorInTheReconnectFallbackIsPassedOn() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-db-error-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (folderA, folderB, rows) = try await Self.seedMovedFiles(store: store, id: id, root: root, files: [("a.txt", 50)])
        // Das Medium war schon einmal vollständig indiziert (sonst schreibt der Lauf keinen Merker).
        let first = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: first))
        try #require(try await store.finishIndexing(mediumUUID: id, token: first, status: .indexed, firstIndexedAt: Date()))
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 50)], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        try await store.applyDirectories(
            mediumUUID: id, batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: root.path
        )
        let merkerBefore = try await store.pendingReconnectIDsForTesting(mediumUUID: id)
        try #require(!merkerBefore.isEmpty, "Voraussetzung: Merker aus dem Lauf")
        await store.setPartialLookupHookForTesting { throw DatabaseError(resultCode: .SQLITE_IOERR) }
        var thrown: Error?
        do {
            _ = try await store.finishIndexing(
                mediumUUID: id, token: token, status: .indexed, firstIndexedAt: Date(), mountPath: root.path, ranToEnd: true
            )
        } catch {
            thrown = error
        }
        #expect(thrown is DatabaseError, "Datenbankfehler nicht weitergegeben: \(String(describing: thrown))")
        let old = try #require(rows.first)
        let pool = store.pool
        let oldRow: Row? = try pool.read { db in try Row.fetchOne(db, sql: "SELECT id FROM items WHERE id = ?", arguments: [old.id]) }
        #expect(oldRow != nil, "alte Zeile trotz Datenbankfehler gelöscht")
        #expect(try await store.favoriteItemIDs().contains(old.id), "Favorit trotz Datenbankfehler gelöscht")
        #expect(try await store.pendingReconnectIDsForTesting(mediumUUID: id) == merkerBefore, "Merker verändert")
    }

    /// bug.0.4.171: Der Merker wird an der Grenze gekürzt, nicht um den ganzen Stapel überschritten.
    @Test func pendingMerkerIsCutAtTheLimit() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let id = harness.mediumID
        // Eine verschwundene Zeile, damit das Medium wiederverbinden kann (Merker wird geschrieben).
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [
            ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true),
        ], seenAt: Date())
        let folderA = try #require(try await store.folderID(mediumUUID: id, path: ["A"]))
        let folderB = try #require(try await store.folderID(mediumUUID: id, path: ["B"]))
        try await store.applyDirectory(
            mediumUUID: id, parentID: folderB, entries: [ScannedEntry(name: "alt.txt", isFolder: false, sizeBytes: 5)], seenAt: Date()
        )
        try await store.applyDirectory(mediumUUID: id, parentID: folderB, entries: [], seenAt: Date())
        let limit = 30
        await store.setPendingReconnectMaxLengthForTesting(limit)
        let token = UUID()
        try #require(try await store.beginIndexing(mediumUUID: id, token: token))
        // Erster Stapel kurz (unter der Grenze), zweiter lang (würde sie weit überschreiten).
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: (1...2).map {
                ScannedEntry(name: "kurz-\($0).txt", isFolder: false, sizeBytes: Int64($0))
            }, finalize: true)],
            seenAt: Date()
        )
        let first = try await store.pendingReconnectValueLengthForTesting(mediumUUID: id)
        try #require(first > 0 && first < limit, "Voraussetzung: erster Stapel unter der Grenze (\(first))")
        try await store.applyDirectories(
            mediumUUID: id,
            batches: [(parentID: folderB, path: nil, depth: nil, entries: (1...30).map {
                ScannedEntry(name: "lang-\($0).txt", isFolder: false, sizeBytes: Int64(100 + $0))
            }, finalize: true)],
            seenAt: Date()
        )
        let length = try await store.pendingReconnectValueLengthForTesting(mediumUUID: id)
        #expect(length <= limit, "Merker \(length) Zeichen, Grenze \(limit)")
        #expect(length > first, "zweiter Stapel gar nicht angehängt (\(first) → \(length))")
    }
}

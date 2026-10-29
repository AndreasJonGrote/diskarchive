//
//  LargeMediumFolderCostTests.swift
//  diskindexTests
//
//  bug.0.4.228: Was ein Ordner beim Indizieren oder Abgleichen kostet, hängt nicht von der Größe des Mediums ab. Vorher
//  fragte `precomputedPartials` vor jedem Ordner das ganze Medium nach vergleichbaren Größen ab, und `mayReconnect` las
//  beim Erstindex je Stapel alle Einträge (gebundener `status`, Teilindex `items_gone` griff nicht). „Daten I“ (exFAT,
//  283 000 Einträge) stand so über 30 Minuten bei 99 %.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct LargeMediumFolderCostTests {
    private static let ballastRows = 200_000
    private static let folderCount = 1_000
    private static let seen = Date(timeIntervalSince1970: 1_700_000_700)
    /// Höchstens dreimal so teuer wie beim kleinen Medium; dazu 2 ms je Ordner Spielraum, damit Rauschen bei sehr
    /// kleinen Zeiten den Vergleich nicht kippt (vorher kostete jede Abfrage beim großen Medium ein Vielfaches davon).
    private static func withinBudget(large: Double, small: Double) -> Bool { large < 3 * small + 0.002 }

    private struct PreparedMedium {
        let medium: StoredMedium
        let folders: [Int64]
        let entries: [[ScannedEntry]]
    }

    /// exFAT-Medium mit `folderCount` Ordnern (je drei Dateien, wenn `withFiles`) und `ballast` Einträgen, die direkt in
    /// die Datenbank geschrieben werden (wie ein großer, schon indizierter Bestand).
    private static func prepare(
        _ harness: StoreHarness, name: String, ballast: Int, withFiles: Bool
    ) async throws -> PreparedMedium {
        let store = harness.store
        let medium = try await harness.insert(name: name, fsType: "exfat", bytes: 1_000_000)
        let roots = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "work", isFolder: true, modifiedAt: seen),
            ScannedEntry(name: "bestand", isFolder: true, modifiedAt: seen),
        ], seenAt: seen)
        let work = try #require(roots.first { $0.name == "work" }).id
        let bestand = try #require(roots.first { $0.name == "bestand" }).id
        let folderEntries = (0..<folderCount).map {
            ScannedEntry(name: String(format: "o-%04d", $0), isFolder: true, modifiedAt: seen)
        }
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: work, entries: folderEntries, seenAt: seen)
        let folders = try await store.children(mediumUUID: medium.uuid, parentID: work, limit: nil, offset: 0, scope: nil)
            .sorted { $0.name < $1.name }.map(\.id)
        #expect(folders.count == folderCount)
        let entries = (0..<folders.count).map { index in
            (0..<3).map { k in
                ScannedEntry(
                    name: "f-\(k).bin", isFolder: false, sizeBytes: Int64(10_000 + index * 3 + k), modifiedAt: seen
                )
            }
        }
        if withFiles {
            for start in stride(from: 0, to: folders.count, by: 100) {
                let end = min(start + 100, folders.count)
                try await store.applyDirectories(
                    mediumUUID: medium.uuid,
                    batches: (start..<end).map { (parentID: folders[$0], path: nil, depth: nil, entries: entries[$0], finalize: true) },
                    seenAt: seen
                )
            }
        }
        if ballast > 0 {
            try await store.pool.write { db in
                let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: medium.uuid))
                try db.execute(
                    sql: """
                        WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < ?)
                        INSERT INTO items (storageID, parentID, name, slug, depth, modifiedAt)
                        SELECT ?, ?, 'b-' || x || '.bin', 'b-' || x || '.bin', 2, 1700000000 FROM n
                        """,
                    arguments: [ballast, storageID, bestand]
                )
            }
        }
        return PreparedMedium(medium: medium, folders: folders, entries: entries)
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// Ein Ordner des Laufs, wie der Indexer ihn schreibt.
    private static func applyFolder(
        _ store: IndexStoreV3, _ prepared: PreparedMedium, _ index: Int, mountPath: String?
    ) async throws -> Double {
        let started = ContinuousClock.now
        try await store.applyDirectories(
            mediumUUID: prepared.medium.uuid,
            batches: [(parentID: prepared.folders[index], path: nil, depth: nil, entries: prepared.entries[index], finalize: true)],
            seenAt: seen, mountPath: mountPath
        )
        return seconds(started.duration(to: .now))
    }

    /// Test 1 (realistisch): Abgleich ohne Änderungen, Ordner für Ordner. Beim Medium mit 200 000 weiteren Einträgen
    /// kostet ein Ordner höchstens wenig mehr als beim kleinen (beide abwechselnd gemessen, gleiche Last).
    @Test func reconcileCostPerFolderDoesNotGrowWithMedium() async throws {
        let harness = try StoreHarness.make()
        let store = harness.store
        let large = try await Self.prepare(harness, name: "Daten I", ballast: Self.ballastRows, withFiles: true)
        let small = try await Self.prepare(harness, name: "Klein", ballast: 0, withFiles: true)
        try #require(try await store.beginIndexing(mediumUUID: large.medium.uuid, token: UUID()))
        try #require(try await store.beginIndexing(mediumUUID: small.medium.uuid, token: UUID()))
        var largeTotal = 0.0
        var smallTotal = 0.0
        for index in 0..<Self.folderCount {
            largeTotal += try await Self.applyFolder(store, large, index, mountPath: "/Volumes/DATEN")
            smallTotal += try await Self.applyFolder(store, small, index, mountPath: "/Volumes/KLEIN")
        }
        let largePer = largeTotal / Double(Self.folderCount)
        let smallPer = smallTotal / Double(Self.folderCount)
        print(String(
            format: "bug.0.4.228 Abgleich je Ordner: groß %.2f ms (gesamt %.1f s), klein %.2f ms (gesamt %.1f s)",
            largePer * 1_000, largeTotal, smallPer * 1_000, smallTotal
        ))
        #expect(Self.withinBudget(large: largePer, small: smallPer),
                "Ordner kostet beim großen Medium \(largePer * 1_000) ms, beim kleinen \(smallPer * 1_000) ms")
    }

    /// Test 2: Die vergleichbaren Größen werden je Lauf einmal gefragt, nicht je Ordner – und nach dem Speichern einer
    /// Teil-Prüfsumme genau einmal neu.
    @Test func comparableSizesAreQueriedOncePerRunAndAfterStoring() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-sizes-once-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let harness = try StoreHarness.make()
        let store = harness.store
        let prepared = try await Self.prepare(harness, name: "Klein", ballast: 0, withFiles: true)
        try #require(try await store.beginIndexing(mediumUUID: prepared.medium.uuid, token: UUID()))
        let before = await store.comparableSizeQueriesForTesting
        for index in 0..<50 { _ = try await Self.applyFolder(store, prepared, index, mountPath: mount.path) }
        let firstPass = await store.comparableSizeQueriesForTesting - before
        #expect(firstPass == 1, "Größen \(firstPass)-mal gefragt für 50 Ordner")

        // Favorit in o-0000 (echte Datei, damit die Teil-Prüfsumme gespeichert wird).
        let folder = mount.appendingPathComponent("work/o-0000", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let first = try #require(prepared.entries.first?.first)
        try Data(repeating: 0x5A, count: Int(first.sizeBytes ?? 0)).write(to: folder.appendingPathComponent(first.name))
        let item = try #require(
            try await store.children(mediumUUID: prepared.medium.uuid, parentID: prepared.folders.first)
                .first { $0.name == first.name }
        )
        try await store.setFavorite(itemID: item.id, true)
        try await store.storePartialChecksum(itemID: item.id, mountPath: mount.path)
        let afterStore = await store.comparableSizeQueriesForTesting
        for index in 0..<50 { _ = try await Self.applyFolder(store, prepared, index, mountPath: mount.path) }
        let secondPass = await store.comparableSizeQueriesForTesting - afterStore
        #expect(secondPass == 1, "nach dem Speichern \(secondPass)-mal gefragt (erwartet: genau einmal neu)")
    }

    /// Test 3 (Erstindex): Jeder Stapel bringt neue Einträge (Merker fürs Wiederverbinden wird geprüft). Beim Medium mit
    /// 200 000 Einträgen und ohne verschwundene Zeilen kostet ein Stapel höchstens wenig mehr als beim kleinen.
    @Test func firstIndexBatchCostDoesNotGrowWithMedium() async throws {
        let harness = try StoreHarness.make()
        let store = harness.store
        let large = try await Self.prepare(harness, name: "Daten I", ballast: Self.ballastRows, withFiles: false)
        let small = try await Self.prepare(harness, name: "Klein", ballast: 0, withFiles: false)
        try #require(try await store.beginIndexing(mediumUUID: large.medium.uuid, token: UUID()))
        try #require(try await store.beginIndexing(mediumUUID: small.medium.uuid, token: UUID()))
        var largeTotal = 0.0
        var smallTotal = 0.0
        for index in 0..<Self.folderCount {
            largeTotal += try await Self.applyFolder(store, large, index, mountPath: nil)
            smallTotal += try await Self.applyFolder(store, small, index, mountPath: nil)
        }
        let largePer = largeTotal / Double(Self.folderCount)
        let smallPer = smallTotal / Double(Self.folderCount)
        print(String(
            format: "bug.0.4.228 Erstindex je Stapel: groß %.2f ms (gesamt %.1f s), klein %.2f ms (gesamt %.1f s)",
            largePer * 1_000, largeTotal, smallPer * 1_000, smallTotal
        ))
        let written = try await store.children(mediumUUID: large.medium.uuid, parentID: large.folders.last)
        #expect(written.count == 3, "Stapel nicht geschrieben")
        #expect(Self.withinBudget(large: largePer, small: smallPer),
                "Stapel kostet beim großen Medium \(largePer * 1_000) ms, beim kleinen \(smallPer * 1_000) ms")
    }

    /// Test 4a (Live-Abgleich): Die Größen sind schon gemerkt (leer), dann wird ein Favorit gesetzt und die Datei auf exFAT
    /// verschoben. Der Favorit hängt danach an der verschobenen Datei – der Merker wurde beim Speichern verworfen.
    @Test func favoriteSetAfterSizesWereCachedFollowsMove() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-sizes-live-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let seen = Self.seen
        let others = (0..<20).map {
            ScannedEntry(name: String(format: "o-%02d.bin", $0), isFolder: false, sizeBytes: Int64(300 + $0), modifiedAt: seen)
        }
        let favoriteEntry = ScannedEntry(name: "fav.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen)
        for folder in ["A", "B"] {
            try FileManager.default.createDirectory(at: mount.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for entry in others {
            try Data(repeating: 0x11, count: Int(entry.sizeBytes ?? 0)).write(to: mount.appendingPathComponent("A/\(entry.name)"))
        }
        try Data(repeating: 0xAA, count: 128).write(to: mount.appendingPathComponent("B/fav.bin"))

        let harness = try StoreHarness.make()
        let store = harness.store
        let medium = try await harness.insert(name: "Daten I", fsType: "exfat", bytes: 1_000)
        let roots = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "A", isFolder: true, modifiedAt: seen),
            ScannedEntry(name: "B", isFolder: true, modifiedAt: seen),
        ], seenAt: seen)
        let folderA = try #require(roots.first { $0.name == "A" }).id
        let folderB = try #require(roots.first { $0.name == "B" }).id
        // Mit `mountPath` geschrieben: die (noch leere) Menge der vergleichbaren Größen ist gemerkt.
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [
                (parentID: folderA, path: nil, depth: nil, entries: others, finalize: true),
                (parentID: folderB, path: nil, depth: nil, entries: [favoriteEntry], finalize: true),
            ],
            seenAt: seen, mountPath: mount.path
        )
        let before = try #require(try await store.children(mediumUUID: medium.uuid, parentID: folderB).first)
        try await store.setFavorite(itemID: before.id, true)
        try await store.storePartialChecksum(itemID: before.id, mountPath: mount.path)

        try FileManager.default.moveItem(at: mount.appendingPathComponent("B/fav.bin"), to: mount.appendingPathComponent("A/fav.bin"))
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: folderB, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: seen, mountPath: mount.path
        )
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: folderA, path: nil, depth: nil, entries: others + [favoriteEntry], finalize: true)],
            seenAt: seen, mountPath: mount.path
        )
        let moved = try #require(
            try await store.children(mediumUUID: medium.uuid, parentID: folderA).first { $0.name == "fav.bin" },
            "fav.bin fehlt im neuen Ordner"
        )
        #expect(moved.id == before.id, "neue Zeile statt der alten – Favorit hängt nicht an der verschobenen Datei")
        #expect(try await store.favoriteItemIDs().contains(before.id), "Favorit verloren")
    }

    /// Test 4b (Lauf): Der Favorit wird erst nach einem vollständigen Lauf gesetzt, die Datei dann verschoben. Der nächste
    /// Lauf liest ihre Teil-Prüfsumme schon beim Schreiben des Ordners (nicht erst am Laufende), und der Favorit bleibt.
    @Test func favoriteSetAfterRunIsComparedInNextRun() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-sizes-run-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for folder in ["A", "B"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for index in 0..<10 {
            try Data(repeating: 0x22, count: 400 + index).write(to: root.appendingPathComponent(String(format: "A/o-%02d.bin", index)))
        }
        try Data(repeating: 0xBC, count: 2_048).write(to: root.appendingPathComponent("B/fav.mov"))

        let harness = try await ScanHarness.make(fsType: "exfat")
        defer { harness.closeDatabase() }
        let store = harness.store
        await store.setMountCheckForTesting { _, _ in true }
        var access = DirectMediumAccess()
        access.mountCheck = { _, _ in true }
        let vol = harness.volume(at: root.path)
        let first = try await harness.run(access: access, maxDepth: nil, fromScratch: true, volume: vol)
        #expect(!first.interrupted)
        let favorite = try #require(try await harness.item(named: "fav.mov"))
        try await store.setFavorite(itemID: favorite.id, true)
        try await store.storePartialChecksum(itemID: favorite.id, mountPath: root.path)

        try FileManager.default.moveItem(at: root.appendingPathComponent("B/fav.mov"), to: root.appendingPathComponent("A/fav.mov"))
        let reads = PartialReadTally()
        store.precomputeReadHookForTesting.set { reads.add() }
        defer { store.precomputeReadHookForTesting.set(nil) }
        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false, volume: vol)
        #expect(!second.interrupted)
        let folderA = try #require(try await harness.item(named: "A"))
        let moved = try #require(try await harness.item(named: "fav.mov"), "fav.mov fehlt")
        #expect(moved.id == favorite.id, "Favorit hängt nicht an der verschobenen Datei")
        #expect(moved.parentID == folderA.id)
        #expect(moved.isFavorite)
        #expect(reads.value >= 1, "Teil-Prüfsumme der verschobenen Datei beim Schreiben nicht gelesen (Merker veraltet)")
    }
}

//
//  PartialReadOnDemandTests.swift
//  DiskArchiveTests
//
//  bug.0.4.225: Das Indizieren liest Dateiinhalte (Anfang und Ende, Teil-Prüfsumme) nur, wenn gegen einen Eintrag mit
//  gespeicherter Teil-Prüfsumme verglichen wird. Vorher las es jede Datei jedes Stapels – auf exFAT mit großen Dateien
//  kam „Daten I“ so auf eine Datei pro Minute.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct PartialReadOnDemandTests {
    /// Test 1: Erstindex mit 500 Dateien und ein Abgleich mit umbenannten, verschobenen, gelöschten, neuen und mehrdeutig
    /// gleich großen Dateien, ohne Favoriten: keine Datei wird gelesen (weder beim Schreiben der Stapel noch am Laufende).
    @Test func indexingWithoutStoredPartialsReadsNoFile() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        defer { harness.closeDatabase() }
        let volume = MemoryVolume(mountPath: "/Volumes/EXFAT")
        for index in 0..<500 {
            volume.file(String(format: "D%02d/f-%03d.bin", index % 9, index), size: Int64(1_000 + index % 40))
        }
        for index in 1...3 { volume.file("Z/gleich-\(index).bin", size: 7_777) }
        let reads = PartialReadTally()
        harness.store.precomputeReadHookForTesting.set { reads.add() }
        await harness.store.setPartialReadHookForTesting { _ in reads.add() }
        let vol = harness.volume(at: volume.mountPath)
        let first = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: vol)
        #expect(!first.interrupted)
        #expect(reads.value == 0, "Erstindex las \(reads.value) Dateien")

        for index in 0..<20 {
            let old = String(format: "D%02d/f-%03d.bin", index % 9, index)
            volume.remove(old)
            volume.file(String(format: "D%02d/umbenannt-%03d.bin", (index + 1) % 9, index), size: Int64(1_000 + index % 40))
        }
        for index in 20..<30 { volume.remove(String(format: "D%02d/f-%03d.bin", index % 9, index)) }
        for index in 0..<10 { volume.file(String(format: "Neu/n-%03d.bin", index), size: Int64(5_000 + index)) }
        // Mehrdeutig: drei gleich große Dateien verschwinden, eine gleich große kommt neu – ohne gespeicherte Teil-Prüfsumme
        // gibt es nichts zu vergleichen, auch am Laufende wird nichts gelesen.
        for index in 1...3 { volume.remove("Z/gleich-\(index).bin") }
        volume.file("Y/gleich-neu.bin", size: 7_777)
        let lookupsBefore = await harness.store.reconnectSegmentLookupsForTesting
        let second = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: vol)
        #expect(!second.interrupted)
        let names = try await harness.names()
        #expect(names.contains("umbenannt-000.bin") && names.contains("n-009.bin"), "Abgleich nicht angekommen")
        #expect(!names.contains("f-025.bin"))
        #expect(names.contains("gleich-neu.bin") && !names.contains("gleich-1.bin"))
        #expect(reads.value == 0, "Abgleich ohne gespeicherte Teil-Prüfsumme las \(reads.value) Dateien")
        let requested = await harness.store.reconnectSegmentLookupsForTesting - lookupsBefore
        #expect(requested == 0, "Laufende wollte \(requested) Dateien lesen")
    }

    /// Test 2: Ein Favorit mit gespeicherter Teil-Prüfsumme wird auf exFAT in einen Ordner mit 200 anderen Dateien
    /// verschoben; beide Ordner werden neu gelesen (Live-Abgleich, ohne Laufende). Der Favorit hängt an der verschobenen
    /// Datei, und gelesen wird nur die eine Datei, die als Kandidat in Frage kommt.
    @Test func movedFavoriteReconnectsAndOnlyTheCandidateIsRead() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-partial-on-demand-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let seen = Date(timeIntervalSince1970: 1_700_000_300)
        let others = (0..<200).map { ScannedEntry(name: String(format: "o-%03d.bin", $0), isFolder: false, sizeBytes: Int64(200 + $0), modifiedAt: seen) }
        let favoriteEntry = ScannedEntry(name: "fav.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen)
        try FileManager.default.createDirectory(at: mount.appendingPathComponent("A"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mount.appendingPathComponent("B"), withIntermediateDirectories: true)
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
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: folderA, entries: others, seenAt: seen)
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: folderB, entries: [favoriteEntry], seenAt: seen)
        let before = try #require(try await store.children(mediumUUID: medium.uuid, parentID: folderB).first)
        try await store.setFavorite(itemID: before.id, true)
        try await store.storePartialChecksum(itemID: before.id, mountPath: mount.path)

        try FileManager.default.moveItem(at: mount.appendingPathComponent("B/fav.bin"), to: mount.appendingPathComponent("A/fav.bin"))
        let reads = PartialReadTally()
        store.precomputeReadHookForTesting.set { reads.add() }
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
        #expect(reads.value == 1, "gelesen: \(reads.value) Dateien statt nur des einen Kandidaten")
    }
}

/// Zählt Lesevorgänge aus den Haken des Stores (von beliebigen Fäden).
final class PartialReadTally: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func add() { lock.withLock { count += 1 } }
}

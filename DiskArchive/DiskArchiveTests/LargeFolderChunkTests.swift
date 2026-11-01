//
//  LargeFolderChunkTests.swift
//  DiskArchiveTests
//
//  bug.0.4.227: Große Ordner schreibt der Indexer stückweise (`finalize: false`). Einträge früherer Stücke desselben
//  Laufs sind keine Kandidaten für „verschoben/umbenannt“ – vorher hielt der Schreiber sie für verschwunden, verglich
//  jeden neuen Eintrag mit allen gleich großen (je Kandidat eine Abfrage) und hielt so den Store minutenlang fest
//  („Daten I“ stand bei 15 %, Erkennung, „Ja“ und „Vergessen“ warteten).
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct LargeFolderChunkTests {
    private static let fileCount = 20_000
    /// Großzügige Grenze für den Erstindex; danach bricht der Test den Lauf ab, statt zu hängen.
    private static let runLimit: TimeInterval = 15

    /// exFAT-ähnlich (keine verlässliche `fileID`): ein Ordner mit 20 000 Dateien gleicher Größe, Endung und Zeit.
    private static func sameSizeVolume() -> MemoryVolume {
        let volume = MemoryVolume(mountPath: "/Volumes/DATEN")
        for index in 0..<fileCount {
            volume.file(String(format: "data/f-%05d.bin", index), size: 514)
        }
        volume.file("andere/x.txt", size: 9)
        return volume
    }

    /// Erstindex im Hintergrund mit der Stückgröße des echten Laufs; nach `runLimit` abgebrochen.
    private static func startRun(
        _ harness: ScanHarness, _ volume: MemoryVolume, done: RunSignal
    ) -> Task<(outcome: IndexRunOutcome, seconds: Double), Error> {
        let started = ContinuousClock.now
        let cutoff = started + .seconds(runLimit)
        return Task {
            let outcome = try await harness.run(
                access: volume, maxDepth: nil, fromScratch: true, volume: harness.volume(at: volume.mountPath),
                limits: .standard,
                shouldHalt: { ContinuousClock.now > cutoff ? .cancel : .none }
            )
            done.raise()
            let elapsed = started.duration(to: .now)
            return (outcome, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        }
    }

    /// Test 1: Erstindex des großen Ordners dauert höchstens wenige Sekunden, alle Einträge stehen unter ihrem Namen.
    @Test func firstIndexOfLargeSameSizeFolderIsFast() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        defer { harness.closeDatabase() }
        let volume = Self.sameSizeVolume()
        let result = try await Self.startRun(harness, volume, done: RunSignal()).value
        print("bug.0.4.227 Erstindex \(Self.fileCount) gleich große Dateien: \(String(format: "%.1f", result.seconds)) s")
        #expect(!result.outcome.interrupted, "Lauf nach \(Self.runLimit) s abgebrochen")
        #expect(result.seconds < Self.runLimit, "Erstindex dauerte \(result.seconds) s")
        let data = try #require(try await harness.item(named: "data"))
        let rows = try await harness.store.children(mediumUUID: harness.mediumID, parentID: data.id)
        let expected = Set((0..<Self.fileCount).map { String(format: "f-%05d.bin", $0) })
        #expect(rows.count == Self.fileCount, "\(rows.count) statt \(Self.fileCount) Einträge")
        #expect(Set(rows.map(\.name)) == expected, "Einträge stehen nicht unter ihrem eigenen Namen")
    }

    /// Test 2: Während dieses Erstindex antwortet der Store einem anderen Medium (Erkennung schreibt, Liste liest)
    /// jeweils in unter 1 s.
    @Test func otherMediumIsAnsweredDuringLargeFolderIndex() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        defer { harness.closeDatabase() }
        let store = harness.store
        let second = StoredMedium(fsType: "apfs", volumeTotalBytes: 2_000, name: "ZOOM_H4E", type: .usb, decision: .index)
        try await store.upsertMedium(second)
        let volume = Self.sameSizeVolume()
        let done = RunSignal()
        let run = Self.startRun(harness, volume, done: done)
        // Positives Signal: der große Ordner wird schon geschrieben.
        let pool = store.pool
        let writing = await waitUntil(timeout: 10) {
            let count = (try? await pool.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE name LIKE 'f-%'") ?? 0
            }) ?? 0
            return count > 0
        }
        #expect(writing, "großer Ordner wurde nicht geschrieben")
        let clock = ContinuousClock()
        var slowest: Duration = .zero
        var probesDuringRun = 0
        while !done.isRaised {
            let started = clock.now
            try await store.upsertMedium(second)
            _ = try await store.children(mediumUUID: second.uuid, parentID: nil)
            slowest = max(slowest, started.duration(to: clock.now))
            if !done.isRaised { probesDuringRun += 1 }
            try await Task.sleep(for: .milliseconds(50))
        }
        let result = try await run.value
        print("bug.0.4.227 längste Antwort für das zweite Medium: \(slowest), Proben: \(probesDuringRun)")
        #expect(probesDuringRun > 0, "keine Probe während des Laufs")
        #expect(slowest < .seconds(1), "zweites Medium wartete \(slowest)")
        #expect(!result.outcome.interrupted, "Lauf nach \(Self.runLimit) s abgebrochen")
    }

    /// Test 3: Zwei Favoriten (mit gespeicherter Teil-Prüfsumme, wie in der App) in einem Ordner, der stückweise gelesen
    /// wird: einer umbenannt, einer in einen anderen Ordner verschoben. Nach dem Abgleich hängen beide an der neuen Datei.
    @Test func favoritesInChunkedFolderFollowRenameAndMove() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-large-folder-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = root.appendingPathComponent("data", isDirectory: true)
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("B"), withIntermediateDirectories: true)
        try Data(repeating: 0x01, count: 9).write(to: root.appendingPathComponent("B/x.txt"))
        let filler = Data(repeating: 0x11, count: 514)
        for index in 0..<2_500 {
            try filler.write(to: data.appendingPathComponent(String(format: "f-%04d.bin", index)))
        }
        try Data(repeating: 0xAB, count: 4_096).write(to: data.appendingPathComponent("fav.mov"))
        try Data(repeating: 0xCD, count: 3_000).write(to: data.appendingPathComponent("mv.mov"))
        #expect(2_500 > IndexingRunLimits.standard.directoryChunkSize, "Vorbedingung: Ordner wird stückweise gelesen")

        let harness = try await ScanHarness.make(fsType: "exfat")
        defer { harness.closeDatabase() }
        let store = harness.store
        // Der Testordner steht für das eingehängte Medium (bug.0.4.175).
        await store.setMountCheckForTesting { _, _ in true }
        var access = DirectMediumAccess()
        access.mountCheck = { _, _ in true }
        let vol = harness.volume(at: root.path)
        let first = try await harness.run(access: access, maxDepth: nil, fromScratch: true, volume: vol)
        #expect(!first.interrupted)
        let renamed = try #require(try await harness.item(named: "fav.mov"))
        let moved = try #require(try await harness.item(named: "mv.mov"))
        for item in [renamed, moved] {
            try await store.setFavorite(itemID: item.id, true)
            try await store.storePartialChecksum(itemID: item.id, mountPath: root.path)
        }

        try FileManager.default.moveItem(at: data.appendingPathComponent("fav.mov"), to: data.appendingPathComponent("umbenannt.mov"))
        try FileManager.default.moveItem(at: data.appendingPathComponent("mv.mov"), to: root.appendingPathComponent("B/mv.mov"))
        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false, volume: vol)
        #expect(!second.interrupted)

        let afterRename = try #require(try await harness.item(named: "umbenannt.mov"), "umbenannt.mov fehlt")
        #expect(afterRename.id == renamed.id, "Favorit hängt nicht an der umbenannten Datei")
        #expect(afterRename.isFavorite)
        let folderB = try #require(try await harness.item(named: "B"))
        let afterMove = try #require(try await harness.item(named: "mv.mov"), "mv.mov fehlt")
        #expect(afterMove.id == moved.id, "Favorit hängt nicht an der verschobenen Datei")
        #expect(afterMove.parentID == folderB.id)
        #expect(afterMove.isFavorite)
        #expect(try await harness.item(named: "fav.mov") == nil, "alter Name noch im Index")
    }

    /// Test 4 (Nebenrisiko): Genau ein gleich großer Eintrag aus einem früheren Stück wird beim nächsten Stück nicht auf
    /// den neuen Namen umgehängt – die Zeile bleibt bei ihrer Datei (sonst wandern Kennung, Favorit und Zusatzdaten).
    @Test func earlierChunkEntryKeepsItsRow() async throws {
        let harness = try StoreHarness.make()
        let store = harness.store
        let seen = Date(timeIntervalSince1970: 1_700_000_500)
        let medium = try await harness.insert(name: "Daten I", fsType: "exfat", bytes: 1_000)
        let folder = try #require(try await harness.addRoot(
            medium: medium, entries: [ScannedEntry(name: "data", isFolder: true, modifiedAt: seen)], seenAt: seen
        ).first).id
        try #require(try await store.beginIndexing(mediumUUID: medium.uuid, token: UUID()))
        let a = ScannedEntry(name: "a.wav", isFolder: false, sizeBytes: 514, modifiedAt: seen)
        let b = ScannedEntry(name: "b.wav", isFolder: false, sizeBytes: 514, modifiedAt: seen)
        // Abfolge des Indexers: jedes Stück mit `finalize: false`, dann der ganze Ordner mit `finalize: true`.
        for batch in [(entries: [a], finalize: false), (entries: [b], finalize: false), (entries: [a, b], finalize: true)] {
            if batch.finalize {
                let afterFirst = try await store.children(mediumUUID: medium.uuid, parentID: folder)
                #expect(afterFirst.map(\.name).sorted() == ["a.wav", "b.wav"], "nach zwei Stücken: \(afterFirst.map(\.name))")
            }
            try await store.applyDirectories(
                mediumUUID: medium.uuid,
                batches: [(parentID: folder, path: nil, depth: nil, entries: batch.entries, finalize: batch.finalize)],
                seenAt: seen, mountPath: "/Volumes/DATEN"
            )
        }
        let rows = try await store.children(mediumUUID: medium.uuid, parentID: folder)
        let rowA = try #require(rows.first { $0.name == "a.wav" })
        let rowB = try #require(rows.first { $0.name == "b.wav" })
        #expect(rows.count == 2)
        #expect(rowA.id < rowB.id, "a.wav (erstes Stück) wurde auf b.wav umgehängt und neu eingefügt")
    }
}

/// Einmal gesetztes Signal, von beliebigen Fäden lesbar.
private final class RunSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false
    var isRaised: Bool { lock.withLock { raised } }
    func raise() { lock.withLock { raised = true } }
}

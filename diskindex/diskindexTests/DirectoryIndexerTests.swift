//
//  DirectoryIndexerTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import diskindex

@Suite struct DirectoryIndexerTests {
    private let indexer = DirectoryIndexer()

    @Test func depthThreeStoresThreeLevelsAndDoesNotOpenTheLastFolders() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b/file.txt")
        access.file("a/b/c/secret.txt")
        let outcome = try await harness.run(access: access, maxDepth: 3)
        #expect(outcome.status == .indexed)
        let names = try await harness.names()
        #expect(names.contains("file.txt"))
        #expect(names.contains("c"))
        #expect(!names.contains("secret.txt"))
        #expect(!access.listed.contains { $0.hasSuffix("/a/b/c") })
        #expect(access.listed.contains { $0.hasSuffix("/a/b") })
    }

    @Test func unlimitedDepthReadsEverything() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b/c/secret.txt")
        let outcome = try await harness.run(access: access, maxDepth: nil)
        #expect(outcome.status == .indexed)
        #expect(try await harness.names().contains("secret.txt"))
        #expect(access.listed.contains { $0.hasSuffix("/a/b/c") })
    }

    @Test func levelsFinishBeforeTheNextBegins() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/a2/x.txt")
        access.file("b/b2/y.txt")
        let outcome = try await harness.run(access: access, maxDepth: nil)
        let paths = access.listed
        let a = try #require(paths.firstIndex { $0.hasSuffix("/a") && !$0.hasSuffix("/a2") })
        let b = try #require(paths.firstIndex { $0.hasSuffix("/b") && !$0.hasSuffix("/b2") })
        let a2 = try #require(paths.firstIndex { $0.hasSuffix("/a/a2") })
        let b2 = try #require(paths.firstIndex { $0.hasSuffix("/b/b2") })
        #expect(a2 > a && a2 > b)
        #expect(b2 > a && b2 > b)
        #expect(outcome.completedDepths == [1, 2, 3])
    }

    @Test func progressCountsFoldersWhenTheyAreDiscovered() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        for folder in 0..<10 {
            for child in 0..<10 {
                access.file("f\(folder)/c\(child)/x.txt")
            }
        }
        let samples = Samples()
        let outcome = try await harness.run(access: access, maxDepth: 3, onProgress: { progress in
            if !progress.finished { samples.values.append(progress.ratio) }
        })
        #expect(outcome.status == .indexed)
        #expect(samples.values.count >= 2)
        #expect(zip(samples.values, samples.values.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(samples.values.dropLast().allSatisfy { $0 < 0.99 })
        #expect(outcome.progress.last == 1)
        if let first = samples.values.first {
            #expect(first < 0.25)
        }
    }

    @Test func failedDirectoryWriteStopsWithoutAdvancingDepth() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b.txt")
        let before = try #require(try await harness.store.medium(uuid: harness.mediumID)).completedDepth
        await harness.store.setDirectoryWritesFailing(true)
        let outcome = try await harness.run(access: access, maxDepth: nil)
        let after = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(outcome.status == .error)
        #expect(after.indexStatus == .error)
        #expect(after.completedDepth == before)
        #expect(outcome.completedDepths.isEmpty)
    }

    /// bug.0.4.066: Fortsetzen nach Ebene 2 zählt den ganzen Baum (das Zählen darf die Wurzel lesen),
    /// indiziert Ebene 1 und 2 aber nicht noch einmal (Trigger in der Test-DB zählen die Schreibvorgänge):
    /// keine Zeile der Ebenen 1/2 neu angelegt, gelöscht oder als Kind geändert, und Ebene 1 gar nicht berührt
    /// (ein erneutes Listen von „a“ für Ebene 2 setzte dort `listedAt`). Erlaubt ist nur, dass „b“ als Eltern
    /// von Ebene 3 gelistet wird (`listedAt`, `contentStamp`). Ein unveränderter Ordner schreibt beim Listen nichts
    /// (gleicher `contentStamp`), deshalb kommen vor dem Fortsetzen auf Ebene 1 und 2 je eine Datei dazu: nur ein
    /// erneutes Indizieren dieser Ebenen würde sie schreiben; das Zählen sieht sie (Gesamtzahl 6).
    @Test func resumeAfterDepthTwoDoesNotIndexTheFirstLevelsAgain() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b/c/f.txt")
        let arm = Arm()
        let first = try await harness.run(access: access, maxDepth: nil, shouldHalt: {
            guard arm.value else { return .none }
            let depth = (try? await harness.store.medium(uuid: harness.mediumID))?.completedDepth ?? 0
            return depth >= 2 ? .cancel : .none
        })
        #expect(first.status == .pending)
        #expect(try await harness.store.medium(uuid: harness.mediumID)?.completedDepth == 2)

        struct Row: Equatable { var id: Int64; var parentID: Int64?; var name: String; var depth: Int }
        func firstLevels() async throws -> [Row] {
            try await harness.store.pool.read { db in
                try GRDB.Row.fetchAll(db, sql: "SELECT id, parentID, name, depth FROM items WHERE depth <= 2 ORDER BY id")
                    .map { Row(id: $0["id"], parentID: $0["parentID"], name: $0["name"], depth: $0["depth"]) }
            }
        }
        let before = try await firstLevels()
        #expect(before.map(\.name) == ["a", "b"])
        try await harness.store.pool.write { db in
            try db.execute(sql: """
                CREATE TABLE test_item_writes (op TEXT NOT NULL, itemID INTEGER, depth INTEGER);
                CREATE TRIGGER test_items_insert AFTER INSERT ON items
                    BEGIN INSERT INTO test_item_writes VALUES ('insert', NEW.id, NEW.depth); END;
                CREATE TRIGGER test_items_child_update
                    AFTER UPDATE OF parentID, name, slug, isFolder, extID, kind, depth, modifiedAt, fileID, status ON items
                    BEGIN INSERT INTO test_item_writes VALUES ('child-update', NEW.id, OLD.depth); END;
                CREATE TRIGGER test_items_depth_one_update AFTER UPDATE ON items WHEN OLD.depth = 1
                    BEGIN INSERT INTO test_item_writes VALUES ('depth1-update', NEW.id, OLD.depth); END;
                CREATE TRIGGER test_items_delete AFTER DELETE ON items
                    BEGIN INSERT INTO test_item_writes VALUES ('delete', OLD.id, OLD.depth); END;
                CREATE TRIGGER test_details_insert AFTER INSERT ON item_details
                    BEGIN INSERT INTO test_item_writes VALUES ('details', NEW.itemID, (SELECT depth FROM items WHERE id = NEW.itemID)); END;
                CREATE TRIGGER test_details_update AFTER UPDATE ON item_details
                    BEGIN INSERT INTO test_item_writes VALUES ('details', NEW.itemID, (SELECT depth FROM items WHERE id = NEW.itemID)); END;
                """)
        }
        access.file("x.txt")
        access.file("a/y.txt")
        arm.value = false
        let progress = ProgressLog()
        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false, onProgress: { progress.note($0) })
        #expect(second.status == .indexed)
        #expect(second.completedDepths.first == 3)
        let names = try await harness.names()
        #expect(names.contains("f.txt"))
        #expect(!names.contains("x.txt"), "Ebene 1 erneut indiziert")
        #expect(!names.contains("y.txt"), "Ebene 2 erneut indiziert")
        // Die Zählung lief über den ganzen Baum (a, b, c, f.txt, x.txt, y.txt) statt `scanTotal = entriesCompleted`.
        let events = progress.events
        #expect(events.contains { $0.phase == .counting && $0.countingCount > 0 })
        let firstIndexing = try #require(events.first { $0.phase == .indexing })
        #expect(firstIndexing.entriesTotal == 6)

        let writes: [(op: String, depth: Int?)] = try await harness.store.pool.read { db in
            try GRDB.Row.fetchAll(db, sql: "SELECT op, depth FROM test_item_writes").map { ($0["op"], $0["depth"]) }
        }
        #expect(writes.contains { ($0.depth ?? 0) >= 3 }, "Trigger hat die neuen Ebenen nicht gesehen: \(writes)")
        let firstLevelWrites = writes.filter { ($0.depth ?? 0) <= 2 }
        #expect(firstLevelWrites.isEmpty, "Ebene 1/2 erneut geschrieben: \(firstLevelWrites)")
        #expect(try await firstLevels() == before)
    }

    @Test func exclusionsSkipSystemFilesPatternsAndHiddenNames() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file(".Spotlight-V100/inside.txt")
        access.file("._x")
        access.file(".DS_Store")
        access.file("note.tmp")
        access.file("node_modules/pkg/a.js")
        access.file("keep.txt")
        _ = try await harness.run(access: access, maxDepth: nil, ignoreHidden: true, patterns: ["*.tmp", "node_modules"])
        var names = try await harness.names()
        #expect(names == ["keep.txt"])
        #expect(!access.listed.contains { $0.contains("node_modules") })
        #expect(!access.listed.contains { $0.contains("Spotlight") })

        let open = try await ScanHarness.make()
        let again = MemoryVolume(mountPath: "/Volumes/T")
        again.file(".Spotlight-V100/inside.txt")
        again.file("._x")
        again.file(".DS_Store")
        again.file("note.tmp")
        again.file("node_modules/pkg/a.js")
        again.file("keep.txt")
        _ = try await open.run(access: again, maxDepth: nil, ignoreHidden: false, patterns: ["*.tmp", "node_modules"])
        names = try await open.names()
        #expect(!names.contains(".DS_Store"))
        #expect(names.contains("keep.txt"))
        #expect(!names.contains("._x"))
        #expect(!names.contains("inside.txt"))
        #expect(!names.contains("note.tmp"))
        #expect(!names.contains("a.js"))
        #expect(!names.contains("node_modules"))
    }

    @Test func unreadableFolderIsSkippedAndUnreadableRootIsAnError() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("bad/keep.txt")
        // Tiefer Zweig daneben: die Ebenen unter der Lücke werden fertig (bug.0.4.127, Folgelauf darf nicht darunter
        // beginnen).
        access.file("ok/a/b/tief.txt")
        _ = try await harness.run(access: access, maxDepth: nil)
        let kept = try #require(try await harness.item(named: "keep.txt"))
        access.markUnreadable("bad")
        // Ohne lange Lese-Wiederholungen (1 + 3 + 10 s je unlesbarem Ordner).
        var fastRetries = IndexingRunLimits.standard
        fastRetries.readRetryDelays = [.milliseconds(1)]
        let outcome = try await harness.run(access: access, maxDepth: nil, fromScratch: true, limits: fastRetries)
        // bug.0.4.127 (README 4): nicht lesbarer Ordner → Index unvollständig („x % indiziert“), nicht `.indexed`.
        #expect(outcome.status != .indexed)
        #expect(outcome.readErrors == 1)
        let partial = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(partial.indexStatus != .indexed)
        let partialPercent = await MainActor.run { partial.asMedium(connection: .connected).indexProgressPercent }
        #expect(partialPercent < 100)
        let still = try #require(try await harness.store.item(id: kept.id))
        #expect(still.name == "keep.txt")
        // Gegenprobe: bleibt „bad“ unlesbar, bleibt der Index unvollständig (der Folgelauf liest die Lücke nach).
        let stillBad = try await harness.run(access: access, maxDepth: nil, fromScratch: false, limits: fastRetries)
        #expect(stillBad.status != .indexed, "Folgelauf meldet ohne Nachlesen „indiziert“")
        access.markReadable("bad")
        let listedBefore = access.listed.filter { $0.hasSuffix("/bad") }.count
        let again = try await harness.run(access: access, maxDepth: nil, fromScratch: false, limits: fastRetries)
        #expect(access.listed.filter { $0.hasSuffix("/bad") }.count > listedBefore, "„bad“ wurde nicht neu gelesen")
        #expect(again.status == .indexed)
        let complete = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(complete.indexStatus == .indexed)
        let completePercent = await MainActor.run { complete.asMedium(connection: .connected).indexProgressPercent }
        #expect(completePercent == 100)

        let broken = try await ScanHarness.make()
        let root = MemoryVolume(mountPath: "/Volumes/T")
        root.markUnreadable("")
        let failed = try await broken.run(access: root, maxDepth: nil)
        #expect(failed.status == .error)
    }

    /// Schema V3: Was beim vollständigen Lesen fehlt, ist erst „verschwunden“ und wird am Ende des Laufs samt Favorit
    /// gelöscht; taucht die Datei später wieder auf, ist sie ein neuer Eintrag (Umbenennen erkennt 235).
    @Test func secondRunRemovesAMissingEntryWithItsFavorite() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("keep.txt")
        _ = try await harness.run(access: access, maxDepth: nil)
        let kept = try #require(try await harness.item(named: "keep.txt"))
        try await harness.store.setFavorite(itemID: kept.id, true)
        access.remove("keep.txt")
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        #expect(try await harness.store.item(id: kept.id) == nil)
        #expect(try await harness.store.favorites().isEmpty)
        access.file("keep.txt")
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        let back = try #require(try await harness.item(named: "keep.txt"))
        #expect(back.id != kept.id)
        #expect(!back.isFavorite)
        #expect(back.fileID == nil)
    }

    @Test func fullReconcileAfterIndexedMediumAppliesAddRemoveAndChange() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("l1/l2/l3/l4/keep.txt", size: 1)
        access.file("l1/l2/l3/l4/remove.txt", size: 2)
        access.file("l1/l2/l3/l4/old.txt", size: 3)
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        let indexed = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(indexed.indexStatus == .indexed)
        #expect(indexed.completedDepth >= 4)

        access.remove("l1/l2/l3/l4/remove.txt")
        access.file("l1/l2/l3/l4/new.txt", size: 4)
        access.remove("l1/l2/l3/l4/old.txt")
        access.file("l1/l2/l3/l4/old.txt", size: 88)

        let outcome = try await harness.run(access: access, maxDepth: nil, fromScratch: false)
        #expect(outcome.status == .indexed)
        let names = try await harness.names()
        #expect(names.contains("new.txt"))
        #expect(names.contains("old.txt"))
        #expect(!names.contains("remove.txt"))
        let old = try #require(try await harness.item(named: "old.txt"))
        #expect(old.sizeBytes == 88)
        #expect(!names.contains("remove.txt"))
    }

    @Test func progressNeverFallsAndFirstIndexedAtIsSetOnce() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b/c.txt")
        let before = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(before.indexStatus == .pending)
        let seen = StatusLog()
        let outcome = try await harness.run(access: access, maxDepth: nil, onProgress: { _ in
            if let status = (try? await harness.store.medium(uuid: harness.mediumID))?.indexStatus, seen.values.last != status {
                seen.values.append(status)
            }
        })
        if let status = try await harness.store.medium(uuid: harness.mediumID)?.indexStatus, seen.values.last != status {
            seen.values.append(status)
        }
        #expect(seen.values == [.pending, .indexing, .indexed])
        #expect(outcome.progress.last == 1)
        #expect(zip(outcome.progress, outcome.progress.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(outcome.progress.dropLast().allSatisfy { $0 <= 0.99 })
        let first = try #require(outcome.firstIndexedAt)
        let again = try await harness.run(access: access, maxDepth: nil, fromScratch: false)
        #expect(again.firstIndexedAt == first)
        #expect(again.status == .indexed)
    }

    @Test func packageAndSymlinkAreStoredAsFiles() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.package("Demo.app", child: "Info.plist")
        access.symlink("link")
        _ = try await harness.run(access: access, maxDepth: nil)
        let app = try #require(try await harness.item(named: "Demo.app"))
        #expect(app.isPackage)
        #expect(!app.isFolder)
        #expect(app.sizeBytes == nil)
        #expect(!access.listed.contains { $0.hasSuffix("/Demo.app") })
        let link = try #require(try await harness.item(named: "link"))
        #expect(!link.isFolder)
        #expect(link.fileID == nil)
        #expect(!access.listed.contains { $0.hasSuffix("/link") })
    }

    @Test func realDirectoryMatchesTheTree() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-tree-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("a/b", isDirectory: true), withIntermediateDirectories: true)
        let file = root.appendingPathComponent("a/b/c.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("hi".utf8))
        FileManager.default.createFile(atPath: root.appendingPathComponent(".hidden").path, contents: Data("h".utf8))
        FileManager.default.createFile(atPath: root.appendingPathComponent("._skip").path, contents: Data("s".utf8))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("a/link"), withDestinationURL: file)
        defer { try? FileManager.default.removeItem(at: root) }

        let harness = try await ScanHarness.make()
        let outcome = try await harness.run(
            access: DirectMediumAccess(),
            maxDepth: nil,
            volume: harness.volume(at: root.path)
        )
        #expect(outcome.status == .indexed)
        let names = try await harness.names()
        #expect(names.contains("c.txt"))
        #expect(names.contains("link"))
        #expect(names.contains("a"))
        #expect(names.contains("b"))
        #expect(!names.contains(".hidden"))
        #expect(!names.contains("._skip"))
        let link = try #require(try await harness.item(named: "link"))
        #expect(!link.isFolder)
    }

    @Test func scanningTwentyThousandFilesStaysUnderThirtySeconds() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-smoke-\(UUID().uuidString)", isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let payload = Data("x".utf8)
        for folder in 0..<500 {
            let directory = root.appendingPathComponent("d\(folder)", isDirectory: true)
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            for file in 0..<40 {
                manager.createFile(atPath: directory.appendingPathComponent("f\(file).txt").path, contents: payload)
            }
        }
        let harness = try await ScanHarness.make()
        let started = ContinuousClock.now
        let outcome = try await harness.run(
            access: DirectMediumAccess(),
            maxDepth: nil,
            volume: harness.volume(at: root.path)
        )
        let elapsed = started.duration(to: .now)
        let counts = try await harness.store.counts(mediumUUID: harness.mediumID)
        let report = "Scanner Rauchtest: \(elapsed), Dateien \(counts.files), Ordner \(counts.folders)"
        print(report)
        Attachment.record(report, named: "scanner-smoke.txt")
        #expect(outcome.status == .indexed)
        #expect(counts.files == 20_000)
        #expect(counts.folders == 500)
        #expect(elapsed < .seconds(60))
    }
}

private final class Samples: @unchecked Sendable {
    var values: [Double] = []
}

/// bug.0.4.066: Fortschrittsereignisse eines Laufs (Instanz je Test, Regel 20).
private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [IndexProgress] = []

    func note(_ progress: IndexProgress) {
        lock.lock()
        defer { lock.unlock() }
        values.append(progress)
    }

    var events: [IndexProgress] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

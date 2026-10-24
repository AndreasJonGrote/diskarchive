//
//  EjectDuringRunTests.swift
//  diskindexTests
//
//  bug.0.4.177: Das Medium wird mitten im Lauf ausgeworfen, der Einhängepunkt bleibt als leerer Ordner stehen. Ein
//  leer gelesener Ordner darf dann nicht den Index (samt Favoriten) löschen; der normale Weg (wirklich geleerter Ordner
//  auf dem eingehängten Medium) bleibt.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct EjectDuringRunTests {
    private func indexed() async throws -> (ScanHarness, MemoryVolume, VolumeInfo) {
        let harness = try await ScanHarness.make()
        let volume = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = volume.file("A/a.txt", size: 10).file("B/b.txt", size: 20).file("C/c.txt", size: 30).file("C/c2.txt", size: 31)
        let info = harness.volume(at: volume.mountPath)
        let first = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, volume: info)
        try #require(first.status == .indexed, "Voraussetzung: erster Lauf vollständig")
        let favorite = try #require(try await harness.item(named: "a.txt"))
        try await harness.store.setFavorite(itemID: favorite.id, true)
        return (harness, volume, info)
    }

    /// (a) Ausgeworfen vor dem Lesen der Wurzel: die Wurzel liest leer → kein Eintrag entfernt, Favorit bleibt, der
    /// Lauf gilt nicht als vollständig.
    @Test func ejectedMediumReadingEmptyRemovesNothing() async throws {
        let (harness, volume, info) = try await indexed()
        volume.eject()
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info)
        let names = try await harness.names()
        #expect(names.isSuperset(of: ["A", "B", "C", "a.txt", "b.txt", "c.txt"]), "Einträge nach Auswurf entfernt: \(names)")
        #expect(!(try await harness.store.favoriteItemIDs()).isEmpty, "Favorit nach Auswurf gelöscht")
        #expect(!outcome.ranToEnd, "Lauf auf dem ausgeworfenen Medium als bis zum Ende gelaufen gewertet")
    }

    /// (a) Unter dem Pfad ist ein anderes Medium mit eigenem Inhalt eingehängt (kein bisheriger Name der Wurzel mehr da)
    /// → nichts entfernt und nichts vom fremden Medium in den Index übernommen.
    @Test func foreignMediumAtThePathIsNotTakenIntoTheIndex() async throws {
        let (harness, _, info) = try await indexed()
        let foreign = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = foreign.file("X/fremd.txt", size: 5).file("Y/auch.txt", size: 6)
        foreign.markForeign()
        let outcome = try await harness.run(access: foreign, maxDepth: nil, fromScratch: false, volume: info)
        let names = try await harness.names()
        #expect(names.isSuperset(of: ["A", "B", "C", "a.txt", "b.txt", "c.txt"]), "Einträge entfernt: \(names)")
        #expect(names.isDisjoint(with: ["X", "Y", "fremd.txt", "auch.txt"]), "Inhalt des fremden Mediums im Index: \(names)")
        #expect(!outcome.ranToEnd)
    }

    /// Gegenprobe: ein wirklich geleerter Ordner auf dem eingehängten Medium → sein Inhalt wird entfernt.
    @Test func reallyEmptiedFolderOnTheMountedMediumIsRemoved() async throws {
        let (harness, volume, info) = try await indexed()
        volume.remove("B/b.txt")
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info)
        #expect(outcome.ranToEnd)
        let names = try await harness.names()
        #expect(!names.contains("b.txt"), "Inhalt des geleerten Ordners blieb")
        #expect(names.contains("a.txt") && names.contains("c.txt"))
    }

    /// (b) Ausgeworfen erst, nachdem alle Ordner gelesen sind; kein Ordner liest leer (C behält `c2.txt`), die Prüfung
    /// beim Leerlesen greift also nicht: vor dem Abschluss wird noch einmal geprüft → der Lauf endet unterbrochen, die
    /// entfernte Datei wird nicht endgültig gelöscht.
    @Test func ejectBeforeTheFinishKeepsTheRunIncomplete() async throws {
        let (harness, volume, info) = try await indexed()
        volume.remove("C/c.txt")
        let mount = URL(fileURLWithPath: volume.mountPath).standardizedFileURL.path
        let earlier = volume.listed.count
        // Nach dem Auswerfen liest die Zählung noch Ordner (fehlen jetzt): kurze Wiederholungen, damit der Test schnell ist.
        var limits = IndexingRunLimits.standard
        limits.readRetryDelays = [.milliseconds(10)]
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info, limits: limits, shouldHalt: {
            // Positives Signal: in diesem Lauf sind alle drei Ordner der zweiten Ebene gelesen → jetzt auswerfen.
            let read = Set(volume.listed.dropFirst(earlier).filter { $0.hasPrefix(mount + "/") })
            if read.count >= 3 { volume.eject() }
            return .none
        })
        #expect(!outcome.ranToEnd, "Lauf trotz Auswurf vor dem Abschluss als vollständig gewertet")
        let pool = harness.store.pool
        let rows: Int = try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE name = 'c.txt'") ?? 0 }
        #expect(rows == 1, "Zeile von c.txt endgültig gelöscht, obwohl das Medium vor dem Abschluss ausgeworfen war")
    }
}

extension FatReconnectIndexerTests {
    /// bug.0.4.177 (c): Während der Teil-Prüfsummen-Lesung wird das Medium ausgeworfen, der Einhängeordner bleibt leer
    /// stehen → die fehlende Datei heißt nichts; Favorit bleibt (unlesbar statt fehlt).
    @Test func ejectDuringThePartialReadWithAnEmptyMountFolderKeepsTheFavorite() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-eject-read-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let ejected = EjectFlag()
        // Vor dem Lesen eingehängt (Testordner steht für das Medium); danach kein Einhängepunkt mehr.
        await store.setMountCheckForTesting { _, _ in true }
        await store.setMountPointCheckForTesting { _ in !ejected.value }
        await store.setPartialReadHookForTesting { _ in
            // Auswerfen: Inhalt weg, der Ordner bleibt.
            for item in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
                try? FileManager.default.removeItem(at: item)
            }
            ejected.set()
        }
        let old = try await Self.runMovedFileFinish(store: store, id: harness.mediumID, root: root, finishMountPath: root.path)
        #expect(try await store.favoriteItemIDs().contains(old.id), "Favorit nach Auswurf während des Lesens gelöscht")
    }
}

private final class EjectFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}

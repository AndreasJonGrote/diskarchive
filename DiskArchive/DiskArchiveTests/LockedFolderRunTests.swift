//
//  LockedFolderRunTests.swift
//  DiskArchiveTests
//
//  bug.0.4.235: Ein nach dem Indizieren gesperrter Ordner (`chmod 000`) machte jeden Abgleich langsam: „keine Rechte“
//  wurde dreimal wiederholt (1 s, 3 s, 10 s), und jeder alte Unterordner aus der Datenbank wurde einzeln gelesen und
//  wartete wieder. Jetzt: einmal gelesen, keine Wiederholung, Nachfahren nicht gelesen, ihre Zeilen und Favoriten
//  bleiben. Echte Dateien im Testordner; die Lesezugriffe zählt eine Hülle um `DirectMediumAccess`.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct LockedFolderRunTests {
    /// Kurze Wartezeiten: vor dem Fix sähe der Test vier Lesezugriffe auf `A` statt einem, ohne 14 s zu warten.
    private static var limits: IndexingRunLimits {
        var limits = IndexingRunLimits.standard
        limits.readRetryDelays = [.milliseconds(1), .milliseconds(1), .milliseconds(1)]
        return limits
    }

    @Test func lockedFolderIsReadOnceAndItsSubfoldersNotAtAll() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-locked-\(UUID().uuidString)", isDirectory: true)
        let locked = root.appendingPathComponent("A", isDirectory: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: root)
        }
        for index in 1...5 {
            let folder = locked.appendingPathComponent("s\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("datei \(index)".utf8).write(to: folder.appendingPathComponent("datei"))
        }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("B"), withIntermediateDirectories: true)
        try Data("frei".utf8).write(to: root.appendingPathComponent("B/frei"))

        let harness = try await ScanHarness.make()
        defer { harness.closeDatabase() }
        await harness.store.setMountCheckForTesting { _, _ in true }
        var direct = DirectMediumAccess()
        direct.mountCheck = { _, _ in true }
        let access = CountingAccess(direct)
        let volume = harness.volume(at: root.path)
        let first = try await harness.run(access: access, maxDepth: nil, fromScratch: true, volume: volume, limits: Self.limits)
        try #require(first.status == .indexed, "Erstindex: \(first.status)")
        let before = try await items(harness)
        let favorite = try #require(before["A/s3/datei"], "A/s3/datei fehlt")
        try await harness.store.setFavorite(itemID: favorite.id, true)

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        try #require((try? FileManager.default.contentsOfDirectory(atPath: locked.path)) == nil, "Voraussetzung: A ist gesperrt")
        access.reset()
        let lockedRun = try await harness.run(access: access, maxDepth: nil, fromScratch: false, volume: volume, limits: Self.limits)

        // Je Schritt (Zählen, Indizieren) höchstens einmal; der Abgleich zählt nur, wenn die Gesamtzahl fehlt.
        #expect(access.reads(of: locked, counting: false) == 1, "A \(access.reads(of: locked, counting: false))× indiziert (Wiederholung bei „keine Rechte“)")
        #expect(access.reads(of: locked, counting: true) <= 1, "A \(access.reads(of: locked, counting: true))× gezählt")
        for index in 1...5 {
            let sub = locked.appendingPathComponent("s\(index)", isDirectory: true)
            #expect(access.reads(of: sub, counting: false) + access.reads(of: sub, counting: true) == 0, "s\(index) gelesen")
        }
        #expect(lockedRun.status == .error, "Status \(lockedRun.status)")
        #expect(lockedRun.failureReason == .unreadableFolders, "Grund \(String(describing: lockedRun.failureReason))")
        let during = try await items(harness)
        for path in before.keys {
            #expect(during[path]?.id == before[path]?.id, "\(path) nach dem gesperrten Lauf verändert oder weg")
        }
        #expect(try await harness.store.favoriteItemIDs().contains(favorite.id), "Favorit auf A/s3/datei weg")
        try await expectNoGoneRows(harness)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        let reopened = try await harness.run(access: access, maxDepth: nil, fromScratch: false, volume: volume, limits: Self.limits)
        #expect(reopened.status == .indexed, "nach dem Entsperren: \(reopened.status)")
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(stored.asMedium(connection: .connected).indexProgressPercent == 100)
        let after = try await items(harness)
        #expect(Set(after.keys) == Set(before.keys), "Einträge nach dem Entsperren: \(after.keys.sorted())")
        #expect(after["A/s3/datei"]?.id == favorite.id)
        try await expectNoGoneRows(harness)
    }

    /// Sichtbare Einträge nach Pfad (`A/s1/datei`).
    private func items(_ harness: ScanHarness) async throws -> [String: StoredItem] {
        var found: [String: StoredItem] = [:]
        func walk(_ parent: Int64?, _ prefix: String) async throws {
            for child in try await harness.store.children(mediumUUID: harness.mediumID, parentID: parent) {
                let path = prefix.isEmpty ? child.name : prefix + "/" + child.name
                found[path] = child
                if child.isFolder { try await walk(child.id, path) }
            }
        }
        try await walk(nil, "")
        return found
    }

    /// Keine verschwundenen Zeilen und keine Zeile außerhalb des sichtbaren Baums (nichts doppelt).
    private func expectNoGoneRows(_ harness: ScanHarness) async throws {
        let mediumUUID = harness.mediumID
        let visible = try await items(harness).count
        let counts = try await harness.store.pool.read { db -> (all: Int, gone: Int) in
            let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: mediumUUID))
            let all = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE storageID = ?", arguments: [storageID]) ?? -1
            let gone = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM items WHERE storageID = ? AND status = 2", arguments: [storageID]
            ) ?? -1
            return (all, gone)
        }
        #expect(counts.gone == 0, "verschwundene Zeilen: \(counts.gone)")
        #expect(counts.all == visible, "Zeilen \(counts.all), im Baum \(visible)")
    }
}

/// Zählt Lesezugriffe je Ordner (Zähl- und Indizierschritt), sonst wie `DirectMediumAccess`.
private final class CountingAccess: MediumAccess, @unchecked Sendable {
    private let inner: DirectMediumAccess
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var countingCounts: [String: Int] = [:]

    init(_ inner: DirectMediumAccess) {
        self.inner = inner
    }

    func reset() {
        lock.withLock {
            counts = [:]
            countingCounts = [:]
        }
    }

    func reads(of url: URL, counting: Bool) -> Int {
        lock.withLock { (counting ? countingCounts : counts)[url.standardizedFileURL.path] ?? 0 }
    }

    private func note(_ url: URL, counting: Bool = false) {
        lock.withLock {
            if counting {
                countingCounts[url.standardizedFileURL.path, default: 0] += 1
            } else {
                counts[url.standardizedFileURL.path, default: 0] += 1
            }
        }
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { await inner.probe(volume) }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        note(url)
        return try await inner.listDirectory(at: url)
    }

    func listDirectoryChunks(at url: URL, chunkSize: Int) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        note(url)
        return inner.listDirectoryChunks(at: url, chunkSize: chunkSize)
    }

    func listDirectoryCountChunks(at url: URL, chunkSize: Int) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        note(url, counting: true)
        return inner.listDirectoryCountChunks(at: url, chunkSize: chunkSize)
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool {
        await inner.mediumIsMounted(medium, mountPath: mountPath)
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String, completion: PartialReadCompletion?) async -> Bool {
        await inner.mediumIsMounted(medium, mountPath: mountPath, completion: completion)
    }
}

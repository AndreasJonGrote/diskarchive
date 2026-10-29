//
//  ForgetDurableTests.swift
//  diskindexTests
//
//  bug.0.4.224: „Vergessen“ ist sofort dauerhaft. Endet die App, während die Einträge noch gelöscht werden, ist das
//  Medium nach dem Neuöffnen trotzdem weg (auch in Suche und Favoriten), und der Start löscht den Rest zu Ende.
//  Das Ende des Prozesses stellt ein Haken vor dem ersten Stück nach: er hält das Löschen an, danach wird die Datei
//  geschlossen und neu geöffnet.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@MainActor
@Suite(.serialized)
struct ForgetDurableTests {
    /// Test 1: ein großes Medium vergessen, sofort danach Ende → nach dem Neuöffnen nicht mehr da.
    @Test func forgottenLargeMediumStaysGoneAfterAnAbruptEnd() async throws {
        let rig = try ForgetRig.make()
        let big = try await rig.addMedium(name: "Daten", rows: 200_000, favorite: true)
        let app = AppState(store: rig.store)
        await app.loadStoredMedia()
        #expect(app.media.contains { $0.id == big.uuid })
        #expect(try await !rig.store.search(query: "daten-1", filters: SearchFilters()).isEmpty)
        #expect(try await !rig.store.favorites().isEmpty)

        let halt = try await rig.haltPurgeAtFirstChunk()
        app.forgetMedium(id: big.uuid)
        #expect(await waitUntil { halt.reached }, "Löschen der Einträge hat nicht begonnen")

        let reopened = try rig.reopen()
        let restarted = AppState(store: reopened)
        await restarted.loadStoredMedia()
        #expect(restarted.media.isEmpty, "vergessenes Medium nach dem Neustart wieder da")
        #expect(try await reopened.media().isEmpty)
        #expect(try await reopened.search(query: "daten-1", filters: SearchFilters()).isEmpty, "Suche zeigt vergessene Einträge")
        #expect(try await reopened.searchCount(query: "daten-1", filters: SearchFilters()) == 0)
        #expect(try await reopened.favorites().isEmpty, "Favorit des vergessenen Mediums wieder da")
        #expect(try await rig.itemCount() > 0, "Vorbedingung: Einträge sind noch nicht gelöscht")
    }

    /// Test 2: „Alle vergessen“ mit drei Medien, das große zuerst, sofort danach Ende → keines mehr da.
    @Test func forgetAllStaysGoneAfterAnAbruptEndDuringTheLargeMedium() async throws {
        let rig = try ForgetRig.make()
        _ = try await rig.addMedium(name: "Daten", rows: 200_000, favorite: true)
        _ = try await rig.addMedium(name: "Stick", rows: 30, favorite: false)
        _ = try await rig.addMedium(name: "Karte", rows: 3, favorite: true)
        let app = AppState(store: rig.store)
        await app.loadStoredMedia()
        #expect(app.registryMedia.count == 3)

        let halt = try await rig.haltPurgeAtFirstChunk()
        app.forgetAllMedia()
        #expect(await waitUntil { halt.reached }, "Löschen der Einträge hat nicht begonnen")

        let reopened = try rig.reopen()
        let restarted = AppState(store: reopened)
        await restarted.loadStoredMedia()
        #expect(restarted.media.isEmpty, "nach dem Neustart wieder da: \(restarted.media.map(\.name))")
        #expect(try await reopened.media().isEmpty)
        #expect(try await reopened.favorites().isEmpty)
    }

    /// Test 3: eine beim Ende offene Löschung läuft nach dem Neuöffnen beim Start zu Ende.
    @Test func pendingDeletionFinishesAfterTheNextStart() async throws {
        let rig = try ForgetRig.make()
        let big = try await rig.addMedium(name: "Daten", rows: 50_000, favorite: true)
        let app = AppState(store: rig.store)
        await app.loadStoredMedia()
        let halt = try await rig.haltPurgeAtFirstChunk()
        app.forgetMedium(id: big.uuid)
        #expect(await waitUntil { halt.reached })

        let reopened = try rig.reopen()
        #expect(try await rig.itemCount() == 50_000, "Vorbedingung: noch nichts gelöscht")
        let restarted = AppState(store: reopened)
        let coordinator = MediumCoordinator(store: reopened, access: NoAccess(), appState: restarted)
        MediumRecognitionStartup.bootstrap(
            appState: restarted,
            store: reopened,
            coordinator: coordinator,
            startChangeLoop: {},
            makeMonitor: { MediumMonitor(mountedVolumes: { [] }, wakeEvents: { AsyncStream { _ in } }) }
        )
        defer { coordinator.stop() }
        let finished = try await waitUntil(timeout: 30) {
            guard try await rig.itemCount() == 0 else { return false }
            return try await rig.storageRowCount() == 0
        }
        let left = try await rig.itemCount()
        #expect(finished, "offene Löschung nach dem Start nicht fortgesetzt: items=\(left)")
    }
}

/// Eigene Datei, die sich schließen und wie nach einem Neustart neu öffnen lässt.
@MainActor
private final class ForgetRig {
    let directory: URL
    let fileURL: URL
    private var database: TestDatabase
    private(set) var store: IndexStoreV3

    static func make() throws -> ForgetRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-forget-\(UUID().uuidString)", isDirectory: true)
        return try ForgetRig(directory: directory)
    }

    private init(directory: URL) throws {
        self.directory = directory
        fileURL = directory.appendingPathComponent("archive.sqlite")
        database = try TestDatabase(fileURL: fileURL)
        store = IndexStoreV3(database: database)
    }

    deinit {
        try? database.close()
        try? FileManager.default.removeItem(at: directory)
    }

    /// Medium mit Index (Entscheidung „Ja“) und `rows` Dateien im Wurzelordner; mit `favorite` ist die letzte ein Favorit.
    func addMedium(name: String, rows: Int, favorite: Bool) async throws -> StoredMedium {
        let medium = StoredMedium(
            volumeUUID: UUID().uuidString, fsType: "apfs", volumeTotalBytes: 10, name: name,
            decision: .index, indexStatus: .indexed, fileCount: rows, firstIndexedAt: Date(), lastIndexedAt: Date()
        )
        try await store.upsertMedium(medium)
        let prefix = name.lowercased()
        try await store.pool.write { db in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: medium.uuid) else { throw IndexStoreError.unknownMedium }
            try db.execute(
                sql: """
                    WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < ?)
                    INSERT INTO items (storageID, name, slug) SELECT ?, ? || '-' || x || '.txt', ? || '-' || x || '.txt' FROM n
                    """,
                arguments: [rows, storageID, prefix, prefix]
            )
            if favorite {
                try db.execute(
                    sql: "INSERT INTO favorites (itemID, createdAt) SELECT MAX(id), 0 FROM items WHERE storageID = ?",
                    arguments: [storageID]
                )
            }
        }
        return medium
    }

    /// Hält das Löschen der Einträge vor dem ersten Stück an, wie ein Ende des Prozesses an dieser Stelle.
    func haltPurgeAtFirstChunk() async throws -> PurgeHalt {
        let halt = PurgeHalt()
        await store.setPurgeChunkHookForTesting {
            halt.reach()
            throw CancellationError()
        }
        return halt
    }

    /// Schließt die Datei und öffnet sie neu (neuer Pool, neuer Speicher, wie nach einem Neustart).
    func reopen() throws -> IndexStoreV3 {
        try database.close()
        database = try TestDatabase(fileURL: fileURL)
        store = IndexStoreV3(database: database)
        return store
    }

    func itemCount() async throws -> Int {
        try await store.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") ?? 0 }
    }

    func storageRowCount() async throws -> Int {
        try await store.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM storages") ?? 0 }
    }
}

final class PurgeHalt: @unchecked Sendable {
    private let lock = NSLock()
    private var wasReached = false
    var reached: Bool { lock.withLock { wasReached } }
    func reach() { lock.withLock { wasReached = true } }
}

private final class NoAccess: MediumAccess, @unchecked Sendable {
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { false }
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

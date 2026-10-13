//
//  ReproAuditTests.swift
//  diskindexTests
//
//  Repro-Tests zum Audit 13.10.2026 (REPORT Nr. 56–70). Jeder Test erwartet das KORREKTE Verhalten
//  und wird rot, solange der Defekt besteht.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct ReproAuditTests {

    // MARK: Hilfen

    private struct RawRow {
        var id: Int64
        var parentID: Int64?
        var name: String
        var status: Int
        var depth: Int
    }

    private func rawRows(_ store: IndexStoreV3) async throws -> [RawRow] {
        try await store.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT id, parentID, name, status, depth FROM items ORDER BY id").map {
                RawRow(id: $0["id"], parentID: $0["parentID"], name: $0["name"], status: $0["status"], depth: $0["depth"])
            }
        }
    }

    private func favoriteCount(_ store: IndexStoreV3) async throws -> Int {
        try await store.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM favorites") ?? 0 }
    }

    private func child(_ store: IndexStoreV3, _ medium: UUID, _ parent: Int64?, _ name: String) async throws -> StoredItem? {
        try await store.children(mediumUUID: medium, parentID: parent).first { $0.name == name }
    }

    // MARK: Nr. 57 — fileID-Verschiebung entfernt die gleichnamige Zeile des Zielordners

    /// P {a.txt F1}, Q {a.txt F2}; dann P neu {a.txt F1, b.txt F2}. 30 frische DBs; jede muss fehlerfrei durchlaufen.
    @Test func nr57_moveIntoFolderWithSameNamedFileNeverFails() async throws {
        var failures: [String] = []
        for run in 0..<30 {
            let harness = try StoreHarness.make()
            let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: nil,
                entries: [
                    ScannedEntry(name: "P", isFolder: true, fileID: "100"),
                    ScannedEntry(name: "Q", isFolder: true, fileID: "200"),
                ],
                seenAt: Date()
            )
            let p = try #require(try await child(harness.store, medium.uuid, nil, "P"))
            let q = try #require(try await child(harness.store, medium.uuid, nil, "Q"))
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: p.id,
                entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, fileID: "1001")],
                seenAt: Date()
            )
            try await harness.store.applyDirectory(
                mediumUUID: medium.uuid, parentID: q.id,
                entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 2, fileID: "1002")],
                seenAt: Date()
            )
            do {
                try await harness.store.applyDirectory(
                    mediumUUID: medium.uuid, parentID: p.id,
                    entries: [
                        ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, fileID: "1001"),
                        ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 2, fileID: "1002"),
                    ],
                    seenAt: Date()
                )
            } catch {
                failures.append("Lauf \(run): \(error)")
            }
        }
        #expect(failures.isEmpty, "Nr. 57: \(failures.count)/30 Läufe scheitern. Erster: \(failures.first ?? "-")")
    }

    /// Variante: P/a.txt gelöscht, Q/a.txt → P/b.txt. R1 (P/a.txt) muss danach `status = 2` haben (keine Leiche).
    @Test func nr57_deletedTargetNameBecomesGone() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [
                ScannedEntry(name: "P", isFolder: true, fileID: "100"),
                ScannedEntry(name: "Q", isFolder: true, fileID: "200"),
            ],
            seenAt: Date()
        )
        let p = try #require(try await child(harness.store, medium.uuid, nil, "P"))
        let q = try #require(try await child(harness.store, medium.uuid, nil, "Q"))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: p.id,
            entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, fileID: "1001")],
            seenAt: Date()
        )
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: q.id,
            entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 2, fileID: "1002")],
            seenAt: Date()
        )
        let r1 = try #require(try await child(harness.store, medium.uuid, p.id, "a.txt"))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: p.id,
            entries: [ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 2, fileID: "1002")],
            seenAt: Date()
        )
        let row = try #require(try await rawRows(harness.store).first { $0.id == r1.id })
        let visible = try await harness.store.children(mediumUUID: medium.uuid, parentID: p.id).map(\.name).sorted()
        #expect(row.status == 2, "Nr. 57: R1 (P/a.txt) hat status=\(row.status) statt 2; sichtbar in P: \(visible)")
    }

    // MARK: Nr. 58 — finishIndexing(.pending) löscht status=2 samt Favorit

    @Test func nr58_pendingFinishKeepsGoneRowsAndFavorites() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "X", isFolder: true, fileID: "10")],
            seenAt: Date()
        )
        let x = try #require(try await child(harness.store, medium.uuid, nil, "X"))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: x.id,
            entries: [ScannedEntry(name: "f.txt", isFolder: false, sizeBytes: 3, fileID: "11")],
            seenAt: Date()
        )
        let f = try #require(try await child(harness.store, medium.uuid, x.id, "f.txt"))
        try await harness.store.setFavorite(itemID: f.id, true)

        // Abgleich: Ebene 1 sieht X nicht mehr (offline nach /A/B/X verschoben) → X samt Unterbaum `gone`.
        let token = UUID()
        #expect(try await harness.store.beginIndexing(mediumUUID: medium.uuid, token: token))
        try await harness.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: [], seenAt: Date())
        let goneBefore = try await rawRows(harness.store).filter { $0.status == 2 }.map(\.name).sorted()
        #expect(goneBefore == ["X", "f.txt"], "Vorbedingung: X und f.txt sind gone, ist \(goneBefore)")
        // Lauf wird pausiert/abgebrochen.
        _ = try await harness.store.finishIndexing(mediumUUID: medium.uuid, token: token, status: .pending, firstIndexedAt: nil)

        let stillThere = try await rawRows(harness.store).contains { $0.id == f.id }
        let favorites = try await favoriteCount(harness.store)
        #expect(stillThere, "Nr. 58: Zeile f.txt (gone) wurde bei finishIndexing(.pending) gelöscht")
        #expect(favorites == 1, "Nr. 58: Favorit verloren nach finishIndexing(.pending), favorites=\(favorites)")
    }

    // MARK: Nr. 56 — Live-Rename mit nicht indiziertem Elternordner trifft die Wurzel

    @Test func nr56_liveRenameWithUnknownParentLeavesRootAlone() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 5, fileID: "77")],
            seenAt: Date()
        )
        let before = try #require(try await child(harness.store, medium.uuid, nil, "readme.txt"))
        let applied = try await harness.store.applyLiveRename(
            mediumUUID: medium.uuid,
            mountPath: "/Volumes/T",
            fromPath: "/Volumes/T/A/B/C/readme.txt",
            toPath: "/Volumes/T/A/B/C/readme2.txt"
        )
        let after = try #require(try await rawRows(harness.store).first { $0.id == before.id })
        #expect(!applied, "Nr. 56: applyLiveRename meldet Erfolg, obwohl /A/B/C nicht im Index ist")
        #expect(after.name == "readme.txt" && after.parentID == nil && after.depth == 1,
                "Nr. 56: Wurzelzeile verändert → name=\(after.name) parent=\(String(describing: after.parentID)) depth=\(after.depth)")
    }

    // MARK: Nr. 67 — beginIndexing wirft → Token bleibt

    @Test func nr67_failedBeginIndexingLeavesNoToken() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.deleteMedium(uuid: medium.uuid)
        var threw = false
        do {
            _ = try await harness.store.beginIndexing(mediumUUID: medium.uuid, token: UUID())
        } catch {
            threw = true
        }
        #expect(threw, "Vorbedingung: beginIndexing für gelöschtes Medium wirft")
        let hasToken = await harness.store.hasAnyActiveIndexingToken()
        let hasMediumToken = await harness.store.hasActiveIndexingToken(mediumUUID: medium.uuid)
        #expect(!hasToken, "Nr. 67: hasAnyActiveIndexingToken()==true nach geworfenem beginIndexing")
        #expect(!hasMediumToken, "Nr. 67: hasActiveIndexingToken(medium)==true nach geworfenem beginIndexing")
    }

    // MARK: Nr. 69 — Ordner-Verschiebung über fileID: Tiefe der Kinder bleibt alt

    @Test func nr69_folderMovedByFileIDShiftsDescendantDepths() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let store = harness.store
        let id = medium.uuid
        let a = ScannedEntry(name: "A", isFolder: true, fileID: "1")
        let b = ScannedEntry(name: "B", isFolder: true, fileID: "2")
        let m = ScannedEntry(name: "M", isFolder: true, fileID: "3")
        let x = ScannedEntry(name: "x", isFolder: true, fileID: "4")
        let y = ScannedEntry(name: "y.txt", isFolder: false, sizeBytes: 9, fileID: "5")
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [a], seenAt: Date())
        let aRow = try #require(try await child(store, id, nil, "A"))
        try await store.applyDirectory(mediumUUID: id, parentID: aRow.id, entries: [b], seenAt: Date())
        let bRow = try #require(try await child(store, id, aRow.id, "B"))
        try await store.applyDirectory(mediumUUID: id, parentID: bRow.id, entries: [m], seenAt: Date())
        let mRow = try #require(try await child(store, id, bRow.id, "M"))
        try await store.applyDirectory(mediumUUID: id, parentID: mRow.id, entries: [x], seenAt: Date())
        let xRow = try #require(try await child(store, id, mRow.id, "x"))
        try await store.applyDirectory(mediumUUID: id, parentID: xRow.id, entries: [y], seenAt: Date())
        let yRow = try #require(try await child(store, id, xRow.id, "y.txt"))
        #expect(xRow.depth == 4 && yRow.depth == 5, "Vorbedingung: x Tiefe 4, y Tiefe 5")

        // Offline: /A/B/M → /M. Abgleich liest Ebene für Ebene neu.
        try await store.applyDirectory(mediumUUID: id, parentID: nil, entries: [a, m], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: aRow.id, entries: [b], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: bRow.id, entries: [], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: mRow.id, entries: [x], seenAt: Date())
        try await store.applyDirectory(mediumUUID: id, parentID: xRow.id, entries: [y], seenAt: Date())

        let rows = try await rawRows(store)
        let mAfter = try #require(rows.first { $0.id == mRow.id })
        let xAfter = try #require(rows.first { $0.id == xRow.id })
        let yAfter = try #require(rows.first { $0.id == yRow.id })
        #expect(mAfter.parentID == nil && mAfter.depth == 1, "Vorbedingung: M liegt in der Wurzel, Tiefe 1 (ist \(mAfter.depth))")
        #expect(xAfter.depth == 2, "Nr. 69: x hat Tiefe \(xAfter.depth) statt 2")
        #expect(yAfter.depth == 3, "Nr. 69: y.txt hat Tiefe \(yAfter.depth) statt 3")
    }

    // MARK: Nr. 59 — pausierter Abgleich → .pending → Folgelauf liest Ebenen 1..n nicht

    @Test func nr59_pausedReconcileDoesNotSkipLayersOnNextRun() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("l1/l2/l3/f.txt")
        let first = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        #expect(first.status == .indexed)
        let indexed = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(indexed.indexStatus == .indexed && indexed.completedDepth >= 3)

        // Abgleich beim Anschließen, nach dem ersten gelesenen Ordner pausiert.
        access.clearListed()
        let paused = try await harness.run(access: access, maxDepth: nil, fromScratch: false, shouldHalt: {
            access.listed.isEmpty ? .none : .pause
        })
        let afterPause = try #require(try await harness.store.medium(uuid: harness.mediumID))

        // Änderung anderswo (auf Ebene 3), danach nächster Anschluss → Folgelauf.
        access.file("l1/l2/spaet.txt")
        access.clearListed()
        let next = try await harness.run(access: access, maxDepth: nil, fromScratch: false)
        let names = try await harness.names()
        #expect(names.contains("spaet.txt"),
                "Nr. 59: Folgelauf findet l1/l2/spaet.txt nicht. pausiert=\(paused.status) DB-Status nach Pause=\(afterPause.indexStatus) completedDepth=\(afterPause.completedDepth); Folgelauf status=\(next.status) gelesen=\(access.listed)")
    }

    // MARK: Nr. 70 — Live-Rename-Paar Löschen+Anlegen einer anderen Datei → Favorit wandert

    @Test func nr70_deleteAndCreateOtherFileDoesNotMoveFavorite() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-nr70-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "alt.jpg", isFolder: false, sizeBytes: 10, fileID: "900000001")],
            seenAt: Date()
        )
        let old = try #require(try await child(harness.store, medium.uuid, nil, "alt.jpg"))
        try await harness.store.setFavorite(itemID: old.id, true)

        // alt.jpg gelöscht, fremde Datei neu.jpg angelegt (eigene Inode).
        let neuURL = mount.appendingPathComponent("neu.jpg")
        try Data(repeating: 1, count: 20).write(to: neuURL)
        var st = stat()
        #expect(stat(neuURL.path, &st) == 0)
        let neuInode = String(st.st_ino)
        let altPath = mount.appendingPathComponent("alt.jpg").path
        let pairs = LiveRenamePairs.pair(
            events: [
                ItemPathEvent(path: altPath, itemCreated: false, itemRemoved: true, itemRenamed: false),
                ItemPathEvent(path: neuURL.path, itemCreated: true, itemRemoved: false, itemRenamed: false),
            ],
            fileExists: { FileManager.default.fileExists(atPath: $0) }
        )
        for pair in pairs {
            _ = try await harness.store.applyLiveRename(
                mediumUUID: medium.uuid, mountPath: mount.path, fromPath: pair.fromPath, toPath: pair.toPath
            )
        }
        // Nachlesen des Ordners (wie der Watcher es danach tut).
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "neu.jpg", isFolder: false, sizeBytes: 20, fileID: neuInode)],
            seenAt: Date()
        )
        let neu = try #require(try await child(harness.store, medium.uuid, nil, "neu.jpg"))
        #expect(!neu.isFavorite && neu.id != old.id,
                "Nr. 70: neu.jpg (fremde Datei, inode \(neuInode)) erbt Zeile/Favorit von alt.jpg (pairs=\(pairs.count), gleiche id=\(neu.id == old.id), favorit=\(neu.isFavorite))")
    }

    // MARK: Nr. 66 — zurückgestellter Flush wird aus dem Quiet-Task nie neu eingeplant

    @Test func nr66_deferredFlushRunsAfterIndexingEnds() async throws {
        let rig = try await watchRig()
        let token = UUID()
        _ = try await rig.store.beginIndexing(mediumUUID: rig.medium.uuid, token: token)
        rig.access.listings["/Volumes/DISK/A"] = [
            ListedDirectoryEntry(name: "neu.txt", isDirectory: false, isPackage: false, isSymbolicLink: false, isHidden: false, fileSize: 1, modifiedAt: nil),
        ]
        var indexing = true
        rig.watcher.isIndexingActive = { _ in indexing }
        rig.watcher.quietInterval = .milliseconds(20)
        rig.watcher.start(mediumID: rig.medium.uuid, volume: rig.volume, source: rig.source)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/A/neu.txt", eventID: 5))
        try await Task.sleep(for: .milliseconds(120))
        #expect(rig.access.listCount.isEmpty, "Vorbedingung: während des Laufs wird nicht gelesen")
        // Lauf endet; kein neues Event.
        _ = try await rig.store.finishIndexing(mediumUUID: rig.medium.uuid, token: token, status: .indexed, firstIndexedAt: nil)
        indexing = false
        let flushed = await waitUntil(timeout: 2) { (rig.access.listCount["/Volumes/DISK/A"] ?? 0) > 0 }
        #expect(flushed, "Nr. 66: zurückgestellter Flush wird nach Laufende nie ausgeführt (listCount=\(rig.access.listCount))")
        await rig.watcher.stop(mediumID: rig.medium.uuid)
    }

    // MARK: Nr. 60 — requestedIndex bleibt nach Lauf gesetzt → „Ja“ nach „Nein“ startet keinen Lauf

    @Test func nr60_yesAfterNoStartsANewRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-nr60-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let access = MapAccess()
        let app = AppState()
        let service = IndexingService(store: store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        let watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator, service: service, watcher: watcher, appState: app,
            startWatching: { _, _ in }
        )
        let volume = VolumeInfo(
            mountPath: "/Volumes/NR60", name: "NR60", fsType: "msdos",
            volumeTotalBytes: 1_000, volumeFreeBytes: 400, diskSizeBytes: 1_024, volumeUUID: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_102_804),
            isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
            deviceProtocol: "USB", model: nil, isTimeMachineSnapshot: false
        )
        await coordinator.handle(.appeared(volume))
        let id = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(id, true, true)
        await coordinator.waitForChoice()
        let firstStarted = await waitUntil(timeout: 3) { (access.listCount["/Volumes/NR60"] ?? 0) > 0 }
        #expect(firstStarted, "Vorbedingung: erster Lauf startet")
        await service.waitUntilIdle(id)
        let doneFirst = await waitUntil(timeout: 3) {
            (try? await store.medium(uuid: id))?.indexStatus == .indexed && !service.isRunActive(id)
        }
        #expect(doneFirst, "Vorbedingung: erster Lauf endet als .indexed")
        let listsAfterFirst = access.listCount["/Volumes/NR60"] ?? 0

        // Einstellungen: „Nein“, dann „Ja“.
        app.onMediumDecisionChanged?(id, .dontIndex, false)
        try await Task.sleep(for: .milliseconds(150))
        app.onMediumDecisionChanged?(id, .index, true)
        let rerun = await waitUntil(timeout: 3) { (access.listCount["/Volumes/NR60"] ?? 0) > listsAfterFirst }
        #expect(rerun, "Nr. 60: „Ja“ nach „Nein“ startet keinen Lauf (Wurzel-Listings vorher=\(listsAfterFirst), nachher=\(access.listCount["/Volumes/NR60"] ?? 0), connected=\(String(describing: app.medium(with: id)?.connectionStatus)), decision=\(String(describing: app.medium(with: id)?.decision)))")
        await service.waitUntilIdle(id)
    }

    // MARK: Nr. 99 — commitPendingMetaIfNeeded: Reentrancy über await

    @Test func nr99_concurrentDirectoryBatchesKeepCountsExact() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let store = harness.store
        let id = medium.uuid
        let folders = try await harness.addRoot(
            medium: medium,
            entries: (0..<40).map { ScannedEntry(name: "d\($0)", isFolder: true) }
        )
        try await withThrowingTaskGroup(of: Void.self) { group in
            for folder in folders {
                let parent = folder.id
                group.addTask {
                    try await store.applyDirectories(
                        mediumUUID: id,
                        batches: [(parentID: parent, path: nil, depth: nil,
                                   entries: (0..<5).map { ScannedEntry(name: "f\($0).txt", isFolder: false, sizeBytes: 1) },
                                   finalize: true)],
                        seenAt: Date()
                    )
                }
            }
            try await group.waitForAll()
        }
        let stored = try #require(try await store.medium(uuid: id))
        let truth = try await store.counts(mediumUUID: id)
        #expect(stored.fileCount == truth.files && stored.folderCount == truth.folders,
                "Nr. 99: Zähler weichen ab: gespeichert files=\(stored.fileCount) folders=\(stored.folderCount), echt files=\(truth.files) folders=\(truth.folders)")
    }
}

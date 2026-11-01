//
//  YesAfterNoIndexingTests.swift
//  DiskArchiveTests
//
//  bug.0.4.027 — Repro Nr. 60 aus audit-repro.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct YesAfterNoIndexingTests {
    @Test func nr60_yesAfterNoStartsANewRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-nr60-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let access = MapAccess()
        access.listings["/Volumes/NR60"] = [
            ListedDirectoryEntry(
                name: "root.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        let app = AppState()
        app.attach(store: store)
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
        let firstStarted = await waitUntil(timeout: 3) { access.listCount(for: "/Volumes/NR60") > 0 }
        #expect(firstStarted)
        await service.waitUntilIdle(id)
        let doneFirst = await waitUntil(timeout: 3) {
            (try? await store.medium(uuid: id))?.indexStatus == .indexed && !service.isRunActive(id)
        }
        #expect(doneFirst)
        let listsAfterFirst = access.listCount(for: "/Volumes/NR60")

        app.onMediumDecisionChanged?(id, .dontIndex, false)
        try await Task.sleep(for: .milliseconds(150))
        app.onMediumDecisionChanged?(id, .index, true)
        let rerun = await waitUntil(timeout: 3) { access.listCount(for: "/Volumes/NR60") > listsAfterFirst }
        #expect(rerun)
        await service.waitUntilIdle(id)
    }

    /// Nacharbeit 3: Lauf aktiv → zweimal „Ja“ über den normalen Weg (Dialog, Entscheidungsänderung)
    /// → nach dem Lauf genau ein Lauf insgesamt, auch kein nachgeholter über `rerunAfterFinish`.
    @Test func doubleIndexRequestDuringRunKeepsOneRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-double-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        let inner = MemoryVolume(mountPath: "/Volumes/DBL")
        inner.file("a/x.txt")
        inner.file("b/y.txt")
        let access = RunGateAccess([inner]) { $0 == "/Volumes/DBL/a" }
        let app = AppState()
        app.attach(store: store)
        let rig = WiredRig(store: store, access: access, app: app)
        await rig.coordinator.handle(.appeared(testVolume(path: "/Volumes/DBL", name: "DBL")))
        let id = try #require(app.newMediumDialogMediumID)
        app.onNewMediumChoice?(id, true, true)
        await rig.coordinator.waitForChoice()
        let held = await waitUntil { await access.heldCount() >= 1 }
        try #require(held)
        #expect(rig.starts(id) == [false])

        app.onNewMediumChoice?(id, true, true)
        await rig.coordinator.waitForChoice()
        app.onMediumDecisionChanged?(id, .index, true)
        try await Task.sleep(for: .milliseconds(200))
        #expect(rig.starts(id) == [false])

        await access.open()
        await rig.service.waitUntilIdle(id)
        try await Task.sleep(for: .milliseconds(500))
        await rig.service.waitUntilIdle(id)
        #expect(rig.starts(id) == [false])
        try await Task.sleep(for: .milliseconds(300))
        #expect(rig.starts(id) == [false])
        #expect(!rig.service.isRunActive(id))
    }
}

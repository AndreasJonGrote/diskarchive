//
//  ScopeChangeAcceptanceTests.swift
//  DiskArchiveTests
//
//  bug.0.4.030 — Nacharbeit 2 Akzeptanztests.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct ScopeChangeAcceptanceTests {
    @Test func excludeTmpHidesAfterRuleReconcile() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "SCOPE", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "drop.tmp", isFolder: false, sizeBytes: 1),
            ],
            seenAt: Date()
        )
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: harness.store)
        await app.loadStoredMedia()
        app.appSettings.excludedPatterns = ["*.tmp"]
        await app.waitForRuleReconcileIdle()
        let visible = try await harness.store.children(
            mediumUUID: medium.uuid,
            parentID: nil,
            scope: IndexScope.from(app.appSettings)
        )
        #expect(!visible.contains { $0.name == "drop.tmp" })
        let counts = try await harness.store.counts(mediumUUID: medium.uuid, scope: IndexScope.from(app.appSettings))
        #expect(counts.files == 1)
    }

    @Test func excludeNodeModulesClearsSearchAndFileCount() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "NM", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "node_modules", isFolder: true)],
            seenAt: Date()
        )
        let nmID = try #require(try await harness.store.folderID(mediumUUID: medium.uuid, path: ["node_modules"]))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nmID,
            entries: [
                ScannedEntry(name: "a.js", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "b.js", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "c.js", isFolder: false, sizeBytes: 1),
            ],
            seenAt: Date()
        )
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 2)
        let app = AppState(store: harness.store)
        await app.loadStoredMedia()
        app.appSettings.excludedPatterns = ["node_modules"]
        await app.waitForRuleReconcileIdle()
        await app.pruneNow()
        let hits = try await harness.store.search(query: "a.js", filters: SearchFilters(), scope: IndexScope.from(app.appSettings))
        #expect(hits.isEmpty)
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        let visibleFiles = try await harness.store.counts(mediumUUID: medium.uuid, scope: IndexScope.from(app.appSettings))
        #expect(visibleFiles.files == stored.fileCount)
    }

    /// Nacharbeit 3: Tiefe 2 → 5 bei fertigem, angeschlossenem Medium → genau ein Abgleich (`fromScratch: false`).
    @Test func deeperScanDepthStartsExactlyOneReconcile() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a/b/c/deep.txt")
        let volume = testVolume(path: "/Volumes/T", name: "TEST")
        let first = try await harness.run(access: inner, maxDepth: 2, fromScratch: true, volume: volume)
        #expect(first.status == .indexed)
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)

        let app = AppState(store: harness.store)
        app.appSettings.scanDepth = 2
        await app.waitForRuleReconcileIdle()
        let rig = WiredRig(store: harness.store, access: inner, app: app)
        await rig.coordinator.handle(.appeared(volume))
        // Anschließen eines fertigen Mediums startet selbst einen Abgleich; der zählt als Ausgangslage.
        let connected = await waitUntil { rig.starts(id) == [false] && !rig.service.isRunActive(id) }
        #expect(connected)
        #expect(try await harness.item(named: "deep.txt") == nil)

        app.appSettings.scanDepth = 5
        let started = await waitUntil { rig.starts(id).count == 2 }
        #expect(started)
        await rig.service.waitUntilIdle(id)
        try await Task.sleep(for: .milliseconds(300))
        #expect(rig.starts(id) == [false, false])
        #expect(try await harness.item(named: "deep.txt") != nil)
        let stored = try #require(try await harness.store.medium(uuid: id))
        #expect(stored.indexStatus == .indexed)
    }

    /// Nacharbeit 3: Ausschluss hinzu bei laufendem Lauf → Lauf abgebrochen, als Abgleich neu gestartet;
    /// ein anderes fertiges Medium startet keinen Lauf.
    @Test func excludeDuringRunRestartsOnlyThatRunAsReconcile() async throws {
        let harness = try await ScanHarness.make()
        let runningID = harness.mediumID
        let innerA = MemoryVolume(mountPath: "/Volumes/A")
        innerA.file("x/a.txt")
        let innerB = MemoryVolume(mountPath: "/Volumes/B")
        innerB.file("y/b.txt")
        let other = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "OTHER", type: .usb, decision: .index)
        try await harness.store.upsertMedium(other)
        let volumeB = testVolume(path: "/Volumes/B", name: "OTHER")
        let otherRun = try await ScanHarness(store: harness.store, mediumID: other.uuid)
            .run(access: innerB, maxDepth: nil, fromScratch: true, volume: volumeB)
        #expect(otherRun.status == .indexed)
        let volumeA = testVolume(path: "/Volumes/A", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: runningID, volumeA.identity)
        try await harness.store.recordIdentity(mediumUUID: other.uuid, volumeB.identity)

        let access = RunGateAccess([innerA, innerB]) { $0 == "/Volumes/A/x" }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)
        await rig.coordinator.handle(.appeared(volumeB))
        let otherSettled = await waitUntil { rig.starts(other.uuid) == [false] && !rig.service.isRunActive(other.uuid) }
        #expect(otherSettled)

        await rig.coordinator.handle(.appeared(volumeA))
        let held = await waitUntil { await access.heldCount() >= 1 }
        try #require(held)
        #expect(rig.starts(runningID) == [false])
        #expect(app.medium(with: runningID)?.indexStatus == .indexing)

        app.appSettings.excludedPatterns.append("*.tmp")
        // Der Neustart erreicht das Tor, solange es zu ist: der erste Lauf wurde also abgebrochen, nicht nachgeholt.
        let restarted = await waitUntil { await access.heldCount() >= 2 }
        #expect(restarted)
        #expect(rig.starts(runningID) == [false, false])

        await access.open()
        await rig.service.waitUntilIdle(runningID)
        await app.waitForRuleReconcileIdle()
        try await Task.sleep(for: .milliseconds(300))
        #expect(rig.starts(runningID) == [false, false])
        #expect(rig.starts(other.uuid) == [false])
        let stored = try #require(try await harness.store.medium(uuid: runningID))
        #expect(stored.indexStatus == .indexed)
    }

    /// Nacharbeit 3: Lauf nach Ebene 1 angehalten, `*.tmp` ausschließen, freigeben → keine `.tmp`-Zeile,
    /// `fileCount` = `COUNT(status = 0)`.
    @Test func excludeTmpDuringRunLeavesNoTmpRow() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("keep.txt")
        inner.file("drop.tmp")
        inner.file("sub/inner.txt")
        inner.file("sub/late.tmp")
        inner.file("sub/deeper/last.txt")
        let volume = testVolume(path: "/Volumes/T", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)

        let access = RunGateAccess([inner]) { $0 == "/Volumes/T/sub/deeper" }
        let app = AppState(store: harness.store)
        // `*.tmp` ist ein Standard-Artefakt; ohne diesen Schalter würde die Datei nie geschrieben.
        app.appSettings.artifactsIgnored = false
        await app.waitForRuleReconcileIdle()
        let rig = WiredRig(store: harness.store, access: access, app: app)
        await rig.coordinator.handle(.appeared(volume))
        let held = await waitUntil { await access.heldCount() >= 1 }
        try #require(held)
        let levelOneWritten = await waitUntil { (try? await harness.item(named: "drop.tmp")) != nil }
        #expect(levelOneWritten)

        app.appSettings.excludedPatterns.append("*.tmp")
        let restarted = await waitUntil { await access.heldCount() >= 2 }
        #expect(restarted)
        await access.open()
        let done = await waitUntil { rig.starts(id).count == 2 && !rig.service.isRunActive(id) }
        #expect(done)
        await app.waitForRuleReconcileIdle()

        let scope = IndexScope.from(app.appSettings)
        var visible: [String] = []
        func walk(_ parent: Int64?) async throws {
            let rows = try await harness.store.children(mediumUUID: id, parentID: parent, scope: scope)
            visible.append(contentsOf: rows.map(\.name))
            for row in rows where row.isFolder { try await walk(row.id) }
        }
        try await walk(nil)
        #expect(!visible.contains { $0.hasSuffix(".tmp") })
        #expect(visible.contains("inner.txt"))
        #expect(visible.contains("last.txt"))
        let raw = try await harness.store.counts(mediumUUID: id)
        #expect(raw.files == 3)
        let stored = try #require(try await harness.store.medium(uuid: id))
        #expect(stored.fileCount == raw.files)
        #expect(stored.indexStatus == .indexed)
    }
}

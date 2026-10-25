//
//  UnreadableFoldersErrorTests.swift
//  diskindexTests
//
//  bug.0.4.199 — Ein Lauf bis zum Ende mit nicht lesbaren Ordnern endet als „Fehler“ (Grund `.unreadableFolders`);
//  der nächste Lauf ohne Lücke gilt wieder als indiziert und zieht die Mitteilung zurück. Details-Modal: Zeile
//  „Indiziert“ mit dem Fortschritt. Nur Testordner im Speicher (`MemoryVolume`), nie echte Medien.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct UnreadableFoldersErrorTests {
    private static var fastRetries: IndexingRunLimits {
        var limits = IndexingRunLimits.standard
        limits.readRetryDelays = [.milliseconds(1)]
        return limits
    }

    /// Test 1: Lücke am Laufende → `.error` mit Grund, Merker gesetzt, Fortschritt unter 100 %, Chip „Fehler“.
    @Test func runWithAnUnreadableFolderEndsAsError() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("bad/keep.txt")
        access.file("ok/a.txt")
        access.markUnreadable("bad")
        let outcome = try await harness.run(access: access, maxDepth: nil, limits: Self.fastRetries)
        #expect(outcome.status == .error)
        #expect(outcome.failureReason == .unreadableFolders)
        #expect(outcome.ranToEnd, "Lauf mit Lücke lief bis zum Ende")
        #expect(try await harness.store.indexHasGaps(mediumUUID: harness.mediumID))
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(stored.indexStatus == .error)
        let medium = stored.asMedium(connection: .connected)
        #expect(medium.indexProgressPercent < 100)
        #expect(MediumChip.presentation(medium).text == LayoutCopy.chipError)
        #expect(MediumChip.presentation(medium).error)
    }

    /// Test 2: Der Ordner wird lesbar, „Erneut versuchen“ → `.indexed`, 100 %, Merker gelöscht, Mitteilung zurückgezogen
    /// (ohne Aushängen dazwischen: das zieht seit bug.0.4.200 e selbst zurück und verdeckte sonst den Rückzug des Laufs).
    @Test func readableAgainOnRetryEndsTheErrorAndWithdrawsTheNotice() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/LUECKE", name: "LUECKE")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let access = MemoryVolume(mountPath: volume.mountPath)
        access.file("bad/keep.txt")
        access.file("ok/a.txt")
        access.markUnreadable("bad")
        let app = AppState(store: harness.store, defaults: TestDefaults.make())
        var withdrawn: [UUID] = []
        app.withdrawIndexingFailureNotice = { withdrawn.append($0) }
        let rig = WiredRig(store: harness.store, access: access, app: app)
        rig.service.runLimitsForTesting = Self.fastRetries
        defer { rig.coordinator.stop() }
        let id = harness.mediumID

        await rig.coordinator.handle(.appeared(volume))
        let failed = await waitUntil { app.medium(with: id)?.indexStatus == .error }
        try #require(failed, "Lauf mit Lücke endet nicht als Fehler: \(String(describing: app.medium(with: id)?.indexStatus))")
        #expect(app.indexingFailure?.reason == .unreadableFolders, "Hinweis: \(String(describing: app.indexingFailure))")
        #expect(withdrawn.isEmpty)
        await rig.service.waitUntilIdle(id)
        // Aktivieren der App (Neuprüfung verweigerter Zugriffe) liest die Lücke nicht neu: der gespeicherte Status bleibt
        // `.error` (ein Neulauf setzte ihn innerhalb dieses `await` auf `.pending`, bevor er den Lauf anfordert).
        await rig.coordinator.applicationDidBecomeActive()
        #expect(try await harness.store.medium(uuid: id)?.indexStatus == .error, "Aktivieren liest die Lücke neu")
        #expect(app.medium(with: id)?.indexStatus == .error)

        access.markReadable("bad")
        app.indexingFailure = nil
        app.onReindexMedium?(id)
        let indexed = await waitUntil { app.medium(with: id)?.indexStatus == .indexed }
        #expect(indexed, "Nach lesbarem Ordner nicht indiziert: \(String(describing: app.medium(with: id)?.indexStatus))")
        #expect(app.medium(with: id)?.indexProgressPercent == 100)
        #expect(try await harness.store.indexHasGaps(mediumUUID: id) == false, "Merker nach geschlossener Lücke nicht gelöscht")
        #expect(try await harness.store.medium(uuid: id)?.indexStatus == .indexed)
        #expect(withdrawn == [id], "Zurückgezogen: \(withdrawn)")
        #expect(app.indexingFailure == nil, "Hinweis blieb nach erfolgreichem Lauf")
    }

    /// Test 2b: Der Ordner wird lesbar, nächstes Anschließen liest die Lücke nach → `.indexed`, Merker gelöscht.
    @Test func readableAgainOnReconnectEndsTheError() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/LUECKE2", name: "LUECKE2")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let access = MemoryVolume(mountPath: volume.mountPath)
        access.file("bad/keep.txt")
        access.file("ok/a.txt")
        access.markUnreadable("bad")
        let app = AppState(store: harness.store, defaults: TestDefaults.make())
        app.withdrawIndexingFailureNotice = { _ in }
        let rig = WiredRig(store: harness.store, access: access, app: app)
        rig.service.runLimitsForTesting = Self.fastRetries
        defer { rig.coordinator.stop() }
        let id = harness.mediumID
        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { app.medium(with: id)?.indexStatus == .error }, "Lauf mit Lücke endet nicht als Fehler")
        await rig.service.waitUntilIdle(id)
        access.markReadable("bad")
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .offline }, "Aushängen nicht verarbeitet")
        await rig.coordinator.handle(.appeared(volume))
        let indexed = await waitUntil { app.medium(with: id)?.indexStatus == .indexed }
        #expect(indexed, "Nach lesbarem Ordner nicht indiziert: \(String(describing: app.medium(with: id)?.indexStatus))")
        #expect(try await harness.store.indexHasGaps(mediumUUID: id) == false, "Merker nach geschlossener Lücke nicht gelöscht")
        #expect(try await harness.store.medium(uuid: id)?.indexStatus == .indexed)
    }

    /// Test 3: Nur ein immer ausgeschlossener Systemordner ist unlesbar → `.indexed`, kein Fehler.
    @Test func unreadableSystemFolderNeverCausesAGap() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("ok/a.txt")
        for name in [".Trashes", ".Spotlight-V100", ".fseventsd"] {
            access.file("\(name)/x")
            access.markUnreadable(name)
        }
        // Versteckte Dateien mitlesen: nur die Liste der immer ausgeschlossenen Ordner darf sie fernhalten.
        let outcome = try await harness.run(access: access, maxDepth: nil, ignoreHidden: false, limits: Self.fastRetries)
        #expect(outcome.status == .indexed)
        #expect(outcome.failureReason == nil)
        #expect(outcome.readErrors == 0)
        #expect(try await harness.store.indexHasGaps(mediumUUID: harness.mediumID) == false)
    }

    /// Test 4: Grund-Text de/en wortgleich, Code der Mitteilung hin und zurück.
    @Test func reasonTextAndNotificationCode() {
        let reason = IndexFailureReason.unreadableFolders
        #expect(reason.notificationCode == "unreadableFolders")
        #expect(IndexFailureReason(notificationCode: reason.notificationCode) == reason)
        #expect(L10n.$languageOverride.withValue(.german) { reason.line }
            == "Einige Ordner auf diesem Medium konnten nicht gelesen werden.")
        #expect(L10n.$languageOverride.withValue(.english) { reason.line }
            == "Some folders on this medium couldn't be read.")
    }

    /// Test 5: Details-Modal, Zeile „Indiziert“: vollständig 100 %, mit Lücke 99 % (de und en).
    @Test func detailRowShowsTheIndexedPercent() {
        var complete = Self.medium(status: .indexed)
        complete.scanTotal = 100
        var gap = Self.medium(status: .error)
        gap.scanTotal = 100
        gap.fileCount = 99
        gap.folderCount = 0
        #expect(L10n.$languageOverride.withValue(.german) { LayoutCopy.detailIndexed } == "Indiziert")
        #expect(L10n.$languageOverride.withValue(.english) { LayoutCopy.detailIndexed } == "Indexed")
        #expect(L10n.$languageOverride.withValue(.german) { complete.indexedLabel } == "100 %")
        #expect(L10n.$languageOverride.withValue(.english) { complete.indexedLabel } == "100%")
        #expect(L10n.$languageOverride.withValue(.german) { gap.indexedLabel } == "99 %")
        #expect(L10n.$languageOverride.withValue(.english) { gap.indexedLabel } == "99%")
        var counting = Self.medium(status: .indexing)
        counting.indexRunPhase = .counting
        #expect(L10n.$languageOverride.withValue(.german) { counting.indexedLabel } == "0 %")
    }

    private static func medium(status: IndexStatus) -> Medium {
        Medium(
            id: UUID(),
            name: "LUECKE",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: status,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000_000_000,
            capacityUsedBytes: 0,
            fileCount: 100,
            folderCount: 0,
            lastSeenAt: nil,
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0
        )
    }
}

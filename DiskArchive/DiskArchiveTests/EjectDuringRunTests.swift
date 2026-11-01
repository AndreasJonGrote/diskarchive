//
//  EjectDuringRunTests.swift
//  DiskArchiveTests
//
//  bug.0.4.177: Das Medium wird mitten im Lauf ausgeworfen, der Einhängepunkt bleibt als leerer Ordner stehen. Ein
//  leer gelesener Ordner darf dann nicht den Index (samt Favoriten) löschen; der normale Weg (wirklich geleerter Ordner
//  auf dem eingehängten Medium) bleibt.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

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

    /// bug.0.4.187 (b): Bei ausgeschalteten Optionen „versteckte Dateien“ und „Artefakte ignorieren“ teilen sich Medien `.DS_Store`; das darf
    /// die Prüfung „alles Bisherige fehlt“ nicht aushebeln – ein fremdes Medium nur mit `.DS_Store` gemeinsam kommt nicht in den Index.
    @Test func foreignMediumSharingOnlyAdministrativeFilesIsNotTakenIntoTheIndex() async throws {
        let harness = try await ScanHarness.make()
        let volume = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = volume.file(".DS_Store", size: 3).file("A/a.txt", size: 10).file("B/b.txt", size: 20)
        let info = harness.volume(at: volume.mountPath)
        let first = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, ignoreHidden: false, artifactsIgnored: false, volume: info)
        try #require(first.status == .indexed, "Voraussetzung: erster Lauf vollständig")
        try #require(try await harness.names().contains(".DS_Store"), "Voraussetzung: .DS_Store im Index")
        let foreign = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = foreign.file(".DS_Store", size: 3).file("X/fremd.txt", size: 5)
        foreign.markForeign()
        let outcome = try await harness.run(access: foreign, maxDepth: nil, fromScratch: false, ignoreHidden: false, artifactsIgnored: false, volume: info)
        let names = try await harness.names()
        #expect(names.isSuperset(of: ["A", "B", "a.txt", "b.txt"]), "Einträge entfernt: \(names)")
        #expect(names.isDisjoint(with: ["X", "fremd.txt"]), "Inhalt des fremden Mediums im Index: \(names)")
        #expect(!outcome.ranToEnd)
    }

    /// bug.0.4.189: Wie 187 (b), aber mit den übrigen Verwaltungsnamen (auch kleingeschrieben, wie in `ArtifactRules`).
    private func foreignMediumShares(_ shared: String, otherName: String) async throws {
        let harness = try await ScanHarness.make()
        let volume = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = volume.file(shared, size: 3).file("A/a.txt", size: 10).file("B/b.txt", size: 20)
        let info = harness.volume(at: volume.mountPath)
        let first = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, ignoreHidden: false, artifactsIgnored: false, volume: info)
        try #require(first.status == .indexed, "Voraussetzung: erster Lauf vollständig")
        try #require(try await harness.names().contains(shared), "Voraussetzung: \(shared) im Index")
        let foreign = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = foreign.file(otherName, size: 3).file("X/fremd.txt", size: 5)
        foreign.markForeign()
        let outcome = try await harness.run(access: foreign, maxDepth: nil, fromScratch: false, ignoreHidden: false, artifactsIgnored: false, volume: info)
        let names = try await harness.names()
        #expect(names.isSuperset(of: ["A", "B", "a.txt", "b.txt"]), "Einträge entfernt: \(names)")
        #expect(names.isDisjoint(with: ["X", "fremd.txt"]), "Inhalt des fremden Mediums im Index: \(names)")
        #expect(!outcome.ranToEnd)
    }

    @Test func foreignMediumSharingOnlyTheRecycleBinIsNotTakenIntoTheIndex() async throws {
        try await foreignMediumShares("$RECYCLE.BIN", otherName: "$RECYCLE.BIN")
    }

    @Test func foreignMediumSharingOnlyALowercasedAdministrativeNameIsNotTakenIntoTheIndex() async throws {
        try await foreignMediumShares(".ds_store", otherName: ".ds_store")
    }

    @Test func foreignMediumSharingOnlyOtherAdministrativeNamesIsNotTakenIntoTheIndex() async throws {
        for name in ["Thumbs.db", "desktop.ini", ".Trash", ".Trash-501", ".VolumeIcon.icns", ".apdisk", ".metadata_never_index", ".localized", ".hidden", ".AppleDouble", ".com.apple.timemachine.donotpresent"] {
            try await foreignMediumShares(name, otherName: name)
        }
    }

    /// bug.0.4.194 (c): auch `Icon\r` (Ordnersymbol) und `.git` (aus den versteckten Artefakten) zählen nicht.
    @Test func foreignMediumSharingOnlyTheFolderIconOrGitIsNotTakenIntoTheIndex() async throws {
        for name in ["Icon\r", ".git"] {
            try await foreignMediumShares(name, otherName: name)
        }
    }

    /// Gegenprobe: eigenes eingehängtes Medium (mit einem Verwaltungsnamen in der Wurzel) → eine Änderung unter den echten Ordnern wird geschrieben.
    @Test func ownMediumWithARealSharedFolderIsUpdated() async throws {
        let harness = try await ScanHarness.make()
        let volume = MemoryVolume(mountPath: "/Volumes/EJECT")
        _ = volume.file("$RECYCLE.BIN", size: 3).file("A/a.txt", size: 10).file("B/b.txt", size: 20)
        let info = harness.volume(at: volume.mountPath)
        let first = try await harness.run(access: volume, maxDepth: nil, fromScratch: true, ignoreHidden: false, artifactsIgnored: false, volume: info)
        try #require(first.status == .indexed)
        _ = volume.file("A/neu.txt", size: 4)
        let second = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, ignoreHidden: false, artifactsIgnored: false, volume: info)
        #expect(second.ranToEnd)
        #expect(try await harness.names().contains("neu.txt"))
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

// MARK: - bug.0.4.182: Prüfung vor dem Abschluss

extension EjectDuringRunTests {
    /// Läuft vollständig, wenn `c.txt` entfernt ist; die Prüfung vor dem Abschluss ist die einzige Prüfung des Laufs.
    private func runWithRemovedFile(
        answers: [Bool], shouldHalt: @escaping @Sendable () async -> ScanHalt = { .none }
    ) async throws -> (outcome: IndexRunOutcome, harness: ScanHarness, volume: MemoryVolume) {
        let (harness, volume, info) = try await indexed()
        volume.remove("C/c.txt")
        volume.scriptMountChecks(answers)
        volume.resetMountChecks()
        var limits = IndexingRunLimits.standard
        limits.unmountGrace = .milliseconds(100)
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info, limits: limits, shouldHalt: shouldHalt)
        return (outcome, harness, volume)
    }

    private func rowsNamed(_ harness: ScanHarness, _ name: String) async throws -> Int {
        try await harness.store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items WHERE name = ?", arguments: [name]) ?? 0
        }
    }

    /// Erst negativ, dann positiv → die Wiederholung bestätigt das Medium, der Lauf ist vollständig.
    @Test func gateCheckIsRepeatedOnceBeforeItCountsAsUnmounted() async throws {
        let (outcome, harness, volume) = try await runWithRemovedFile(answers: [false, true])
        #expect(volume.mountChecks == 2, "Wiederholung fehlt: \(volume.mountChecks)")
        #expect(outcome.ranToEnd || outcome.status == .indexed)
        #expect(outcome.failureReason == nil)
        #expect(try await rowsNamed(harness, "c.txt") == 0, "entfernte Datei blieb")
    }

    /// Zweimal negativ ohne Aushängen → Fehler mit eigenem Grund, nichts gelöscht.
    @Test func unconfirmedMediumEndsAsErrorWithItsOwnReason() async throws {
        let (outcome, harness, _) = try await runWithRemovedFile(answers: [false, false])
        #expect(outcome.status == .error)
        #expect(outcome.failureReason == .unconfirmed)
        #expect(!outcome.ranToEnd)
        #expect(try await rowsNamed(harness, "c.txt") == 1, "Zeile von c.txt gelöscht, obwohl das Medium nicht bestätigt war")
    }

    /// Aushängen-Ereignis (Halt) → stiller Abbruch wie bisher: kein Fehlergrund.
    @Test func unmountEventKeepsTheQuietCancel() async throws {
        let (harness, volume, info) = try await indexed()
        volume.remove("C/c.txt")
        volume.scriptMountChecks([false, false])
        volume.resetMountChecks()
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info, shouldHalt: {
            // Positives Signal: die Prüfung vor dem Abschluss lief; erst dann meldet sich das Aushängen.
            volume.mountChecks >= 2 ? .cancel : .none
        })
        #expect(outcome.failureReason == nil)
        #expect(outcome.status != .error)
        #expect(!outcome.ranToEnd)
        #expect(try await rowsNamed(harness, "c.txt") == 1)
    }

    /// Das Aushängen-Ereignis kommt erst kurz nach der Prüfung (echtes Auswerfen) → noch innerhalb der Karenz: stiller
    /// Abbruch, kein Fehlergrund.
    @Test func unmountEventArrivingWithinTheGraceKeepsTheQuietCancel() async throws {
        let (harness, volume, info) = try await indexed()
        volume.remove("C/c.txt")
        volume.scriptMountChecks([false, false])
        volume.resetMountChecks()
        let polls = PollCounter()
        var limits = IndexingRunLimits.standard
        limits.unmountGrace = .seconds(5)
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info, limits: limits, shouldHalt: {
            // Positives Signal: die Prüfung lief; das Ereignis kommt erst bei der zweiten Nachfrage danach.
            guard volume.mountChecks >= 2 else { return .none }
            return polls.next() >= 2 ? .cancel : .none
        })
        #expect(outcome.failureReason == nil, "Fehlergrund trotz Aushängen innerhalb der Karenz")
        #expect(outcome.status != .error)
        #expect(!outcome.ranToEnd)
        #expect(try await rowsNamed(harness, "c.txt") == 1)
    }
}

private final class PollCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int { lock.withLock { count += 1; return count } }
}

// MARK: - bug.0.4.185: Kleinkram aus Prüfung 19

extension EjectDuringRunTests {
    /// (a) Hängt die Prüfung des Indexers über ihre Zeitgrenze hinaus, zählt sie wie im Store-Pfad als hängender
    /// Zugriff des Mediums; eine neue Prüfung startet dann nicht, kehrt der Zugriff zurück, ist der Zähler null.
    @Test func hangingMountCheckOfTheIndexerCountsAsHangingAccess() async throws {
        let (harness, volume, info) = try await indexed()
        volume.remove("C/c.txt")
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        volume.hangMountChecks(until: gate)
        volume.scriptMountChecks([false])
        volume.resetMountChecks()
        var limits = IndexingRunLimits.standard
        limits.unmountGrace = .milliseconds(100)
        let outcome = try await harness.run(access: volume, maxDepth: nil, fromScratch: false, volume: info, limits: limits)
        #expect(outcome.failureReason == .unconfirmed)
        #expect(volume.mountChecks == 1, "zweite Prüfung gestartet, obwohl die erste hängt: \(volume.mountChecks)")
        #expect(await harness.store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 1, "hängende Prüfung nicht gezählt")
        gate.signal()
        #expect(await waitUntil { await harness.store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 0 },
                "Rückkehr der Prüfung nicht gemeldet")
    }

    /// (b) Ein widerrufenes Token, dessen Beginn erst nach dem Vergessen des Mediums kommt, startet nicht.
    @Test func revokedTokenBeginningAfterForgettingDoesNotStart() async throws {
        let harness = try await ScanHarness.make()
        let store = harness.store
        let token = UUID()
        _ = try await store.finishIndexing(mediumUUID: harness.mediumID, token: token, status: .pending, firstIndexedAt: nil)
        try await store.forgetMedium(uuid: harness.mediumID)
        let began = try await store.beginIndexing(mediumUUID: harness.mediumID, token: token)
        #expect(!began, "Beginn auf dem vergessenen Medium")
        let status = try await store.medium(uuid: harness.mediumID)?.indexStatus
        #expect(status != .indexing, "vergessenes Medium steht auf „indiziert gerade“")
    }

    /// (d) Die Rückkehr eines Zugriffs aus der Zeit vor dem Vergessen zieht keinen Zähler eines späteren Zugriffs ab.
    @Test func lateReturnOfAnOldAccessDoesNotReleaseALaterOne() async throws {
        let harness = try await ScanHarness.make()
        let store = harness.store
        let stored = try #require(try await store.medium(uuid: harness.mediumID))
        let (oldVolume, newVolume) = (MemoryVolume(mountPath: "/Volumes/A"), MemoryVolume(mountPath: "/Volumes/A"))
        let (oldGate, newGate) = (DispatchSemaphore(value: 0), DispatchSemaphore(value: 0))
        defer { oldGate.signal(); newGate.signal() }
        oldVolume.hangMountChecks(until: oldGate)
        newVolume.hangMountChecks(until: newGate)
        _ = await store.confirmMounted(stored, mountPath: "/Volumes/A", access: oldVolume)
        try #require(await store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 1, "Voraussetzung: erster Zugriff hängt")
        try await store.forgetMedium(uuid: harness.mediumID)
        _ = await store.confirmMounted(stored, mountPath: "/Volumes/A", access: newVolume)
        try #require(await store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 1, "Voraussetzung: zweiter Zugriff hängt")
        oldGate.signal()
        // Positives Signal: der alte Zugriff ist zurückgekehrt; sein Zähler gehört nicht mehr zum Medium.
        try #require(await waitUntil { oldVolume.mountCheckReturns == 1 })
        let released = await waitUntil(timeout: 0.3) { await store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 0 }
        #expect(!released, "Rückkehr des alten Zugriffs gab den späteren frei")
        newGate.signal()
        #expect(await waitUntil { await store.hangingPartialReadsForTesting(mediumUUID: harness.mediumID) == 0 })
    }
}

extension FatReconnectIndexerTests {
    /// bug.0.4.177 (c): Während der Teil-Prüfsummen-Lesung wird das Medium ausgeworfen, der Einhängeordner bleibt leer
    /// stehen → die fehlende Datei heißt nichts; Favorit bleibt (unlesbar statt fehlt).
    @Test func ejectDuringThePartialReadWithAnEmptyMountFolderKeepsTheFavorite() async throws {
        let harness = try await ScanHarness.make(fsType: "exfat")
        let store = harness.store
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-eject-read-\(UUID().uuidString)", isDirectory: true)
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

// MARK: - bug.0.4.187 (a): Hinweis „nicht bestätigt“ bei später Aushängen-Meldung zurücknehmen

@Suite(.serialized) @MainActor
struct UnconfirmedNoticeWithdrawalTests {
    /// Kette: Medium erscheint, der Hinweis „nicht bestätigt“ steht → das Aushängen-Ereignis desselben Mediums nimmt ihn
    /// zurück. Ein Hinweis eines anderen Mediums bleibt; bug.0.4.200 (e): ein Hinweis mit anderem Grund geht auch (Hinweis
    /// nur für angeschlossene Medien).
    @Test func lateUnmountEventWithdrawsOnlyTheNoticeOfThatMedium() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/SPAET", name: "SPAET")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: MemoryVolume(mountPath: volume.mountPath), app: app)
        defer { rig.coordinator.stop() }
        let id = harness.mediumID
        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht verbunden")

        // bug.0.4.200 (e): anderer Grund geht ebenfalls.
        app.indexingFailure = IndexingFailureNotice(id: id, name: "SPAET", reason: .unknown)
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .offline }, "Aushängen nicht verarbeitet")
        #expect(app.indexingFailure == nil, "Hinweis mit anderem Grund blieb nach dem Aushängen")

        // Hinweis eines anderen Mediums bleibt.
        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht erneut verbunden")
        let other = UUID()
        app.indexingFailure = IndexingFailureNotice(id: other, name: "ANDERES", reason: .unconfirmed)
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .offline }, "Aushängen nicht verarbeitet")
        #expect(app.indexingFailure?.id == other, "Hinweis eines anderen Mediums zurückgenommen")

        // Der Hinweis dieses Mediums geht.
        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht erneut verbunden")
        app.indexingFailure = IndexingFailureNotice(id: id, name: "SPAET", reason: .unconfirmed)
        await rig.coordinator.handle(.disappeared(path: volume.mountPath))
        let withdrawn = await waitUntil { app.indexingFailure == nil }
        #expect(withdrawn, "Hinweis „nicht bestätigt“ blieb nach dem Aushängen: \(String(describing: app.indexingFailure))")
    }

    /// bug.0.4.190: Mit dem Hinweis geht auch die schon zugestellte Systemmitteilung dieses Mediums (Klick darauf zeigte sonst
    /// den falschen Hinweis wieder). Mitteilungen anderer Medien oder bei anderem Grund bleiben.
    @Test func lateUnmountEventWithdrawsTheDeliveredNoticeOfThatMediumOnly() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/SPAET2", name: "SPAET2")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: MemoryVolume(mountPath: volume.mountPath), app: app)
        defer { rig.coordinator.stop() }
        let id = harness.mediumID
        var withdrawn: [String] = []
        let hooks = NoticeTestHooks(post: { _, _ in }, withdraw: { withdrawn.append($0) })
        try await SystemNotice.$testHooks.withValue(hooks) {
            // Anderer Grund: nichts zurückgezogen.
            await rig.coordinator.handle(.appeared(volume))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht verbunden")
            app.indexingFailure = IndexingFailureNotice(id: id, name: "SPAET2", reason: .unknown)
            await rig.coordinator.handle(.disappeared(path: volume.mountPath))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .offline }, "Aushängen nicht verarbeitet")
            #expect(withdrawn.isEmpty, "Mitteilung bei anderem Grund zurückgezogen: \(withdrawn)")

            // Hinweis eines anderen Mediums: nichts zurückgezogen.
            await rig.coordinator.handle(.appeared(volume))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht erneut verbunden")
            app.indexingFailure = IndexingFailureNotice(id: UUID(), name: "ANDERES", reason: .unconfirmed)
            await rig.coordinator.handle(.disappeared(path: volume.mountPath))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .offline }, "Aushängen nicht verarbeitet")
            #expect(withdrawn.isEmpty, "Mitteilung eines anderen Mediums zurückgezogen: \(withdrawn)")

            // Der Hinweis dieses Mediums: genau seine Kennung wird zurückgezogen.
            await rig.coordinator.handle(.appeared(volume))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht erneut verbunden")
            // bug.0.4.193: über den echten Weg (Hinweis und zugestellte Mitteilung).
            app.presentIndexingFailure(mediumID: id, name: "SPAET2", reason: .unconfirmed)
            await rig.coordinator.handle(.disappeared(path: volume.mountPath))
            #expect(withdrawn == ["diskarchive.indexing-failure-\(id.uuidString)"], "Zurückgezogen: \(withdrawn)")
        }
    }

    /// bug.0.4.193: Das Zurückziehen hängt an der zugestellten Mitteilung, nicht am Hinweis. Hinweis geschlossen →
    /// Mitteilung trotzdem zurückgezogen; Hinweis von einem anderen Medium überschrieben → Mitteilung des ersten
    /// zurückgezogen, Hinweis des zweiten bleibt; Mitteilung mit anderem Grund → nichts zurückgezogen.
    @Test func lateUnmountWithdrawsTheDeliveredNoticeEvenWhenTheHintIsGone() async throws {
        let harness = try await ScanHarness.make()
        let volume = testVolume(path: "/Volumes/SPAET3", name: "SPAET3")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, volume.identity)
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: MemoryVolume(mountPath: volume.mountPath), app: app)
        defer { rig.coordinator.stop() }
        let id = harness.mediumID
        let identifier = "diskarchive.indexing-failure-\(id.uuidString)"
        var withdrawn: [String] = []
        let hooks = NoticeTestHooks(post: { _, _ in }, withdraw: { withdrawn.append($0) })
        try await SystemNotice.$testHooks.withValue(hooks) {
            // Hinweis geschlossen (wie „OK“ im Dialog), dann spätes Aushängen.
            await rig.coordinator.handle(.appeared(volume))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht verbunden")
            app.presentIndexingFailure(mediumID: id, name: "SPAET3", reason: .unconfirmed)
            try #require(app.indexingFailure?.id == id, "Voraussetzung: Hinweis steht")
            app.indexingFailure = nil
            await rig.coordinator.handle(.disappeared(path: volume.mountPath))
            #expect(withdrawn == [identifier], "Mitteilung nach geschlossenem Hinweis nicht zurückgezogen: \(withdrawn)")

            // Hinweis von einem anderen Medium überschrieben.
            withdrawn = []
            await rig.coordinator.handle(.appeared(volume))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht erneut verbunden")
            app.presentIndexingFailure(mediumID: id, name: "SPAET3", reason: .unconfirmed)
            let other = UUID()
            app.presentIndexingFailure(mediumID: other, name: "ANDERES", reason: .unconfirmed)
            try #require(app.indexingFailure?.id == other, "Voraussetzung: Hinweis des anderen Mediums steht")
            await rig.coordinator.handle(.disappeared(path: volume.mountPath))
            #expect(withdrawn == [identifier], "Mitteilung des ersten Mediums nicht zurückgezogen: \(withdrawn)")
            #expect(app.indexingFailure?.id == other, "Hinweis des anderen Mediums zurückgenommen")

            // bug.0.4.200 (e): anderer Grund wird ebenfalls zurückgezogen.
            withdrawn = []
            app.indexingFailure = nil
            await rig.coordinator.handle(.appeared(volume))
            try #require(await waitUntil { app.medium(with: id)?.connectionStatus == .connected }, "Medium nicht erneut verbunden")
            // Eine Stunde später (Drosselung: höchstens 3 Hinweise je Medium und Stunde).
            let later = Date().addingTimeInterval(7_200)
            app.presentIndexingFailure(mediumID: id, name: "SPAET3", reason: .unconfirmed, now: later)
            app.presentIndexingFailure(mediumID: id, name: "SPAET3", reason: .unknown, now: later)
            try #require(app.indexingFailure?.reason == .unknown, "Voraussetzung: neue Mitteilung mit anderem Grund")
            app.indexingFailure = nil
            await rig.coordinator.handle(.disappeared(path: volume.mountPath))
            #expect(withdrawn == [identifier], "Mitteilung mit anderem Grund nicht zurückgezogen: \(withdrawn)")
        }
    }
}

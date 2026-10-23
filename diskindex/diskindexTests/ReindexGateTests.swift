//
//  ReindexGateTests.swift
//  diskindexTests
//
//  Aufgabe 160: „Neu indizieren“ sperrt sofort und 59 s nach dem Laufende.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct ReindexGateTests {
    @Test func doubleClickRunsOnce() async {
        let app = AppState()
        let id = testUUID("D1600001-0000-4000-8000-000000000160")
        app.media = [medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))]
        var calls = 0
        app.onReindexMedium = { _ in calls += 1 }
        let session = PixelProbe.open(row(app: app, id: id), size: CGSize(width: 340, height: 56))
        session.click(at: CGPoint(x: 300, y: 28))
        session.click(at: CGPoint(x: 300, y: 28))
        session.close()
        #expect(calls == 1)
    }

    @Test func cooldownUsesInjectedClock() {
        let app = AppState()
        let id = testUUID("D1600002-0000-4000-8000-000000000160")
        let end = Date(timeIntervalSince1970: 10_000)
        app.media = [medium(id: id, indexing: false, lastIndexedAt: end)]
        #expect(!app.canReindex(id, now: end.addingTimeInterval(58)))
        #expect(app.canReindex(id, now: end.addingTimeInterval(59)))
    }

    /// bug.0.4.129: offline → „Neu indizieren“ gesperrt, kein hängender Eintrag.
    @Test func offlineMediumCannotReindex() {
        let app = AppState()
        let id = UUID()
        var offline = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        offline.connectionStatus = .offline
        app.media = [offline]
        app.onReindexMedium = { _ in }
        #expect(!app.canReindex(id))
        app.reindexMedium(id: id)
        #expect(app.reindexRequested.isEmpty)
    }

    /// bug.0.4.129: pausiert → gesperrt; nach Pausenende wieder aktiv.
    @Test func pausedMediumCannotReindexUntilResumed() {
        let app = AppState()
        let id = UUID()
        app.media = [medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))]
        app.globalAutoIndexPaused = true
        #expect(!app.canReindex(id))
        app.globalAutoIndexPaused = false
        app.updateMedium(id: id) { $0.autoIndexPaused = true }
        #expect(!app.canReindex(id))
        app.updateMedium(id: id) { $0.autoIndexPaused = false }
        #expect(app.canReindex(id))
    }

    /// bug.0.4.129: Lehnt der Dienst den Start ab (pausiert), bleibt kein Eintrag in `reindexRequested` hängen.
    @Test func rejectedStartClearsReindexRequest() async throws {
        let harness = try await ScanHarness.make()
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)
        let app = AppState()
        let id = harness.mediumID
        var shown = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        shown.decision = .index
        app.media = [shown]
        let service = IndexingService(store: harness.store, access: MemoryVolume(mountPath: "/Volumes/T"), appState: app)
        app.onReindexMedium = { mediumID in
            // Zwischen Klick und Start wird pausiert (Wettlauf): der Dienst lehnt ab.
            app.globalAutoIndexPaused = true
            service.start(mediumUUID: mediumID, volume: harness.volume(at: "/Volumes/T"), fromScratch: true)
        }
        app.reindexMedium(id: id)
        await service.waitUntilIdle(id)
        #expect(!app.reindexRequested.contains(id), "Eintrag hängt nach abgelehntem Start")
    }

    /// bug.0.4.129: Abbruch direkt nach dem Klick (vor „wird indiziert“, z. B. Aushängen) → kein hängender Eintrag.
    @Test func cancelBeforeRunBeginsClearsReindexRequest() async throws {
        let harness = try await ScanHarness.make()
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)
        let app = AppState()
        let id = harness.mediumID
        var shown = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        shown.decision = .index
        app.media = [shown]
        let service = IndexingService(store: harness.store, access: MemoryVolume(mountPath: "/Volumes/T"), appState: app)
        app.onReindexMedium = { mediumID in
            service.start(mediumUUID: mediumID, volume: harness.volume(at: "/Volumes/T"), fromScratch: true)
        }
        app.reindexMedium(id: id)
        try #require(app.reindexRequested.contains(id))
        await service.cancel(mediumUUID: id)
        await service.waitUntilIdle(id)
        #expect(!app.reindexRequested.contains(id), "Eintrag hängt nach Abbruch vor dem Laufbeginn")
    }

    /// bug.0.4.152: Klick → Abbruch läuft → Medium wird ausgehängt (wartender Start verworfen) → Knopf wieder frei.
    @Test func discardedWaitingStartClearsReindexRequest() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("hold/x.txt")
        _ = try await harness.run(access: inner, maxDepth: nil)
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)
        let app = AppState()
        let id = harness.mediumID
        var shown = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        shown.decision = .index
        app.media = [shown]
        let gate = RunGateAccess([inner]) { $0 == "/Volumes/T/hold" }
        let service = IndexingService(store: harness.store, access: gate, appState: app)
        let volume = harness.volume(at: "/Volumes/T")
        app.onReindexMedium = { mediumID in
            service.start(mediumUUID: mediumID, volume: volume, fromScratch: true)
        }
        service.start(mediumUUID: id, volume: volume, fromScratch: false)
        await gate.entered.wait()
        service.cancelBeforeAwaitHookForTesting = { mediumID in
            app.reindexMedium(id: mediumID)
            #expect(service.hasWaitingStartForTesting(mediumID), "Voraussetzung: der Start wartet auf den Abbruch")
            service.discardWaitingStart(mediumUUID: mediumID)
        }
        await service.cancel(mediumUUID: id)
        await service.waitUntilIdle(id)
        #expect(!app.reindexRequested.contains(id), "Sperre hängt nach verworfenem wartendem Start")
    }

    /// bug.0.4.139: Gesperrt (Versions-Sperre) hält ein laufender Lauf sofort an (`halt`), ohne auf das Abbrechen der
    /// Reihe nach zu warten – er schreibt nichts mehr.
    @Test func versionLockStopsARunningRunAtOnce() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("hold/sub/y.txt")
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)
        let app = AppState()
        let id = harness.mediumID
        var shown = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        shown.decision = .index
        app.media = [shown]
        let gate = RunGateAccess([inner]) { $0 == "/Volumes/T/hold" }
        let service = IndexingService(store: harness.store, access: gate, appState: app)
        service.start(mediumUUID: id, volume: harness.volume(at: "/Volumes/T"), fromScratch: true)
        await gate.entered.wait()
        app.versionLockState = .locked(.betaExpired)
        await gate.open()
        await service.waitUntilIdle(id)
        #expect(!(try await harness.store.storedNames()).contains("y.txt"), "gesperrter Lauf schrieb weiter")
    }

    /// bug.0.4.130 (a): Ein ausstehender Nachhol-Abgleich überlebt den Abbruch nicht.
    @Test func cancelDiscardsThePendingRerun() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("hold/x.txt")
        _ = try await harness.run(access: inner, maxDepth: nil)
        let app = AppState()
        let id = harness.mediumID
        var shown = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        shown.decision = .index
        app.media = [shown]
        var stored = try #require(try await harness.store.medium(uuid: id))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)
        let gate = RunGateAccess([inner]) { $0 == "/Volumes/T/hold" }
        let service = IndexingService(store: harness.store, access: gate, appState: app)
        let volume = harness.volume(at: "/Volumes/T")
        service.start(mediumUUID: id, volume: volume, fromScratch: false)
        await gate.entered.wait()
        // Zweiter Abgleich während des Laufs → wird nachgeholt …
        service.start(mediumUUID: id, volume: volume, fromScratch: false)
        try #require(service.hasPendingRerunForTesting(id), "Voraussetzung: Nachhol-Abgleich vorgemerkt")
        // … aber der Abbruch verwirft ihn.
        await service.cancel(mediumUUID: id)
        #expect(!service.hasPendingRerunForTesting(id), "Nachhol-Abgleich überlebt den Abbruch")
        await gate.open()
        await service.waitUntilIdle(id)
        #expect(service.startedRunsForTesting[id]?.count == 1)
    }

    /// bug.0.4.152: Der Speicher lehnt den Beginn ab → Knopf wieder frei.
    @Test func rejectedBeginClearsReindexRequest() async throws {
        let harness = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a.txt")
        _ = try await harness.run(access: inner, maxDepth: nil)
        var stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        stored.decision = .index
        try await harness.store.upsertMedium(stored)
        let app = AppState()
        let id = harness.mediumID
        var shown = medium(id: id, indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        shown.decision = .index
        app.media = [shown]
        let service = IndexingService(store: harness.store, access: inner, appState: app)
        let volume = harness.volume(at: "/Volumes/T")
        app.onReindexMedium = { mediumID in
            service.start(mediumUUID: mediumID, volume: volume, fromScratch: false)
        }
        await harness.store.setBeginIndexingRejected(true)
        app.reindexMedium(id: id)
        await service.waitUntilIdle(id)
        #expect(!app.reindexRequested.contains(id), "Sperre hängt nach abgelehntem Beginn")
    }

    @Test func buttonsLookDisabledDuringRun() async {
        let idle = await buttonInk(indexing: false, lastIndexedAt: Date(timeIntervalSince1970: 0))
        let locked = await buttonInk(indexing: false, lastIndexedAt: Date())
        let running = await buttonInk(indexing: true, lastIndexedAt: Date())
        #expect(locked.popover < idle.popover * 0.75)
        #expect(running.detail < idle.detail * 0.75)
    }

    private func buttonInk(indexing: Bool, lastIndexedAt: Date) async -> (popover: CGFloat, detail: CGFloat) {
        let app = AppState()
        let id = testUUID("D1600003-0000-4000-8000-000000000160")
        app.media = [medium(id: id, indexing: indexing, lastIndexedAt: lastIndexedAt)]
        let popover = await PixelProbe.render(row(app: app, id: id), size: CGSize(width: 340, height: 56))
        let detail = await PixelProbe.render(
            MediumDetailModalView(mediumID: id).environment(app).frame(width: 540, height: 420, alignment: .top),
            size: CGSize(width: 540, height: 420)
        )
        // Bereich relativ zur Bitmap (Knopf „Neu indizieren“ rechts in der Zeile), unabhängig von Punkt- und Pixeleinheiten.
        return (contrast(popover, x0: popover.size.width * 0.73, x1: popover.size.width * 0.97, y0: popover.size.height * 0.3, y1: popover.size.height * 0.72), contrast(detail, x0: 290, x1: 370, y0: 328, y1: 352))
    }

    private func row(app: AppState, id: UUID) -> some View {
        MenuBarConnectedMediumRow(medium: firstMedium(of: app), forceHover: true)
            .environment(app)
            .environment(\.colorScheme, .light)
            .frame(width: 340, height: 56)
            .background(Color.white)
    }

    private func medium(id: UUID, indexing: Bool, lastIndexedAt: Date?) -> Medium {
        var medium = Medium(
            id: id,
            name: "Sperre",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: indexing ? .indexing : .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000_000_000,
            capacityUsedBytes: 100,
            fileCount: 12,
            folderCount: 2,
            lastSeenAt: Date(),
            firstIndexedAt: lastIndexedAt,
            lastIndexedAt: lastIndexedAt,
            isForgotten: false,
            indexingProgress: indexing ? 0.4 : 1
        )
        medium.completedDepth = 1
        return medium
    }

    private func contrast(_ bitmap: NSBitmapImageRep, x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat) -> CGFloat {
        let background = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 16, y: 8)))
        var peak: CGFloat = 0
        var y = y0
        while y < y1 {
            var x = x0
            while x < x1 {
                let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)))
                peak = max(peak, abs(color.redComponent - background.redComponent)
                    + abs(color.greenComponent - background.greenComponent)
                    + abs(color.blueComponent - background.blueComponent))
                x += 2
            }
            y += 2
        }
        return peak
    }

    private func srgb(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.sRGB) ?? color
    }
}
}

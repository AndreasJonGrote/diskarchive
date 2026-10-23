//
//  ColumnIgnoreInPlaceTests.swift
//  diskindexTests
//
//  bug.0.4.088 / bug.0.4.090: „Dateinamen ignorieren“ an einem Ordner und das Aufheben im echten Fenster
//  (außerhalb des Bildschirms, Regel 10/19). Der Test löst nur das Ignorieren aus (wie das Kontextmenü,
//  `requestIgnore`) und wartet; er lädt nichts von Hand nach (Regel 18).
//  088: Der Eintrag verschwindet an Ort und Stelle; keine Spalte zeigt zu irgendeinem Zeitpunkt den Ladezustand.
//  090: Nach Ignorieren, Aufheben und Ende der Warteschlange erscheint bei einer Datei die Details-Spalte, keine Spalte
//  füllt die Restbreite – angeschlossen und offline.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnIgnoreInPlaceTests {
    private let size = CGSize(width: 1280, height: 700)

    @Test func ignoringAndRestoringAFolderHidesItInPlaceConnected() async throws {
        try await run(offline: false)
    }

    @Test func ignoringAndRestoringAFolderHidesItInPlaceOffline() async throws {
        try await run(offline: true)
    }

    /// bug.0.4.090 (Zustand vom Bildschirmfoto des Nutzers): Ordner öffnen, Laden hängt, Ladehinweis steht; zurück zum
    /// Elternordner (die Spalte verschwindet), Laden endet; Ordner wieder öffnen → Inhalt aus dem Zwischenspeicher,
    /// kein Ladehinweis mehr (sonst füllt die Spalte die Restbreite), Details-Spalte bei einer Datei da.
    @Test func loadingHintOfAColumnLeftWhileLoadingDoesNotStick() async throws {
        let rig = try await Self.makeRig(offline: true)
        defer { rig.close() }
        let app = rig.app
        let id = rig.id
        let repo = app.indexRepository
        app.columnBrowserState.pathStack = []
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height).background(DesignColor.bg),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        try #require(await waitUntil { repo.hasLoadedChildren(mediumID: id, path: []) })
        let gate = LoadGate()
        repo.loadProgressStepForTesting = { step in
            if step == .counted { await gate.pause() }
        }
        app.columnBrowserState.pathStack = ["Ceres"]
        let hint = await waitUntil(timeout: 5) { app.columnBrowserState.loadingHintVisible(mediumID: id, path: ["Ceres"]) }
        try #require(hint, "Ladehinweis erschien nicht")
        app.columnBrowserState.pathStack = []
        try await Task.sleep(for: .milliseconds(200))
        repo.loadProgressStepForTesting = nil
        await gate.open()
        try #require(await waitUntil { repo.hasLoadedChildren(mediumID: id, path: ["Ceres"]) })
        app.columnBrowserState.pathStack = ["Ceres"]
        try await Task.sleep(for: .milliseconds(500))
        #expect(!app.columnBrowserState.loadingHintVisible(mediumID: id, path: ["Ceres"]), "Ladehinweis hängt")

        let file = try #require(repo.children(mediumID: id, path: ["Ceres"]).first { !$0.isFolder })
        var selection = ColumnSelection()
        selection.replace(id: file.id, column: 1)
        app.columnBrowserState.selection = selection
        let detail = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return Self.detailHeaderHasInk(session.bitmap())
        }
        #expect(detail, "Details-Spalte fehlt")
    }

    /// bug.0.4.090 (Ursache, Prüf-Agent): Die Wurzelspalte hieß für jedes Medium „root“; ihre Ansicht blieb beim
    /// Medienwechsel stehen und meldete das Ende des Ladehinweises für das neue Medium. Ablauf: Wurzel von „Daten“ lädt,
    /// Hinweis steht → anderes Medium wählen → Laden endet → zurück zu „Daten“: kein Hinweis, Details bei einer Datei.
    @Test func loadingHintSurvivesNoMediumSwitch() async throws {
        let rig = try await Self.makeRig(offline: true)
        defer { rig.close() }
        let app = rig.app
        let id = rig.id
        let repo = app.indexRepository
        var other = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Andere", decision: .index, indexStatus: .indexed, completedDepth: 5)
        try await rig.store.upsertMedium(other)
        other = try #require(try await rig.store.medium(uuid: other.uuid))
        try await rig.store.applyDirectory(mediumUUID: other.uuid, parentID: nil, entries: [ScannedEntry(name: "Pallas", isFolder: true)], seenAt: Date())
        await app.loadStoredMedia()
        app.updateMedium(id: id) { $0.connectionStatus = .offline }
        app.columnBrowserState.pathStack = []
        let gate = LoadGate()
        repo.loadProgressStepForTesting = { step in
            if step == .counted { await gate.pause() }
        }
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height).background(DesignColor.bg),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let hint = await waitUntil(timeout: 5) { app.columnBrowserState.loadingHintVisible(mediumID: id, path: []) }
        try #require(hint, "Ladehinweis der Wurzel erschien nicht")
        repo.loadProgressStepForTesting = nil
        app.columnBrowserState.selectedMediumID = other.uuid
        try #require(await waitUntil { repo.hasLoadedChildren(mediumID: other.uuid, path: []) })
        await gate.open()
        try #require(await waitUntil { repo.hasLoadedChildren(mediumID: id, path: []) })
        app.columnBrowserState.selectedMediumID = id
        app.columnBrowserState.pathStack = ["Ceres"]
        try #require(await waitUntil { repo.hasLoadedChildren(mediumID: id, path: ["Ceres"]) })
        // Ein hängender Hinweis bliebe stehen; sonst ist er nach dem Laden (Mindestanzeige ≤ 400 ms) weg.
        let cleared = await waitUntil(timeout: 3) {
            ![[], ["Ceres"]].contains { app.columnBrowserState.loadingHintVisible(mediumID: id, path: $0) }
        }
        #expect(cleared, "Ladehinweis der Wurzel von „Daten“ hängt nach dem Medienwechsel")
        let file = try #require(repo.children(mediumID: id, path: ["Ceres"]).first { !$0.isFolder })
        var selection = ColumnSelection()
        selection.replace(id: file.id, column: 1)
        app.columnBrowserState.selection = selection
        let detail = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return Self.detailHeaderHasInk(session.bitmap())
        }
        #expect(detail, "Details-Spalte fehlt nach dem Medienwechsel")
    }

    /// bug.0.4.088 (Prüf-Agent): Ist der ignorierte Ordner selbst als Spalte offen, schließt sie sofort (Ordner und
    /// seine Spalte verschwinden zusammen), die Warteschlange läuft noch.
    @Test func ignoringTheOpenFolderClosesItsColumn() async throws {
        let rig = try await Self.makeRig(offline: false)
        defer { rig.close() }
        let app = rig.app
        await rig.store.setReconcileBatchDelay(.milliseconds(150))
        app.columnBrowserState.pathStack = ["Ceres", "geheim"]
        // Auswahl in der Spalte des ignorierten Ordners (rechts von „Ceres“) verschwindet mit ihr (bug.0.4.099 b:
        // Auswahl in „Ceres“ selbst bleibt, siehe unten).
        var selection = ColumnSelection()
        selection.replace(id: UUID(), column: 2)
        app.columnBrowserState.selection = selection
        app.requestIgnore(["geheim"], targetCount: 1)
        #expect(app.isRuleReconcileQueueActive)
        #expect(app.columnBrowserState.pathStack == ["Ceres"])
        #expect(app.columnBrowserState.selection.ids.isEmpty)
        await app.waitForRuleReconcileIdle()
    }

    /// bug.0.4.099 (a): Eine Spalte, die gerade zum ersten Mal lädt (kein Cache), bleibt bei `markAllStale` im
    /// Ladezustand und lädt selbst neu – ohne Anfrage der Ansicht. Vorher: sofort „nicht ladend, leer“ (= „Ordner leer“).
    @Test func firstLoadingColumnStaysLoadingAcrossMarkAllStale() async throws {
        let rig = try await Self.makeRig(offline: false)
        defer { rig.close() }
        let repo = rig.app.indexRepository
        let id = rig.id
        let gate = MultiGate()
        repo.loadProgressStepForTesting = { step in
            if step == .counted { await gate.pause() }
        }
        // Vorbereitung (kein End-to-End-Test): erster Load der Spalte „Ceres“, angehalten nach der Zählung.
        repo.requestLoad(mediumID: id, path: ["Ceres"])
        try #require(await waitUntil { gate.waiting >= 1 })
        try #require(repo.isLoading(mediumID: id, path: ["Ceres"]))
        let startedBefore = repo.loadSessionsStartedForTesting
        repo.markAllStale()
        #expect(repo.isLoading(mediumID: id, path: ["Ceres"]), "erstmals ladende Spalte nach markAllStale nicht mehr ladend (zeigt „Ordner leer“)")
        #expect(!repo.hasLoadedChildren(mediumID: id, path: ["Ceres"]))
        let restarted = await waitUntil { repo.loadSessionsStartedForTesting > startedBefore }
        #expect(restarted, "kein neuer Load ohne Anfrage der Ansicht")
        repo.loadProgressStepForTesting = nil
        gate.openAll()
        let loaded = await waitUntil { repo.hasLoadedChildren(mediumID: id, path: ["Ceres"]) }
        try #require(loaded)
        #expect(repo.children(mediumID: id, path: ["Ceres"]).count == 41)
        #expect(!repo.isLoading(mediumID: id, path: ["Ceres"]))
    }

    /// bug.0.4.099 (a) im echten Fenster: Während der Warteschlange öffnet der Nutzer einen Ordner, der zum ersten Mal
    /// lädt. Endet die Warteschlange (`markAllStale`), zeigt die Spalte zu keinem Zeitpunkt „leer, nicht ladend“.
    @Test func firstLoadingColumnNeverShowsEmptyWhenQueueEnds() async throws {
        let rig = try await Self.makeRig(offline: false)
        defer { rig.close() }
        let app = rig.app
        let id = rig.id
        let repo = app.indexRepository
        await rig.store.setReconcileBatchDelay(.milliseconds(150))
        app.columnBrowserState.pathStack = []
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height).background(DesignColor.bg),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        try #require(await waitUntil { repo.hasLoadedChildren(mediumID: id, path: []) })
        let gate = MultiGate()
        repo.loadProgressStepForTesting = { step in
            if step == .counted { await gate.pause() }
        }
        app.columnBrowserState.pathStack = ["Ceres"]
        try #require(await waitUntil { repo.isLoading(mediumID: id, path: ["Ceres"]) })
        let sampler = Sampler()
        sampler.start {
            if !repo.isLoading(mediumID: id, path: ["Ceres"]), !repo.hasLoadedChildren(mediumID: id, path: ["Ceres"]) {
                return "leer, nicht ladend"
            }
            return nil
        }
        defer { sampler.stop() }
        app.requestIgnore(["Vesta"], targetCount: 1)
        await app.waitForRuleReconcileIdle()
        // Ende der Warteschlange: `resumeAfterRuleReconcile` markiert alles veraltet, „Ceres“ lädt erneut (zweiter
        // Load am Tor).
        let resumed = await waitUntil { gate.waiting >= 2 }
        try #require(resumed, "Spalte nach der Warteschlange nicht neu geladen")
        try await Task.sleep(for: .milliseconds(300))
        repo.loadProgressStepForTesting = nil
        gate.openAll()
        let loaded = await waitUntil { repo.hasLoadedChildren(mediumID: id, path: ["Ceres"]) }
        sampler.stop()
        #expect(loaded)
        #expect(sampler.samples > 10)
        #expect(sampler.violations.isEmpty, "\(sampler.violations)")
    }

    /// bug.0.4.099 (b): Ignorieren des offenen Ordners schließt seine Spalte; die Mehrfachauswahl in der Spalte, die
    /// ihn enthält, bleibt (ohne den ignorierten Ordner selbst).
    @Test func ignoringTheOpenFolderKeepsVisibleMultiSelectionInItsColumn() async throws {
        let rig = try await Self.makeRig(offline: false)
        defer { rig.close() }
        let app = rig.app
        let repo = app.indexRepository
        await rig.store.setReconcileBatchDelay(.milliseconds(150))
        // Vorbereitung: Spalte „Ceres“ geladen (kein End-to-End-Test, Regel 18 betrifft nur Ketten).
        let items = await repo.loadChildren(mediumID: rig.id, path: ["Ceres"])
        let geheim = try #require(items.first { $0.name == "geheim" })
        let files = items.filter { !$0.isFolder }
        try #require(files.count >= 2)
        let first = try #require(files.first)
        let second = try #require(files.dropFirst().first)
        app.columnBrowserState.pathStack = ["Ceres", "geheim"]
        app.columnBrowserState.selection = ColumnSelection(
            ids: [first.id, geheim.id, second.id], anchorID: geheim.id, focusColumnIndex: 1, lastClickedID: geheim.id
        )
        app.requestIgnore(["geheim"], targetCount: 1)
        #expect(app.columnBrowserState.pathStack == ["Ceres"])
        #expect(app.columnBrowserState.selection.ids == [first.id, second.id])
        #expect(app.columnBrowserState.selection.focusColumnIndex == 1)
        await app.waitForRuleReconcileIdle()
    }

    /// Tor für mehrere Loads: hält jeden an, bis `openAll`.
    @MainActor
    private final class MultiGate {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private var opened = false
        var waiting: Int { waiters.count }
        func pause() async {
            if opened { return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func openAll() {
            opened = true
            let all = waiters
            waiters.removeAll()
            all.forEach { $0.resume() }
        }
    }

    private actor LoadGate {
        private var waiter: CheckedContinuation<Void, Never>?
        private var opened = false
        func pause() async {
            if opened { return }
            await withCheckedContinuation { waiter = $0 }
        }
        func open() {
            opened = true
            waiter?.resume()
            waiter = nil
        }
    }

    /// Medium „Daten“ mit Ceres (40 Dateien und Ordner „geheim“) und Vesta; Ansicht noch nicht geöffnet.
    @MainActor
    struct Rig {
        let app: AppState
        let store: IndexStoreV3
        let id: UUID
        let database: TestDatabase
        let directory: URL
        func close() {
            app.prepareForTermination()
            try? database.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    static func makeRig(offline: Bool) async throws -> Rig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-ignore-in-place-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Daten", decision: .index, indexStatus: .indexed, completedDepth: 5)
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))
        let id = stored.uuid
        try await store.applyDirectory(
            mediumUUID: id, parentID: nil,
            entries: [ScannedEntry(name: "Ceres", isFolder: true), ScannedEntry(name: "Vesta", isFolder: true)],
            seenAt: Date()
        )
        let ceres = try #require(try await store.children(mediumUUID: id, parentID: nil).first { $0.name == "Ceres" })
        try await store.applyDirectory(
            mediumUUID: id, parentID: ceres.id,
            entries: [ScannedEntry(name: "geheim", isFolder: true)]
                + (1...40).map { ScannedEntry(name: String(format: "datei%02d.txt", $0), isFolder: false, sizeBytes: 1, modifiedAt: Date()) },
            seenAt: Date()
        )
        let app = AppState()
        app.attach(store: store)
        // Wie in der App (`StoreLaunchSequence.startServices`): Änderungen des Stores, u. a. „Warteschlange leer“.
        app.startChangeLoop()
        await app.loadStoredMedia()
        app.updateMedium(id: id) { $0.connectionStatus = offline ? .offline : .connected }
        app.columnBrowserState.selectedMediumID = id
        app.columnBrowserState.pathStack = ["Ceres"]
        return Rig(app: app, store: store, id: id, database: database, directory: directory)
    }

    /// Verletzungen, die während der Warteschlange abgetastet werden.
    @MainActor
    private final class Sampler {
        var violations: [String] = []
        var samples = 0
        private var task: Task<Void, Never>?

        func start(_ check: @escaping @MainActor () -> String?) {
            task = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    if let problem = check(), let self, self.violations.count < 10 { self.violations.append(problem) }
                    self?.samples += 1
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
        }

        func stop() {
            task?.cancel()
            task = nil
        }
    }

    private func run(offline: Bool) async throws {
        let rig = try await Self.makeRig(offline: offline)
        defer { rig.close() }
        let app = rig.app
        let store = rig.store
        let id = rig.id
        await store.setReconcileBatchDelay(.milliseconds(150))

        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height).background(DesignColor.bg),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let repo = app.indexRepository
        func names(_ path: [String]) -> [String] { repo.children(mediumID: id, path: path).map(\.name) }
        let loaded = await waitUntil { names(["Ceres"]).contains("geheim") && names([]) == ["Ceres", "Vesta"] }
        try #require(loaded, "Spalten nicht geladen: \(names([])) / \(names(["Ceres"]))")
        // Mindestanzeige eines Ladehinweises vom ersten Laden abwarten (bis 400 ms), dann erst abtasten.
        let settled = await waitUntil {
            ![[], ["Ceres"]].contains { app.columnBrowserState.loadingHintVisible(mediumID: id, path: $0) }
        }
        try #require(settled, "Ladehinweis vom ersten Laden bleibt")
        let rootBefore = names([])
        let ceresBefore = names(["Ceres"])

        let sampler = Sampler()
        sampler.start {
            for path in [[], ["Ceres"]] as [[String]] {
                if app.columnBrowserState.loadingHintVisible(mediumID: id, path: path) { return "Ladehinweis \(path)" }
                if repo.isLoading(mediumID: id, path: path) { return "lädt \(path)" }
                if repo.children(mediumID: id, path: path).isEmpty { return "leer \(path)" }
            }
            return nil
        }
        defer { sampler.stop() }

        // Ignorieren (wie das Kontextmenü am Ordner „geheim“): sofort weg, die Warteschlange läuft noch.
        app.requestIgnore(["geheim"], targetCount: 1)
        let hidden = await waitUntil(timeout: 2) { !names(["Ceres"]).contains("geheim") }
        #expect(hidden, "„geheim“ noch sichtbar: \(names(["Ceres"]))")
        #expect(app.isRuleReconcileQueueActive, "Warteschlange schon fertig – Ausblenden nicht vor ihrem Ende belegt")
        #expect(names([]) == rootBefore, "Nachbarspalte verändert: \(names([]))")
        #expect(names(["Ceres"]).count == 40)
        await app.waitForRuleReconcileIdle()
        let calmAfterHide = await waitUntil { !repo.stale.contains { $0.hasPrefix(id.uuidString) } }
        #expect(calmAfterHide, "Spalten nach der Warteschlange nicht neu gelesen")
        #expect(!names(["Ceres"]).contains("geheim"))

        // Aufheben: nach der Warteschlange erscheint der Ordner an seinem Platz wieder, ohne Ladezustand.
        app.requestIgnore(["geheim"], targetCount: 1)
        await app.waitForRuleReconcileIdle()
        let back = await waitUntil { names(["Ceres"]) == ceresBefore }
        #expect(back, "„geheim“ nicht an seinem Platz zurück: \(names(["Ceres"]))")
        sampler.stop()
        #expect(sampler.samples > 10)
        #expect(sampler.violations.isEmpty, "Ladezustand während der Warteschlange: \(sampler.violations)")

        // 090: Datei wählen → Details-Spalte da, keine Spalte im Ladezustand.
        let file = try #require(repo.children(mediumID: id, path: ["Ceres"]).first { !$0.isFolder })
        var selection = ColumnSelection()
        selection.replace(id: file.id, column: 1)
        app.columnBrowserState.selection = selection
        let detail = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return Self.detailHeaderHasInk(session.bitmap())
        }
        #expect(detail, "Details-Spalte fehlt nach Ignorieren und Aufheben")
        #expect(![[], ["Ceres"]].contains { app.columnBrowserState.loadingHintVisible(mediumID: id, path: $0) })
    }

    /// Bereich rechts neben zwei Ordnerspalten (Kopf, auch unter dem Offline-Banner): Text nur mit Details-Spalte.
    static func detailHeaderHasInk(_ bitmap: NSBitmapImageRep) -> Bool {
        let left = Int(DesignSpacing.columnBrowserSidebarWidth + 2 * DesignSpacing.columnBrowserColumnWidth + 10)
        let scale = CGFloat(bitmap.pixelsWide) / max(1, bitmap.size.width)
        var dark = 0
        for y in stride(from: 6, through: 120, by: 1) {
            for x in stride(from: left, through: left + 160, by: 1) {
                guard let color = bitmap.colorAt(x: Int(CGFloat(x) * scale), y: Int(CGFloat(y) * scale))?.usingColorSpace(.sRGB) else { continue }
                let luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
                if luminance < 0.55 { dark += 1 }
            }
        }
        return dark >= 6
    }
}
}

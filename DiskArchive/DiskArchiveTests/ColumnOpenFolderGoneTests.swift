//
//  ColumnOpenFolderGoneTests.swift
//  DiskArchiveTests
//
//  bug.0.4.131: Gelöschter oder umbenannter offener Ordner. Löschen → `pathStack` ab dieser Ebene gekürzt, Auswahl auf
//  den Elternordner; Umbenennung → Pfad folgt dem neuen Namen, Auswahl bleibt. Regel 18: nur die Store-Änderung über
//  den echten Änderungsweg (`applyDirectory` bzw. `applyLiveRename` wie die Überwachung), dann warten und lesen.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
private func openFolderFixture(mount: URL) async throws -> (app: AppState, store: IndexStoreV3, medium: StoredMedium) {
    let database = try TestDatabase(fileURL: mount.deletingLastPathComponent().appendingPathComponent("archive.sqlite"))
    let store = IndexStoreV3(database: database)
    let app = AppState(store: store)
    app.startChangeLoop()
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await store.upsertMedium(medium)
    medium = try #require(try await store.medium(uuid: medium.uuid))
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4),
        ],
        seenAt: Date()
    )
    let alpha = try #require(try await store.children(mediumUUID: medium.uuid, parentID: nil).first { $0.name == "Alpha" })
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: alpha.id,
        entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1)],
        seenAt: Date()
    )
    await app.loadStoredMedia()
    return (app, store, medium)
}

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnOpenFolderGoneTests {
    private static let size = CGSize(width: 1280, height: 800)

    private func makeMount() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-open-gone-\(UUID().uuidString)", isDirectory: true)
        let mount = base.appendingPathComponent("BAUM", isDirectory: true)
        try FileManager.default.createDirectory(at: mount.appendingPathComponent("Alpha"), withIntermediateDirectories: true)
        return mount
    }

    private func openAlpha(_ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium)) async throws -> PixelProbe.Session {
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = tree.medium.uuid
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(tree.app)
                .environment(\.colorScheme, .light)
                .frame(width: Self.size.width, height: Self.size.height),
            size: Self.size
        )
        let rootLoaded = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).contains { $0.name == "Alpha" }
        }
        try #require(rootLoaded)
        let alpha = try #require(tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).first { $0.name == "Alpha" })
        var state = tree.app.columnBrowserState
        state.pathStack = ["Alpha"]
        state.selection = ColumnSelection(ids: [alpha.id], anchorID: alpha.id, focusColumnIndex: 0, lastClickedID: alpha.id)
        tree.app.columnBrowserState = state
        let alphaLoaded = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"]).contains { $0.name == "a.txt" }
        }
        try #require(alphaLoaded)
        return session
    }

    @Test func deletedOpenFolderTruncatesThePath() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        // Wie die Überwachung: Wurzel neu gelesen, „Alpha“ fehlt.
        try await tree.store.applyDirectory(
            mediumUUID: tree.medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4)],
            seenAt: Date()
        )
        let truncated = await waitUntil { tree.app.columnBrowserState.pathStack.isEmpty }
        #expect(truncated, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        #expect(tree.app.columnBrowserState.selection.ids.isEmpty)
    }

    // MARK: - bug.0.4.134: Live-Änderungen scrollen nicht waagerecht

    private static let narrow = CGSize(width: 560, height: 600)

    /// Schmales Fenster (waagerechter Überlauf), „Alpha“ offen, `a.txt` per Nutzeraktion gewählt → Details-Spalte bündig
    /// rechts; liefert das Fenster und die Scrollansicht.
    private func openAlphaFileNarrow(
        _ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium),
        settle: Duration = .milliseconds(100),
        waitUntilDone: Bool = true,
        done orders: ScrollOrdersDone? = nil,
        gate: SurfaceAsyncSignal? = nil,
        trace: SettleTrace? = nil
    ) async throws -> (PixelProbe.Session, NSScrollView) {
        let done = orders ?? ScrollOrdersDone()
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = tree.medium.uuid
        tree.app.columnBrowserState.pathStack = ["Alpha"]
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(tree.app)
                .environment(\.colorScheme, .light)
                .environment(\.columnScrollSettleDelay, settle)
                .environment(\.columnScrollOrderDone, { token in done.tokens.append(token) })
                .environment(\.columnScrollSettleGate, gate.map { gate -> @Sendable () async -> Void in { @Sendable in await gate.wait() } })
                .environment(\.columnScrollSettleTrace, trace.map { trace -> @MainActor (ColumnScrollSettleEvent) -> Void in { event in trace.record(event) } })
                .frame(width: Self.narrow.width, height: Self.narrow.height),
            size: Self.narrow
        )
        let loaded = await waitUntil {
            tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
        }
        try #require(loaded)
        let items = tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"])
        let file = try #require(items.first { $0.name == "a.txt" })
        let medium = try #require(tree.app.media.first { $0.id == tree.medium.uuid })
        // Wie ein Klick auf die Zeile (Nutzeraktion, neuer Scroll-Auftrag).
        tree.app.commitColumnSelection(
            ColumnSelection(ids: [file.id], anchorID: file.id, focusColumnIndex: 1, lastClickedID: file.id),
            items: items, columnIndex: 1, medium: medium
        )
        let flush = await waitUntil {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window) else { return false }
            return scroll.documentVisibleRect.minX > 1 && ColumnAutoScrollTestSupport.detailTrailingFlushWithViewport(scroll)
        }
        try #require(flush, "Details-Spalte nach der Auswahl nicht bündig (kein Überlauf?)")
        let scroll = try #require(ColumnAutoScrollTestSupport.mainColumnHorizontalScroll(in: session.window))
        // Auftrag erledigt erst, wenn die Spalte der Auswahl geladen ist und keinen Ladehinweis mehr zeigt – darauf
        // warten (positives Signal), dann die Ruhezeit des Auftrags (300 ms) mit Reserve.
        let settled = await waitUntil {
            tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
                && !tree.app.columnBrowserState.loadingHintVisible(mediumID: tree.medium.uuid, path: ["Alpha"])
        }
        try #require(settled, "Spalte „Alpha“ nicht fertig")
        // bug.0.4.168: positives Signal – der Auftrag des Klicks ist erledigt (statt fester Wartezeit).
        if waitUntilDone {
            let token = tree.app.columnScrollToken
            try #require(await waitUntil { done.tokens.contains(token) }, "Auftrag nicht erledigt")
        }
        // Auch bei offenem Auftrag: die Animation des ersten Scrolls ist gelaufen, bevor der Test selbst scrollt.
        try #require(await scrollComesToRest(scroll), "Scroll-Animation endet nicht")
        return (session, scroll)
    }

    /// bug.0.4.168: Auftrag noch offen (lange Ruhezeit), der Nutzer hat nach links gescrollt; dann wird die gewählte
    /// Datei live umbenannt → am Ende der Ruhezeit kein Sprung nach rechts.
    @Test func liveRenameWhileTheOrderIsOpenDoesNotScroll() async throws {
        let mount = try makeMount()
        try Data("x".utf8).write(to: mount.appendingPathComponent("Alpha/a.txt"))
        let tree = try await openFolderFixture(mount: mount)
        // bug.0.4.192: Der Auftrag bleibt hinter dem Tor offen, bis das Umbenennen in der Spalte steht (statt auf eine
        // lange Ruhezeit zu hoffen, die unter Last vorher ablief).
        let gate = SurfaceAsyncSignal()
        let done = ScrollOrdersDone()
        let (session, scroll) = try await openAlphaFileNarrow(tree, waitUntilDone: false, done: done, gate: gate)
        defer { session.close() }
        defer { Task { await gate.signal() } }
        let token = tree.app.columnScrollToken
        try #require(await scrollToLeadingAndRest(session.window, scroll), "bleibt nicht links stehen")
        let before = scroll.documentVisibleRect.minX
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha/a.txt"), to: mount.appendingPathComponent("Alpha/c.txt"))
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha/a.txt").path,
            toPath: mount.appendingPathComponent("Alpha/c.txt").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
        let renamed = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"]).contains { $0.name == "c.txt" }
        }
        try #require(renamed, "Umbenennen nicht in der Spalte")
        try #require(!done.tokens.contains(token), "Auftrag schon vor dem Umbenennen erledigt – Test prüft nichts")
        await gate.signal()
        // Positives Signal: der Auftrag endet (ohne Scroll), dann die Scroll-Animation (0,2 s).
        try #require(await waitUntil { done.tokens.contains(token) }, "Auftrag nicht erledigt")
        try await Task.sleep(for: .milliseconds(300))
        session.window.contentView?.layoutSubtreeIfNeeded()
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "offener Auftrag scrollte nach Live-Änderung: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    /// bug.0.4.168 (Selbstprüfung): Auftrag offen, die gewählte Datei wird live gelöscht (Ordner neu gelesen, Datei fehlt)
    /// → am Ende der Ruhezeit kein Sprung nach rechts.
    @Test func liveDeleteWhileTheOrderIsOpenDoesNotScroll() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        // bug.0.4.192: Tor statt langer Ruhezeit (siehe Umbenennen).
        let gate = SurfaceAsyncSignal()
        let done = ScrollOrdersDone()
        let (session, scroll) = try await openAlphaFileNarrow(tree, waitUntilDone: false, done: done, gate: gate)
        defer { session.close() }
        defer { Task { await gate.signal() } }
        let token = tree.app.columnScrollToken
        try #require(await scrollToLeadingAndRest(session.window, scroll), "bleibt nicht links stehen")
        let before = scroll.documentVisibleRect.minX
        let alpha = try #require(try await tree.store.folderID(mediumUUID: tree.medium.uuid, path: ["Alpha"]))
        try await tree.store.applyDirectories(
            mediumUUID: tree.medium.uuid,
            batches: [(parentID: alpha, path: nil, depth: nil, entries: [], finalize: true)],
            seenAt: Date(), mountPath: mount.path
        )
        let gone = await waitUntil {
            tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
                && !tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"]).contains { $0.name == "a.txt" }
        }
        try #require(gone, "Löschen nicht in der Spalte")
        try #require(!done.tokens.contains(token), "Auftrag schon vor dem Löschen erledigt – Test prüft nichts")
        await gate.signal()
        try #require(await waitUntil { done.tokens.contains(token) }, "Auftrag nicht erledigt")
        try #require(await scrollComesToRest(scroll), "Scroll-Animation endet nicht")
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "offener Auftrag scrollte nach Löschen: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    /// bug.0.4.168: Auftrag noch offen, der Nutzer scrollt selbst nach links → der Auftrag endet sofort (nicht erst nach
    /// der Ruhezeit mit einem Schlussscroll nach rechts), die Ansicht bleibt links.
    @Test func userScrollWhileTheOrderIsOpenEndsIt() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        // bug.0.4.192: Das Tor hält den Auftrag offen, bis der Test es öffnet. Ohne Nutzer-Scroll bliebe er offen; endet er,
        // war es der Scroll.
        // bug.0.4.197 a: Das Tor öffnet erst NACH dem Nutzer-Scroll; dann läuft die Aufgabe weiter. Der Test wartet auf
        // das positive Signal „alle begonnenen Ruhezeit-Aufgaben sind zu Ende“ und prüft erst danach, ob ein Rücksprung
        // angestoßen wurde (ohne den Abbruch durch den Nutzer-Scroll scrollt der Schlussscroll nach rechts).
        let gate = SurfaceAsyncSignal()
        let done = ScrollOrdersDone()
        let trace = SettleTrace()
        let (session, scroll) = try await openAlphaFileNarrow(tree, waitUntilDone: false, done: done, gate: gate, trace: trace)
        defer { session.close() }
        defer { Task { await gate.signal() } }
        let token = tree.app.columnScrollToken
        try #require(!done.tokens.contains(token), "Auftrag schon vor dem Scroll erledigt – Test prüft nichts")
        try #require(trace.started > 0, "keine Ruhezeit-Aufgabe begonnen – Test prüft nichts")
        // Wie ein Scroll mit Trackpad/Maus: Beginn des Live-Scrolls.
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scroll)
        // Positives Signal: der Auftrag ist sofort erledigt (das Tor ist noch zu).
        #expect(await waitUntil(timeout: 1) { done.tokens.contains(token) }, "Nutzer-Scroll beendete den Auftrag nicht")
        try #require(await scrollToLeadingAndRest(session.window, scroll), "bleibt nicht links stehen")
        NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: scroll)
        let before = scroll.documentVisibleRect.minX
        // Tor auf; die festgehaltene Aufgabe läuft zu Ende (abgebrochen oder – ohne Abbruch – mit Schlussscroll).
        await gate.signal()
        try #require(await waitUntil { trace.ended == trace.started }, "Ruhezeit-Aufgabe nicht zu Ende gelaufen")
        // Ein angestoßener Schlussscroll animiert (0,2 s); abwarten, bis die Ansicht ruht, dann prüfen.
        try #require(await scrollComesToRest(scroll), "Scroll-Animation endet nicht")
        session.window.contentView?.layoutSubtreeIfNeeded()
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "Auftrag scrollte nach Nutzer-Scroll zurück: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    private func renameAlphaToBeta(_ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium), mount: URL) async throws {
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("Beta"))
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("Beta").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
    }

    /// bug.0.4.134 (d): Der offene Ordner wird über den Store umbenannt (Live-Änderung) → die Ansicht bleibt stehen.
    @Test func liveRenameOfTheOpenFolderDoesNotScrollHorizontally() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let (session, scroll) = try await openAlphaFileNarrow(tree)
        defer { session.close() }
        // Etwas nach links (wie der Nutzer), damit ein Scroll nach rechts sichtbar würde.
        try #require(await scrollToLeadingAndRest(session.window, scroll), "bleibt nicht links stehen")
        let before = scroll.documentVisibleRect.minX
        try await renameAlphaToBeta(tree, mount: mount)
        let followed = await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] }
        try #require(followed, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        // Positives Signal: neue Spalte geladen; danach die Scroll-Animation (0,2 s) abwarten.
        try #require(await waitUntil { tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Beta"]) })
        try await Task.sleep(for: .milliseconds(500))
        session.window.contentView?.layoutSubtreeIfNeeded()
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "Live-Änderung scrollte: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    /// bug.0.4.148 (b)/134 (d): Klick auf die schon gewählte Zeile (neuer Auftrag ohne Pfad-/Auswahländerung), danach
    /// scrollt der Nutzer nach links; die nächste Live-Änderung scrollt nicht nach rechts.
    @Test func clickOnTheSelectedRowThenLiveChangeDoesNotScroll() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let (session, scroll) = try await openAlphaFileNarrow(tree)
        defer { session.close() }
        let items = tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"])
        let medium = try #require(tree.app.media.first { $0.id == tree.medium.uuid })
        let tokenBefore = tree.app.columnScrollToken
        tree.app.commitColumnSelection(tree.app.columnBrowserState.selection, items: items, columnIndex: 1, medium: medium)
        try #require(tree.app.columnScrollToken == tokenBefore + 1, "Klick erzeugte keinen Auftrag")
        try await Task.sleep(for: .milliseconds(600))
        try #require(await scrollToLeadingAndRest(session.window, scroll), "bleibt nicht links stehen")
        let before = scroll.documentVisibleRect.minX
        try await renameAlphaToBeta(tree, mount: mount)
        try #require(await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] })
        try #require(await waitUntil { tree.app.indexRepository.hasLoadedChildren(mediumID: tree.medium.uuid, path: ["Beta"]) })
        try await Task.sleep(for: .milliseconds(500))
        session.window.contentView?.layoutSubtreeIfNeeded()
        #expect(abs(scroll.documentVisibleRect.minX - before) <= 1, "Live-Änderung nach Klick scrollte: \(before) → \(scroll.documentVisibleRect.minX)")
    }

    /// bug.0.4.147 / 163 (a): Pixel-Nachweis im echten Fenster – nach dem Umbenennen des offenen Ordners zeigt der Kopf
    /// seiner Spalte den neuen (viel kürzeren) Namen ohne Reste des alten, und die Spalte zeigt ihren Inhalt.
    @Test func renamedOpenFolderHeaderShowsOnlyTheNewName() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        let left = DesignSpacing.columnBrowserSidebarWidth + DesignSpacing.columnBrowserColumnWidth
        // Unter dem Offline-Hinweis (≈ 26 pt): Spaltenkopf bei ≈ 40 pt, erste Zeile bei ≈ 70 pt.
        let header = CGRect(x: left + 4, y: 32, width: DesignSpacing.columnBrowserColumnWidth - 12, height: 16)
        func headerInk() -> CGRect? {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            return PixelProbe.inkBounds(in: session.bitmap(), rect: header, background: CGPoint(x: header.maxX - 2, y: 40))
        }
        let rowRect = CGRect(x: left + 4, y: 58, width: DesignSpacing.columnBrowserColumnWidth - 12, height: 24)
        let before = try #require(await waitUntil { (headerInk()?.width ?? 0) > 20 } ? headerInk() : nil, "Kopf „Alpha“ ohne Tinte")
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("B"))
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("B").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
        try #require(await waitUntil { tree.app.columnBrowserState.pathStack == ["B"] })
        // Kopf: nur noch „B“ (schmale Tinte, deutlich schmaler als „Alpha“), keine alte Tinte daneben.
        let narrowed = await waitUntil {
            guard let ink = headerInk() else { return false }
            return ink.width > 2 && ink.width < before.width * 0.6
        }
        #expect(narrowed, "Kopf zeigt nicht nur den neuen Namen: vorher \(before.width), jetzt \(headerInk()?.width ?? -1)")
        // Inhalt der Spalte (a.txt) gezeichnet.
        let rowInk = await waitUntil {
            PixelProbe.inkBounds(in: session.bitmap(), rect: rowRect, background: CGPoint(x: rowRect.maxX - 2, y: 60)) != nil
        }
        #expect(rowInk, "Spalte „B“ ohne Inhalt")
    }

    @Test func renamedOpenFolderFollowsTheNewName() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        let selected = tree.app.columnBrowserState.selection.ids
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("Beta"))
        // Wie die Überwachung bei einem Umbenennen-Paar.
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("Beta").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
        let followed = await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] }
        #expect(followed, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        #expect(tree.app.columnBrowserState.selection.ids == selected, "Auswahl verloren")
        let contents = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Beta"]).contains { $0.name == "a.txt" }
        }
        #expect(contents, "Spalte „Beta“ zeigt den Inhalt nicht")
    }
}
}

/// Scrollposition ruht: über 400 ms (vier Messungen im Abstand von 100 ms) unverändert – länger als die Scroll-Animation
/// (0,2 s). Auch ein Scroll ohne sichtbare Bewegung (Ziel = aktuelle Stelle) hält die Position während seiner Animation
/// fest. Vor jeder Messung wird das Fenster gezeichnet – eine ausstehende Animation startet erst damit.
@MainActor
private func scrollComesToRest(_ scroll: NSScrollView) async -> Bool {
    scroll.window?.display()
    var last = scroll.documentVisibleRect.minX
    var still = 0
    for _ in 0..<60 {
        try? await Task.sleep(for: .milliseconds(100))
        scroll.window?.display()
        let now = scroll.documentVisibleRect.minX
        still = abs(now - last) < 0.5 ? still + 1 : 0
        if still >= 4 { return true }
        last = now
    }
    return false
}

/// Wie der Nutzer nach links scrollen. Der Test setzt die Clip-Ansicht direkt; SwiftUI holt seine gemerkte Position
/// dabei mitunter animiert zurück (ein echter Scroll des Nutzers läuft über SwiftUI). Darum wiederholen, bis die
/// Ansicht links ruht – erst danach kommt die Live-Änderung, deren Wirkung der Test misst.
@MainActor
private func scrollToLeadingAndRest(_ window: NSWindow, _ scroll: NSScrollView) async -> Bool {
    for _ in 0..<10 {
        ColumnAutoScrollTestSupport.scrollMainHorizontalToLeading(in: window)
        guard await scrollComesToRest(scroll) else { return false }
        if scroll.documentVisibleRect.minX < 1 { return true }
    }
    return false
}

/// bug.0.4.197 a: zählt begonnene und beendete Ruhezeit-Aufgaben des Scroll-Auftrags.
@MainActor
final class SettleTrace {
    private(set) var started = 0
    private(set) var ended = 0

    func record(_ event: ColumnScrollSettleEvent) {
        switch event {
        case .started: started += 1
        case .ended: ended += 1
        }
    }
}

@MainActor
final class ScrollOrdersDone {
    var tokens: [Int] = []
}

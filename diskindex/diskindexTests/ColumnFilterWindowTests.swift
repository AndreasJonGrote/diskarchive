//
//  ColumnFilterWindowTests.swift
//  diskindexTests
//
//  todo.0.4.2.003 (Layout ab 0.4.2 „Ordner ohne Treffer geöffnet“, „Filter wird angewendet“): Spaltenansicht im
//  echten Fenster außerhalb des Bildschirms. Status in der richtigen Spalte (Pixel: blaues Filter-Icon bzw. Spinner),
//  „Filter zurücksetzen“ per Klick, Wartescreen erst nach 1 s, Abbruch ohne spätes Ergebnis, Live ohne Wartescreen.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

/// Tor für Test-Haken: wartet, bis der Test es öffnet.
@MainActor
final class ColumnFilterGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

/// Pause, die ein Abbruch nicht verkürzt (wie eine langsame Abfrage).
@MainActor
func columnFilterPause(_ milliseconds: Int) async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { continuation.resume() }
    }
}

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct ColumnFilterWindowTests {
    private static let size = CGSize(width: 1100, height: 560)

    private static var tree: [ColumnFilterTreeNode] {
        [
            .folder("A", [
                .folder("B", [.folder("C", [.folder("D", [.file("bild.cr2")])])]),
                .folder("X", [.file("text.txt")]),
            ]),
            .folder("F", [.folder("leer")]),
        ]
    }

    @MainActor
    private struct Opened {
        let rig: ColumnFilterTreeRig
        let app: AppState
        let session: PixelProbe.Session

        func close() {
            session.close()
            app.prepareForTermination()
            rig.close()
        }

        func key() -> ColumnFilterKey? {
            ColumnFilterKey(mediumID: app.columnBrowserState.selectedMediumID, filters: app.searchState.filters)
        }

        /// Bereich (x) der Ordnerspalte `index`, aus den senkrechten Trennlinien im Bild (Seitenleiste, Spalten).
        func columnRange(_ index: Int) -> ClosedRange<CGFloat> {
            let bitmap = session.bitmap()
            let y = ColumnFilterWindowTests.size.height - 60
            let background = PixelProbe.color(in: bitmap, at: CGPoint(x: ColumnFilterWindowTests.size.width - 20, y: y))
            var lines: [CGFloat] = []
            var x: CGFloat = 40
            while x < ColumnFilterWindowTests.size.width - 40 {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                let dark = background.redComponent - sample.redComponent > 0.08
                if dark, lines.last.map({ x - $0 > 6 }) ?? true { lines.append(x) }
                x += 0.5
            }
            let start = index < lines.count ? lines[index] + 2 : ColumnFilterWindowTests.size.width - 1
            let end = index + 1 < lines.count ? lines[index + 1] - 2 : min(start + 320, ColumnFilterWindowTests.size.width - 1)
            return start...max(start, end)
        }
    }

    private static func open(path: [String], rig given: ColumnFilterTreeRig? = nil) async throws -> Opened {
        let rig: ColumnFilterTreeRig
        if let given {
            rig = given
        } else {
            rig = try await ColumnFilterTreeRig.make(tree)
        }
        let app = AppState(store: rig.store)
        await app.loadStoredMedia()
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = rig.mediumID
        app.columnBrowserState.pathStack = path
        app.isFilterBarVisible = true
        let session = PixelProbe.open(
            MainWindowScreenScaffold { ColumnBrowserView() }
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size
        )
        for depth in 0...path.count {
            let prefix = Array(path.prefix(depth))
            try #require(await waitUntil { app.indexRepository.hasLoadedChildren(mediumID: rig.mediumID, path: prefix) }, "Spalte \(prefix) nicht geladen")
        }
        await PixelProbe.settleOpenWindow(session)
        return Opened(rig: rig, app: app, session: session)
    }

    /// Rahmen der blauen Pixel (`DesignColor.filterSearch`) in `range` unterhalb von Werkzeug- und
    /// Filterleiste: Filter-Icon bzw. Spinner der Statusfläche.
    private static func blueBounds(_ session: PixelProbe.Session, in range: ClosedRange<CGFloat>) -> CGRect? {
        session.window.contentView?.layoutSubtreeIfNeeded()
        let bitmap = session.bitmap()
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude, maxX: CGFloat = -1, maxY: CGFloat = -1
        var y: CGFloat = 110
        while y < size.height - 30 {
            var x = range.lowerBound
            while x <= range.upperBound {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                // Deutlich blau (Ton von `filterSearch`), unabhängig von Farbraum und Kantenglättung.
                if sample.blueComponent - sample.redComponent > 0.3, sample.blueComponent > 0.6 {
                    minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
                }
                x += 1
            }
            y += 1
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Link „Filter zurücksetzen“: letzte Textzeile unter dem Icon (Titel, Text, Link).
    private static func linkPoint(_ session: PixelProbe.Session, icon: CGRect) -> CGPoint? {
        let bitmap = session.bitmap()
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: icon.minX + 280, y: icon.minY))
        var lines: [[CGFloat]] = []
        var y = icon.maxY + 4
        while y < min(icon.maxY + 170, size.height - 30) {
            var ink = false
            var x = icon.minX
            while x < icon.minX + 90, !ink {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                ink = abs(sample.redComponent - background.redComponent) > 0.25
                    || abs(sample.greenComponent - background.greenComponent) > 0.25
                    || abs(sample.blueComponent - background.blueComponent) > 0.25
                x += 1
            }
            if ink {
                if let last = lines.last?.last, y - last <= 2 { lines[lines.count - 1].append(y) } else { lines.append([y]) }
            }
            y += 1
        }
        guard let link = lines.last, let top = link.first, let bottom = link.last else { return nil }
        return CGPoint(x: icon.minX + 30, y: (top + bottom) / 2)
    }

    private static func waitForBlue(_ session: PixelProbe.Session, in range: ClosedRange<CGFloat>) async -> CGRect? {
        var found: CGRect?
        _ = await waitUntil(timeout: 5) {
            found = blueBounds(session, in: range)
            return found != nil
        }
        return found
    }

    // Gegenprobe 4: leiser Ordner geöffnet – Status mit Zähler „0 von n“; der Link hebt den Filter auf, Pfad bleibt.
    @Test func quietFolderShowsNoMatchesAndResetKeepsThePath() async throws {
        let opened = try await Self.open(path: ["F"])
        defer { opened.close() }
        let app = opened.app
        app.searchState.filters.fileTypes = [.image]
        let key = try #require(opened.key())
        try #require(await waitUntil { app.columnFilterFolderHits(for: key) != nil }, "Treffermenge fehlt")
        let hits = app.columnFilterFolderHits(for: key)
        let root = app.indexRepository.children(mediumID: opened.rig.mediumID, path: [])
        let inside = app.indexRepository.children(mediumID: opened.rig.mediumID, path: ["F"])
        let status = ColumnBrowserFiltering.status(columnPath: ["F"], pathStack: ["F"], parentItems: root, hits: hits, waiting: false)
        #expect(status == .noMatches)
        let counts = ColumnBrowserFiltering.counts(
            items: inside, visible: ColumnBrowserFiltering.visibleItems(inside, filters: app.searchState.filters), hits: hits, status: status
        )
        #expect(counts.matching == 0 && counts.total == 1, "Zähler \(counts)")
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.columnHeaderCount("F", 0, 1).uppercased() == "F · 0 VON 1")
            #expect(ObjectCountFormatting.label(filtered: 0, total: 1) == "0 von 1 Objekten")
        }

        let column = opened.columnRange(1)
        let icon = try #require(await Self.waitForBlue(opened.session, in: column), "Filter-Icon fehlt in der Spalte von „F“")
        let link = try #require(Self.linkPoint(opened.session, icon: icon), "Link nicht gefunden")
        opened.session.click(at: link, settle: 0.2)
        #expect(!app.searchState.filters.hasActiveObjectFilters, "Filter nicht zurückgesetzt")
        #expect(app.columnBrowserState.pathStack == ["F"], "Pfad \(app.columnBrowserState.pathStack)")
        let gone = await waitUntil(timeout: 3) { Self.blueBounds(opened.session, in: column) == nil }
        #expect(gone, "Status steht noch")
        let rowInk = PixelProbe.inkBounds(
            in: opened.session.bitmap(),
            rect: CGRect(x: column.lowerBound + 8, y: 110, width: 160, height: 120),
            background: CGPoint(x: column.lowerBound + 300, y: 300)
        )
        #expect(rowInk != nil, "Inhalt von „F“ nicht sichtbar")
    }

    // Gegenprobe 4 (Selbstprüfung): tiefer Pfad unter einem leisen Ordner (G/H) – nur ein Status, rechts davon nichts.
    @Test func deepPathUnderAQuietFolderShowsOneStatus() async throws {
        let rig = try await ColumnFilterTreeRig.make(Self.tree + [.folder("G", [.folder("H", [.file("notiz.txt")])])])
        let opened = try await Self.open(path: ["G", "H"], rig: rig)
        defer { opened.close() }
        let app = opened.app
        app.searchState.filters.fileTypes = [.image]
        let key = try #require(opened.key())
        try #require(await waitUntil { app.columnFilterFolderHits(for: key) != nil }, "Treffermenge fehlt")
        let column = opened.columnRange(1)
        let icon = try #require(await Self.waitForBlue(opened.session, in: column), "Filter-Icon fehlt in der Spalte von „G“")
        let all = try #require(Self.blueBounds(opened.session, in: column.lowerBound...(Self.size.width - 1)))
        #expect(all.width < icon.width + 4, "mehr als ein Status rechts von „G“: \(all)")
        #expect(app.columnBrowserState.pathStack == ["G", "H"], "Pfad geändert")
    }

    // Gegenprobe 5: Wartescreen nach 1 s in der Spalte des tiefsten geöffneten Ordners; unter 1 s keiner.
    @Test func waitScreenAppearsAfterOneSecondInTheDeepestColumn() async throws {
        for path in [[String](), ["A", "B"]] {
            let opened = try await Self.open(path: path)
            defer { opened.close() }
            let app = opened.app
            app.columnFilterComputeHookForTesting = { _ in await columnFilterPause(1_600) }
            app.searchState.filters.fileTypes = [.image]
            let key = try #require(opened.key())
            try #require(await waitUntil(timeout: 4) { app.columnFilterWaitVisible }, "kein Wartescreen (\(path))")
            #expect(ColumnBrowserFiltering.status(columnPath: path, pathStack: path, parentItems: [], hits: nil, waiting: true) == .applying)
            #expect(ColumnBrowserFiltering.status(columnPath: Array(path.prefix(1)), pathStack: path, parentItems: [], hits: nil, waiting: true) == (path.isEmpty ? .applying : nil))
            let spinner = await Self.waitForBlue(opened.session, in: opened.columnRange(path.count))
            #expect(spinner != nil, "Spinner fehlt in Spalte \(path.count)")
            let done = await waitUntil(timeout: 6) { !app.columnFilterWaitVisible && app.columnFilterFolderHits(for: key) != nil }
            #expect(done, "Ergebnis nicht übernommen (\(path))")
        }
    }

    @Test func noWaitScreenUnderOneSecond() async throws {
        let opened = try await Self.open(path: [])
        defer { opened.close() }
        let app = opened.app
        app.columnFilterComputeHookForTesting = { _ in await columnFilterPause(300) }
        app.searchState.filters.fileTypes = [.image]
        let key = try #require(opened.key())
        var sawWait = false
        let done = await waitUntil(timeout: 5) {
            sawWait = sawWait || app.columnFilterWaitVisible
            return app.columnFilterFolderHits(for: key) != nil
        }
        #expect(done, "Ergebnis fehlt")
        #expect(!sawWait, "Wartescreen unter 1 s")
    }

    @Test func resetLinkOnTheWaitScreenStopsTheRun() async throws {
        let opened = try await Self.open(path: [])
        defer { opened.close() }
        let app = opened.app
        var returned = false
        app.columnFilterComputeHookForTesting = { _ in
            await columnFilterPause(2_500)
            returned = true
        }
        app.searchState.filters.fileTypes = [.image]
        try #require(await waitUntil(timeout: 4) { app.columnFilterWaitVisible }, "kein Wartescreen")
        let spinner = try #require(await Self.waitForBlue(opened.session, in: opened.columnRange(0)), "Spinner fehlt")
        let link = try #require(Self.linkPoint(opened.session, icon: spinner), "Link nicht gefunden")
        opened.session.click(at: link, settle: 0.2)
        #expect(!app.searchState.filters.hasActiveObjectFilters)
        #expect(!app.columnFilterWaitVisible, "Wartescreen steht noch")
        try #require(await waitUntil(timeout: 5) { returned }, "Rechnung nicht zu Ende")
        for _ in 0..<20 { await Task.yield() }
        #expect(app.columnFilterHits == nil, "spätes Ergebnis nach „Filter zurücksetzen“")
    }

    // Gegenprobe 6: Abbruch – zweiter Filter gewinnt; nach Medienwechsel kein Ergebnis des alten Mediums.
    @Test func newFilterOrMediumDropsTheOldResult() async throws {
        var rig = try await ColumnFilterTreeRig.make(Self.tree)
        let second = try await rig.addMedium([.folder("Z", [.file("z.txt")])], name: "Zweit")
        let first = rig.mediumID
        let opened = try await Self.open(path: [], rig: rig)
        defer { opened.close() }
        let app = opened.app
        let gate = ColumnFilterGate()
        var entered = false
        var returned = false
        app.columnFilterComputeHookForTesting = { key in
            guard key.mediumID == first, key.filters.fileTypes == [.image] else { return }
            entered = true
            await gate.wait()
            returned = true
        }
        app.searchState.filters.fileTypes = [.image]
        try #require(await waitUntil { entered }, "erste Rechnung nicht begonnen")
        app.searchState.filters.fileTypes = [.text]
        let textKey = try #require(opened.key())
        try #require(await waitUntil { app.columnFilterFolderHits(for: textKey) != nil }, "zweiter Filter ohne Ergebnis")
        gate.open()
        try #require(await waitUntil { returned })
        for _ in 0..<20 { await Task.yield() }
        #expect(app.columnFilterHits?.key == textKey, "Ergebnis des ersten Filters übernommen")

        // Medium gewechselt, während das alte noch rechnet.
        entered = false
        returned = false
        let secondGate = ColumnFilterGate()
        app.columnFilterComputeHookForTesting = { key in
            guard key.mediumID == first else { return }
            entered = true
            await secondGate.wait()
            returned = true
        }
        app.searchState.filters.fileTypes = [.image]
        try #require(await waitUntil { entered }, "Rechnung für das erste Medium nicht begonnen")
        app.columnBrowserState.selectedMediumID = second
        let secondKey = try #require(opened.key())
        try #require(await waitUntil { app.columnFilterFolderHits(for: secondKey) != nil }, "neues Medium ohne Ergebnis")
        secondGate.open()
        try #require(await waitUntil { returned })
        for _ in 0..<20 { await Task.yield() }
        #expect(app.columnFilterHits?.key.mediumID == second, "Ergebnis des alten Mediums übernommen")
    }
}
}

//
//  FilterPopoverScrollTests.swift
//  DiskArchiveTests
//
//  bug.0.4.212 — Bei offenem Filter scrollt das Fenster darunter. Ein Klick daneben schließt den Filter, ohne dort etwas
//  auszulösen; ein Klick ins Panel schließt nicht; Escape schließt. Hauptfenster-Rahmen mit Spaltenansicht außerhalb des
//  Bildschirms, echte Ereignisse über `NSApp.sendEvent` (wie in der App, mit lokalen Monitoren).
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct FilterPopoverScrollTests {
    private static let size = CGSize(width: 1100, height: 700)

    /// Wurzel mit 120 Dateien; Spaltenansicht im Hauptfenster-Rahmen, Filterleiste sichtbar.
    /// Fenster schließen, Aufgaben des Zustands beenden (sonst bleibt die Testdatenbank offen), Ordner löschen.
    private static func close(_ app: AppState, _ session: PixelProbe.Session) {
        session.close()
        app.prepareForTermination()
        if let folder = openFolders[ObjectIdentifier(app)] { try? FileManager.default.removeItem(at: folder) }
        openFolders[ObjectIdentifier(app)] = nil
    }

    private static var openFolders: [ObjectIdentifier: URL] = [:]

    private static func open() async throws -> (AppState, PixelProbe.Session) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-filter-scroll-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Lang", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))
        try await store.applyDirectory(
            mediumUUID: stored.uuid, parentID: nil,
            entries: (1...120).map { ScannedEntry(name: String(format: "datei%03d.txt", $0), isFolder: false, sizeBytes: 1) },
            seenAt: Date()
        )
        let app = AppState(store: store)
        openFolders[ObjectIdentifier(app)] = directory
        await app.loadStoredMedia()
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = stored.uuid
        app.isFilterBarVisible = true
        let session = PixelProbe.open(
            MainWindowScreenScaffold { ColumnBrowserView() }
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size
        )
        try #require(await waitUntil { app.indexRepository.children(mediumID: stored.uuid, path: []).count == 120 }, "Wurzel nicht geladen")
        await PixelProbe.settleOpenWindow(session)
        return (app, session)
    }

    /// Senkrechte Scrollansicht der Wurzelspalte (die mit Überlauf).
    private static func columnScroll(_ window: NSWindow) -> NSScrollView? {
        ColumnAutoScrollTestSupport.allViews(of: NSScrollView.self, in: window.contentView).first { scroll in
            (scroll.documentView?.frame.height ?? 0) > scroll.contentView.bounds.height + 200
        }
    }

    private static func frameInWindow(_ view: NSView) -> NSRect {
        view.convert(view.bounds, to: nil)
    }

    private static func settle(_ window: NSWindow, _ seconds: TimeInterval = 0.15) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline { CFRunLoopRunInMode(.defaultMode, 0.01, true) }
        window.contentView?.layoutSubtreeIfNeeded()
    }

    /// Ansicht, die AppKit an `point` (Fensterkoordinaten) ein Mausrad-Ereignis zustellt (`NSWindow.sendEvent`: Hit-Test,
    /// dann die Responder-Kette hinauf).
    private static func wheelTarget(_ window: NSWindow, at point: NSPoint) -> NSView? {
        guard let content = window.contentView else { return nil }
        return content.hitTest(content.superview?.convert(point, from: nil) ?? point)
    }

    /// Mausklick an `point` (Fensterkoordinaten, AppKit) über `NSApp.sendEvent`.
    private static func click(_ window: NSWindow, at point: NSPoint) {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
            ) else { continue }
            NSApp.sendEvent(event)
        }
        settle(window)
    }

    /// Punkt im unteren Teil der Spalte, nicht unter dem Filter-Panel.
    private static func pointInColumn(_ scroll: NSScrollView, avoiding panel: NSRect?) throws -> NSPoint {
        let frame = frameInWindow(scroll)
        let point = NSPoint(x: frame.midX, y: frame.minY + 40)
        if let panel { try #require(!panel.insetBy(dx: -8, dy: -8).contains(point), "Spaltenpunkt \(point) unter dem Panel \(panel)") }
        return point
    }

    private static func panelFrame(_ window: NSWindow) throws -> NSRect {
        let monitor = try #require(
            ColumnAutoScrollTestSupport.allViews(of: OutsideClickMonitorNSView.self, in: window.contentView).first,
            "Filter-Panel nicht offen"
        )
        return frameInWindow(monitor)
    }

    /// Mausrad über der Spalte erreicht bei offenem Filter die Scrollansicht der Spalte (Gegenprobe: ohne Filter).
    /// Ein synthetisches Mausrad bewegt SwiftUIs Scrollansicht außerhalb des Bildschirms nicht (auch ohne Filter); geprüft
    /// wird deshalb der Zustellweg – genau ihn unterbrach die fensterfüllende Fläche.
    @Test func columnScrollsWhileTheFilterIsOpen() async throws {
        let (app, session) = try await Self.open()
        defer { Self.close(app, session) }
        let window = session.window
        let scroll = try #require(Self.columnScroll(window), "keine Spalte mit Überlauf")
        let point = try Self.pointInColumn(scroll, avoiding: nil)
        let free = Self.wheelTarget(window, at: point)
        #expect(free?.isDescendant(of: scroll) == true,
                "Gegenprobe: ohne Filter erreicht das Mausrad die Spalte nicht (\(String(describing: free.map { type(of: $0) })))")

        app.isFilterPopoverShown = true
        Self.settle(window, 0.3)
        let panel = try Self.panelFrame(window)
        let below = try Self.pointInColumn(scroll, avoiding: panel)
        let target = Self.wheelTarget(window, at: below)
        #expect(target?.isDescendant(of: scroll) == true,
                "bei offenem Filter erreicht das Mausrad die Spalte nicht (\(String(describing: target.map { type(of: $0) })))")
        #expect(app.isFilterPopoverShown)
    }

    /// Klick ins Panel schließt nicht; Klick daneben schließt, ohne dort zu wählen; Escape schließt.
    @Test func clickOutsideClosesWithoutSelectingAndEscapeCloses() async throws {
        let (app, session) = try await Self.open()
        defer { Self.close(app, session) }
        let window = session.window
        let scroll = try #require(Self.columnScroll(window), "keine Spalte mit Überlauf")

        app.isFilterPopoverShown = true
        Self.settle(window, 0.3)
        let panel = try Self.panelFrame(window)
        Self.click(window, at: NSPoint(x: panel.midX, y: panel.minY + 6))
        #expect(app.isFilterPopoverShown, "Klick ins Panel schließt den Filter")

        let row = try Self.pointInColumn(scroll, avoiding: panel)
        Self.click(window, at: row)
        #expect(!app.isFilterPopoverShown, "Klick daneben schließt den Filter nicht")
        #expect(app.columnBrowserState.selection.ids.isEmpty, "Klick daneben wählt dort etwas aus")

        app.isFilterPopoverShown = true
        Self.settle(window, 0.3)
        NSApp.sendEvent(try escapeKey(in: window))
        Self.settle(window)
        #expect(!app.isFilterPopoverShown, "Escape schließt den Filter nicht")

        // Gegenprobe: ohne Filter wählt derselbe Klick die Zeile.
        Self.click(window, at: row)
        let selected = await waitUntil(timeout: 3) { !app.columnBrowserState.selection.ids.isEmpty }
        #expect(selected, "Gegenprobe: Klick an dieser Stelle trifft keine Zeile")
    }
}
}

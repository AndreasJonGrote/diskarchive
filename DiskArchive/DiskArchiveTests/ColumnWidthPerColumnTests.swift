//
//  ColumnWidthPerColumnTests.swift
//  DiskArchiveTests
//
//  bug.0.4.218 — Jede Ordnerspalte hat ihre eigene Breite (Konzept `suche-navigation.md`, „Spaltenbreite“): Ziehen am Rand
//  ändert nur diese Spalte, beim Ziehen und danach, ohne Ruckeln (die Breite folgt der Maus Schritt für Schritt). Neu
//  geöffnete Spalten beginnen mit 230 pt; schließt eine Spalte, fällt ihre Breite weg. Echtes Fenster außerhalb des
//  Bildschirms, Ziehen über die getroffene Ansicht, Spaltenränder über die Trennlinien (`ColumnDividerTests.verticalLines`).
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnWidthPerColumnTests {
    private static let size = CGSize(width: 1400, height: 600)
    private static let sidebar = DesignSpacing.columnBrowserSidebarWidth
    private static let standard = DesignSpacing.columnBrowserColumnWidth

    /// Wurzel (A), A (B, x.txt), B (C), C (leer); geöffnet bis B: drei Ordnerspalten.
    private static func app() -> AppState {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID, name: "Breiten", type: .ssd, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 100,
            fileCount: 1, folderCount: 3, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = 5
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["A", "B"]
        func item(_ row: Int64, _ name: String, _ parent: [String], folder: Bool) -> IndexedItem {
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: row), rowID: row, name: name,
                kind: folder ? .folder : .file, parentPath: parent, modifiedAt: Date(), sizeBytes: folder ? 0 : 1, listedAt: Date()
            )
        }
        app.indexRepository.seedScreenshotCache(
            mediumID: mediumID,
            entries: [
                ([], [item(1, "A", [], folder: true)]),
                (["A"], [item(2, "B", ["A"], folder: true), item(3, "x.txt", ["A"], folder: false)]),
                (["A", "B"], [item(4, "C", ["A", "B"], folder: true)]),
                (["A", "B", "C"], []),
            ]
        )
        return app
    }

    private static func open(_ app: AppState, appearance: NSAppearance.Name) async -> PixelProbe.Session {
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                .frame(width: size.width, height: size.height).background(DesignColor.bg),
            size: size,
            appearance: appearance
        )
        await PixelProbe.settleOpenWindow(session)
        return session
    }

    private static func settle(_ session: PixelProbe.Session, _ seconds: TimeInterval = 0.12) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline { CFRunLoopRunInMode(.defaultMode, 0.01, true) }
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
    }

    /// Rechte Ränder der Ordnerspalten (Trennlinien rechts der Seitenleiste), in pt.
    private static func edges(_ session: PixelProbe.Session) -> [CGFloat] {
        settle(session)
        return ColumnDividerTests.verticalLines(in: session.bitmap(), from: sidebar + 3, to: size.width - 3)
    }

    /// Erwartete rechte Ränder bei diesen Spaltenbreiten (Linie = letzter Punkt der Spalte).
    private static func expected(_ widths: [CGFloat]) -> [CGFloat] {
        var x = sidebar
        return widths.map { x += $0; return x - 1 }
    }

    private static func matches(_ edges: [CGFloat], _ widths: [CGFloat]) -> Bool {
        let want = expected(widths)
        return edges.count == want.count && zip(edges, want).allSatisfy { abs($0 - $1) <= 0.5 }
    }

    /// Mausereignis an die Ansicht, die beim Drücken getroffen wurde (wie `PixelProbe.clickThroughHitTest`): Über
    /// `window.sendEvent` kommt im inaktiven Testfenster weder Tippen noch Ziehen bei SwiftUI-Gesten an.
    private static func mouse(_ type: NSEvent.EventType, x: CGFloat, in session: PixelProbe.Session, target: inout NSView?) {
        let location = NSPoint(x: x, y: size.height - 300)
        guard let event = NSEvent.mouseEvent(
            with: type, location: location, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: session.window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1
        ) else { return }
        if type == .leftMouseDown, let content = session.window.contentView {
            target = content.hitTest(content.superview?.convert(location, from: nil) ?? location)
        }
        switch type {
        case .leftMouseDown: target?.mouseDown(with: event)
        case .leftMouseDragged: target?.mouseDragged(with: event)
        default: target?.mouseUp(with: event)
        }
    }

    /// Zieht den Griff am rechten Rand der Spalte, die bei `edge` endet, in Schritten von ±10 pt um `distance`; nach jedem
    /// Schritt die Ränder (beim Ziehen).
    private static func drag(_ session: PixelProbe.Session, edge: CGFloat, by distance: CGFloat) -> [[CGFloat]] {
        let start = edge - 3
        var target: NSView?
        mouse(.leftMouseDown, x: start, in: session, target: &target)
        settle(session, 0.05)
        var during: [[CGFloat]] = []
        var moved: CGFloat = 0
        let step: CGFloat = distance < 0 ? -10 : 10
        while abs(moved) < abs(distance) {
            moved += step
            mouse(.leftMouseDragged, x: start + moved, in: session, target: &target)
            during.append(edges(session))
        }
        mouse(.leftMouseUp, x: start + distance, in: session, target: &target)
        settle(session)
        return during
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func onlyTheDraggedColumnChanges(appearance: NSAppearance.Name) async throws {
        let app = Self.app()
        let session = await Self.open(app, appearance: appearance)
        defer { session.close() }
        let s = Self.standard
        let before = Self.edges(session)
        try #require(Self.matches(before, [s, s, s]), "Ausgangslage: Ränder \(before), erwartet \(Self.expected([s, s, s]))")

        // Mittlere Spalte (A) um 60 breiter: beim Ziehen folgt nur sie der Maus, Schritt für Schritt.
        let during = Self.drag(session, edge: before[1], by: 60)
        for (step, edges) in during.enumerated() {
            let width = s + CGFloat(step + 1) * 10
            #expect(Self.matches(edges, [s, width, s]),
                    "beim Ziehen, Schritt \(step + 1): Ränder \(edges), erwartet \(Self.expected([s, width, s]))")
        }
        let after = Self.edges(session)
        #expect(Self.matches(after, [s, s + 60, s]), "nach dem Loslassen: Ränder \(after), erwartet \(Self.expected([s, s + 60, s]))")

        // Neue Spalte (C geöffnet): Standardbreite, die gezogene bleibt.
        app.columnBrowserState.pathStack = ["A", "B", "C"]
        let opened = Self.edges(session)
        #expect(Self.matches(opened, [s, s + 60, s, s]), "neue Spalte: Ränder \(opened), erwartet \(Self.expected([s, s + 60, s, s]))")

        // Spalte A geschlossen und wieder geöffnet: ihre Breite ist weggefallen.
        app.columnBrowserState.pathStack = []
        _ = Self.edges(session)
        app.columnBrowserState.pathStack = ["A", "B"]
        let reopened = Self.edges(session)
        #expect(Self.matches(reopened, [s, s, s]), "wieder geöffnet: Ränder \(reopened), erwartet \(Self.expected([s, s, s]))")
    }

    /// Gegenprobe: die erste Spalte ziehen – nur sie wird schmaler, die anderen behalten 230.
    @Test func draggingTheFirstColumnLeavesTheOthers() async throws {
        let app = Self.app()
        let session = await Self.open(app, appearance: .aqua)
        defer { session.close() }
        let s = Self.standard
        let before = Self.edges(session)
        try #require(Self.matches(before, [s, s, s]), "Ausgangslage: Ränder \(before)")
        _ = Self.drag(session, edge: before[0], by: -40)
        let after = Self.edges(session)
        #expect(Self.matches(after, [s - 40, s, s]), "Ränder \(after), erwartet \(Self.expected([s - 40, s, s]))")
    }
}
}

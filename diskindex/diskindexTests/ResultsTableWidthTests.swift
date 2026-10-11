//
//  ResultsTableWidthTests.swift
//  diskindexTests
//
//  Aufgabe 218 — die Ergebnistabelle (Suche, Favoriten) nutzt die ganze Breite: Name und Pfad teilen den freien
//  Platz, Status sitzt rechts mit 16 pt Rand. Beide Scroller-Stile, 1000 und 1600 pt.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ResultsTableWidthTests {
    private let longName = "aachener-bericht-04-28.html"

    private func items() -> [SearchResultItem] {
        let mediumID = UUID()
        return (0..<60).map { index in
            let name = index == 0 ? longName : "bericht-\(index).pdf"
            let item = IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: name,
                kind: .file,
                parentPath: ["Archiv", "2024"],
                modifiedAt: Date(),
                sizeBytes: 10,
                lastSeenAt: Date(),
                listedAt: Date()
            )
            return SearchResultItem(item: item, mediumID: mediumID, isOnline: true)
        }
    }

    /// Breite der Inhaltsfläche: im Legacy-Stil belegt die Systemleiste eigenen Platz.
    private func contentWidth(window width: CGFloat, style: NSScroller.Style) -> CGFloat {
        style == .legacy ? width - NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : width
    }

    private func render(width: CGFloat, style: NSScroller.Style) async throws -> (bitmap: NSBitmapImageRep, session: PixelProbe.Session) {
        let app = AppState()
        let size = CGSize(width: width, height: 500)
        let session = PixelProbe.open(
            ObjectResultsTable(results: items()) { Text("leer") }
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height)
                .background(Color.white),
            size: size,
            appearance: .aqua
        )
        await PixelProbe.settleOpenWindow(session)
        let host = try #require(session.window.contentView)
        applyStyle(style, to: host)
        await PixelProbe.settleOpenWindow(session)
        session.window.display()
        return (session.bitmap(), session)
    }

    private func applyStyle(_ style: NSScroller.Style, to view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.scrollerStyle = style
            scroll.verticalScroller?.scrollerStyle = style
        }
        for sub in view.subviews { applyStyle(style, to: sub) }
    }

    private func ink(_ bitmap: NSBitmapImageRep, x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat) -> CGRect? {
        PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
            background: CGPoint(x: 6, y: (y0 + y1) / 2)
        )
    }

    @Test func columnMathAddsUpToTheTableWidth() {
        for total in [900.0, 985, 1000, 1585, 1600] {
            let columns = ObjectTableColumns(totalWidth: total)
            let fixed = ObjectTableColumns.icon + ObjectTableColumns.date + ObjectTableColumns.medium
                + ObjectTableColumns.status + 2 * ObjectTableColumns.horizontalPadding
            #expect(abs(columns.name + columns.path + fixed - total) <= 1, "Summe bei \(total)")
            #expect(columns.name > 160, "Name bleibt auf Mindestbreite bei \(total)")
        }
    }

    @Test(arguments: [NSScroller.Style.overlay, .legacy], [CGFloat(1000), 1600])
    func statusSitsAtTheRightEdgeWith16pt(style: NSScroller.Style, width: CGFloat) async throws {
        let (bitmap, session) = try await render(width: width, style: style)
        defer { session.close() }
        let tableRight = contentWidth(window: width, style: style)
        let chip = try #require(ink(bitmap, x0: tableRight - 150, x1: tableRight + 1, y0: 46, y1: 66), "kein Status-Chip")
        #expect(abs(chip.maxX - (tableRight - 16)) <= 1.5, "Chip rechts \(chip.maxX), erwartet \(tableRight - 16)")
    }

    /// Dieselbe Tabelle in den Favoriten: Status sitzt rechts (Filterleiste darüber verschiebt nur die Zeilenhöhe).
    @Test(arguments: [NSScroller.Style.overlay, .legacy], [CGFloat(1000), 1600])
    func favoritesTableUsesTheWholeWidth(style: NSScroller.Style, width: CGFloat) async throws {
        let app = AppState()
        app.favoriteObjects = items()
        app.screenshotFrozenLists = true
        let size = CGSize(width: width, height: 500)
        let session = PixelProbe.open(
            FavoritesView().environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height).background(Color.white),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let host = try #require(session.window.contentView)
        applyStyle(style, to: host)
        await PixelProbe.settleOpenWindow(session)
        session.window.display()
        let bitmap = session.bitmap()
        let tableRight = contentWidth(window: width, style: style)
        // Zeilenhöhe der ersten Zeile unbekannt (Filterleiste): ganzen Bereich unter dem Kopf absuchen.
        let chip = try #require(ink(bitmap, x0: tableRight - 150, x1: tableRight + 1, y0: 90, y1: 130), "kein Status-Chip")
        #expect(abs(chip.maxX - (tableRight - 16)) <= 1.5, "Chip rechts \(chip.maxX), erwartet \(tableRight - 16)")
    }

    @Test(arguments: [NSScroller.Style.overlay, .legacy])
    func pathColumnMovesWithTheFreeSpace(style: NSScroller.Style) async throws {
        let (narrow, narrowSession) = try await render(width: 1000, style: style)
        narrowSession.close()
        let (wide, wideSession) = try await render(width: 1600, style: style)
        wideSession.close()
        // Kopf „Pfad“: linke Tintenkante in der Kopfzeile, rechts der festen Spalten.
        let narrowW = contentWidth(window: 1000, style: style)
        let wideW = contentWidth(window: 1600, style: style)
        let nameNarrow = ObjectTableColumns(totalWidth: narrowW).name
        let nameWide = ObjectTableColumns(totalWidth: wideW).name
        let fixedLeft = ObjectTableColumns.horizontalPadding + ObjectTableColumns.icon + ObjectTableColumns.date + ObjectTableColumns.medium
        func pathHeaderX(_ bitmap: NSBitmapImageRep, name: CGFloat, tableWidth: CGFloat) -> CGFloat? {
            let start = fixedLeft + name
            return ink(bitmap, x0: start - 4, x1: min(tableWidth - 120, start + 120), y0: 6, y1: 32)?.minX
        }
        let a = try #require(pathHeaderX(narrow, name: nameNarrow, tableWidth: narrowW), "Kopf „Pfad“ (1000) fehlt")
        let b = try #require(pathHeaderX(wide, name: nameWide, tableWidth: wideW), "Kopf „Pfad“ (1600) fehlt")
        #expect(abs((b - a) - (nameWide - nameNarrow)) <= 2, "Pfad-Spalte verschiebt sich um \(b - a), erwartet \(nameWide - nameNarrow)")
        #expect(b - a > 100)
    }

    @Test(arguments: [NSScroller.Style.overlay, .legacy], [CGFloat(1000), 1600])
    func aNameThatFitsIsNotTruncated(style: NSScroller.Style, width: CGFloat) async throws {
        let (bitmap, session) = try await render(width: width, style: style)
        defer { session.close() }
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let textWidth = (longName as NSString).size(withAttributes: [.font: font]).width
        let columns = ObjectTableColumns(totalWidth: contentWidth(window: width, style: style))
        try #require(columns.name > textWidth + 8, "Testname passt nicht in die Spalte")
        let start = ObjectTableColumns.horizontalPadding + ObjectTableColumns.icon
        let name = try #require(ink(bitmap, x0: start - 2, x1: start + columns.name, y0: 46, y1: 66), "kein Name")
        #expect(abs(name.width - textWidth) <= 4, "Tintenbreite \(name.width), Textbreite \(textWidth)")
    }
}
}

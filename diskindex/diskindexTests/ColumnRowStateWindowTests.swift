//
//  ColumnRowStateWindowTests.swift
//  diskindexTests
//
//  bug.0.4.034 — Zustand „wird indiziert“ je Zeile im echten Fenster außerhalb des Bildschirms (Regel 10/19/21):
//  indizierter Ordner Deckkraft 1, Ordner ohne `listedAt` bei laufender Indizierung 0,55; bei Scan-Tiefe 2 sind
//  Ordner der Ebene 2 gelb („Inhalt wird nicht indiziert“), nicht grün.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct ColumnRowStateWindowTests {
    private let size = CGSize(width: 1280, height: 800)

    /// Deckkraft je Zeile = Kontrast des Titels ÷ Kontrast des Titels einer Datei-Zeile derselben Spalte
    /// (Dateien werden nie gedimmt; unabhängig von Spaltengeometrie und aufgelöster Textfarbe).
    @Test func indexedRowIsOpaqueAndUnlistedRowIsDimmedWhileIndexing() async throws {
        let rig = RowRig(scanDepth: AppSettings.defaultScanDepth)
        let session = PixelProbe.open(browser(rig), size: size)
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let bands = RowRig.inkBands(in: session.bitmap(), column: 0, titleOnly: true)
        // Reihenfolge nach Namen: A-fertig (Ordner, indiziert), B-offen (Ordner ohne listedAt), C-datei.txt (Datei).
        try #require(bands.count == 3, "Zeilen: \(bands.count)")
        let file = bands[2].contrast
        let indexed = bands[0].contrast / file
        let pending = bands[1].contrast / file
        #expect(abs(indexed - 1) <= 0.08, "indizierter Ordner Deckkraft \(indexed)")
        #expect(abs(pending - 0.55) <= 0.08, "Ordner ohne listedAt Deckkraft \(pending)")
    }

    /// Fester Hintergrund: im durchsichtigen Testfenster änderte die Deckkraft sonst nur Alpha, nicht die Farbe.
    private func browser(_ rig: RowRig) -> some View {
        ColumnBrowserView().environment(rig.app).frame(width: size.width, height: size.height).background(DesignColor.bg)
    }

    @Test func folderAtScanDepthIsYellowNotPending() async throws {
        let rig = RowRig(scanDepth: 2)
        rig.app.columnBrowserState.pathStack = [RowRig.indexedName]
        let session = PixelProbe.open(browser(rig), size: size)
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)

        let before = session.bitmap()
        let bands = RowRig.inkBands(in: before, column: 1)
        try #require(bands.count >= 1, "Ebene 2 ohne Zeilen")
        #expect(RowRig.contains(before, column: 1, hue: .yellow), "Ordner der Ebene 2 nicht gelb")

        // Anklicken öffnet die Statusspalte: gelber Warnkreis statt grünem Spinner.
        let row = bands[0]
        session.click(at: CGPoint(x: RowRig.columnX(1) + 60, y: (row.minY + row.maxY) / 2))
        let shown = await waitUntil {
            let bitmap = session.bitmap()
            return RowRig.contains(bitmap, column: 2, hue: .yellow)
        }
        #expect(shown, "„Inhalt wird nicht indiziert“ (gelb) fehlt")
        #expect(!RowRig.contains(session.bitmap(), column: 2, hue: .green), "grüner Spinner statt gelb")
    }
}
}

@MainActor
private struct RowRig {
    static let indexedName = "A-fertig"
    let app = AppState()

    init(scanDepth: Int) {
        var medium = Medium(
            id: UUID(),
            name: "Zeilen",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 0,
            folderCount: 3,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0.3
        )
        medium.completedDepth = 1
        func folder(_ rowID: Int64, _ name: String, _ parent: [String], listed: Bool) -> IndexedItem {
            IndexedItem(
                id: IndexedItem.stableID(mediumID: medium.id, rowID: rowID),
                rowID: rowID,
                name: name,
                kind: .folder,
                parentPath: parent,
                modifiedAt: Date(),
                sizeBytes: nil,
                listedAt: listed ? Date() : nil
            )
        }
        let root = [
            folder(1, Self.indexedName, [], listed: true),
            folder(2, "B-offen", [], listed: false),
            IndexedItem(
                id: IndexedItem.stableID(mediumID: medium.id, rowID: 4),
                rowID: 4,
                name: "C-datei.txt",
                kind: .file,
                parentPath: [],
                modifiedAt: Date(),
                sizeBytes: 10,
                listedAt: nil
            ),
        ]
        let level2 = [folder(3, "C-tief", [Self.indexedName], listed: false)]
        app.appSettings.scanDepth = scanDepth
        app.media = [medium]
        app.indexRepository.seedScreenshotCache(mediumID: medium.id, entries: [
            ([], root),
            ([Self.indexedName], level2),
        ])
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.id
    }

    static func columnX(_ index: Int) -> CGFloat {
        DesignSpacing.columnBrowserSidebarWidth + CGFloat(index) * DesignSpacing.columnBrowserColumnWidth
    }

    /// Spaltenfläche ohne Rand (pt): Innenbereich der Spalte.
    static func columnRect(_ index: Int) -> CGRect {
        CGRect(x: columnX(index) + 10, y: 20, width: DesignSpacing.columnBrowserColumnWidth - 20, height: 700)
    }

    static func luminance(_ color: NSColor) -> CGFloat {
        let c = color.usingColorSpace(.sRGB) ?? color
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }

    /// Zusammenhängende Pixelzeilen mit Schrift/Icon in der Spalte, von oben nach unten, mit größtem Kontrast.
    static func inkBands(
        in bitmap: NSBitmapImageRep,
        column: Int,
        titleOnly: Bool = false
    ) -> [(minY: CGFloat, maxY: CGFloat, contrast: CGFloat)] {
        var rect = columnRect(column)
        if titleOnly {
            // Rechts vom Symbol (Zeilenabstand 10 + Symbol 16 + Abstand 8), nur Titelschrift.
            rect = CGRect(x: columnX(column) + 48, y: rect.minY, width: 120, height: rect.height)
        }
        // Hintergrund je Pixelzeile rechts in der Spalte (dort steht kein Titel), nicht einmal für die ganze Spalte.
        let backgroundX = columnX(column) + DesignSpacing.columnBrowserColumnWidth - 14
        var bands: [(minY: CGFloat, maxY: CGFloat, contrast: CGFloat)] = []
        var current: (minY: CGFloat, maxY: CGFloat, contrast: CGFloat)?
        var y = rect.minY
        while y < rect.maxY {
            let background = luminance(PixelProbe.color(in: bitmap, at: CGPoint(x: backgroundX, y: y)))
            var strongest: CGFloat = 0
            var x = rect.minX
            while x < rect.maxX {
                strongest = max(strongest, abs(luminance(PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))) - background))
                x += 1
            }
            if strongest > 0.06 {
                if var band = current {
                    band.maxY = y
                    band.contrast = max(band.contrast, strongest)
                    current = band
                } else {
                    current = (y, y, strongest)
                }
            } else if let band = current {
                bands.append(band)
                current = nil
            }
            y += 0.5
        }
        if let band = current { bands.append(band) }
        // Schrift-Unterlängen trennen keine Zeilen: Bänder unter 4 pt Abstand zusammenfassen.
        var merged: [(minY: CGFloat, maxY: CGFloat, contrast: CGFloat)] = []
        for band in bands {
            if let last = merged.popLast() {
                if band.minY - last.maxY < 4 {
                    merged.append((last.minY, band.maxY, max(last.contrast, band.contrast)))
                } else {
                    merged.append(last)
                    merged.append(band)
                }
            } else {
                merged.append(band)
            }
        }
        return merged.filter { $0.maxY - $0.minY >= 6 }
    }

    enum Hue { case yellow, green }

    /// Farbton statt exaktem Wert: Symbole sind kantengeglättet. Gelb = `stateIgnored` (#eda12d), Grün = Spinner (#20a04e).
    static func contains(_ bitmap: NSBitmapImageRep, column: Int, hue: Hue) -> Bool {
        let rect = columnRect(column)
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let c = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)).usingColorSpace(.sRGB) ?? .black
                let (r, g, b) = (c.redComponent, c.greenComponent, c.blueComponent)
                switch hue {
                case .yellow where r > 0.8 && g > 0.5 && g < r - 0.03 && b < g - 0.2:
                    return true
                case .green where g > 0.5 && g > r + 0.25 && g > b + 0.15:
                    return true
                default:
                    break
                }
                x += 1
            }
            y += 1
        }
        return false
    }
}

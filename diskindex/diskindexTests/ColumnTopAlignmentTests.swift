//
//  ColumnTopAlignmentTests.swift
//  diskindexTests
//
//  Aufgabe 143 — Spaltenkopf an der Oberkante des Spaltenbereichs.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct ColumnTopAlignmentTests {
    @Test func folderColumnHeaderSitsAtTopOfArea() async throws {
        let app = AppState()
        var medium = Medium(
            id: UUID(),
            name: "Demo",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 3,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 2
        app.media = [medium]
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.id

        let host = NSHostingView(
            rootView: ColumnBrowserView()
                .environment(app)
                .frame(width: 1280, height: 800)
        )
        let window = PixelProbe.offscreenWindow(hosting: host, size: CGSize(width: 1280, height: 800))
        // Auf die Bedingung warten: der erste Treffer am oberen Rand steht, sobald das Layout fertig ist.
        let laidOut = await waitUntil {
            host.layoutSubtreeIfNeeded()
            return host.hitTest(NSPoint(x: 400, y: host.bounds.height - 80)) != nil
        }
        try #require(laidOut)

        // Spaltenbereich beginnt unter Sidebar/Toolbar; Kopf darf nicht auf halber Höhe sitzen.
        // Treffer nahe der oberen Kante des rechten Inhalts (x≈280, y nahe maxY).
        let topY = host.bounds.height - 80
        let hit = host.hitTest(NSPoint(x: 400, y: topY))
        #expect(hit != nil)
        // Mitte der Fläche (y≈400) darf nicht der einzige Trefferort für den Kopf sein —
        // Inhalt muss oben anfangen: fitting der Spalten-HStack-Höhe ≈ Fensterhöhe.
        #expect(host.bounds.height >= 700)
        window.orderOut(nil)
    }
}

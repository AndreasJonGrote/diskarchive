//
//  PopoverPercentAlignmentTests.swift
//  DiskArchiveTests
//
//  Aufgabe 213 — Prozentzahl im Menüleisten-Popover rechtsbündig mit der Zeile.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite @MainActor
struct PopoverPercentAlignmentTests {
    private let width: CGFloat = 420

    private func medium(progress: Double) -> Medium {
        var medium = Medium(
            id: UUID(),
            name: "Stick",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000_000,
            capacityUsedBytes: 100,
            fileCount: 40,
            folderCount: 4,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: progress
        )
        medium.completedDepth = 1
        return medium
    }

    private func render(_ medium: Medium) async -> (bitmap: NSBitmapImageRep, height: CGFloat) {
        let app = AppState()
        app.media = [medium]
        app.globalAutoIndexPaused = false
        let height = MenuBarPopoverLayout.rowHeight(for: medium)
        let bitmap = await PixelProbe.render(
            MenuBarConnectedMediumRow(medium: medium)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: width, height: height)
                .background(Color.white),
            size: CGSize(width: width, height: height),
            appearance: .aqua
        )
        return (bitmap, height)
    }

    /// Rechte Tintenkante des Prozentblocks (rechte 130 pt) und linke Tintenkante des Icons.
    private func edges(_ medium: Medium) async -> (right: CGFloat, iconLeft: CGFloat)? {
        let (bitmap, height) = await render(medium)
        let background = CGPoint(x: width - 1, y: 1)
        guard
            let right = PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: width - 130, y: 0, width: 130, height: height), background: background),
            let left = PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: 0, y: 0, width: 40, height: height), background: background)
        else { return nil }
        return (right.maxX, left.minX)
    }

    @Test func percentValuesEndAtTheSameRightEdgeAsTheRow() async throws {
        var rights: [CGFloat] = []
        var iconLeft: CGFloat = 0
        for progress in [0.05, 0.63, 0.99] {
            let measured = try #require(await edges(medium(progress: progress)), "keine Tinte bei \(progress)")
            rights.append(measured.right)
            iconLeft = measured.iconLeft
        }
        let first = try #require(rights.first)
        for right in rights {
            #expect(abs(right - first) <= 0.5, "rechte Kanten \(rights)")
        }
        // Abstand rechts = Abstand links (Icon zum Zeilenrand), ±1 pt wegen Glyphenrand.
        #expect(abs((width - first) - iconLeft) <= 1.5, "rechts \(width - first), links \(iconLeft)")
    }
}
}

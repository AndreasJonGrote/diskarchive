//
//  ColumnHorizontalScrollerTests.swift
//  diskindexTests
//
//  Aufgabe 187 / 192 c — waagerechte Scrollleiste über Statusleiste.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnHorizontalScrollerTests {
    @Test(arguments: [false, true])
    func horizontalScrollerSitsAboveFooter(forceLegacy: Bool) async throws {
        let bitmap = await ColumnChromeTests().scrolledColumnBitmap(forceLegacyScrollers: forceLegacy)
        let footerTop = try #require(footerDividerY(in: bitmap))
        try #require(footerDividerContinuous(at: footerTop, in: bitmap))
        if forceLegacy {
            let scrollerBottom = try #require(legacyHorizontalScrollerBottom(in: bitmap, footerTop: footerTop))
            #expect(scrollerBottom + 2 <= footerTop - 2)
        }
    }

    @Test func noBottomInsetWhenColumnsFitWithoutOverflow() async throws {
        let app = AppState()
        let mediumID = UUID()
        let medium = Medium(
            id: mediumID,
            name: "Fit",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 1,
            folderCount: 1,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.indexRepository.seedScreenshotCache(
            mediumID: mediumID,
            entries: [([], [
                IndexedItem(
                    id: IndexedItem.stableID(mediumID: mediumID, rowID: 1),
                    rowID: 1,
                    name: "A",
                    kind: .folder,
                    parentPath: [],
                    modifiedAt: Date(),
                    sizeBytes: 0,
                    lastSeenAt: Date(),
                    listedAt: Date()
                ),
            ])]
        )
        let size = CGSize(width: 1600, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        #expect(!horizontalScrollerIsVisible(in: session.window))
    }

    private func footerDividerY(in bitmap: NSBitmapImageRep) -> CGFloat? {
        let x = DesignSpacing.columnBrowserSidebarWidth + 40
        let h = bitmap.size.height
        var y = h - 4
        while y > h - 48 {
            let c = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
            if c.redComponent < 0.85 { return y }
            y -= 1
        }
        return nil
    }

    private func footerDividerContinuous(at y: CGFloat, in bitmap: NSBitmapImageRep) -> Bool {
        let divider = PixelProbe.color(in: bitmap, at: CGPoint(x: DesignSpacing.columnBrowserSidebarWidth + 80, y: y))
        let left = DesignSpacing.columnBrowserSidebarWidth + 20
        let right = bitmap.size.width - 20
        var x = left
        while x < right {
            let c = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
            if abs(c.redComponent - divider.redComponent) > 3.0 / 255
                || abs(c.greenComponent - divider.greenComponent) > 3.0 / 255
                || abs(c.blueComponent - divider.blueComponent) > 3.0 / 255 {
                return false
            }
            x += 6
        }
        return true
    }

    private func horizontalScrollerIsVisible(in window: NSWindow) -> Bool {
        guard let root = window.contentView else { return false }
        func walk(_ view: NSView) -> Bool {
            if let scroll = view as? NSScrollView {
                if scroll.hasHorizontalScroller,
                   let scroller = scroll.horizontalScroller,
                   !scroller.isHidden,
                   scroller.alphaValue > 0.01 {
                    return true
                }
            }
            for child in view.subviews where walk(child) { return true }
            return false
        }
        return walk(root)
    }

    private func legacyHorizontalScrollerBottom(in bitmap: NSBitmapImageRep, footerTop: CGFloat) -> CGFloat? {
        let left = DesignSpacing.columnBrowserSidebarWidth + 24
        let right = bitmap.size.width - 24
        var maxY: CGFloat?
        var y = min(footerTop - 4, bitmap.size.height - 6)
        while y > footerTop - 22 {
            var hits = 0
            var x = left
            while x < right {
                let c = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if c.redComponent < 0.72 { hits += 1 }
                x += 12
            }
            if hits >= 4 { maxY = max(maxY ?? y, y) }
            y -= 1
        }
        return maxY
    }
}
}

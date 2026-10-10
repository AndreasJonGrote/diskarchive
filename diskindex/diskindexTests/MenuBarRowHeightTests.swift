//
//  MenuBarRowHeightTests.swift
//  diskindexTests
//
//  Aufgabe 159: Popover-Zeile bleibt 56 pt, zweite Zeile und rechte Spalte teilen sich einen Platz.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct MenuBarRowHeightTests {
    @Test func popoverHeightAndSecondLineStayPut() async {
        let idle = await measure(indexing: false)
        let busy = await measure(indexing: true)
        #expect(abs(idle.height - busy.height) <= 0.5)
        #expect(abs(idle.nameTop - busy.nameTop) <= 0.5)
        #expect(abs(idle.secondMid - busy.secondMid) <= 1)
    }

    private func measure(indexing: Bool) async -> (height: CGFloat, nameTop: CGFloat, secondMid: CGFloat) {
        let state = AppState()
        state.media = [medium(indexing: indexing)]
        let view = ZStack(alignment: .top) {
            Color.red
            MenuBarPopoverView()
        }
        .environment(state)
        .frame(width: MenuBarPopoverLayout.panelWidth, height: 420, alignment: .top)
        let bitmap = await PixelProbe.render(view, size: CGSize(width: MenuBarPopoverLayout.panelWidth, height: 420))
        let height = popoverHeight(bitmap)
        let nameTop = firstInkRow(bitmap, from: 70, until: 280)
        let secondMid = bandMid(bitmap, from: nameTop + 14, until: nameTop + 36)
        return (height, nameTop, secondMid)
    }

    private func medium(indexing: Bool) -> Medium {
        var medium = Medium(
            id: UUID(uuidString: "D1590001-0000-4000-8000-000000000159")!,
            name: "Zeilenhalt",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: indexing ? .indexing : .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000_000_000,
            capacityUsedBytes: 400_000_000,
            fileCount: 12,
            folderCount: 2,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 0.4
        )
        medium.completedDepth = 1
        medium.scanTotal = 100
        return medium
    }

    private func popoverHeight(_ bitmap: NSBitmapImageRep) -> CGFloat {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        let outside = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 170, y: 410)))
        var last = 0
        var y = 0
        while y < bitmap.pixelsHigh {
            let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 170, y: CGFloat(y) / scale)))
            if !near(color, outside) { last = y }
            y += 1
        }
        return CGFloat(last + 1) / scale
    }

    private func firstInkRow(_ bitmap: NSBitmapImageRep, from: CGFloat, until: CGFloat) -> CGFloat {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        let ground = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 52, y: from + 2)))
        let start = Int(from * scale)
        let end = Int(until * scale)
        for y in start..<end {
            let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 52, y: CGFloat(y) / scale)))
            if !near(color, ground) { return CGFloat(y) / scale }
        }
        return from
    }

    private func bandMid(_ bitmap: NSBitmapImageRep, from: CGFloat, until: CGFloat) -> CGFloat {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        let ground = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 20, y: from)))
        let start = Int(from * scale)
        let end = min(bitmap.pixelsHigh, Int(until * scale))
        var top: Int?
        var bottom = start
        for y in start..<end {
            let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: 52, y: CGFloat(y) / scale)))
            if !near(color, ground) {
                if top == nil { top = y }
                bottom = y
            } else if top != nil {
                break
            }
        }
        let a = top ?? start
        return CGFloat(a + bottom) / 2 / scale
    }

    private func srgb(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.sRGB) ?? color
    }

    private func near(_ color: NSColor, _ other: NSColor) -> Bool {
        abs(color.redComponent - other.redComponent) < 0.08
            && abs(color.greenComponent - other.greenComponent) < 0.08
            && abs(color.blueComponent - other.blueComponent) < 0.08
    }
}
}

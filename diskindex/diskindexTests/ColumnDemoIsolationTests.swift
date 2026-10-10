//
//  ColumnDemoIsolationTests.swift
//  diskindexTests
//
//  Aufgabe 157 — Demo-Medium nur in der Spaltenansicht.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnDemoIsolationTests {
    @Test func demoStaysOutOfTheApp() async throws {
        ColumnStateSimulation.injectOverrideForTesting = true
        defer { ColumnStateSimulation.injectOverrideForTesting = false }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-demo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite"))
        let store = IndexStore(database: database)
        let real = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "Echt", type: .usb, decision: .index)
        try await store.upsertMedium(real)

        let app = AppState(store: store)
        await app.loadStoredMedia()
        let demoID = ColumnStateSimulation.mediumID

        #expect(!app.connectedMedia.contains { $0.id == demoID })
        #expect(!app.registryMedia.contains { $0.id == demoID })
        #expect(!app.indexedMedia.contains { $0.id == demoID })
        #expect(app.columnBrowserMedia.contains { $0.id == demoID })

        app.noteMenuBarIndexingSpinner(demoID, active: true)
        #expect(app.effectiveMenuBarBadge != .indexing)

        var storeErrors: [String] = []
        let previous = DiskIndexLog.shared.onTrackedError
        DiskIndexLog.shared.onTrackedError = { category, message in
            if category == "store" { storeErrors.append(message) }
            previous?(category, message)
        }
        app.forgetAllMedia()
        pump(0.4)
        DiskIndexLog.shared.onTrackedError = previous
        #expect(storeErrors.isEmpty)

        let demo = ColumnStateSimulation.makeMedium()
        #expect(MediumChip.presentation(demo).text == "42 % indiziert")
        let chip = await PixelProbe.render(
            StatusChip(medium: demo)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 140, height: 28),
            size: CGSize(width: 140, height: 28),
            appearance: .aqua
        )
        let label = await PixelProbe.render(
            Text(verbatim: "42 % indiziert")
                .font(.system(size: 10))
                .foregroundStyle(DesignColor.stateOnline)
                .frame(width: 120, height: 16, alignment: .leading)
                .background(Color.white),
            size: CGSize(width: 120, height: 16),
            appearance: .aqua
        )
        #expect(labelMatch(label, in: chip) >= 0.55)

        app.media = []
        _ = await PixelProbe.render(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 900, height: 500),
            size: CGSize(width: 900, height: 500),
            appearance: .aqua
        )
        let host = NSApp.windows.last {
            $0.contentView?.bounds.size == CGSize(width: 900, height: 500)
        }?.contentView
        #expect(sidebarCatchers(in: host) == 0)
        if let button = firstButton(in: host) {
            button.performClick(nil)
            button.performClick(nil)
        }
        #expect(app.detailMediumID == nil)
    }

    private func labelMatch(_ label: NSBitmapImageRep, in chip: NSBitmapImageRep) -> Double {
        let labelBg = PixelProbe.color(in: label, at: CGPoint(x: 110, y: 2))
        let chipBg = PixelProbe.color(in: chip, at: CGPoint(x: 70, y: 14))
        var points: [CGPoint] = []
        for y in 0..<16 {
            for x in 0..<120 {
                if !close(PixelProbe.color(in: label, at: CGPoint(x: x, y: y)), labelBg, tolerance: 0.08) {
                    points.append(CGPoint(x: x, y: y))
                }
            }
        }
        guard points.count > 8 else { return 0 }
        let originX = points.map(\.x).min() ?? 0
        let originY = points.map(\.y).min() ?? 0
        let shifted = points.map { CGPoint(x: $0.x - originX, y: $0.y - originY) }
        var best = 0
        for y in 0..<28 {
            for x in 0..<140 {
                var hits = 0
                for point in shifted {
                    let color = PixelProbe.color(in: chip, at: CGPoint(x: x + Int(point.x), y: y + Int(point.y)))
                    if !close(color, chipBg, tolerance: 0.08) { hits += 1 }
                }
                best = max(best, hits)
            }
        }
        return Double(best) / Double(shifted.count)
    }

    private func pump(_ seconds: TimeInterval) {
        let until = Date().addingTimeInterval(seconds)
        while Date() < until {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func close(_ color: NSColor?, _ ink: NSColor, tolerance: CGFloat) -> Bool {
        guard let color else { return false }
        let sample = color.usingColorSpace(.sRGB) ?? color
        let target = ink.usingColorSpace(.sRGB) ?? ink
        return abs(sample.redComponent - target.redComponent) < tolerance
            && abs(sample.greenComponent - target.greenComponent) < tolerance
            && abs(sample.blueComponent - target.blueComponent) < tolerance
    }

    private func sidebarCatchers(in view: NSView?) -> Int {
        guard let view else { return 0 }
        var count = 0
        if String(describing: type(of: view)).contains("Catcher") {
            let frame = view.convert(view.bounds, to: nil)
            if frame.midX < DesignSpacing.columnBrowserSidebarWidth { count += 1 }
        }
        for subview in view.subviews {
            count += sidebarCatchers(in: subview)
        }
        return count
    }

    private func firstButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let button = firstButton(in: subview) { return button }
        }
        return nil
    }
}
}

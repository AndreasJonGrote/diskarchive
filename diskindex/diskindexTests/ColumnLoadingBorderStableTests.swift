//
//  ColumnLoadingBorderStableTests.swift
//  diskindexTests
//
//  Aufgabe 156 — Spaltenrand bleibt, solange der Ladehinweis noch nicht sichtbar ist.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnLoadingBorderStableTests {
    @Test func shortLoadKeepsTheColumnBorder() async {
        let samples = await sampleBorder(loadSeconds: 0.45, observeSeconds: 0.7)
        #expect(samples.allSatisfy { $0.border })
        let xs = Set(samples.map { Int($0.edge.rounded()) })
        #expect(xs.count == 1)
    }

    @Test func longLoadSwitchesToStatusFillOnce() async {
        let samples = await sampleBorder(loadSeconds: 2.0, observeSeconds: 2.4)
        let drops = transitions(samples, toBorder: false)
        let returns = transitions(samples, toBorder: true)
        #expect(drops.count == 1)
        #expect(returns.count == 1)
        // Messjitter: Übergang knapp unter 1.0 s trotzdem nach der Ladehinweis-Schwelle.
        #expect((drops.first ?? 0) >= 0.99)
    }

    private struct Sample {
        var time: Double
        var border: Bool
        var edge: CGFloat
        var hint: Bool
        var loading: Bool
    }

    private func sampleBorder(loadSeconds: Double, observeSeconds: Double) async -> [Sample] {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID,
            name: "Groß",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 10,
            fileCount: 20_000,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 1
        )
        medium.completedDepth = 2
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        app.indexRepository.setLoadingForUITest(mediumID: mediumID, path: [], loading: true, total: 20_000)
        let host = NSHostingView(
            rootView: ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 1280, height: 800)
        )
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = host.appearance
        let previous = NSApp.appearance
        NSApp.appearance = host.appearance
        window.contentView = host
        window.orderFrontRegardless()
        let start = Date()
        var samples: [Sample] = []
        var stopped = false
        while Date().timeIntervalSince(start) < observeSeconds {
            let elapsed = Date().timeIntervalSince(start)
            if !stopped, elapsed >= loadSeconds {
                app.indexRepository.setLoadingForUITest(mediumID: mediumID, path: [], loading: false)
                stopped = true
            } else if !stopped {
                app.indexRepository.setLoadingForUITest(
                    mediumID: mediumID,
                    path: [],
                    loading: true,
                    total: 20_000,
                    loaded: Int(elapsed * 1_000)
                )
            }
            host.layoutSubtreeIfNeeded()
            window.display()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                let edge = borderEdge(in: rep)
                let hint = app.columnBrowserState.loadingHintVisible(mediumID: mediumID, path: [])
                let loading = app.indexRepository.isLoading(mediumID: mediumID, path: [])
                samples.append(Sample(time: elapsed, border: edge != nil, edge: edge ?? -1, hint: hint, loading: loading))
            }
            pump()
        }
        window.orderOut(nil)
        NSApp.appearance = previous
        return samples
    }

    /// Senkrechte Trennlinie rechts der ersten Ordnerspalte, sonst nil (Statusfläche).
    private func borderEdge(in bitmap: NSBitmapImageRep) -> CGFloat? {
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        let y: CGFloat = 240
        let probe = PixelProbe.color(in: bitmap, at: CGPoint(x: sidebar + 40, y: y))
        var x = sidebar + width - 8
        while x < sidebar + width + 4 {
            let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
            if !same(color, probe) {
                return x
            }
            x += 1
        }
        return nil
    }

    private func pump() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.016))
    }

    private func transitions(_ samples: [Sample], toBorder: Bool) -> [Double] {
        var times: [Double] = []
        for index in samples.indices.dropFirst() where samples[index].border == toBorder && samples[index - 1].border != toBorder {
            times.append(samples[index].time)
        }
        return times
    }

    private func same(_ a: NSColor, _ b: NSColor) -> Bool {
        abs(a.redComponent - b.redComponent) <= 0.08
            && abs(a.greenComponent - b.greenComponent) <= 0.08
            && abs(a.blueComponent - b.blueComponent) <= 0.08
    }
}
}

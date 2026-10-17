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
        // bug.0.3.8.007: Beobachtungsende relativ zum Ladeende statt fest 0,7 s nach Start.
        let samples = await sampleBorder(loadSeconds: 0.45, settleSeconds: 0.25)
        // Das Ladeende muss beobachtet worden sein, sonst sagt die Stabilität nichts.
        #expect(samples.contains { !$0.loading })
        #expect(samples.allSatisfy { $0.border })
        let xs = Set(samples.map { Int($0.edge.rounded()) })
        #expect(xs.count == 1)
    }

    @Test func longLoadSwitchesToStatusFillOnce() async {
        // bug.0.3.8.007: Beobachtungsende relativ zum Ladeende statt fest 2,4 s nach Start.
        let samples = await sampleBorder(loadSeconds: 2.0, settleSeconds: 0.4)
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

    /// Tastet ab Start ab; nach dem Ladeende (`loadSeconds`) noch mindestens `settleSeconds`,
    /// und bis der Rand wieder steht (höchstens `maxAfterStop`).
    private func sampleBorder(loadSeconds: Double, settleSeconds: Double, maxAfterStop: Double = 5) async -> [Sample] {
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
        // bug.0.3.8.007: Ende hängt am tatsächlichen Ladeende, nicht an einer festen Uhrzeit —
        // ein Hänger des Schedulers verschiebt sonst das Ladeende hinter das Beobachtungsende.
        var stoppedAt: Double?
        while true {
            let elapsed = Date().timeIntervalSince(start)
            if let stoppedAt {
                let since = elapsed - stoppedAt
                if since >= maxAfterStop { break }
                if since >= settleSeconds, let last = samples.last, last.border, !last.loading { break }
            }
            let stopped = stoppedAt != nil
            if !stopped, elapsed >= loadSeconds {
                app.indexRepository.setLoadingForUITest(mediumID: mediumID, path: [], loading: false)
                stoppedAt = elapsed
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
        // bug.0.3.8.007: Paare statt Indexzugriff (Regel 20).
        zip(samples, samples.dropFirst())
            .filter { previous, current in current.border == toBorder && previous.border != toBorder }
            .map { _, current in current.time }
    }

    private func same(_ a: NSColor, _ b: NSColor) -> Bool {
        abs(a.redComponent - b.redComponent) <= 0.08
            && abs(a.greenComponent - b.greenComponent) <= 0.08
            && abs(a.blueComponent - b.blueComponent) <= 0.08
    }
}
}

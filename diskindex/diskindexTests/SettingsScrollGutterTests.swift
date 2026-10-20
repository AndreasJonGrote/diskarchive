//
//  SettingsScrollGutterTests.swift
//  diskindexTests
//
//  bug.0.4.091: Platz für den senkrechten Rollbalken ist immer reserviert (`stableScrollbarGutter`). Echtes Fenster
//  außerhalb des Bildschirms (Regel 19). Dauerhafter Stil (wie mit angeschlossener Maus): alle Einstellungs-Tabs haben
//  dieselbe Inhaltsbreite, direkt nach dem Wechsel und nach dem Layout, ob sie überlaufen oder nicht. Overlay: kein
//  Abstand.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct SettingsScrollGutterTests {
    private let size = CGSize(width: 900, height: 700)
    private let tabs: [SettingsTab] = [.general, .files, .storageMedia, .advanced, .general]

    @Test func legacyStyleKeepsTheSameContentWidthInAllTabs() async throws {
        let widths = try await measure(style: .legacy)
        let gutter = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        try #require(gutter > 0)
        let all = widths.flatMap { [$0.early, $0.settled] }
        let first = try #require(all.first)
        #expect(all.allSatisfy { abs($0 - first) <= 0.5 }, "Inhaltsbreiten: \(widths)")
        #expect(widths.allSatisfy { abs($0.scrollWidth - $0.settled - gutter) <= 0.5 }, "kein Platz reserviert: \(widths)")
        #expect(widths.contains { $0.overflows } && widths.contains { !$0.overflows }, "Vergleich braucht Tabs mit und ohne Überlauf: \(widths)")
    }

    /// bug.0.4.100 c (Nutzer 20.10.): Im dauerhaften Stil ohne Überlauf keine leere Leiste, nur freier Platz; mit
    /// Überlauf erscheint die Leiste in diesem Platz (Inhaltsbreite gleich: `legacyStyleKeepsTheSameContentWidthInAllTabs`).
    @Test func legacyStyleShowsNoEmptyBar() async throws {
        let widths = try await measure(style: .legacy)
        try #require(widths.contains { $0.overflows } && widths.contains { !$0.overflows }, "\(widths)")
        #expect(widths.allSatisfy { $0.barVisible == $0.overflows }, "Leiste sichtbar ohne Überlauf bzw. fehlt mit: \(widths)")
    }

    /// bug.0.4.100 b: Die Abschnittstitel stehen in allen Tabs an derselben x-Position (dauerhafter Stil).
    @Test func sectionTitlesShareTheSameXInAllTabs() async throws {
        // „Speichermedien“ hat seinen Titel über der Liste, außerhalb der Scrollansicht: hier nicht vergleichbar.
        let widths = try await measure(style: .legacy).filter { $0.tab != .storageMedia }
        let lefts = widths.compactMap(\.inkLeft)
        try #require(lefts.count == widths.count, "Titel nicht gefunden: \(widths)")
        let first = try #require(lefts.first)
        #expect(lefts.allSatisfy { abs($0 - first) <= 0.5 }, "x-Positionen: \(widths)")
    }

    /// bug.0.4.100 b: Wechsel des Stils zur Laufzeit gilt sofort (Platz dauerhaft ↔ Overlay 0), ohne neues Fenster.
    @Test func styleChangeAtRuntimeAppliesAtOnce() async throws {
        let box = ScrollerStyleBox()
        box.style = .legacy
        let app = AppState()
        app.settingsTab = .advanced
        let session = PixelProbe.open(
            ScrollerStyleHost(box: box) { SettingsView().environment(app) }
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let gutter = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        let legacy = try #require(Self.tabScroll(in: session.window))
        #expect(abs(legacy.frame.width - legacy.contentView.bounds.width - gutter) <= 0.5, "dauerhaft: \(legacy.contentView.bounds.width) von \(legacy.frame.width)")
        box.style = .overlay
        let overlay = await waitUntil(timeout: 5) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = Self.tabScroll(in: session.window) else { return false }
            return abs(scroll.frame.width - scroll.contentView.bounds.width) <= 0.5
        }
        #expect(overlay, "Overlay nach Wechsel reserviert noch Platz")
        box.style = .legacy
        let back = await waitUntil(timeout: 5) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            guard let scroll = Self.tabScroll(in: session.window) else { return false }
            return abs(scroll.frame.width - scroll.contentView.bounds.width - gutter) <= 0.5
        }
        #expect(back, "dauerhaft nach Rückwechsel ohne Platz")
    }

    @Test func overlayStyleReservesNothing() async throws {
        let widths = try await measure(style: .overlay)
        #expect(widths.allSatisfy { abs($0.scrollWidth - $0.settled) <= 0.5 && abs($0.early - $0.settled) <= 0.5 }, "Overlay: \(widths)")
    }

    struct Measurement: CustomStringConvertible {
        var tab: SettingsTab
        var early: CGFloat
        var settled: CGFloat
        var scrollWidth: CGFloat
        var overflows: Bool
        var barVisible = false
        var inkLeft: CGFloat?
        var description: String {
            "\(tab): \(early)/\(settled) von \(scrollWidth)\(overflows ? " Überlauf" : "")\(barVisible ? " Leiste" : "") x=\(inkLeft.map { String(Double($0)) } ?? "–")"
        }
    }

    private func measure(style: NSScroller.Style) async throws -> [Measurement] {
        let app = AppState()
        // Ein Medium, damit „Speichermedien“ seine Liste (Kopf außerhalb, Zeilen in der Scrollansicht) zeigt.
        app.media = [Medium(
            id: UUID(), name: "Liste", type: .usb, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 10,
            fileCount: 1, folderCount: 1, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )]
        let session = PixelProbe.open(
            SettingsView().environment(app).environment(\.scrollerStyleOverride, style)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        var result: [Measurement] = []
        for tab in tabs {
            app.settingsTab = tab
            // Erster Durchgang nach dem Wechsel: ein Durchlauf der Runloop und ein Layout, noch ohne Warten.
            Self.turnRunLoopOnce()
            session.window.contentView?.layoutSubtreeIfNeeded()
            let early = try #require(Self.tabScroll(in: session.window), "Scrollansicht für \(tab) fehlt: \(Self.allScrollFrames(in: session.window))")
            let earlyWidth = early.contentView.bounds.width
            try await Task.sleep(for: .milliseconds(300))
            session.window.contentView?.layoutSubtreeIfNeeded()
            let scroll = try #require(Self.tabScroll(in: session.window))
            let documentHeight = scroll.documentView?.frame.height ?? 0
            result.append(Measurement(
                tab: tab,
                early: earlyWidth,
                settled: scroll.contentView.bounds.width,
                scrollWidth: scroll.frame.width,
                overflows: documentHeight > scroll.contentView.bounds.height + 1,
                barVisible: Self.barVisible(scroll),
                inkLeft: Self.firstInkLeft(of: scroll, in: session)
            ))
        }
        return result
    }

    /// Linker Rand der ersten Tinte oben in der Scrollansicht (Abschnittstitel), in Fensterpunkten.
    static func firstInkLeft(of scroll: NSScrollView, in session: PixelProbe.Session) -> CGFloat? {
        let frame = scroll.convert(scroll.bounds, to: nil)
        let height = session.window.contentView?.bounds.height ?? 0
        let top = height - frame.maxY
        let rect = CGRect(x: frame.minX, y: top, width: frame.width - 20, height: min(60, frame.height))
        return PixelProbe.inkBounds(
            in: session.bitmap(), rect: rect, background: CGPoint(x: frame.maxX - 30, y: top + 2)
        )?.minX
    }

    /// Senkrechte Leiste sichtbar (nicht versteckt, nicht durchsichtig).
    static func barVisible(_ scroll: NSScrollView) -> Bool {
        guard scroll.hasVerticalScroller, let bar = scroll.verticalScroller else { return false }
        return !bar.isHidden && bar.alphaValue > 0.01 && bar.frame.width > 0
    }

    /// Ein Durchlauf der Runloop (synchron, nicht im async-Kontext aufrufbar wie `CFRunLoopRunInMode`).
    static func turnRunLoopOnce() {
        CFRunLoopRunInMode(.defaultMode, 0.01, true)
    }

    static func allScrollFrames(in window: NSWindow) -> [CGRect] {
        guard let root = window.contentView else { return [] }
        var frames: [CGRect] = []
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView { frames.append(scroll.convert(scroll.bounds, to: nil)) }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return frames
    }

    /// Größte senkrechte Scrollansicht rechts der Tab-Leiste (170 pt).
    static func tabScroll(in window: NSWindow) -> NSScrollView? {
        guard let root = window.contentView else { return nil }
        var best: NSScrollView?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let frame = scroll.convert(scroll.bounds, to: nil)
                if frame.minX >= 160, frame.height > 200, frame.width * frame.height > (best.map { $0.frame.width * $0.frame.height } ?? 0) {
                    best = scroll
                }
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return best
    }
}
}

/// bug.0.4.100 b: Stil zur Laufzeit wechseln (Umgebung, kein prozessweiter Schalter).
@MainActor
@Observable
private final class ScrollerStyleBox {
    var style: NSScroller.Style?
}

private struct ScrollerStyleHost<Content: View>: View {
    let box: ScrollerStyleBox
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().environment(\.scrollerStyleOverride, box.style)
    }
}

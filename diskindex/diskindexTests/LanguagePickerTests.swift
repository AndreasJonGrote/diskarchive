//
//  LanguagePickerTests.swift
//  diskindexTests
//
//  Aufgabe 165: Sprachknopf 160 × 24,4, Feld 4 pt darunter, Klick auf English.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct LanguagePickerTests {
    @Test func buttonOpensPanelAndSelectsEnglish() {
        let box = LanguageBox()
        let session = PixelProbe.open(
            SettingsLanguagePicker(
                selection: Binding(get: { box.language }, set: { box.language = $0 }),
                isOpen: Binding(get: { box.open }, set: { box.open = $0 })
            )
                .frame(width: 360, height: 220, alignment: .topLeading)
                .background(Color.red),
            size: CGSize(width: 360, height: 220),
            appearance: .aqua
        )
        defer { session.close() }
        let closed = session.bitmap()
        let button = controlBounds(closed)
        #expect(abs(button.width - 160) <= 0.5, "Breite \(button.width)")
        #expect(abs(button.height - 24.4) <= 0.5, "Höhe \(button.height)")
        let caret = darkestInRightEdge(closed, button: button)
        #expect(caret < 0.5, "Pfeil \(caret)")
        session.click(at: CGPoint(x: button.midX, y: button.midY))
        let opened = session.bitmap()
        let panelTop = panelTopEdge(opened, button: button)
        #expect(abs(panelTop - (button.maxY + 4)) <= 1, "Feld \(panelTop)")
        session.click(at: CGPoint(x: button.minX + 40, y: panelTop + 36))
        #expect(box.language == .english)
        let after = session.bitmap()
        #expect(panelTopEdge(after, button: button) < 0)
    }

    @Test func openPanelCoversFollowingSections() {
        let app = AppState()
        let size = CGSize(width: 860, height: 600)
        let session = PixelProbe.open(
            SettingsGeneralTab(section: .general)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(Color.white),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        let closed = session.bitmap()
        guard let button = pickerButton(in: session.window) else {
            Issue.record("Sprachknopf nicht gefunden")
            return
        }
        let background = PixelProbe.color(in: closed, at: CGPoint(x: button.maxX + 30, y: button.midY))
        let x = button.maxX - 20
        // Feld: 4 pt Abstand, 4 pt Innenrand, je Sprache eine Zeile von 24 pt.
        let panelBottom = button.maxY + 4 + 8 + CGFloat(AppDisplayLanguage.allCases.count) * 24
        guard let divider = firstInk(closed, x: x, from: button.maxY + 2, to: panelBottom - 4, background: background) else {
            Issue.record("Trennlinie unter dem Feld nicht gefunden")
            return
        }
        let dividerColor = PixelProbe.color(in: closed, at: CGPoint(x: x, y: divider))
        let start = Date()
        session.click(at: CGPoint(x: button.midX, y: button.midY), settle: 0)
        var elapsed = TimeInterval.infinity
        while Date().timeIntervalSince(start) < BenchGate.paintDeadline {
            if !near(session.color(at: CGPoint(x: x, y: divider)), dividerColor, tolerance: 3.0 / 255) {
                elapsed = Date().timeIntervalSince(start)
                break
            }
            CFRunLoopRunInMode(.defaultMode, 0.001, true)
        }
        #expect(elapsed.isFinite, "Feld wurde nicht gezeichnet")
        if BenchGate.enabled { #expect(elapsed <= 0.25, "Feld nach \(Int(elapsed * 1000)) ms") }
        let opened = session.bitmap()
        let atDivider = PixelProbe.color(in: opened, at: CGPoint(x: x, y: divider))
        let panelFill = PixelProbe.color(in: opened, at: CGPoint(x: button.maxX - 12, y: button.maxY + 4 + 12))
        #expect(!near(atDivider, dividerColor, tolerance: 3.0 / 255), "Trennlinie liegt über dem Feld")
        #expect(near(atDivider, panelFill, tolerance: 3.0 / 255), "Feldfarbe an der Trennlinie")
    }

    /// Aufgabe 172 e: Feld im nächsten Bild, keine Fokusmarkierung an Knopf und Feld.
    @Test func panelOpensWithinOneFrameWithoutFocusRing() {
        let app = AppState()
        let size = CGSize(width: 860, height: 600)
        let session = PixelProbe.open(
            SettingsGeneralTab(section: .general)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(Color.white),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        guard let button = pickerButton(in: session.window) else {
            Issue.record("Sprachknopf nicht gefunden")
            return
        }
        // Rechter Rand des Feldes, zweite Zeile: vorher weiße Seite, offen Feldfarbe/Rahmen.
        let probe = CGPoint(x: button.maxX - 12, y: button.maxY + 4 + 36)
        let before = session.color(at: probe)
        // Erster Klick im frischen Fenster richtet die Ereignisverarbeitung ein; auf leerer Fläche, misst nicht das Feld.
        session.click(at: CGPoint(x: 20, y: size.height - 20))
        var samples: [TimeInterval] = []
        var clickTimes: [TimeInterval] = []
        for _ in 0..<3 {
            let start = Date()
            session.click(at: CGPoint(x: button.midX, y: button.midY), settle: 0)
            clickTimes.append(Date().timeIntervalSince(start))
            var elapsed = TimeInterval.infinity
            while Date().timeIntervalSince(start) < 0.5 {
                if !near(session.color(at: probe), before, tolerance: 3.0 / 255) {
                    elapsed = Date().timeIntervalSince(start)
                    break
                }
                CFRunLoopRunInMode(.defaultMode, 0.001, true)
            }
            samples.append(elapsed)
            let opened = session.bitmap()
            #expect(accentPixels(opened, in: CGRect(x: button.minX - 4, y: button.minY - 4, width: button.width + 8, height: 100)) == 0,
                    "Fokusfarbe an Knopf oder Feld")
            session.click(at: CGPoint(x: button.midX, y: button.midY))
            let closed = session.bitmap()
            #expect(accentPixels(closed, in: button.insetBy(dx: -4, dy: -4)) == 0, "Markierung am Knopf nach dem Schließen")
        }
        print("LANGTIME ms \(samples.map { Int($0 * 1000) }) click \(clickTimes.map { Int($0 * 1000) })")
        // Erstes Öffnen nur protokolliert (Debug-Build, schwankt mit der Last); jedes weitere im nächsten Bild.
        #expect((samples.dropFirst().max() ?? .infinity) <= 0.017, "Öffnen nach \(samples.map { Int($0 * 1000) }) ms")
    }

    private func accentPixels(_ bitmap: NSBitmapImageRep, in rect: CGRect) -> Int {
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        let blue = NSColor.systemBlue.usingColorSpace(.sRGB) ?? .blue
        var count = 0
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let c = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if near(c, accent, tolerance: 0.12) || near(c, blue, tolerance: 0.12) { count += 1 }
                x += 1
            }
            y += 1
        }
        return count
    }

    private func pickerButton(in window: NSWindow) -> CGRect? {
        guard let root = window.contentView else { return nil }
        let height = root.bounds.height
        func walk(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(walk) }
        return walk(root).compactMap { view -> CGRect? in
            let frame = view.convert(view.bounds, to: nil)
            guard abs(frame.width - 160) <= 1, abs(frame.height - 24.4) <= 1 else { return nil }
            return CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
        }.first
    }

    private func firstInk(_ bitmap: NSBitmapImageRep, x: CGFloat, from: CGFloat, to: CGFloat, background: NSColor) -> CGFloat? {
        var y = from
        while y < to {
            if !near(PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)), background, tolerance: 0.03) { return y }
            y += 0.5
        }
        return nil
    }

    private func near(_ a: NSColor, _ b: NSColor, tolerance: CGFloat) -> Bool {
        abs(a.redComponent - b.redComponent) <= tolerance
            && abs(a.greenComponent - b.greenComponent) <= tolerance
            && abs(a.blueComponent - b.blueComponent) <= tolerance
    }

    private func controlBounds(_ bitmap: NSBitmapImageRep) -> CGRect {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = 0
        var maxY = 0
        var y = 0
        while y < Int(40 * scale) {
            var x = 0
            while x < Int(200 * scale) {
                let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: CGFloat(x) / scale, y: CGFloat(y) / scale)))
                if color.redComponent < 0.85 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
                x += 1
            }
            y += 1
        }
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

    private func darkestInRightEdge(_ bitmap: NSBitmapImageRep, button: CGRect) -> CGFloat {
        var darkest: CGFloat = 1
        var y = button.minY + 2
        while y < button.maxY - 2 {
            var x = button.maxX - 24
            while x < button.maxX - 2 {
                let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)))
                darkest = min(darkest, color.redComponent)
                x += 0.5
            }
            y += 0.5
        }
        return darkest
    }

    /// Oberkante des Feldes, oder -1 wenn zu.
    private func panelTopEdge(_ bitmap: NSBitmapImageRep, button: CGRect) -> CGFloat {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        var y = button.maxY + 1
        while y < button.maxY + 40 {
            let color = srgb(PixelProbe.color(in: bitmap, at: CGPoint(x: button.minX + 8, y: y)))
            if color.redComponent < 0.85 { return y }
            y += 1 / scale
        }
        return -1
    }

    private func srgb(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.sRGB) ?? color
    }
}
}

@Observable
private final class LanguageBox {
    var language = AppDisplayLanguage.german
    var open = false
}

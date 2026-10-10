//
//  PixelProbe.swift
//  diskindexTests
//
//  Aufgabe 150 (a) — Pixel aus einem echten Fenster.
//

import AppKit
import SwiftUI

private final class ProbePanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
enum PixelProbe {
    private static let offscreenOrigin = CGPoint(x: -20_000, y: -20_000)
    private static var probeWindowSlot = 0

    /// Vor UI-Tests mit Mausklick: alte Fenster aus vorherigen Suites schließen.
    static func dismissStrayWindows() {
        NSApp.appearance = NSAppearance(named: .aqua)
        for window in NSApp.windows {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        probeWindowSlot = 0
    }

    private static func nextOffscreenOrigin(size: CGSize) -> CGPoint {
        if probeWindowSlot > 48 { probeWindowSlot = 0 }
        let slot = probeWindowSlot
        probeWindowSlot += 1
        return CGPoint(
            x: offscreenOrigin.x - CGFloat(slot % 8) * (size.width + 48),
            y: offscreenOrigin.y - CGFloat(slot / 8) * (size.height + 48)
        )
    }

    /// Rendert eine SwiftUI-Ansicht in einem echten Fenster (außerhalb des Bildschirms) und liefert die Bitmap.
    static func render<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name = .aqua) async -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view)
        let look = NSAppearance(named: appearance)
        host.appearance = look
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: nextOffscreenOrigin(size: size), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = look
        window.contentView = host
        let previousAppAppearance = NSApp.appearance
        NSApp.appearance = look
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(300))
        host.layoutSubtreeIfNeeded()
        window.display()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)
            ?? NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        window.orderOut(nil)
        window.close()
        NSApp.appearance = previousAppAppearance
        return rep
    }

    /// Fenster bleibt offen, damit ein echter Mausklick die Ansicht umschaltet.
    @MainActor
    final class Session {
        let window: NSWindow
        private let previousAppAppearance: NSAppearance?
        private var didClose = false

        fileprivate init(window: NSWindow, previousAppAppearance: NSAppearance?) {
            self.window = window
            self.previousAppAppearance = previousAppAppearance
        }

        func bitmap() -> NSBitmapImageRep {
            let look = window.appearance
            window.contentView?.appearance = look
            guard let host = window.contentView else {
                return NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            }
            host.layoutSubtreeIfNeeded()
            window.display()
            let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)
                ?? NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            host.cacheDisplay(in: host.bounds, to: rep)
            return rep
        }

        /// Farbe (sRGB) eines einzelnen Punkts, frisch gezeichnet; billig genug für Zeitmessungen.
        func color(at point: CGPoint) -> NSColor {
            guard let host = window.contentView else { return .clear }
            host.layoutSubtreeIfNeeded()
            let y = host.isFlipped ? point.y : host.bounds.height - point.y - 1
            let rect = NSRect(x: point.x.rounded(.down), y: y.rounded(.down), width: 1, height: 1)
            guard let rep = host.bitmapImageRepForCachingDisplay(in: rect) else { return .clear }
            host.cacheDisplay(in: rect, to: rep)
            guard let sample = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else { return .clear }
            return NSColor(srgbRed: sample.redComponent, green: sample.greenComponent, blue: sample.blueComponent, alpha: 1)
        }

        /// Mausklick in Fensterkoordinaten (AppKit, Ursprung unten links).
        func clickInWindow(at locationInWindow: NSPoint, clickCount: Int = 1, settle: TimeInterval = 0.05) {
            window.orderFrontRegardless()
            for index in 0..<clickCount {
                let count = index + 1
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    guard let event = NSEvent.mouseEvent(
                        with: type,
                        location: locationInWindow,
                        modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber,
                        context: nil,
                        eventNumber: count,
                        clickCount: count,
                        pressure: 1
                    ) else { continue }
                    window.sendEvent(event)
                }
            }
            let deadline = Date().addingTimeInterval(settle)
            while Date() < deadline {
                CFRunLoopRunInMode(.defaultMode, 0.01, true)
            }
        }

        /// Klick mit Hit-Test — trifft SwiftUI-`Button` in verschachtelten `NSHostingView`s.
        func clickThroughHitTest(at point: CGPoint, settle: TimeInterval = 0.05) {
            guard let view = window.contentView else { return }
            window.orderFrontRegardless()
            let local = NSPoint(
                x: point.x,
                y: view.isFlipped ? point.y : view.bounds.height - point.y
            )
            if let hit = view.hitTest(local) {
                let inWindow = view.convert(local, to: nil)
                guard
                    let down = NSEvent.mouseEvent(
                        with: .leftMouseDown,
                        location: inWindow,
                        modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber,
                        context: nil,
                        eventNumber: 1,
                        clickCount: 1,
                        pressure: 1
                    ),
                    let up = NSEvent.mouseEvent(
                        with: .leftMouseUp,
                        location: inWindow,
                        modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber,
                        context: nil,
                        eventNumber: 1,
                        clickCount: 1,
                        pressure: 1
                    )
                else { return }
                hit.mouseDown(with: down)
                hit.mouseUp(with: up)
            } else {
                click(at: point, settle: 0)
            }
            let deadline = Date().addingTimeInterval(settle)
            while Date() < deadline {
                CFRunLoopRunInMode(.defaultMode, 0.01, true)
            }
        }

        /// `point` in pt, Ursprung oben links im Inhalt.
        func click(at point: CGPoint, clickCount: Int = 1, settle: TimeInterval = 0.05) {
            guard let view = window.contentView else { return }
            window.orderFrontRegardless()
            let local = NSPoint(
                x: point.x,
                y: view.isFlipped ? point.y : view.bounds.height - point.y
            )
            let inWindow = view.convert(local, to: nil)
            for index in 0..<clickCount {
                let count = index + 1
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    guard let event = NSEvent.mouseEvent(
                        with: type,
                        location: inWindow,
                        modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber,
                        context: nil,
                        eventNumber: count,
                        clickCount: count,
                        pressure: 1
                    ) else { continue }
                    window.sendEvent(event)
                }
            }
            let deadline = Date().addingTimeInterval(settle)
            while Date() < deadline {
                CFRunLoopRunInMode(.defaultMode, 0.01, true)
            }
        }

        /// Echte Mausbewegung an `point` (pt, oben links).
        func move(to point: CGPoint) {
            guard let view = window.contentView else { return }
            window.acceptsMouseMovedEvents = true
            let local = NSPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
            let inWindow = view.convert(local, to: nil)
            if let event = NSEvent.mouseEvent(
                with: .mouseMoved,
                location: inWindow,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            ) {
                window.sendEvent(event)
            }
            let deadline = Date().addingTimeInterval(0.1)
            while Date() < deadline {
                CFRunLoopRunInMode(.defaultMode, 0.01, true)
            }
        }

        func close() {
            guard !didClose else { return }
            didClose = true
            window.orderOut(nil)
            window.contentView = nil
            window.close()
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                NSApp.appearance = NSAppearance(named: .aqua)
            } else {
                NSApp.appearance = previousAppAppearance
            }
        }
    }

    static func open<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name = .aqua) -> Session {
        let look = NSAppearance(named: appearance)
        let previous = NSApp.appearance
        NSApp.appearance = look
        let host = NSHostingView(rootView: view)
        host.appearance = look
        host.frame = NSRect(origin: .zero, size: size)
        let window = ProbePanel(
            contentRect: NSRect(origin: nextOffscreenOrigin(size: size), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = look
        window.contentView = host
        window.orderFrontRegardless()
        window.appearance = look
        host.appearance = look
        host.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()
        window.display()
        return Session(window: window, previousAppAppearance: previous)
    }

    /// Kurz warten, bis ein offenes Fenster Layout abgeschlossen hat (ohne Runloop in async-Kontext).
    static func settleOpenWindow(_ session: Session) async {
        try? await Task.sleep(for: .milliseconds(300))
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
    }

    /// Kleinster Rahmen (in pt, Ursprung oben links) aller Pixel in `rect`, die sich vom Hintergrund
    /// (Farbe am Punkt `background`) um mehr als `tolerance` (0…1, je Kanal) unterscheiden.
    static func inkBounds(in bitmap: NSBitmapImageRep, rect: CGRect, background: CGPoint, tolerance: CGFloat = 0.08) -> CGRect? {
        let bg = color(in: bitmap, at: background)
        let scale = pixelScale(bitmap)
        let px0 = Int((rect.minX * scale).rounded(.down))
        let px1 = Int((rect.maxX * scale).rounded(.up))
        let py0 = Int((rect.minY * scale).rounded(.down))
        let py1 = Int((rect.maxY * scale).rounded(.up))
        guard let rowRange = pixelRowRange(py0..<py1, within: bitmap.pixelsHigh),
              let colRange = pixelRowRange(px0..<px1, within: bitmap.pixelsWide)
        else { return nil }
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        var found = false
        for py in rowRange {
            for px in colRange {
                guard let sample = bitmap.colorAt(x: px, y: py)?.usingColorSpace(.sRGB) else { continue }
                if abs(sample.redComponent - bg.redComponent) > tolerance
                    || abs(sample.greenComponent - bg.greenComponent) > tolerance
                    || abs(sample.blueComponent - bg.blueComponent) > tolerance {
                    found = true
                    minX = min(minX, px)
                    minY = min(minY, py)
                    maxX = max(maxX, px)
                    maxY = max(maxY, py)
                }
            }
        }
        guard found else { return nil }
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

    /// Farbe (sRGB) an einem Punkt in pt (Ursprung oben links).
    static func color(in bitmap: NSBitmapImageRep, at point: CGPoint) -> NSColor {
        let scale = pixelScale(bitmap)
        let px = min(bitmap.pixelsWide - 1, max(0, Int((point.x * scale).rounded(.down))))
        let py = min(bitmap.pixelsHigh - 1, max(0, Int((point.y * scale).rounded(.down))))
        guard let sample = bitmap.colorAt(x: px, y: py)?.usingColorSpace(.sRGB) else { return .clear }
        return NSColor(srgbRed: sample.redComponent, green: sample.greenComponent, blue: sample.blueComponent, alpha: 1)
    }

    /// Schnitt aus gewünschtem Pixelbereich und Bitmap; `nil` wenn nichts zu scannen (kein leerer `Range`).
    private static func pixelRowRange(_ desired: Range<Int>, within limit: Int) -> Range<Int>? {
        let lo = max(0, min(limit, desired.lowerBound))
        let hi = max(0, min(limit, desired.upperBound))
        guard lo < hi else { return nil }
        return lo..<hi
    }

    private static func pixelScale(_ bitmap: NSBitmapImageRep) -> CGFloat {
        // Retina: Bitmap ist typisch 2× der pt-Größe. Ohne View-Höhe aus der bekannten 1280er Breite nicht ableitbar —
        // `bitmapImageRepForCachingDisplay` setzt size in pt.
        let ptWidth = bitmap.size.width
        guard ptWidth > 1 else { return 2 }
        return CGFloat(bitmap.pixelsWide) / ptWidth
    }
}

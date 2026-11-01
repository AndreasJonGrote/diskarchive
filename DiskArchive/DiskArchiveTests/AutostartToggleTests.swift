//
//  AutostartToggleTests.swift
//  DiskArchiveTests
//
//  Aufgabe 162: das Kästchen schaltet im nächsten Bild, die Systemanmeldung läuft danach.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite
struct AutostartToggleTests {
    @Test func checkboxFlipsBeforeSetEnabledReturns() async {
        let finished = LockedFlag()
        // Tor statt Schlaf: die Registrierung hält, bis der Test das Kästchen geprüft hat (spätestens am Testende).
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let app = AppState()
        // bug.0.3.9.001: Attrappe je AppState-Instanz statt prozessweitem Schalter.
        app.launchAtLoginRegister = { _ in
            release.wait()
            finished.set()
        }
        app.launchAtLoginStateProvider = { .requiresApproval }
        let session = PixelProbe.open(
            SettingsGeneralTab(section: .advanced)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 860, height: 700, alignment: .top),
            size: CGSize(width: 860, height: 700),
            appearance: .aqua
        )
        defer { session.close() }
        let rows = checkboxRows(in: session.window)
        #expect(!rows.isEmpty)
        guard let row = rows.first else { return }
        let before = session.bitmap()
        let box = CGRect(x: row.minX, y: row.minY, width: 16, height: 16)
        session.click(at: CGPoint(x: row.minX + 8, y: row.midY))
        let after = session.bitmap()
        #expect(!finished.isSet)
        #expect(interiorInk(in: before, rect: box) != interiorInk(in: after, rect: box))
        release.signal()
        // Der Klick erreicht die Attrappe dieser Instanz (also nie die echte Systemregistrierung).
        let registered = await waitUntil(timeout: 10) { finished.isSet }
        #expect(registered, "Klick hat die Registrierung der AppState-Instanz nicht erreicht")
        // Danach liest der Schalter den Systemstand über die Abfrage derselben Instanz.
        let mirrored = await waitUntil(timeout: 10) { app.launchAtLoginState == .requiresApproval }
        #expect(mirrored, "Schalter las den Systemstand nicht über die AppState-Instanz")
    }

    /// bug.0.3.9.001: `refreshLaunchAtLoginState` fragt über die Abfrage der Instanz ab, nie auf dem Hauptfaden.
    @Test func refreshReadsInstanceProviderOffMain() async {
        let ranOnMain = LockedFlag()
        let app = AppState()
        app.launchAtLoginStateProvider = {
            if Thread.isMainThread { ranOnMain.set() }
            return .requiresApproval
        }
        app.refreshLaunchAtLoginState()
        let mirrored = await waitUntil(timeout: 10) { app.launchAtLoginState == .requiresApproval }
        #expect(mirrored, "Abfrage der AppState-Instanz nicht verwendet")
        #expect(!ranOnMain.isSet)
    }

    private func checkboxRows(in window: NSWindow) -> [CGRect] {
        guard let root = window.contentView else { return [] }
        let height = root.bounds.height
        return proxies(in: root).compactMap { view in
            let frame = view.convert(view.bounds, to: nil)
            guard frame.height >= 14, frame.height <= 22, frame.width > 40, frame.width < 320 else { return nil }
            return CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
        }.sorted { $0.minY < $1.minY }
    }

    private func proxies(in view: NSView) -> [NSView] {
        let name = String(describing: type(of: view))
        var found: [NSView] = name.contains("KeyViewProxy") ? [view] : []
        for subview in view.subviews {
            found.append(contentsOf: proxies(in: subview))
        }
        return found
    }

    private func interiorInk(in bitmap: NSBitmapImageRep, rect: CGRect) -> Int {
        let inset = rect.insetBy(dx: 4, dy: 4)
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: max(0, rect.minX - 6), y: rect.midY))
        var count = 0
        var y = inset.minY
        while y < inset.maxY {
            var x = inset.minX
            while x < inset.maxX {
                let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if !near(color, background) { count += 1 }
                x += 1
            }
            y += 1
        }
        return count
    }

    private func near(_ color: NSColor, _ other: NSColor) -> Bool {
        let sample = color.usingColorSpace(.sRGB) ?? color
        let target = other.usingColorSpace(.sRGB) ?? other
        return abs(sample.redComponent - target.redComponent) < 0.12
            && abs(sample.greenComponent - target.greenComponent) < 0.12
            && abs(sample.blueComponent - target.blueComponent) < 0.12
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
}

//
//  SettingsTabSwitchTests.swift
//  DiskArchiveTests
//
//  Aufgabe 167: Tabwechsel zeichnet sofort; der Autostart-Zustand wird nie auf dem Hauptfaden gelesen.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite
struct SettingsTabSwitchTests {
    private static let size = CGSize(width: 900, height: 640)
    private static let contentProbe = CGRect(x: 200, y: 20, width: 660, height: 600)

    @Test func everyTabAppearsWithin50msAndProviderNeverRunsOnMain() {
        let calls = ThreadCounter()
        let app = AppState()
        // bug.0.3.9.001: Attrappe je AppState-Instanz statt prozessweitem Schalter.
        app.launchAtLoginStateProvider = {
            calls.record(main: Thread.isMainThread)
            Thread.sleep(forTimeInterval: 0.3)
            return .off
        }
        app.settingsTab = .advanced
        let session = PixelProbe.open(
            SettingsView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: Self.size.width, height: Self.size.height),
            size: Self.size,
            appearance: .aqua
        )
        defer { session.close() }

        var previous = signature(session.bitmap())
        for (index, tab) in SettingsTab.allCases.enumerated() {
            let start = Date()
            session.click(at: CGPoint(x: 80, y: 16 + 15 + CGFloat(index) * 32), settle: 0)
            var changed = false
            var current = previous
            var elapsed = TimeInterval.infinity
            while Date().timeIntervalSince(start) < BenchGate.paintDeadline {
                CFRunLoopRunInMode(.defaultMode, 0.001, true)
                // Gemessen bis zum Beginn der Aufnahme; die Aufnahme selbst kostet 10–30 ms.
                let captureStart = Date()
                current = signature(session.bitmap())
                if current != previous {
                    changed = true
                    elapsed = captureStart.timeIntervalSince(start)
                    break
                }
            }
            #expect(app.settingsTab == tab)
            #expect(changed, "Tab \(tab) nicht gezeichnet")
            if BenchGate.enabled { #expect(elapsed <= 0.15, "Tab \(tab) nach \(Int(elapsed * 1000)) ms") }
            previous = current
        }
        #expect(calls.mainCount == 0)
    }

    /// Grobe Signatur des Inhaltsbereichs rechts neben der Seitenleiste.
    private func signature(_ bitmap: NSBitmapImageRep) -> [Int] {
        var values: [Int] = []
        var y = Self.contentProbe.minY
        while y < Self.contentProbe.maxY {
            var x = Self.contentProbe.minX
            while x < Self.contentProbe.maxX {
                let c = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                values.append(Int(c.redComponent * 15) << 8 | Int(c.greenComponent * 15) << 4 | Int(c.blueComponent * 15))
                x += 6
            }
            y += 6
        }
        return values
    }
}

private final class ThreadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var main = 0
    func record(main isMain: Bool) {
        lock.lock()
        if isMain { main += 1 }
        lock.unlock()
    }
    var mainCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return main
    }
}
}

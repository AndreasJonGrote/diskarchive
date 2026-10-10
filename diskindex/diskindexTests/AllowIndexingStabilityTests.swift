//
//  AllowIndexingStabilityTests.swift
//  diskindexTests
//
//  Aufgabe 149 — Ja/Nein-Gruppe body bleibt bei Fortschrittsticks stabil.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct AllowIndexingStabilityTests {
    final class BodyCounter: @unchecked Sendable {
        var count = 0
    }

    struct CountingGroup: View {
        let mediumID: UUID
        let allowIndexing: Bool
        let counter: BodyCounter

        var body: some View {
            let _ = { counter.count += 1 }()
            EquatableView(content: AllowIndexingBinaryGroup(
                mediumID: mediumID,
                allowIndexing: allowIndexing,
                isPending: false,
                onChange: { _ in }
            ))
        }
    }

    @Test func groupBodyStableAcrossProgressTicks() async throws {
        let id = UUID()
        let counter = BodyCounter()
        let host = NSHostingView(
            rootView: CountingGroup(mediumID: id, allowIndexing: true, counter: counter)
                .frame(width: 120, height: 40)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        try await pump(0.05)
        let afterFirst = counter.count
        for tick in 0..<50 {
            host.rootView = CountingGroup(mediumID: id, allowIndexing: true, counter: counter)
                .frame(width: 120, height: 40)
            if tick % 10 == 0 { try await pump(0.01) }
        }
        try await pump(0.05)
        #expect(counter.count - afterFirst <= 4, "body-Zähler \(counter.count - afterFirst)")
        let alone = NSHostingView(rootView: AllowIndexingBinaryGroup(
            mediumID: id, allowIndexing: true, isPending: false, onChange: { _ in }
        ))
        alone.layoutSubtreeIfNeeded()
        #expect(abs(alone.fittingSize.height - 24.4) <= 1.0)
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        PixelProbe.dismissStrayWindows()
    }

    private func pump(_ seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
}

//
//  ConfirmButtonTests.swift
//  DiskArchiveTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

/// Aufgabe 172 d: Verlassen setzt nicht zurück; nur 3 s ohne Klick.
extension WindowTestGroup {
@MainActor
@Suite
struct ConfirmButtonTimeoutTests {
    @Test func armedStageSurvivesLeavingAndResetsAfterThreeSeconds() async {
        let clock = TestClock()
        let size = CGSize(width: 300, height: 120)
        let session = PixelProbe.open(
            ConfirmButton(title: LayoutCopy.forgetAll, now: { clock.now }) {}
                .frame(width: size.width, height: size.height)
                .background(Color.white),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let probe = CGPoint(x: center.x, y: center.y - ConfirmButton.layoutHeight / 2 + 5)
        session.click(at: center)
        let armed = await waitUntil { isArmedRed(session.color(at: probe)) }
        #expect(armed, "nach Klick nicht „Bestätigen“")
        session.move(to: CGPoint(x: 10, y: 10))
        #expect(isArmedRed(session.color(at: probe)), "Verlassen setzt zurück")
        clock.now = clock.now.addingTimeInterval(3)
        let reset = await waitUntil { !isArmedRed(session.color(at: probe)) }
        #expect(reset, "nach 3 s nicht zurückgesetzt")
    }

    /// Füllung der Stufe „Bestätigen“ ist kräftig rot; der Ausgangszustand zeigt den weißen Hintergrund.
    private func isArmedRed(_ color: NSColor) -> Bool {
        color.redComponent - color.greenComponent > 0.3 && color.redComponent - color.blueComponent > 0.3
    }
}
}

private final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_000)
}

@Suite struct ConfirmButtonTests {
    @Test func firstClickArmsAndSecondRuns() {
        var gate = ConfirmGate(title: "Vergessen")
        let start = Date(timeIntervalSince1970: 10)
        let first = gate.click(now: start)
        #expect(!first)
        #expect(gate.label() == LayoutCopy.confirm)
        let second = gate.click(now: start.addingTimeInterval(1))
        #expect(second)
        #expect(gate.isConfirmed())
    }

    @Test func timeoutAndLeaveResetOnlyWhenArmed() {
        var gate = ConfirmGate(title: "Entfernen")
        let start = Date(timeIntervalSince1970: 10)
        _ = gate.click(now: start)
        gate.resetArmedTimeout(now: start.addingTimeInterval(3))
        #expect(gate.label() == "Entfernen")
        _ = gate.click(now: start)
        gate.leave()
        #expect(gate.label() == "Entfernen")
    }

    @Test func confirmedStageIgnoresLeave() {
        var gate = ConfirmGate(title: "Test")
        let start = Date(timeIntervalSince1970: 10)
        _ = gate.click(now: start)
        _ = gate.click(now: start.addingTimeInterval(1))
        gate.leave()
        #expect(gate.isConfirmed())
    }
}

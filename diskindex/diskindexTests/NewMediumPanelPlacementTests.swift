//
//  NewMediumPanelPlacementTests.swift
//  diskindexTests
//
//  todo.0.4.012 — Erkennungs-Panel immer Standardposition (goldener Schnitt).
//

import CoreGraphics
import Foundation
import Testing
@testable import diskindex

@Suite struct NewMediumPanelPlacementTests {
    @Test func frameCentersXAndGoldenRatioY() {
        let visible = CGRect(x: 100, y: 50, width: 1_000, height: 800)
        let size = CGSize(width: 320, height: 200)
        let frame = AppWindowPresenter.newMediumPanelFrame(
            visibleFrame: visible,
            panelSize: size,
            depthFromNewest: 0
        )
        #expect(abs(frame.midX - visible.midX) < 0.5)
        let expectedCenterY = visible.maxY - visible.height * 0.382
        #expect(abs(frame.midY - expectedCenterY) < 0.5)
    }

    @Test func frameRespectsMenubarInsetInVisibleFrame() {
        // visibleFrame beginnt unter der Menüleiste (y > 0 relativ zum Screen).
        let visible = CGRect(x: 0, y: 38, width: 1_440, height: 860)
        let size = CGSize(width: 300, height: 180)
        let frame = AppWindowPresenter.newMediumPanelFrame(
            visibleFrame: visible,
            panelSize: size,
            depthFromNewest: 0
        )
        #expect(abs(frame.midX - visible.midX) < 0.5)
        let expectedCenterY = visible.maxY - visible.height * 0.382
        #expect(abs(frame.midY - expectedCenterY) < 0.5)
    }

    @Test func stackOffsetShiftsOlderPanels() {
        let visible = CGRect(x: 0, y: 0, width: 1_200, height: 900)
        let size = CGSize(width: 280, height: 160)
        let newest = AppWindowPresenter.newMediumPanelFrame(
            visibleFrame: visible,
            panelSize: size,
            depthFromNewest: 0
        )
        let older = AppWindowPresenter.newMediumPanelFrame(
            visibleFrame: visible,
            panelSize: size,
            depthFromNewest: 1
        )
        #expect(older.origin.x == newest.origin.x - 24)
        #expect(older.origin.y == newest.origin.y - 24)
    }

    /// Sabotage: alter unten-rechts-Wert (maxX − width − 24) → rot.
    @Test func sabotageOldBottomTrailingRejected() {
        let visible = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let size = CGSize(width: 320, height: 200)
        let frame = AppWindowPresenter.newMediumPanelFrame(
            visibleFrame: visible,
            panelSize: size,
            depthFromNewest: 0
        )
        let oldX = visible.maxX - size.width - 24
        #expect(abs(frame.origin.x - oldX) > 1)
    }
}

/// bug.0.4.162 (g): Die Erkennungs-Panels nehmen ihre Lage über `effectivePlacement` – im Testprozess immer außerhalb
/// des Bildschirms, auch wenn ein Test `.centered` setzt (Regel 19/21); `nil` heißt weiter „kein Panel“.
@Suite @MainActor
struct NewMediumPanelEffectivePlacementTests {
    @Test func centeredRequestStaysOffscreenInTests() {
        let app = AppState()
        app.promptPanelPlacement = .centered
        #expect(AppWindowPresenter.newMediumPanelPlacement(for: app) == .offscreen)
        app.promptPanelPlacement = .offscreen
        #expect(AppWindowPresenter.newMediumPanelPlacement(for: app) == .offscreen)
        app.promptPanelPlacement = nil
        #expect(AppWindowPresenter.newMediumPanelPlacement(for: app) == nil, "ohne Lage kein Panel")
    }
}

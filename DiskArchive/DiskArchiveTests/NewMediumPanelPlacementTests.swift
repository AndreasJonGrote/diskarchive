//
//  NewMediumPanelPlacementTests.swift
//  DiskArchiveTests
//
//  todo.0.4.012 — Erkennungs-Panel immer Standardposition (goldener Schnitt).
//

import CoreGraphics
import Foundation
import Testing
@testable import DiskArchive

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
        // todo.0.4.048 (Layout 02): ältere Panels nach links **oben** (AppKit: größeres y); vorher nach unten.
        #expect(older.origin.y == newest.origin.y + 24)
    }

    /// todo.0.4.048: Tiefe 1 und 2 liegen links oberhalb des neuesten, je 24 pt Schritt, alle gleich groß.
    @Test func olderPanelsStackUpAndToTheLeft() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let size = CGSize(width: 300, height: 180)
        let frames = (0...2).map {
            AppWindowPresenter.newMediumPanelFrame(visibleFrame: visible, panelSize: size, depthFromNewest: $0)
        }
        for depth in 1...2 {
            #expect(frames[depth].minX == frames[0].minX - CGFloat(depth) * 24, "Tiefe \(depth): x \(frames[depth].minX)")
            #expect(frames[depth].minY == frames[0].minY + CGFloat(depth) * 24, "Tiefe \(depth): y \(frames[depth].minY)")
            #expect(frames[depth].size == size)
        }
    }

    /// todo.0.4.048: am oberen Rand bleibt jeder Rahmen im sichtbaren Bereich (Schritt nach oben gekürzt).
    @Test func olderPanelsStayInsideTheVisibleFrameAtTheTop() {
        // Niedriger Bildschirm: das neueste Panel reicht fast bis an den oberen Rand.
        let visible = CGRect(x: 0, y: 30, width: 1_200, height: 320)
        let size = CGSize(width: 300, height: 220)
        let newest = AppWindowPresenter.newMediumPanelFrame(visibleFrame: visible, panelSize: size, depthFromNewest: 0)
        for depth in 1...4 {
            let frame = AppWindowPresenter.newMediumPanelFrame(visibleFrame: visible, panelSize: size, depthFromNewest: depth)
            #expect(frame.maxY <= max(visible.maxY, newest.maxY) + 0.5, "Tiefe \(depth) über dem sichtbaren Bereich: \(frame)")
            #expect(frame.minY >= newest.minY, "Tiefe \(depth) nach unten statt oben")
            #expect(frame.minX == newest.minX - CGFloat(depth) * 24)
        }
    }

    /// bug.0.4.197 d: Schmaler Bildschirm, viele Panels: der Schritt nach links endet an `visibleFrame.minX`,
    /// jeder Rahmen liegt ganz im sichtbaren Bereich.
    @Test func manyPanelsOnNarrowScreenStayInsideTheVisibleFrame() {
        let visible = CGRect(x: 40, y: 20, width: 400, height: 900)
        let size = CGSize(width: 300, height: 100)
        for depth in 0...8 {
            let frame = AppWindowPresenter.newMediumPanelFrame(visibleFrame: visible, panelSize: size, depthFromNewest: depth)
            #expect(frame.minX >= visible.minX, "Tiefe \(depth) links herausgeragt: \(frame)")
            #expect(visible.contains(frame), "Tiefe \(depth) nicht ganz sichtbar: \(frame)")
        }
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

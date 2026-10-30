//
//  MainWindowFrameTests.swift
//  diskindexTests
//
//  todo.0.4.050: Ohne gespeicherte Lage öffnet das Hauptfenster mit 1258 × 770 pt mittig auf der sichtbaren Fläche;
//  ist sie kleiner, wird je Richtung auf sie begrenzt.
//

import AppKit
import Testing
@testable import diskindex

@Suite
struct MainWindowFrameTests {
    @Test func largeScreenGetsTheDefaultSizeCentered() {
        let visible = NSRect(x: 0, y: 25, width: 2560, height: 1415)
        let frame = AppWindowPresenter.initialMainWindowFrame(visible: visible)
        #expect(frame.size == NSSize(width: 1258, height: 770), "Größe \(frame.size)")
        #expect(frame.midX == visible.midX && frame.midY == visible.midY, "nicht mittig: \(frame)")
    }

    @Test func smallScreenLimitsEachDirectionAndStaysVisible() {
        let fits = NSRect(x: 0, y: 25, width: 1280, height: 775)
        let fitting = AppWindowPresenter.initialMainWindowFrame(visible: fits)
        #expect(fitting.size == NSSize(width: 1258, height: 770), "Größe \(fitting.size)")
        #expect(fits.contains(fitting), "nicht ganz sichtbar: \(fitting)")

        let small = NSRect(x: 0, y: 25, width: 1200, height: 700)
        let limited = AppWindowPresenter.initialMainWindowFrame(visible: small)
        #expect(limited.size == NSSize(width: 1200, height: 700), "Größe \(limited.size)")
        #expect(small.contains(limited), "nicht ganz sichtbar: \(limited)")

        let lowOnly = NSRect(x: 0, y: 25, width: 1440, height: 720)
        let lowLimited = AppWindowPresenter.initialMainWindowFrame(visible: lowOnly)
        #expect(lowLimited.size == NSSize(width: 1258, height: 720), "Größe \(lowLimited.size)")
        #expect(lowOnly.contains(lowLimited), "nicht ganz sichtbar: \(lowLimited)")
    }
}

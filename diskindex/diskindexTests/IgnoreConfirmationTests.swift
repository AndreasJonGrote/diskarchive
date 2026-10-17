//
//  IgnoreConfirmationTests.swift
//  diskindexTests
//
//  bug.0.4.035 (todo.0.4.031) — Rückfrage ab 500 Zielen beim Ignorieren über das Kontextmenü.
//  Logik über den echten Menüeintrag; Dialog im echten Fenster außerhalb des Bildschirms (Regel 10/19/21),
//  Maße aus dem Katalog (340 / 149 × 38,8, hell und dunkel), Klick auf beide Knöpfe per `window.sendEvent`.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private func targets(_ count: Int) -> [ObjectContextTarget] {
    let medium = Medium(
        id: UUID(), name: "Viele", type: .usb, connectionStatus: .connected, indexStatus: .indexed,
        allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0,
        fileCount: count, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
        isForgotten: false, indexingProgress: 1
    )
    return (0..<count).map { index in
        ObjectContextTarget.fromIndexedItem(
            IndexedItem(
                id: IndexedItem.stableID(mediumID: medium.id, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: "eintrag-\(index).txt",
                kind: .file,
                parentPath: [],
                modifiedAt: nil,
                sizeBytes: 1,
                listedAt: nil
            ),
            medium: medium
        )
    }
}

@MainActor
private func ignoreNameEntry(_ targets: [ObjectContextTarget], app: AppState) throws -> ContextMenuEntry {
    let entries = multipleContextMenuGroups(targets, appState: app).flatMap { $0 }
    return try #require(entries.first { $0.id == "ignoreName" })
}

@Suite(.serialized) @MainActor
struct IgnoreConfirmationTests {
    @Test func below500IgnoresWithoutAsking() throws {
        let app = AppState()
        let chosen = targets(499)
        try ignoreNameEntry(chosen, app: app).action()
        #expect(app.ignoreConfirmationPrompt == nil)
        #expect(app.appSettings.excludedPatterns.count == 499)
    }

    @Test func from500AsksAndCancelChangesNothing() throws {
        let app = AppState()
        let before = app.appSettings.excludedPatterns
        try ignoreNameEntry(targets(500), app: app).action()
        #expect(app.ignoreConfirmationPrompt?.count == 500)
        #expect(app.appSettings.excludedPatterns == before)
        app.resolveIgnoreConfirmation(confirm: false)
        #expect(app.ignoreConfirmationPrompt == nil)
        #expect(app.appSettings.excludedPatterns == before)
    }

    @Test func from500ConfirmIgnoresAll() throws {
        let app = AppState()
        try ignoreNameEntry(targets(500), app: app).action()
        app.resolveIgnoreConfirmation(confirm: true)
        #expect(app.ignoreConfirmationPrompt == nil)
        #expect(app.appSettings.excludedPatterns.count == 500)
    }
}

extension WindowTestGroup {
@MainActor
@Suite
struct IgnoreConfirmDialogWindowTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func dialogMatchesTheCatalog(appearance: NSAppearance.Name) async throws {
        let app = AppState()
        let prompt = IgnoreConfirmationPrompt(count: 500, patterns: ["a"])
        app.ignoreConfirmationPrompt = prompt
        let probe = try await IgnoreDialogProbe.open(app: app, prompt: prompt, appearance: appearance)
        defer { probe.session.close() }
        #expect(abs(probe.dialog.width - 340) <= 0.5, "Dialog \(probe.dialog.width)")
        #expect(abs(probe.cancel.width - 149) <= 0.5, "Abbrechen breit \(probe.cancel.width)")
        #expect(abs(probe.cancel.height - 38.8) <= 0.5, "Abbrechen hoch \(probe.cancel.height)")
        #expect(abs(probe.ignore.width - 149) <= 0.5, "Ignorieren breit \(probe.ignore.width)")
        #expect(abs(probe.ignore.height - 38.8) <= 0.5, "Ignorieren hoch \(probe.ignore.height)")
        // bug.0.3.9.007 a: Katalog „Dialog: Abstand 12“ zwischen Text und Knöpfen.
        #expect(abs(probe.textToButtons - 12) <= 0.5, "Abstand Text–Knöpfe \(probe.textToButtons)")
    }

    /// bug.0.3.9.005 c: echtes Panel über den echten Menüeintrag, Esc → Abbrechen. Zwei Wege: `window.sendEvent`
    /// (Tastenereignis an das Fenster) und `performKeyEquivalent` (Weg der App über das Key-Fenster).
    @Test(arguments: [false, true])
    func escapeInTheRealPanelCancels(viaKeyEquivalent: Bool) async throws {
        let app = AppState()
        app.promptPanelPlacement = .offscreen
        defer { AppWindowPresenter.closePromptPanels(for: app) }
        try ignoreNameEntry(targets(500), app: app).action()
        #expect(app.ignoreConfirmationPrompt?.count == 500)
        let panel = try #require(AppWindowPresenter.ignoreConfirmationPanel(for: app))
        #expect(panel.isVisible)
        #expect(panel.frame.minX <= -10_000 && panel.frame.minY <= -10_000, "Panel \(panel.frame)")
        #expect(!panel.isKeyWindow)
        try await Task.sleep(for: .milliseconds(300))

        try sendEscape(to: panel, viaKeyEquivalent: viaKeyEquivalent)
        let closed = await waitUntil(timeout: 3) {
            app.ignoreConfirmationPrompt == nil && AppWindowPresenter.ignoreConfirmationPanel(for: app) == nil
        }
        #expect(closed)
        #expect(!panel.isVisible)
        #expect(app.appSettings.excludedPatterns.isEmpty)
    }

    /// Ohne gesetzte Lage öffnet die Instanz kein Panel (Standard im Testprozess).
    @Test func withoutPlacementNoPanelOpens() throws {
        let app = AppState()
        #expect(app.promptPanelPlacement == nil)
        try ignoreNameEntry(targets(500), app: app).action()
        #expect(app.ignoreConfirmationPrompt != nil)
        #expect(AppWindowPresenter.ignoreConfirmationPanel(for: app) == nil)
    }

    /// Prüf-Agent zu 005c: Panels gehören zur Instanz — ein fremdes offenes Panel wird weder gezeigt noch geschlossen.
    @Test func panelsBelongToTheirInstance() throws {
        let first = AppState()
        let second = AppState()
        first.promptPanelPlacement = .offscreen
        defer {
            AppWindowPresenter.closePromptPanels(for: first)
            AppWindowPresenter.closePromptPanels(for: second)
        }
        first.requestIgnore(["a"], targetCount: 500)
        let firstPanel = try #require(AppWindowPresenter.ignoreConfirmationPanel(for: first))
        second.requestIgnore(["b"], targetCount: 500)
        #expect(AppWindowPresenter.ignoreConfirmationPanel(for: second) == nil)

        second.promptPanelPlacement = .offscreen
        second.resolveIgnoreConfirmation(confirm: false)
        second.requestIgnore(["b"], targetCount: 500)
        let secondPanel = try #require(AppWindowPresenter.ignoreConfirmationPanel(for: second))
        #expect(secondPanel !== firstPanel)

        AppWindowPresenter.closePromptPanels(for: second)
        #expect(second.ignoreConfirmationPrompt == nil)
        #expect(first.ignoreConfirmationPrompt != nil)
        #expect(firstPanel.isVisible)
        #expect(AppWindowPresenter.ignoreConfirmationPanel(for: first) === firstPanel)
    }

    /// bug.0.3.9.007 b: Schließen aller Fenster setzt beide Rückfragen zurück.
    @Test func closingAllWindowsResetsBothPrompts() async throws {
        let app = AppState()
        defer { AppWindowPresenter.closePromptPanels(for: app) }
        app.ignoreConfirmationPrompt = IgnoreConfirmationPrompt(count: 500, patterns: ["a"])
        AppWindowPresenter.openIgnoreConfirmation(appState: app, placement: .offscreen)
        app.replaceMediumPrompt = ReplaceMediumPrompt(newID: UUID(), oldID: UUID(), name: "USB")
        AppWindowPresenter.openReplaceMediumPrompt(appState: app, placement: .offscreen)
        try #require(AppWindowPresenter.ignoreConfirmationPanel(for: app) != nil)
        try #require(AppWindowPresenter.replaceMediumPromptPanel(for: app) != nil)

        // Gleicher Weg wie `prepareForTermination`, aber nur für diese Instanz (keine fremden Fenster).
        AppWindowPresenter.closePromptPanels(for: app)
        #expect(app.ignoreConfirmationPrompt == nil)
        #expect(app.replaceMediumPrompt == nil)
        #expect(AppWindowPresenter.ignoreConfirmationPanel(for: app) == nil)
        #expect(AppWindowPresenter.replaceMediumPromptPanel(for: app) == nil)
        #expect(app.appSettings.excludedPatterns.isEmpty)
    }

    @Test func cancelClickChangesNothing() async throws {
        let app = AppState()
        try ignoreNameEntry(targets(500), app: app).action()
        let prompt = try #require(app.ignoreConfirmationPrompt)
        let probe = try await IgnoreDialogProbe.open(app: app, prompt: prompt, appearance: .aqua)
        defer { probe.session.close() }
        probe.session.click(at: CGPoint(x: probe.cancel.midX, y: probe.cancel.midY))
        let closed = await waitUntil(timeout: 3) { app.ignoreConfirmationPrompt == nil }
        #expect(closed)
        #expect(app.appSettings.excludedPatterns.isEmpty)
    }

    @Test func ignoreClickIgnoresAll() async throws {
        let app = AppState()
        try ignoreNameEntry(targets(500), app: app).action()
        let prompt = try #require(app.ignoreConfirmationPrompt)
        let probe = try await IgnoreDialogProbe.open(app: app, prompt: prompt, appearance: .aqua)
        defer { probe.session.close() }
        probe.session.click(at: CGPoint(x: probe.ignore.midX, y: probe.ignore.midY))
        let closed = await waitUntil(timeout: 3) { app.ignoreConfirmationPrompt == nil }
        #expect(closed)
        #expect(app.appSettings.excludedPatterns.count == 500)
    }
}
}

/// Esc als Tastenereignis an das eigene Testfenster (Regel 21).
@MainActor
func escapeKey(in window: NSWindow) throws -> NSEvent {
    try #require(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        characters: "\u{1b}",
        charactersIgnoringModifiers: "\u{1b}",
        isARepeat: false,
        keyCode: 53
    ))
}

/// Esc an das Panel: `sendEvent` (Fenster) oder `performKeyEquivalent` (wie NSApp beim Key-Fenster).
@MainActor
func sendEscape(to window: NSWindow, viaKeyEquivalent: Bool) throws {
    let event = try escapeKey(in: window)
    if viaKeyEquivalent {
        #expect(window.performKeyEquivalent(with: event), "Esc als Tastenkürzel nicht behandelt")
    } else {
        window.sendEvent(event)
    }
}

/// Höhe eines Textblocks bei der Innenbreite des Dialogs (340 − 2 × 17).
@MainActor
func dialogTextHeight<V: View>(_ text: V) -> CGFloat {
    NSHostingView(rootView: text.frame(width: 340 - 2 * 17, alignment: .leading)).fittingSize.height
}

/// Dialog auf grünem Grund, Maße aus Pixeln (pt, Ursprung oben links).
@MainActor
private struct IgnoreDialogProbe {
    let session: PixelProbe.Session
    let dialog: CGRect
    let ignore: CGRect
    let cancel: CGRect
    /// Oberkante der Knöpfe minus (Dialogoberkante + Rahmen und Innenabstand 17 + Texthöhe).
    let textToButtons: CGFloat

    static func open(app: AppState, prompt: IgnoreConfirmationPrompt, appearance: NSAppearance.Name) async throws -> IgnoreDialogProbe {
        let content = IgnoreConfirmDialog(prompt: prompt)
            .environment(app)
            .padding(40)
            .background(Color(red: 0, green: 1, blue: 0))
        let size = NSHostingView(rootView: content).fittingSize
        let session = PixelProbe.open(content, size: size, appearance: appearance)
        await PixelProbe.settleOpenWindow(session)
        let bitmap = session.bitmap()
        let scale = CGFloat(bitmap.pixelsWide) / size.width
        let dialog = try #require(bounds(in: bitmap, scale: scale, area: CGRect(origin: .zero, size: size)) { color in
            color.greenComponent - max(color.redComponent, color.blueComponent) < 0.3
        })
        let band = CGRect(x: dialog.minX, y: dialog.maxY - 17 - 44, width: dialog.width, height: 44)
        let dark = appearance == .darkAqua
        // Katalog: Primärfläche hell #1f1f1f / dunkel #eae9e9; Sekundärrand #9b9797.
        let controlHex: CGFloat = dark ? 0xEA : 0x1F
        let cancel = try #require(bounds(in: bitmap, scale: scale, area: CGRect(x: dialog.midX, y: band.minY, width: dialog.width / 2, height: band.height)) { c in
            abs(c.redComponent - controlHex / 255) < 0.06 && abs(c.greenComponent - controlHex / 255) < 0.06 && abs(c.blueComponent - controlHex / 255) < 0.06
        })
        let border = try #require(secondaryBorder(dark: dark))
        let ignore = try #require(bounds(in: bitmap, scale: scale, area: CGRect(x: dialog.minX, y: band.minY, width: dialog.width / 2, height: band.height)) { c in
            abs(c.redComponent - border.r) < 0.08 && abs(c.greenComponent - border.g) < 0.08 && abs(c.blueComponent - border.b) < 0.08
        })
        let textToButtons = min(cancel.minY, ignore.minY) - dialog.minY - 17 - dialogTextHeight(IgnoreConfirmDialog.text(prompt))
        return IgnoreDialogProbe(session: session, dialog: dialog, ignore: ignore, cancel: cancel, textToButtons: textToButtons)
    }

    /// Randfarbe des Sekundärknopfs aus dem Design-Token (hell/dunkel aufgelöst).
    private static func secondaryBorder(dark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        var result: (CGFloat, CGFloat, CGFloat)?
        appearance?.performAsCurrentDrawingAppearance {
            if let c = NSColor(DesignBorder.secondaryControlBorderColor).usingColorSpace(.sRGB) {
                result = (c.redComponent, c.greenComponent, c.blueComponent)
            }
        }
        return result.map { (r: $0.0, g: $0.1, b: $0.2) }
    }

    private static func bounds(in bitmap: NSBitmapImageRep, scale: CGFloat, area: CGRect, matches: (NSColor) -> Bool) -> CGRect? {
        let x0 = max(0, Int((area.minX * scale).rounded(.down)))
        let x1 = min(bitmap.pixelsWide, Int((area.maxX * scale).rounded(.up)))
        let y0 = max(0, Int((area.minY * scale).rounded(.down)))
        let y1 = min(bitmap.pixelsHigh, Int((area.maxY * scale).rounded(.up)))
        guard x0 < x1, y0 < y1 else { return nil }
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), matches(color) else { continue }
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard minX <= maxX, minY <= maxY else { return nil }
        return CGRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale, width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
    }
}

//
//  ReplaceMediumDialogWindowTests.swift
//  diskindexTests
//
//  bug.0.4.031 c — Rückfrage im echten Fenster außerhalb des Bildschirms (Regel 10/19): Maße aus dem Katalog
//  (Dialog 340, Knöpfe 149 × 38,8, hell und dunkel), Klick auf beide Knöpfe per `window.sendEvent` (Regel 21).
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct ReplaceMediumDialogWindowTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func dialogAndButtonsMatchTheCatalog(appearance: NSAppearance.Name) async throws {
        let app = AppState()
        let prompt = ReplaceMediumPrompt(newID: UUID(), oldID: UUID(), name: "USB")
        app.replaceMediumPrompt = prompt
        let probe = try await DialogProbe.open(app: app, prompt: prompt, appearance: appearance)
        defer { probe.session.close() }

        #expect(abs(probe.dialog.width - 340) <= 0.5, "Dialogbreite \(probe.dialog.width)")
        #expect(abs(probe.forget.width - 149) <= 0.5, "Altes vergessen breit \(probe.forget.width)")
        #expect(abs(probe.forget.height - 38.8) <= 0.5, "Altes vergessen hoch \(probe.forget.height)")
        #expect(abs(probe.keep.width - 149) <= 0.5, "Behalten breit \(probe.keep.width)")
        #expect(abs(probe.keep.height - 38.8) <= 0.5, "Behalten hoch \(probe.keep.height)")
        #expect(abs(probe.forget.minY - probe.keep.minY) <= 0.5)
        #expect(probe.forget.maxX < probe.keep.minX)
        // bug.0.3.9.007 a: Katalog „Dialog: Abstand 12“ zwischen Text und Knöpfen.
        let textToButtons = min(probe.forget.minY, probe.keep.minY) - probe.dialog.minY - 17
            - dialogTextHeight(ReplaceMediumDialog.text(prompt))
        #expect(abs(textToButtons - 12) <= 0.5, "Abstand Text–Knöpfe \(textToButtons)")
    }

    /// bug.0.3.9.005 c: Rückfrage über `offerReplaceMediumPrompt` (Aufruf des Erkennungs-Coordinators) öffnet das
    /// echte Panel; Esc per `window.sendEvent` → Behalten, beide Medien bleiben.
    @Test(arguments: [false, true])
    func escapeInTheRealPanelKeepsBothMedia(viaKeyEquivalent: Bool) async throws {
        let (app, store, oldID, newID) = try await twoMedia()
        app.promptPanelPlacement = .offscreen
        defer { AppWindowPresenter.closePromptPanels(for: app) }
        #expect(app.offerReplaceMediumPrompt(newID: newID))
        let panel = try #require(AppWindowPresenter.replaceMediumPromptPanel(for: app))
        #expect(panel.isVisible)
        #expect(panel.frame.minX <= -10_000 && panel.frame.minY <= -10_000, "Panel \(panel.frame)")
        #expect(!panel.isKeyWindow)
        try await Task.sleep(for: .milliseconds(300))

        try sendEscape(to: panel, viaKeyEquivalent: viaKeyEquivalent)
        let closed = await waitUntil(timeout: 3) {
            app.replaceMediumPrompt == nil && AppWindowPresenter.replaceMediumPromptPanel(for: app) == nil
        }
        #expect(closed)
        #expect(!panel.isVisible)
        try await Task.sleep(for: .milliseconds(200))
        #expect(app.medium(with: oldID) != nil)
        #expect(app.medium(with: newID) != nil)
        #expect(try await store.medium(uuid: oldID) != nil)
    }

    @Test func keepClosesThePromptAndLeavesBothMedia() async throws {
        let (app, store, oldID, newID) = try await twoMedia()
        let prompt = ReplaceMediumPrompt(newID: newID, oldID: oldID, name: "USB")
        app.replaceMediumPrompt = prompt
        let probe = try await DialogProbe.open(app: app, prompt: prompt, appearance: .aqua)
        defer { probe.session.close() }

        probe.session.click(at: CGPoint(x: probe.keep.midX, y: probe.keep.midY))
        let closed = await waitUntil(timeout: 3) { app.replaceMediumPrompt == nil }
        #expect(closed)
        #expect(probe.done.count == 1)
        try await Task.sleep(for: .milliseconds(200))
        #expect(app.medium(with: oldID) != nil)
        #expect(app.medium(with: newID) != nil)
        #expect(try await store.medium(uuid: oldID) != nil)
    }

    @Test func forgetOldRemovesTheOldMediumOnly() async throws {
        let (app, store, oldID, newID) = try await twoMedia()
        let prompt = ReplaceMediumPrompt(newID: newID, oldID: oldID, name: "USB")
        app.replaceMediumPrompt = prompt
        let probe = try await DialogProbe.open(app: app, prompt: prompt, appearance: .aqua)
        defer { probe.session.close() }

        probe.session.click(at: CGPoint(x: probe.forget.midX, y: probe.forget.midY))
        let closed = await waitUntil(timeout: 3) { app.replaceMediumPrompt == nil }
        #expect(closed)
        #expect(probe.done.count == 1)
        #expect(app.medium(with: oldID) == nil)
        let gone = await waitUntil { (try? await store.medium(uuid: oldID)) == nil }
        #expect(gone)
        #expect(app.medium(with: newID) != nil)
        #expect(try await store.medium(uuid: newID) != nil)
    }

    private func twoMedia() async throws -> (AppState, IndexStoreV3, UUID, UUID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-replace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let old = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "USB", type: .usb, decision: .index, indexStatus: .indexed)
        let new = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "USB", type: .usb, decision: .dontIndex, indexStatus: .pending)
        try await store.upsertMedium(old)
        try await store.upsertMedium(new)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        try #require(app.medium(with: old.uuid) != nil)
        try #require(app.medium(with: new.uuid) != nil)
        return (app, store, old.uuid, new.uuid)
    }
}
}

/// Öffnet die Rückfrage auf grünem Grund und misst Dialog und Knöpfe aus den Pixeln (pt, Ursprung oben links).
@MainActor
private struct DialogProbe {
    let session: PixelProbe.Session
    let done: DoneCounter
    let dialog: CGRect
    let forget: CGRect
    let keep: CGRect

    static let margin: CGFloat = 40

    static func open(app: AppState, prompt: ReplaceMediumPrompt, appearance: NSAppearance.Name) async throws -> DialogProbe {
        let done = DoneCounter()
        let content = ReplaceMediumDialog(prompt: prompt, onDone: { done.count += 1 })
            .environment(app)
            .padding(margin)
            .background(Color(red: 0, green: 1, blue: 0))
        let size = NSHostingView(rootView: content).fittingSize
        let session = PixelProbe.open(content, size: size, appearance: appearance)
        await PixelProbe.settleOpenWindow(session)
        let bitmap = session.bitmap()
        let scale = CGFloat(bitmap.pixelsWide) / size.width

        let dialog = try #require(bounds(in: bitmap, scale: scale, area: CGRect(origin: .zero, size: size)) { color in
            color.greenComponent - max(color.redComponent, color.blueComponent) < 0.3
        })
        // Knopfzeile: unterste 38,8 pt plus Reserve innerhalb des Rahmens und Innenabstands (17 pt).
        let band = CGRect(x: dialog.minX, y: dialog.maxY - 17 - 44, width: dialog.width, height: 44)
        let forget = try #require(bounds(in: bitmap, scale: scale, area: band) { color in
            color.redComponent - color.greenComponent > 0.25 && color.redComponent - color.blueComponent > 0.25
        })
        // Katalog: Primärfläche hell `#1f1f1f`, dunkel `#eae9e9`.
        let hex: CGFloat = appearance == .darkAqua ? 0xEA : 0x1F
        let control = NSColor(srgbRed: hex / 255, green: hex / 255, blue: hex / 255, alpha: 1)
        let rightHalf = CGRect(x: dialog.midX, y: band.minY, width: dialog.width / 2, height: band.height)
        let keep = try #require(bounds(in: bitmap, scale: scale, area: rightHalf) { color in
            abs(color.redComponent - control.redComponent) < 0.06
                && abs(color.greenComponent - control.greenComponent) < 0.06
                && abs(color.blueComponent - control.blueComponent) < 0.06
        })
        return DialogProbe(session: session, done: done, dialog: dialog, forget: forget, keep: keep)
    }

    private static func bounds(
        in bitmap: NSBitmapImageRep,
        scale: CGFloat,
        area: CGRect,
        matches: (NSColor) -> Bool
    ) -> CGRect? {
        let x0 = max(0, Int((area.minX * scale).rounded(.down)))
        let x1 = min(bitmap.pixelsWide, Int((area.maxX * scale).rounded(.up)))
        let y0 = max(0, Int((area.minY * scale).rounded(.down)))
        let y1 = min(bitmap.pixelsHigh, Int((area.maxY * scale).rounded(.up)))
        guard x0 < x1, y0 < y1 else { return nil }
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), matches(color) else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard minX <= maxX, minY <= maxY else { return nil }
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }
}

@MainActor
private final class DoneCounter {
    var count = 0
}

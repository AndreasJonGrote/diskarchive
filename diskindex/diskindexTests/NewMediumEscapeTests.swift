//
//  NewMediumEscapeTests.swift
//  diskindexTests
//
//  bug.0.3.9.014 a — Esc im Erkennungs-Panel schließt es (Medium bleibt unentschieden, Panel gilt als weggeklickt).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct NewMediumEscapeTests {
    /// Panel aus `AppWindowPresenter.makeNewMediumPanel` (wie `openOrUpdateNewMediumPanel`), aber außerhalb des
    /// Bildschirms und ohne Key-Fenster (Regel 19/21). Zwei Wege wie bei den Rückfragen:
    /// `window.sendEvent` und `performKeyEquivalent`.
    @Test(arguments: [false, true])
    func escapeInThePanelDismisses(viaKeyEquivalent: Bool) async throws {
        let app = AppState()
        var medium = try #require(PreviewData.media.first)
        medium.decision = .undecided
        medium.allowIndexing = false
        app.media = [medium]
        let mediumID = medium.id

        let hosting = NSHostingView(rootView: AnyView(NewMediumDialogWindowHost(mediumID: mediumID).environment(app)))
        // Gleiche Erzeugung wie in der App (`AppWindowPresenter.makeNewMediumPanel`); nur Lage und Anzeige
        // unterscheiden sich (außerhalb des Bildschirms, kein Key-Fenster).
        let panel = AppWindowPresenter.makeNewMediumPanel(hosting: hosting)
        panel.isReleasedWhenClosed = false
        panel.setFrameOrigin(PromptPanelPlacement.offscreenOrigin)
        panel.orderFrontRegardless()
        defer {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        #expect(panel.frame.minX <= -10_000 && panel.frame.minY <= -10_000, "Panel \(panel.frame)")
        #expect(!panel.isKeyWindow)
        #expect(!app.dismissedNewMediumPanelIDs.contains(mediumID))
        try await Task.sleep(for: .milliseconds(300))

        try sendEscape(to: panel, viaKeyEquivalent: viaKeyEquivalent)
        let dismissed = await waitUntil(timeout: 3) { app.dismissedNewMediumPanelIDs.contains(mediumID) }
        #expect(dismissed, "Esc hat das Erkennungs-Panel nicht geschlossen")
        #expect(app.medium(with: mediumID)?.decision == .undecided)
    }
}
}

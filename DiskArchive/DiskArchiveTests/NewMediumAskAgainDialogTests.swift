//
//  NewMediumAskAgainDialogTests.swift
//  DiskArchiveTests
//
//  todo.0.4.026 — Erneut gefragter Erkennungs-Dialog (ohne „Für dieses Medium merken“): Vorbelegung = letzte
//  Entscheidung. Echtes Panel außerhalb des Bildschirms, kein Key-Fenster, Taste nur per `window.sendEvent`
//  bzw. `performKeyEquivalent` (Regel 19/21).
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite @MainActor
struct NewMediumAskAgainDialogTests {
    /// Eingabetaste im erneut gefragten Dialog wählt die letzte Entscheidung, „merken“ ist wie zuletzt aus.
    @Test(arguments: [StoredIndexDecision.dontIndex, .index])
    func returnKeyRepeatsLastDecision(last: StoredIndexDecision) async throws {
        let app = AppState()
        var medium = try #require(PreviewData.media.first)
        medium.decision = last
        medium.allowIndexing = last == .index
        medium.connectionStatus = .connected
        app.media = [medium]
        let mediumID = medium.id
        app.enqueueNewMediumDecision(mediumID)
        let choices = ChoiceLog()
        app.onNewMediumChoice = { id, allow, remember in choices.items.append((id, allow, remember)) }

        let hosting = NSHostingView(rootView: AnyView(NewMediumDialogWindowHost(mediumID: mediumID).environment(app)))
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
        try await Task.sleep(for: .milliseconds(300))
        #expect(hosting.fittingSize.width > 100, "erneut gefragter Dialog nicht gezeichnet")

        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        ))
        #expect(panel.performKeyEquivalent(with: event), "Eingabetaste nicht behandelt")
        let chosen = await waitUntil(timeout: 3) { !choices.items.isEmpty }
        try #require(chosen, "keine Entscheidung angekommen")
        let choice = try #require(choices.items.first)
        #expect(choice.0 == mediumID)
        #expect(choice.1 == (last == .index), "Vorbelegung ist nicht die letzte Entscheidung")
        #expect(choice.2 == false, "„merken“ ist im erneuten Dialog nicht wie zuletzt aus")
    }
}
}

@MainActor
private final class ChoiceLog {
    var items: [(UUID, Bool, Bool)] = []
}

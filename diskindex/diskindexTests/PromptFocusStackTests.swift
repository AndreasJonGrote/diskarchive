//
//  PromptFocusStackTests.swift
//  diskindexTests
//
//  bug.0.4.209 + bug.0.4.216 — Dialoge (Konzept `medien.md` Punkt 3, „Fokus einmal beim Erscheinen“): Fokus nur, wenn ein
//  Panel neu erscheint; die Lage aller Erkennungs-Panels bei jedem Abgleich (Stapel nach Layout 02); kein `.floating`.
//  Fenster außerhalb des Bildschirms, kein `NSApp.activate`; Fokus gezählt über den Haken je Instanz.
//

import AppKit
import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct PromptFocusStackTests {
    private final class FocusLog {
        var kinds: [String] = []
    }

    private struct Rig {
        let app: AppState
        let ids: [UUID]
        let focus: FocusLog

        @MainActor
        func close() {
            for id in ids {
                AppWindowPresenter.closeNewMediumPanel(mediumID: id, appState: app, userDismissed: false)
            }
            AppWindowPresenter.closePromptPanels(for: app)
        }
    }

    /// Drei angeschlossene, unentschiedene Medien (noch nicht in der Warteschlange).
    private static func rig() throws -> Rig {
        let app = AppState()
        app.promptPanelPlacement = .offscreen
        var media: [Medium] = []
        for index in 0..<3 {
            var medium = previewMedium(index)
            medium.decision = .undecided
            medium.allowIndexing = false
            medium.connectionStatus = .connected
            media.append(medium)
        }
        try #require(Set(media.map(\.id)).count == 3, "Voraussetzung: drei verschiedene Medien")
        app.media = media
        let focus = FocusLog()
        app.promptFocusHookForTesting = { focus.kinds.append($0) }
        return Rig(app: app, ids: media.map(\.id), focus: focus)
    }

    private static func origin(_ rig: Rig, _ id: UUID) throws -> CGPoint {
        try #require(AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: id), "Panel fehlt").frame.origin
    }

    /// 216: Zwei Medien in getrennten Abgleichen → gestapelt, das ältere nach links oben (24 pt); den vorderen
    /// beantworten → der übrige rückt nach vorn. Gegenprobe: beide im selben Abgleich.
    @Test func panelsStackOnEverySync() throws {
        let together = try Self.rig()
        defer { together.close() }
        together.app.enqueueNewMediumDecision(together.ids[0])
        together.app.enqueueNewMediumDecision(together.ids[1])
        AppWindowPresenter.syncNewMediumPanels(appState: together.app)
        let olderTogether = try Self.origin(together, together.ids[0])
        let newestTogether = try Self.origin(together, together.ids[1])
        #expect(olderTogether.x == newestTogether.x - 24 && olderTogether.y == newestTogether.y + 24,
                "Gegenprobe: im selben Abgleich nicht gestapelt (\(olderTogether) / \(newestTogether))")

        let apart = try Self.rig()
        defer { apart.close() }
        apart.app.enqueueNewMediumDecision(apart.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: apart.app)
        let alone = try Self.origin(apart, apart.ids[0])
        apart.app.enqueueNewMediumDecision(apart.ids[1])
        AppWindowPresenter.syncNewMediumPanels(appState: apart.app)
        let older = try Self.origin(apart, apart.ids[0])
        let newest = try Self.origin(apart, apart.ids[1])
        #expect(newest == alone, "das neueste nicht vorn und mittig")
        #expect(older.x == newest.x - 24 && older.y == newest.y + 24, "getrennt gekommen, nicht gestapelt (\(older) / \(newest))")

        apart.app.updateMedium(id: apart.ids[1]) { $0.decision = .index }
        apart.app.completeNewMediumDecision(apart.ids[1])
        AppWindowPresenter.syncNewMediumPanels(appState: apart.app)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: apart.app) == 1)
        #expect(try Self.origin(apart, apart.ids[0]) == alone, "der übrige rückt nicht nach vorn")
    }

    /// 209: Das neu erscheinende Panel wird einmal nach vorn geholt; ein weiterer Abgleich ohne neues Panel (ein anderes
    /// Medium hängt aus) fordert den Fokus nicht wieder an. Öffnet der Nutzer den Dialog selbst, darf er ihn holen.
    @Test func focusOnlyWhenAPanelAppears() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(rig.focus.kinds == ["neues-medium"], "Gegenprobe: beim Erscheinen kein Fokus")

        rig.app.updateMedium(id: rig.ids[2]) { $0.connectionStatus = .offline }
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(rig.focus.kinds.count == 1, "Fokus ohne neues Panel erneut angefordert: \(rig.focus.kinds)")

        rig.app.enqueueNewMediumDecision(rig.ids[1])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(rig.focus.kinds.count == 2, "das zweite neue Panel bekommt den Fokus nicht")

        AppWindowPresenter.openNewMedium(appState: rig.app)
        #expect(rig.focus.kinds.count == 3, "vom Nutzer geöffnet: kein Fokus")
    }

    /// 209: „Ersetzt dieses Medium?“ holt den Fokus beim Erscheinen, ein erneutes Öffnen nicht.
    @Test func replacePromptTakesFocusOnce() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.replaceMediumPrompt = ReplaceMediumPrompt(newID: rig.ids[0], oldID: rig.ids[1], name: "STICK")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        #expect(rig.focus.kinds == ["ersetzen"], "Gegenprobe: beim Erscheinen kein Fokus")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        #expect(rig.focus.kinds == ["ersetzen"], "erneutes Öffnen holt den Fokus wieder: \(rig.focus.kinds)")
    }

    /// 209: Keiner der vier Dialoge schwebt über anderen Fenstern.
    @Test func noPanelFloats() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        rig.app.replaceMediumPrompt = ReplaceMediumPrompt(newID: rig.ids[0], oldID: rig.ids[1], name: "STICK")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        rig.app.ignoreConfirmationPrompt = IgnoreConfirmationPrompt(count: 600, patterns: ["*.tmp"])
        AppWindowPresenter.openIgnoreConfirmation(appState: rig.app)
        AppWindowPresenter.openCrashReport()
        defer { AppWindowPresenter.crashReportPanel?.close() }
        let panels: [(String, NSPanel?)] = [
            ("Erkennung", AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[0])),
            ("Ersetzen", AppWindowPresenter.replaceMediumPromptPanel(for: rig.app)),
            ("Ignorieren", AppWindowPresenter.ignoreConfirmationPanel(for: rig.app)),
            ("Absturzbericht", AppWindowPresenter.crashReportPanel),
        ]
        for (name, panel) in panels {
            let panel = try #require(panel, "Gegenprobe: \(name) nicht offen")
            #expect(panel.level == .normal, "\(name) schwebt (Ebene \(panel.level.rawValue))")
            #expect(!panel.isFloatingPanel, "\(name) ist ein schwebendes Panel")
            #expect(!panel.hidesOnDeactivate, "\(name) verschwindet beim Wechsel der App")
        }
    }
}
}

//
//  PromptFocusStackTests.swift
//  DiskArchiveTests
//
//  bug.0.4.209 + bug.0.4.216 — Dialoge (Konzept `medien.md` Punkt 3, „Fokus einmal beim Erscheinen“): Fokus nur, wenn ein
//  Panel neu erscheint; die Lage aller Erkennungs-Panels bei jedem Abgleich (Stapel nach Layout 02); kein `.floating`.
//  Fenster außerhalb des Bildschirms, kein `NSApp.activate`; Fokus gezählt über den Haken je Instanz.
//

import AppKit
import Foundation
import Testing
@testable import DiskArchive

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

    /// bug.0.4.3.001: Öffnet der Nutzer den Erkennungsdialog über die Kachel (`openNewMedium`), liegt der Responder auf
    /// der Inhaltsansicht wie bei den übrigen Dialogen (`show`) – nicht auf dem Fenster, sonst wählt AppKit beim Key-Werden
    /// das erste fokussierbare Element („Für dieses Medium merken“) mit Fokusrahmen. Gegenprobe: „Ersetzt dieses Medium?“.
    @Test func newMediumPanelStartsOnTheContentViewLikeTheOtherDialogs() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.replaceMediumPrompt = ReplaceMediumPrompt(newID: rig.ids[0], oldID: rig.ids[1], name: "STICK")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        let replace = try #require(AppWindowPresenter.replaceMediumPromptPanel(for: rig.app), "Gegenprobe: Ersetzen fehlt")
        #expect(replace.firstResponder === replace.contentView, "Gegenprobe: Ersetzen ohne Responder auf dem Inhalt")

        rig.app.enqueueNewMediumDecision(rig.ids[2])
        AppWindowPresenter.openNewMedium(appState: rig.app)
        let panel = try #require(AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[2]), "Panel fehlt")
        #expect(panel.firstResponder === panel.contentView, "Responder: \(String(describing: panel.firstResponder))")
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

    /// Lage der Panels von vorn nach hinten (`NSWindow.windowNumbers`, die Fenster dieser App; `NSApp.orderedWindows`
    /// enthält keine Panels); fehlt eins, steht `nil` an seiner Stelle.
    private static func frontToBack(_ rig: Rig, _ ids: [UUID]) -> [Int?] {
        let ordered = NSWindow.windowNumbers(options: []) ?? []
        return ids.map { id in
            AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: id).flatMap { panel in
                ordered.firstIndex { $0.intValue == panel.windowNumber }
            }
        }
    }

    /// 223: Zwei Medien im selben Abgleich → das neuere liegt vor dem älteren.
    @Test func newestInFrontWhenTwoComeTogether() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        rig.app.enqueueNewMediumDecision(rig.ids[1])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        let order = Self.frontToBack(rig, [rig.ids[1], rig.ids[0]])
        let newest = try #require(order[0], "Gegenprobe: das neuere Panel fehlt")
        let older = try #require(order[1], "Gegenprobe: das ältere Panel fehlt")
        #expect(newest < older, "das ältere liegt vorn (\(order))")
    }

    /// 223: Zwei Medien in zwei Abgleichen kurz nacheinander (das erste ist schon da) → das neuere liegt vorn.
    @Test func newestInFrontWhenTwoComeApart() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        rig.app.enqueueNewMediumDecision(rig.ids[1])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        let order = Self.frontToBack(rig, [rig.ids[1], rig.ids[0]])
        let newest = try #require(order[0], "Gegenprobe: das neuere Panel fehlt")
        let older = try #require(order[1], "Gegenprobe: das ältere Panel fehlt")
        #expect(newest < older, "das ältere liegt vorn (\(order))")
    }

    /// 223: Drei Medien, dann wird das mittlere entschieden → die übrigen behalten „neuester vorn“.
    @Test func newestStaysInFrontAfterTheMiddleIsAnswered() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        for id in rig.ids {
            rig.app.enqueueNewMediumDecision(id)
            AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        }
        let before = Self.frontToBack(rig, rig.ids.reversed())
        let all = before.compactMap { $0 }
        try #require(all.count == 3, "Gegenprobe: nicht alle drei Panels offen (\(before))")
        #expect(all == all.sorted(), "mit drei Panels nicht neuester vorn (\(before))")

        rig.app.updateMedium(id: rig.ids[1]) { $0.decision = .index }
        rig.app.completeNewMediumDecision(rig.ids[1])
        AppWindowPresenter.closeNewMediumPanel(mediumID: rig.ids[1], appState: rig.app, userDismissed: false)
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.app) == 2)
        let after = Self.frontToBack(rig, [rig.ids[2], rig.ids[0]])
        let newest = try #require(after[0], "das neueste Panel fehlt")
        let oldest = try #require(after[1], "das älteste Panel fehlt")
        #expect(newest < oldest, "nach der Antwort liegt das älteste vorn (\(after))")
    }

    /// 221: Die Dialoge aktivieren die App (kein `.nonactivatingPanel`), sonst gibt eine andere App den Fokus
    /// nach dem Erscheinen nicht mehr zurück.
    @Test func dialogPanelsActivateTheApp() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        rig.app.replaceMediumPrompt = ReplaceMediumPrompt(newID: rig.ids[0], oldID: rig.ids[1], name: "STICK")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        AppWindowPresenter.openCrashReport()
        defer { AppWindowPresenter.crashReportPanel?.close() }
        let panels: [(String, NSPanel?)] = [
            ("Erkennung", AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[0])),
            ("Ersetzen", AppWindowPresenter.replaceMediumPromptPanel(for: rig.app)),
            ("Absturzbericht", AppWindowPresenter.crashReportPanel),
        ]
        for (name, panel) in panels {
            let panel = try #require(panel, "Gegenprobe: \(name) nicht offen")
            #expect(!panel.styleMask.contains(.nonactivatingPanel), "\(name) aktiviert die App nicht")
        }
    }

    /// 221 (Korrektur 2): Die Dialog-Panels können Main werden – die erzwungene Aktivierung holt dann nur den Dialog nach
    /// vorn, nicht das Hauptfenster. Das Popover-Panel (`KeyablePanel`) wird nie Main.
    @Test func dialogPanelsCanBecomeMainThePopoverCannot() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        rig.app.replaceMediumPrompt = ReplaceMediumPrompt(newID: rig.ids[0], oldID: rig.ids[1], name: "STICK")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        AppWindowPresenter.openCrashReport()
        defer { AppWindowPresenter.crashReportPanel?.close() }
        let panels: [(String, NSPanel?)] = [
            ("Erkennung", AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[0])),
            ("Ersetzen", AppWindowPresenter.replaceMediumPromptPanel(for: rig.app)),
            ("Absturzbericht", AppWindowPresenter.crashReportPanel),
        ]
        for (name, panel) in panels {
            let panel = try #require(panel, "Gegenprobe: \(name) nicht offen")
            #expect(panel.canBecomeMain, "\(name) kann nicht Main werden")
        }
        // Wie das Popover in `MenuBarController` (nie nach vorn geholt).
        let popover = KeyablePanel(
            contentRect: NSRect(origin: PromptPanelPlacement.offscreenOrigin, size: CGSize(width: 100, height: 100)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        #expect(!popover.canBecomeMain, "Popover-Panel kann Main werden")
    }

    /// 221: Nach vorn mit Fokus (`.centered`) aktiviert die App, außerhalb des Bildschirms (`.offscreen`) nie.
    /// Das Panel liegt in beiden Fällen außerhalb des Bildschirms; die Aktivierung zählt der Haken.
    @Test func bringForwardActivatesOnlyWhenCentered() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        var activations: [String] = []
        rig.app.promptActivationHookForTesting = { activations.append($0) }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        let panel = try #require(AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[0]), "Panel fehlt")
        #expect(rig.focus.kinds == ["neues-medium"], "Gegenprobe: das Panel kam nicht nach vorn")
        #expect(activations.isEmpty, "außerhalb des Bildschirms aktiviert: \(activations)")

        AppWindowPresenter.bringForward(panel, placement: .centered, appState: rig.app, kind: "neues-medium")
        #expect(activations == ["neues-medium"], "nach vorn mit Fokus aktiviert die App nicht: \(activations)")
    }

    /// 221: Die Menüleiste meldet jede Änderung an `media` (hier ein Prozentschritt eines anderen Mediums). Ein offener
    /// Dialog kommt dadurch nicht wieder nach vorn, ein weggeklickter nicht wieder hervor; ein neuer erscheint mit Fokus.
    @Test func menuBarStateChangeKeepsOpenDialogsQuiet() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        #expect(rig.focus.kinds == ["neues-medium"], "Gegenprobe: beim Erscheinen kein Fokus")

        rig.app.updateMedium(id: rig.ids[2]) { $0.indexingProgress = 0.42 }
        AppWindowPresenter.newMediumStateChanged(appState: rig.app)
        AppWindowPresenter.newMediumStateChanged(appState: rig.app)
        #expect(rig.focus.kinds.count == 1, "offener Dialog bei Zustandsänderung wieder nach vorn: \(rig.focus.kinds)")

        AppWindowPresenter.closeNewMediumPanel(mediumID: rig.ids[0], appState: rig.app, userDismissed: true)
        rig.app.updateMedium(id: rig.ids[2]) { $0.indexingProgress = 0.43 }
        AppWindowPresenter.newMediumStateChanged(appState: rig.app)
        #expect(AppWindowPresenter.openNewMediumPanelCount(for: rig.app) == 0, "weggeklickter Dialog kommt wieder")
        #expect(rig.focus.kinds.count == 1, "weggeklickter Dialog holt den Fokus: \(rig.focus.kinds)")

        rig.app.enqueueNewMediumDecision(rig.ids[1])
        AppWindowPresenter.newMediumStateChanged(appState: rig.app)
        #expect(AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[1]) != nil, "neues Medium ohne Dialog")
        #expect(rig.focus.kinds.count == 2, "neuer Dialog ohne Fokus: \(rig.focus.kinds)")
    }

    /// 209: Keiner der Dialoge schwebt über anderen Fenstern.
    @Test func noPanelFloats() throws {
        let rig = try Self.rig()
        defer { rig.close() }
        rig.app.enqueueNewMediumDecision(rig.ids[0])
        AppWindowPresenter.syncNewMediumPanels(appState: rig.app)
        rig.app.replaceMediumPrompt = ReplaceMediumPrompt(newID: rig.ids[0], oldID: rig.ids[1], name: "STICK")
        AppWindowPresenter.openReplaceMediumPrompt(appState: rig.app)
        AppWindowPresenter.openCrashReport()
        defer { AppWindowPresenter.crashReportPanel?.close() }
        let panels: [(String, NSPanel?)] = [
            ("Erkennung", AppWindowPresenter.newMediumPanel(for: rig.app, mediumID: rig.ids[0])),
            ("Ersetzen", AppWindowPresenter.replaceMediumPromptPanel(for: rig.app)),
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

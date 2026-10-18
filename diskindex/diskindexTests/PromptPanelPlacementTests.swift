//
//  PromptPanelPlacementTests.swift
//  diskindexTests
//
//  bug.0.3.9.014 d — Lage der Rückfrage-Panels kommt aus dem Aufbau, nicht aus einem Prozess-Schalter.
//

import Testing
@testable import diskindex

@Suite @MainActor
struct PromptPanelPlacementTests {
    /// Im Testprozess läuft `applicationDidFinishLaunching` nicht weiter: die Instanz der Host-App bleibt ohne Lage
    /// (kein Panel auf dem Bildschirm). Der Startpfad der App setzt über `configureForApp` die Mitte.
    @Test func hostInstanceHasNoPlacementAndAppSetupCenters() {
        #expect(AppDelegateBridge.appState.promptPanelPlacement == nil)
        let app = AppState()
        app.configureForApp()
        #expect(app.promptPanelPlacement == .centered)
    }

    /// Eine frisch erzeugte Instanz öffnet ohne gesetzte Lage kein Panel.
    @Test func freshInstanceHasNoPlacement() {
        #expect(AppState().promptPanelPlacement == nil)
    }
}

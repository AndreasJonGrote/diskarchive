//
//  PopoverIndexedOnlyTests.swift
//  DiskArchiveTests
//
//  bug.0.4.236 (Konzept `medien.md`, Liste „Angeschlossen“): Die Einstiegskachel zeigt nur angeschlossene Medien mit
//  „Indizieren: Ja“. Abgelehnte stand dort mit „Wird indiziert“. Ansicht und Höhe nehmen dieselbe Liste; eigener
//  Leertext, wenn nur unentschiedene oder abgelehnte angeschlossen sind.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite
struct PopoverIndexedOnlyTests {
    private func medium(_ name: String, _ number: Int, decision: StoredIndexDecision, status: IndexStatus,
                        connected: Bool = true) -> Medium {
        var medium = Medium(
            id: testUUID(String(format: "D2360001-0000-4000-8000-%012d", number)),
            name: name,
            type: .usb,
            connectionStatus: connected ? .connected : .offline,
            indexStatus: status,
            allowIndexing: decision == .index,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000_000_000,
            capacityUsedBytes: 400_000_000,
            fileCount: 12,
            folderCount: 2,
            lastSeenAt: Date(),
            firstIndexedAt: status == .indexed ? Date() : nil,
            lastIndexedAt: status == .indexed ? Date() : nil,
            isForgotten: false,
            indexingProgress: status == .indexing ? 0.4 : 0
        )
        medium.decision = decision
        return medium
    }

    private func fourConnected() -> [Medium] {
        [
            medium("Ja fertig", 1, decision: .index, status: .indexed),
            medium("Ja Lauf", 2, decision: .index, status: .indexing),
            medium("Nein", 3, decision: .dontIndex, status: .pending),
            medium("Offen", 4, decision: .undecided, status: .pending),
        ]
    }

    /// Gezeichnete Kachel als PNG (außerhalb des Bildschirms; die Höhe setzt die Ansicht selbst aus der Layout-Rechnung,
    /// daher zählt der Inhalt, nicht die Größe).
    private func rendered(_ state: AppState) async -> Data? {
        let size = CGSize(width: MenuBarPopoverLayout.panelWidth, height: 600)
        let view = MenuBarPopoverView()
            .environment(state)
            .frame(width: size.width, height: size.height, alignment: .top)
        return await PixelProbe.render(view, size: size).representation(using: .png, properties: [:])
    }

    @Test func listAndHeightShowOnlyIndexedMedia() async throws {
        let all = AppState()
        all.media = fourConnected()
        // todo.0.4.3.013 (Layout 03): unentschiedene Medien stehen mit „Entscheidung ausstehend“ in der Liste; abgelehnte nicht.
        #expect(all.popoverConnectedMedia.map(\.name) == ["Ja fertig", "Ja Lauf", "Offen"], "Liste: \(all.popoverConnectedMedia.map(\.name))")

        let onlyYes = AppState()
        onlyYes.media = [fourConnected()[0], fourConnected()[1], fourConnected()[3]]
        let twoRows = MenuBarPopoverLayout.corePanelHeight(appState: onlyYes)
        let fourYes = AppState()
        fourYes.media = fourConnected().map { medium in
            var yes = medium
            yes.decision = .index
            return yes
        }
        try #require(twoRows != MenuBarPopoverLayout.corePanelHeight(appState: fourYes), "Voraussetzung: vier Zeilen sind höher als zwei")
        #expect(MenuBarPopoverLayout.corePanelHeight(appState: all) == twoRows, "Höhe nicht für drei Zeilen")

        // Ansicht: ohne Spinner (gleiches Bild bei jedem Zeichnen) – Ja und Nein sieht aus wie Ja allein.
        let mixed = AppState()
        mixed.media = [fourConnected()[0], fourConnected()[2]]
        let yesAlone = AppState()
        yesAlone.media = [fourConnected()[0]]
        let mixedImage = try #require(await rendered(mixed))
        let aloneImage = try #require(await rendered(yesAlone))
        #expect(mixedImage == aloneImage, "Ansicht zeigt abgelehnte Medien")
    }

    @Test func emptyTextDependsOnWhatIsConnected() {
        let rejected = AppState()
        rejected.media = [medium("Nein", 3, decision: .dontIndex, status: .pending)]
        #expect(rejected.popoverConnectedMedia.isEmpty)
        #expect(rejected.popoverConnectedEmptyText == LayoutCopy.popoverNoneIndexedConnected)

        let none = AppState()
        none.media = [medium("Weg", 5, decision: .index, status: .indexed, connected: false)]
        #expect(none.popoverConnectedEmptyText == LayoutCopy.popoverNoneConnected)
    }
}
}

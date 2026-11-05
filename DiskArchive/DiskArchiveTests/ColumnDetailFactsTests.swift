//
//  ColumnDetailFactsTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.017 (Layout 07.01.01, 07.03.05, 19): Detailspalte mit Label links und Wert rechts in fester Reihenfolge
//  (Erstellt, Geändert, Größe, Zuletzt gesehen; Mehrfachauswahl mit „Größe gesamt“), online „jetzt“; Fußzeilenpfad in der
//  Mitte geteilt.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct ColumnDetailFactsTests {
    private func medium(online: Bool, lastSeen: Date?) -> Medium {
        Medium(
            id: UUID(), name: "Studio Backup", type: .ssd, connectionStatus: online ? .connected : .offline,
            indexStatus: .indexed, allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 2_000,
            capacityUsedBytes: 0, fileCount: 4, folderCount: 0, lastSeenAt: lastSeen, firstIndexedAt: nil,
            lastIndexedAt: nil, isForgotten: false, indexingProgress: 1
        )
    }

    private func file(_ name: String, size: Int64?, modified: Date?) -> IndexedItem {
        IndexedItem(id: UUID(), name: name, kind: .file, parentPath: ["Projekte"], modifiedAt: modified, sizeBytes: size)
    }

    private func noon(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    @Test func singleFileShowsLabelsInOrderAndNowWhenOnline() throws {
        let modified = try noon(2021, 2, 4)
        let item = file("Briefing_Kunde_B.txt", size: 4_000, modified: modified)
        try L10n.$languageOverride.withValue(.german) {
            let online = ColumnDetailFacts.file(item, medium: medium(online: true, lastSeen: try noon(2024, 1, 1)))
            #expect(online.map(\.label) == ["Erstellt", "Geändert", "Größe", "Zuletzt gesehen"])
            #expect(online.last?.value == "jetzt")
            #expect(online[1].value == IndexedDateFormatting.abbreviatedDay(modified))
            #expect(online[2].value == ByteCountFormatter.storage.string(fromByteCount: 4_000))

            let offline = ColumnDetailFacts.file(
                item, medium: medium(online: false, lastSeen: try noon(2023, 11, 14)), now: try noon(2024, 2, 14)
            )
            #expect(offline.map(\.label) == ["Erstellt", "Geändert", "Größe", "Zuletzt gesehen"])
            #expect(offline.last?.value == "vor 3 Monaten")

            // Unbekannte Werte „—“, Zeile bleibt (Labels immer, 19); offline ohne Datum keine „Zuletzt gesehen“-Zeile.
            let unknown = ColumnDetailFacts.file(file("x", size: nil, modified: nil), medium: medium(online: false, lastSeen: nil))
            #expect(unknown.map(\.label) == ["Erstellt", "Geändert", "Größe"])
            #expect(unknown.map(\.value) == ["—", "—", "—"])
        }
        try L10n.$languageOverride.withValue(.english) {
            let online = ColumnDetailFacts.file(item, medium: medium(online: true, lastSeen: try noon(2024, 1, 1)))
            #expect(online.map(\.label) == ["Created", "Modified", "Size", "Last seen"])
            #expect(online.last?.value == "now")
        }
    }

    @Test func multipleSelectionShowsTotalSize() throws {
        let items = [file("a.png", size: 1_500_000, modified: nil), file("b.png", size: 1_000_000, modified: nil)]
        L10n.$languageOverride.withValue(.german) {
            let facts = ColumnDetailFacts.multiple(items, medium: medium(online: true, lastSeen: nil))
            #expect(facts.map(\.label) == ["Erstellt", "Geändert", "Größe", "Größe gesamt", "Zuletzt gesehen"])
            #expect(facts.map(\.value) == ["—", "—", "—", ByteCountFormatter.storage.string(fromByteCount: 2_500_000), "jetzt"])
        }
    }

    @Test func footerPathSplitsInTheMiddle() {
        let four = ColumnFooterPath.split(["Studio Backup", "Projekte", "Kunde B", "Briefing_Kunde_B.txt"])
        #expect(four.head == ["Studio Backup", "Projekte"] && four.tail == ["Kunde B", "Briefing_Kunde_B.txt"])
        let three = ColumnFooterPath.split(["Studio Backup", "Projekte", "Kunde B"])
        #expect(three.head == ["Studio Backup", "Projekte"] && three.tail == ["Kunde B"])
    }

    /// Zu langer Pfad: bleibt in seiner Breite (rechts daneben kein Text), das Ende des Pfads steht am rechten Rand
    /// (letzter Teil aus Vollblöcken „█“: dort fast durchgehend Tinte), die Mitte ist ausgeblendet.
    @Test func longFooterPathStaysInsideItsWidth() async {
        let parts = ["Studio Backup Archiv 2024", "Projekte und Kunden", "Kunde B", "██████"]
        let size = CGSize(width: 320, height: 24)
        let bitmap = await PixelProbe.render(
            HStack(spacing: 0) {
                ColumnFooterPath(parts: parts).frame(width: 220, alignment: .leading)
                Color.white.frame(width: 100)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Color.black)
            .background(Color.white),
            size: size
        )
        let outside = PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: 222, y: 0, width: 96, height: 24), background: CGPoint(x: 316, y: 2))
        #expect(outside == nil, "Pfad läuft über seine Breite hinaus: \(String(describing: outside))")
        let tail = PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: 150, y: 0, width: 70, height: 24), background: CGPoint(x: 316, y: 2))
        let y = tail?.midY ?? 12
        var dark = 0
        var x: CGFloat = 196
        while x < 216 {
            if PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y)).redComponent < 0.4 { dark += 1 }
            x += 1
        }
        #expect(dark >= 16, "Ende des Pfads nicht am rechten Rand (\(dark) von 20 dunkel)")
    }

    @Test func footerCountsOneAndManyAndSelection() {
        L10n.$languageOverride.withValue(.german) {
            #expect(ColumnFooterLabel.text(selectedCount: 0, visibleCount: 1, filteredCount: 1, totalCount: 1) == "1 Objekt")
            #expect(ColumnFooterLabel.text(selectedCount: 1, visibleCount: 4, filteredCount: 4, totalCount: 4) == "4 Objekte")
            #expect(ColumnFooterLabel.text(selectedCount: 0, visibleCount: 4, filteredCount: 2, totalCount: 4) == "2 von 4 Objekten")
            #expect(ColumnFooterLabel.text(selectedCount: 2, visibleCount: 4, filteredCount: 4, totalCount: 4) == "2 von 4 ausgewählt")
        }
    }
}

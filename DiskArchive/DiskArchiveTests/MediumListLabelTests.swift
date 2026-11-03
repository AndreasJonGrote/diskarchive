//
//  MediumListLabelTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.007: Namen und Farben der Medien überall (Layout 00/19). Benannt: Icon türkis, „{Name} · {Originalname}“
//  in einer Zeile; Favorit: violett (geht vor); Fehler rot (Aufgabe 23.7). Der Medientyp steht nie als Text.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct MediumListLabelTests {
    private static func medium(customName: String? = nil, favorite: Bool = false, error: Bool = false) -> Medium {
        var medium = Medium(
            id: UUID(), name: "Studio Backup", type: .ssd, connectionStatus: .connected,
            indexStatus: error ? .error : .indexed, allowIndexing: true, autoIndexPaused: false,
            capacityTotalBytes: 1_000, capacityUsedBytes: 0, fileCount: 1, folderCount: 0, lastSeenAt: Date(),
            firstIndexedAt: Date(), lastIndexedAt: Date(), isForgotten: false, indexingProgress: 1
        )
        medium.customName = customName
        medium.isFavorite = favorite
        return medium
    }

    @Test func labelAndIconRoleForEveryState() {
        #expect(Self.medium().listLabel == MediumListLabel(name: "Studio Backup", original: nil, iconRole: .plain))
        #expect(Self.medium(customName: "Lauras Platte").listLabel
            == MediumListLabel(name: "Lauras Platte", original: "Studio Backup", iconRole: .named))
        #expect(Self.medium(favorite: true).listLabel
            == MediumListLabel(name: "Studio Backup", original: nil, iconRole: .favorite))
        // Benannt und Favorit: Violett geht vor (Layout 19), der Originalname bleibt.
        #expect(Self.medium(customName: "Lauras Platte", favorite: true).listLabel
            == MediumListLabel(name: "Lauras Platte", original: "Studio Backup", iconRole: .favorite))
        #expect(Self.medium(customName: "Lauras Platte", favorite: true, error: true).iconRole == .error)
    }

    @Test func namedIsTurquoiseAndInvertsOnSelection() {
        func hex(_ color: Color, dark: Bool) -> UInt32? {
            var result: UInt32?
            NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
                guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
                result = UInt32((c.redComponent * 255).rounded()) << 16 | UInt32((c.greenComponent * 255).rounded()) << 8
                    | UInt32((c.blueComponent * 255).rounded())
            }
            return result
        }
        #expect(hex(MediumIconRole.named.color, dark: false) == 0x00A5A8)
        #expect(hex(MediumIconRole.named.color, dark: true) == 0x00D3D5)
        #expect(hex(MediumIconRole.named.colorOnSelection, dark: false) == 0x00D3D5)
        #expect(hex(MediumIconRole.favorite.colorOnSelection, dark: false) == 0xB98CEA)
    }

    /// Jede Liste nimmt Name, Zusatz und Icon-Farbe aus `listLabel` (Popover, Seitenleiste, Tabelle Speichermedien,
    /// Suche/Favoriten: Medienkarten und Medienspalte).
    @Test func everyListUsesTheLabel() throws {
        let app = Self.sources.appendingPathComponent("DiskArchive", isDirectory: true)
        for file in [
            "MenuBar/MenuBarConnectedMediumRow.swift", "Views/ColumnBrowser/ColumnBrowserView.swift",
            "Views/Registry/RegistryTableRow.swift", "Views/Search/SearchCompactMediumCard.swift",
            "Views/Search/ObjectResultsTable.swift",
        ] {
            let text = try String(contentsOf: app.appendingPathComponent(file), encoding: .utf8)
            #expect(text.contains("listLabel"), "\(file) ohne listLabel")
            #expect(!text.contains("Text(medium.shownName)"), "\(file) zeigt nur den Namen")
        }
    }

    /// Kein sichtbarer Text nennt den Typ: kein Literal „HDD“, „SSD“, „USB“ im App-Code (Asset-Namen ausgenommen).
    @Test func noVisibleTextNamesTheType() throws {
        let app = Self.sources.appendingPathComponent("DiskArchive", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
        var hits: [String] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in text.matches(of: /"(HDD|SSD|USB)"/) {
                hits.append("\(file.lastPathComponent): \(match.output.0)")
            }
        }
        #expect(hits.isEmpty, "Typ als Text: \(hits)")
        for type in MediumType.allCases {
            let medium = Medium(
                id: UUID(), name: "Stick", type: type, connectionStatus: .connected, indexStatus: .pending,
                allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0,
                fileCount: 0, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: nil, lastIndexedAt: nil,
                isForgotten: false, indexingProgress: 0
            )
            for line in [medium.specLine, medium.dashboardSpecLine] {
                #expect(!line.contains(type.rawValue.uppercased()), "Typ in „\(line)“")
            }
        }
    }

    private static var sources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
}

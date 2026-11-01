//
//  MediumFilterToggleTests.swift
//  DiskArchiveTests
//
//  todo.0.4.2.001 (Layout ab 0.4.2 „Medium — alle ausgewählt“, „Medium — Suche „SSD““): Angehakt ist nur, was der
//  Nutzer gewählt hat. Die Kopfzeile hakt alle an („Alle Medien“) oder nimmt alle Haken weg („Alle abwählen“); mit
//  Suchtext gilt sie nur für die Treffer der Liste. Alle angehakt wirkt wie keine Auswahl: alle Medien, kein Chip.
//  Echtes Fenster außerhalb des Bildschirms, Klicks per `window.sendEvent`, Haken über Pixel.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct MediumFilterToggleTests {
    private static let size = CGSize(width: 700, height: 420)

    private static func medium(_ name: String, _ number: Int) -> Medium {
        var medium = Medium(
            id: testUUID(String(format: "D4200001-0000-4000-8000-%012d", number)),
            name: name,
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000_000_000,
            capacityUsedBytes: 400_000_000,
            fileCount: 12,
            folderCount: 2,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            isForgotten: false,
            indexingProgress: 0
        )
        medium.decision = .index
        return medium
    }

    private static let names = ["Studio Backup", "Backup SSD", "Archiv", "Reise-SSD", "NAS Klon", "Foto-SSD"]

    private static func open() async -> (AppState, PixelProbe.Session) {
        let app = AppState()
        app.media = names.enumerated().map { medium($0.element, $0.offset + 1) }
        app.mainWindowDestination = .search
        let session = PixelProbe.open(
            SearchFilterPopover()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(Color.white),
            size: size
        )
        await PixelProbe.settleOpenWindow(session)
        return (app, session)
    }

    /// Kästchen der Medium-Gruppe von oben nach unten (Kopfzeile, dann Liste): linker Rand bei x 251,5 pt, 16 pt hoch.
    /// Angehakt = Tinte im Inneren. Erwartet `rows` Listenzeilen plus Kopfzeile.
    private static func boxes(_ session: PixelProbe.Session, rows: Int) -> [(y: CGFloat, checked: Bool)]? {
        let bitmap = session.bitmap()
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: 245, y: 5))
        func ink(_ point: CGPoint, tolerance: CGFloat) -> Bool {
            let sample = PixelProbe.color(in: bitmap, at: point)
            return abs(sample.redComponent - background.redComponent) > tolerance
                || abs(sample.greenComponent - background.greenComponent) > tolerance
                || abs(sample.blueComponent - background.blueComponent) > tolerance
        }
        var runs: [ClosedRange<CGFloat>] = []
        var start: CGFloat?
        var y: CGFloat = 0
        while y < size.height {
            if ink(CGPoint(x: 251.5, y: y), tolerance: 0.04) {
                if start == nil { start = y }
            } else if let begin = start {
                runs.append(begin...y)
                start = nil
            }
            y += 0.5
        }
        // Nur Kästchen (ohne Rundung 10…16 pt); das Suchfeld darüber kann mitzählen und fällt mit `suffix` weg. Genau
        // so viele, sonst zeigt das Bild noch die vorige Liste.
        let candidates = runs.filter { $0.upperBound - $0.lowerBound >= 9 && $0.upperBound - $0.lowerBound <= 17.5 }
        guard candidates.count == rows + 1 || candidates.count == rows + 2 else { return nil }
        return candidates.suffix(rows + 1).map { run in
            let mid = (run.lowerBound + run.upperBound) / 2
            var checked = false
            for dx in stride(from: -4, through: 4, by: 0.5) {
                for dy in stride(from: -3, through: 3, by: 0.5) where ink(CGPoint(x: 259 + dx, y: mid + dy), tolerance: 0.2) {
                    checked = true
                }
            }
            return (mid, checked)
        }
    }

    /// Wartet, bis die Kästchen `expected` zeigen (Kopfzeile zuerst).
    private static func expectBoxes(_ session: PixelProbe.Session, _ expected: [Bool], _ comment: String) async -> [(y: CGFloat, checked: Bool)] {
        var last: [(y: CGFloat, checked: Bool)] = []
        let ok = await waitUntil(timeout: 3) {
            session.window.contentView?.layoutSubtreeIfNeeded()
            last = boxes(session, rows: expected.count - 1) ?? []
            return last.map(\.checked) == expected
        }
        #expect(ok, "\(comment): Haken \(last.map(\.checked)), erwartet \(expected)")
        return last
    }

    /// Tippen ins Feld „Medium suchen …“: Text ins echte Textfeld, Änderung über dessen Delegate wie beim Tippen.
    private static func type(_ text: String, _ session: PixelProbe.Session) throws {
        let fields = ColumnAutoScrollTestSupport.allViews(of: NSTextField.self, in: session.window.contentView)
            .filter { $0.isEditable }
        let field = try #require(fields.first { field in
            let frame = field.convert(field.bounds, to: nil)
            return frame.minX > 251 && frame.minX < 300
        }, "Feld „Medium suchen …“ nicht gefunden (\(fields.count) Felder)")
        field.stringValue = text
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        session.window.contentView?.layoutSubtreeIfNeeded()
    }

    private static func at(_ shown: [(y: CGFloat, checked: Bool)], _ index: Int) -> (y: CGFloat, checked: Bool)? {
        shown.indices.contains(index) ? shown[index] : nil
    }

    private static func click(_ session: PixelProbe.Session, _ box: (y: CGFloat, checked: Bool)?) throws {
        let target = try #require(box, "Kästchen fehlt")
        session.click(at: CGPoint(x: 259, y: target.y), settle: 0.15)
    }

    private static func title(_ app: AppState, query: String, targets: [String]) -> String {
        let media = app.indexedMedia.filter { targets.contains($0.name) }
        return SearchFilterPopover.allMediaToggleTitle(query: query, allChecked: app.searchState.filters.areAllMediaChecked(media))
    }

    /// Alle Medien durchsucht: kein Medium-Filter, also auch kein Chip in der Filterleiste.
    private static func searchesAllMedia(_ app: AppState) -> Bool {
        app.searchState.filters.selectAllMedia
            && app.indexedMedia.allSatisfy { SearchItemFilter.matchesMedium($0, filters: app.searchState.filters) }
    }

    @Test func startsWithoutChecksAndTogglesAll() async throws {
        let (app, session) = await Self.open()
        defer { session.close() }
        let none = Array(repeating: false, count: 7)
        let all = Array(repeating: true, count: 7)

        // 1. Ausgangszustand: kein Haken, „Alle Medien“, Suche über alle Medien.
        var shown = await Self.expectBoxes(session, none, "Ausgangszustand")
        #expect(Self.title(app, query: "", targets: Self.names) == LayoutCopy.searchFilterAllMedia)
        #expect(Self.searchesAllMedia(app))

        // 2. „Alle Medien“ → alle angehakt, „Alle abwählen“, weiter alle Medien ohne Chip; Klick → kein Haken.
        try Self.click(session, shown.first)
        shown = await Self.expectBoxes(session, all, "nach „Alle Medien“")
        #expect(Self.title(app, query: "", targets: Self.names) == LayoutCopy.searchFilterDeselectAll)
        #expect(Self.searchesAllMedia(app), "alle angehakt wirkt nicht wie alle Medien")
        #expect(app.searchState.filters.hasSameHits(as: SearchFilters()), "alle angehakt ändert die Treffermenge")
        try Self.click(session, shown.first)
        shown = await Self.expectBoxes(session, none, "nach „Alle abwählen“")
        #expect(Self.title(app, query: "", targets: Self.names) == LayoutCopy.searchFilterAllMedia)
        #expect(Self.searchesAllMedia(app))

        // 3. Zwei einzeln → Teilmenge, „Alle Medien“; Klick → alle angehakt.
        try Self.click(session, Self.at(shown, 1))
        try Self.click(session, Self.at(shown, 3))
        shown = await Self.expectBoxes(session, [false, true, false, true, false, false, false], "zwei einzeln")
        #expect(Self.title(app, query: "", targets: Self.names) == LayoutCopy.searchFilterAllMedia)
        #expect(!app.searchState.filters.selectAllMedia, "zwei Medien sind keine Teilmenge")
        try Self.click(session, shown.first)
        _ = await Self.expectBoxes(session, all, "nach „Alle Medien“ mit zwei gewählten")
        #expect(Self.searchesAllMedia(app))
    }

    /// todo.0.4.2.002 (Gegenprobe 5): Die Liste findet ein Medium über den eigenen und den Originalnamen.
    @Test func listFindsCustomAndOriginalName() async throws {
        let (app, session) = await Self.open()
        defer { session.close() }
        let studio = try #require(app.indexedMedia.first { $0.name == "Studio Backup" })
        app.updateMedium(id: studio.id) { $0.customName = "Lauras Platte" }
        _ = await Self.expectBoxes(session, Array(repeating: false, count: 7), "Ausgangszustand")
        for query in ["Laura", "Studio"] {
            try Self.type(query, session)
            let shown = await Self.expectBoxes(session, [false, false], "Suche „\(query)“: ein Treffer")
            try Self.click(session, Self.at(shown, 1))
            #expect(app.searchState.filters.mediumIDs == [studio.id], "„\(query)“ findet nicht „Lauras Platte“")
            try Self.click(session, Self.at(shown, 1))
        }
    }

    @Test func searchTextTogglesOnlyTheMatches() async throws {
        let (app, session) = await Self.open()
        defer { session.close() }
        let ssds = ["Backup SSD", "Reise-SSD", "Foto-SSD"]
        let archiv = try #require(app.indexedMedia.first { $0.name == "Archiv" })
        let ssdIDs = Set(app.indexedMedia.filter { ssds.contains($0.name) }.map(\.id))

        // 4. „Archiv“ angehakt, Suchtext „SSD“ → „… anwählen“; Klick hakt die drei an, „Archiv“ bleibt.
        var shown = await Self.expectBoxes(session, Array(repeating: false, count: 7), "Ausgangszustand")
        try Self.click(session, Self.at(shown, 3))
        _ = await Self.expectBoxes(session, [false, false, false, true, false, false, false], "Archiv angehakt")
        try Self.type("SSD", session)
        shown = await Self.expectBoxes(session, [false, false, false, false], "Suche „SSD“")
        #expect(Self.title(app, query: "SSD", targets: ssds) == LayoutCopy.searchFilterSelectMatching("SSD"))
        try Self.click(session, shown.first)
        shown = await Self.expectBoxes(session, [true, true, true, true], "nach „Alle Medien mit „SSD“ anwählen“")
        #expect(app.searchState.filters.mediumIDs == ssdIDs.union([archiv.id]), "Auswahl \(app.searchState.filters.mediumIDs.count)")
        #expect(!app.searchState.filters.selectAllMedia)
        #expect(Self.title(app, query: "SSD", targets: ssds) == LayoutCopy.searchFilterDeselectMatching("SSD"))
        try Self.click(session, shown.first)
        _ = await Self.expectBoxes(session, [false, false, false, false], "nach „… abwählen“")
        #expect(app.searchState.filters.mediumIDs == [archiv.id], "Archiv nicht mehr gewählt oder SSDs noch da")
        #expect(!app.searchState.filters.selectAllMedia)

        // 5. Suchtext leeren → Kopfzeile wieder für alle Medien.
        try Self.type("", session)
        shown = await Self.expectBoxes(session, [false, false, false, true, false, false, false], "Suchtext geleert")
        #expect(Self.title(app, query: "", targets: Self.names) == LayoutCopy.searchFilterAllMedia)
        try Self.click(session, shown.first)
        _ = await Self.expectBoxes(session, Array(repeating: true, count: 7), "alle nach geleertem Suchtext")
        #expect(Self.title(app, query: "", targets: Self.names) == LayoutCopy.searchFilterDeselectAll)
        #expect(Self.searchesAllMedia(app))
    }
}
}

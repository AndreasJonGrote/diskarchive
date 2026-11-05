//
//  SmallTextsAndSingularTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.023 (Layout 07.03.02, 12, 19, 20): Treffer-Kopf der Medium-Suche mit fettem Suchbegriff, „Ordnernamen
//  ignorieren“ bei Ordnern, Einzahl und Mehrzahl je Stelle (1 und 2), Datumsregel bis „vor {1} Monaten“.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct SmallTextsAndSingularTests {
    @Test func mediumSearchHeadingAndBoldTerm() {
        L10n.$languageOverride.withValue(.german) {
            #expect(MediumSearchHeading.title(query: "", matches: 5) == "ALLE SPEICHERMEDIEN")
            #expect(MediumSearchHeading.title(query: "Backup", matches: 2) == "2 TREFFER")
            #expect(MediumSearchHeading.title(query: "Backup", matches: 1) == "1 TREFFER", "„Treffer“ in beiden Formen gleich")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(MediumSearchHeading.title(query: "Backup", matches: 2) == "2 MATCHES")
        }
        #expect(HighlightedName.segments("Studio Backup", term: "back") == [
            .init(text: "Studio ", isMatch: false), .init(text: "Back", isMatch: true), .init(text: "up", isMatch: false),
        ])
        #expect(HighlightedName.segments("Studio Backup", term: " ") == [.init(text: "Studio Backup", isMatch: false)])
        #expect(HighlightedName.segments("Studio Backup", term: nil) == [.init(text: "Studio Backup", isMatch: false)])
    }

    @Test func ignoreNameEntryFollowsTheObjectKind() {
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.contextIgnoreName(for: [.folder]) == "Ordnernamen ignorieren")
            #expect(LayoutCopy.contextIgnoreName(for: [.file]) == "Dateinamen ignorieren")
            #expect(LayoutCopy.contextIgnoreName(for: [.folder, .folder]) == "Ordnernamen ignorieren")
            #expect(LayoutCopy.contextIgnoreName(for: [.folder, .file]) == "Dateinamen ignorieren")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(LayoutCopy.contextIgnoreName(for: [.folder]) == "Ignore Folder Name")
        }
    }

    @Test func oneAndTwoAtEveryCountedText() {
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.mediumFilesCount(1) == "1 Datei")
            #expect(LayoutCopy.mediumFilesCount(2) == "2 Dateien")
            #expect(ObjectCountFormatting.label(filtered: 1, total: 1) == "1 Objekt")
            #expect(ObjectCountFormatting.label(filtered: 2, total: 2) == "2 Objekte")
            #expect(ColumnSizeSummary.objectLine(count: 1) == "1 Objekt")
            #expect(LayoutCopy.loadingSearchTitle(media: 1, files: 1) == "Dein 1 Speichermedium und 1 Datei werden durchsucht …")
            #expect(LayoutCopy.loadingSearchTitle(media: 2, files: 2) == "Deine 2 Speichermedien und 2 Dateien werden durchsucht …")
            #expect(LayoutCopy.menuShowOneResult == "1 Ergebnis anzeigen")
            #expect(LayoutCopy.menuShowAllResults(2) == "Alle 2 Ergebnisse anzeigen")
            #expect(LayoutCopy.noticeFavoritesOnline(name: "A", count: 1) == "Medium „A“ mit 1 Favoriten ist online.")
            #expect(LayoutCopy.noticeIndexedComplete("A", count: 1) == "Medium „A“ ist vollständig indiziert – 1 Objekt.")
            #expect(LayoutCopy.noticeIndexedComplete("A", count: 2) == "Medium „A“ ist vollständig indiziert – 2 Objekte.")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(LayoutCopy.mediumFilesCount(1) == "1 file")
            #expect(ObjectCountFormatting.label(filtered: 1, total: 1) == "1 item")
            #expect(LayoutCopy.noticeIndexedComplete("A", count: 1) == "“A” is fully indexed – 1 item.")
        }
    }

    @Test func dateRuleUpToMonths() throws {
        func noon(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
            try #require(Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        }
        var medium = Medium(
            id: UUID(), name: "A", type: .usb, connectionStatus: .offline, indexStatus: .indexed, allowIndexing: true,
            autoIndexPaused: false, capacityTotalBytes: 1, capacityUsedBytes: 0, fileCount: 0, folderCount: 0,
            lastSeenAt: nil, firstIndexedAt: nil, lastIndexedAt: nil, isForgotten: false, indexingProgress: 1
        )
        let now = try noon(2026, 5, 20)
        try L10n.$languageOverride.withValue(.german) {
            medium.lastSeenAt = try noon(2026, 5, 18)
            #expect(medium.lastSeenDescription(now: now) == "vor 2 Tagen")
            medium.lastSeenAt = try noon(2026, 4, 16)
            #expect(medium.lastSeenDescription(now: now) == "vor 34 Tagen")
            medium.lastSeenAt = try noon(2026, 2, 20)
            #expect(medium.lastSeenDescription(now: now) == "vor 3 Monaten")
            medium.connectionStatus = .connected
            #expect(medium.lastSeenDescription(now: now) == "jetzt")
        }
    }
}

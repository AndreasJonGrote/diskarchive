//
//  LocalizedFormattingTests.swift
//  diskindexTests
//
//  bug.0.4.058 (REPORT 104): Überschriften über den Katalog, Datum/Größe/Zahl nach App-Sprache.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct LocalizedFormattingTests {
    private func medium(fileCount: Int) -> Medium {
        Medium(
            id: UUID(),
            name: "Archiv",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 64_000_000_000,
            capacityUsedBytes: 0,
            fileCount: fileCount,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0
        )
    }

    @Test func headersComeFromCatalogInBothLanguages() {
        let german = L10n.$languageOverride.withValue(.german) {
            [LayoutCopy.popoverGroupMedia, LayoutCopy.popoverGroupFiles, LayoutCopy.popoverGroupFolders,
             LayoutCopy.menuConnectedHeader, LayoutCopy.searchFilterGroupFileType,
             LayoutCopy.searchFilterGroupExtension, LayoutCopy.searchFilterGroupMedium, LayoutCopy.searchFilterGroupAge]
        }
        let english = L10n.$languageOverride.withValue(.english) {
            [LayoutCopy.popoverGroupMedia, LayoutCopy.popoverGroupFiles, LayoutCopy.popoverGroupFolders,
             LayoutCopy.menuConnectedHeader, LayoutCopy.searchFilterGroupFileType,
             LayoutCopy.searchFilterGroupExtension, LayoutCopy.searchFilterGroupMedium, LayoutCopy.searchFilterGroupAge]
        }
        #expect(german == ["SPEICHERMEDIEN", "DATEIEN", "ORDNER", "ANGESCHLOSSEN", "DATEITYP", "DATEIENDUNG", "MEDIUM", "ALTER"])
        #expect(english == ["STORAGE MEDIA", "FILES", "FOLDERS", "CONNECTED", "FILE TYPE", "FILE EXTENSION", "MEDIUM", "AGE"])
    }

    @Test func popoverGroupTitlesFollowAppLanguage() {
        let found = medium(fileCount: 1)
        let titles = L10n.$languageOverride.withValue(.english) {
            PopoverSearch.grouped(media: [found], files: [], folders: [], totalCount: 1, allMedia: [found]).groups.map(\.title)
        }
        #expect(titles.contains("STORAGE MEDIA"), "Gruppen: \(titles)")
        #expect(!titles.contains("SPEICHERMEDIEN"))
    }

    @Test func datesUseAppLanguageNotSystem() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 13
        components.hour = 12
        let date = try #require(Calendar(identifier: .gregorian).date(from: components))
        let german = L10n.$languageOverride.withValue(.german) { IndexedDateFormatting.abbreviatedDay(date) }
        let english = L10n.$languageOverride.withValue(.english) { IndexedDateFormatting.abbreviatedDay(date) }
        #expect(german.contains("Okt"), "\(german)")
        #expect(english.contains("Oct"), "\(english)")
    }

    @Test func byteCountsUseAppLanguage() {
        let german = L10n.$languageOverride.withValue(.german) { ByteCountFormatter.storage.string(fromByteCount: 1_500_000_000) }
        let english = L10n.$languageOverride.withValue(.english) { ByteCountFormatter.storage.string(fromByteCount: 1_500_000_000) }
        // Leerzeichen kann geschützt sein (U+00A0); verglichen wird die Zahl samt Einheit.
        #expect(german.replacingOccurrences(of: "\u{00A0}", with: " ") == "1,5 GB", "\(german)")
        #expect(english.replacingOccurrences(of: "\u{00A0}", with: " ") == "1.5 GB", "\(english)")
    }

    @Test func countsAreGroupedByAppLanguage() {
        let germanLine = L10n.$languageOverride.withValue(.german) { ColumnSizeSummary.objectLine(count: 50_000) }
        let englishLine = L10n.$languageOverride.withValue(.english) { ColumnSizeSummary.objectLine(count: 50_000) }
        #expect(germanLine.contains("50.000"), "\(germanLine)")
        #expect(englishLine.contains("50,000"), "\(englishLine)")

        let englishSpec = L10n.$languageOverride.withValue(.english) { medium(fileCount: 50_000).specLine }
        #expect(englishSpec.contains("50,000"), "\(englishSpec)")
    }
}

//
//  EnglishLocalizationTests.swift
//  diskindexTests
//
//  Aufgabe 203 — sichtbare Texte und Formate folgen der App-Sprache. Sprache nur über
//  `L10n.languageOverride` (Task-lokal, kein globaler Zustand).
//

import Foundation
import Testing
import UserNotifications
@testable import diskindex

@Suite @MainActor
struct EnglishLocalizationTests {
    private func target(_ name: String) -> ObjectContextTarget {
        ObjectContextTarget(id: UUID(), name: name, kind: .file, mediumID: UUID())
    }

    private func contextTitles() -> [String] {
        multipleContextMenuGroups([target("a.mp3"), target("b.txt")], appState: AppState()).flatMap { $0 }.map(\.title)
    }

    @Test func contextMenuFollowsTheLanguage() {
        let english = L10n.$languageOverride.withValue(.english) { contextTitles() }
        #expect(english == [
            "Show in Finder", "Add to Favorites", "Search by Name",
            "Search by Extension", "Ignore File Name", "Ignore File Type",
        ])
        let german = L10n.$languageOverride.withValue(.german) { contextTitles() }
        #expect(german == [
            "Im Finder anzeigen", "Als Favorit markieren", "Nach Namen suchen",
            "Nach Dateiendung suchen", "Dateinamen ignorieren", "Dateitypen ignorieren",
        ])
    }

    @Test func menuBarMenuAgeFilterFooterAndReasonFollowTheLanguage() {
        L10n.$languageOverride.withValue(.english) {
            #expect(LayoutCopy.menuBarShowApp == "Show Disk Archive")
            #expect(LayoutCopy.menuBarLaunchAtLogin == "Open at Login")
            #expect(LayoutCopy.menuBarRevealLog == "Show Log in Finder")
            #expect(LayoutCopy.menuBarQuit == "Quit Disk Archive")
            #expect(SearchAgeFilter.last24Hours.label == "Last 24 Hours")
            #expect(SearchAgeFilter.older.label == "Older")
            #expect(ColumnFooterLabel.text(selectedCount: 2, visibleCount: 3, filteredCount: 3, totalCount: 3) == "2 of 3 selected")
            #expect(ColumnFooterLabel.text(selectedCount: 1, visibleCount: 3, filteredCount: 3, totalCount: 3) == "3 items")
            #expect(IndexFailureReason.disconnected.line == "The connection to the medium was interrupted.")
            #expect(IndexFailureReason.diskSpace.line == "There is not enough free space on this Mac.")
        }
        L10n.$languageOverride.withValue(.german) {
            #expect(SearchAgeFilter.last24Hours.label == "Letzte 24 Stunden")
            #expect(ColumnFooterLabel.text(selectedCount: 2, visibleCount: 3, filteredCount: 3, totalCount: 3) == "2 von 3 ausgewählt")
            #expect(IndexFailureReason.timeout.line == "Das Medium reagiert nicht.")
        }
    }

    /// Aufgabe 214: frühere Vorschlagstexte sind normale Texte (de unverändert, en neu).
    @Test func formerProposalTextsAreLocalized() {
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.loadingSearchTitle(media: 12, files: 48_230) == "Deine 12 Speichermedien und 48.230 Dateien werden durchsucht …")
            #expect(LayoutCopy.loadingFavoritesTitle(media: 1, files: 1) == "Dein 1 Speichermedium und 1 Datei werden gefiltert …")
            #expect(LayoutCopy.loadingOneMoment == "Einen Moment bitte.")
            #expect(LayoutCopy.noResults("abc") == "Keine Ergebnisse für „abc“")
            #expect(LayoutCopy.mediumFilterCount(2, 5) == "2 von 5 Medien")
            #expect(LayoutCopy.folderChangeExclusions == "Ausschlüsse ändern")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(LayoutCopy.loadingSearchTitle(media: 12, files: 48_230) == "Searching your 12 storage media and 48,230 files …")
            #expect(LayoutCopy.loadingFavoritesTitle(media: 1, files: 1) == "Filtering your 1 storage medium and 1 file …")
            #expect(LayoutCopy.loadingOneMoment == "One moment, please.")
            #expect(LayoutCopy.noResults("abc") == "No results for “abc”")
            #expect(LayoutCopy.mediumFilterCount(2, 5) == "2 of 5 media")
            #expect(LayoutCopy.folderChangeExclusions == "Change Exclusions")
            #expect(LayoutCopy.noticePrune == "Index cleaned up.")
        }
    }

    @Test func noticeBodyAndNumbersFollowTheLanguage() throws {
        func body(_ language: AppDisplayLanguage) -> String? {
            var captured: String?
            let hooks = NoticeTestHooks(post: { request, _ in captured = request.content.body })
            SystemNotice.$testHooks.withValue(hooks) {
                L10n.$languageOverride.withValue(language) {
                    SystemNotice.postIndexedComplete(
                        name: "Stick",
                        objectCount: 1_234_567,
                        durationSeconds: 120,
                        settings: AppSettings()
                    )
                }
            }
            return captured
        }
        #expect(try #require(body(.english)) == "Medium “Stick” is fully indexed – 1,234,567 items")
        #expect(try #require(body(.german)) == "Medium „Stick“ ist vollständig indiziert – 1.234.567 Objekte")
        L10n.$languageOverride.withValue(.english) {
            #expect(DisplayNumberFormat.groupedInteger(1_234_567) == "1,234,567")
        }
        L10n.$languageOverride.withValue(.german) {
            #expect(DisplayNumberFormat.groupedInteger(1_234_567) == "1.234.567")
        }
    }

    // MARK: - Quell-Scan

    /// Ausnahmen: Datei (Teilpfad) + Textstück der Zeile, jeweils mit Grund.
    private static let exceptions: [(file: String, fragment: String, reason: String)] = [
        ("App/AppDelegate.swift", "logger.", "Protokollzeile, kein UI"),
        ("App/LaunchAtLogin.swift", "logger.", "Protokollzeile, kein UI"),
        ("App/IssueTracker.swift", "Disk Archive/outbox", "Legacy-Outbox für Migration (0.3.1)"),
        ("Storage/V3/IndexStoreV3.swift", "Disk Archive", "Ordnername auf der Platte"),
        ("App/DiskIndexLog.swift", "Disk Archive", "Dateiname des Absturzberichts"),
        ("MenuBar/MenuBarController.swift", "Absturz testen", "nur Debug-Menü (#if DEBUG)"),
        ("Indexing/IgnoreMatcher.swift", "System Volume Information", "Systemordner-Name"),
        ("Recognition/VolumeLookup.swift", "Time Machine Backups", "Systemname des Volumes"),
        ("Indexing/IndexingVolumeTuning.swift", "Media Solid State", "IOKit-Schlüssel"),
    ]

    private func swiftFiles(under root: URL) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Findet feste deutsche Texte außerhalb von `L10n`/`LayoutCopy` (Muster aus TODO 203 a).
    private func sourceHits(in sourceRoot: URL) throws -> [String] {
        let pattern = try NSRegularExpression(pattern: "\"[A-ZÄÖÜ][a-zäöüß]+ [^\"]*\"")
        var hits: [String] = []
        for file in swiftFiles(under: sourceRoot) {
            let relative = String(file.path.dropFirst(sourceRoot.path.count + 1))
            if relative.hasPrefix("DebugTools/") || relative.hasPrefix("Localization/") { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                guard pattern.firstMatch(in: line, range: range) != nil else { continue }
                if ["record(", "Logger", "L10n"].contains(where: line.contains) { continue }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                let allowed = Self.exceptions.contains { relative.hasSuffix($0.file) && ($0.fragment.isEmpty || line.contains($0.fragment)) }
                if !allowed { hits.append("\(relative):\(index + 1): \(trimmed)") }
            }
        }
        return hits
    }

    @Test func noNewHardCodedGermanTextsInTheSources() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("diskindex", isDirectory: true)
        let hits = try sourceHits(in: root)
        #expect(hits.isEmpty, "feste deutsche Texte: \(hits.joined(separator: " | "))")
    }

    @Test func everyExceptionStillMatchesALine() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("diskindex", isDirectory: true)
        for exception in Self.exceptions {
            let file = root.appendingPathComponent(exception.file)
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(exception.fragment.isEmpty || text.contains(exception.fragment), "Ausnahme veraltet: \(exception.file) \(exception.fragment)")
            #expect(!exception.reason.isEmpty)
        }
    }
}

//
//  LayoutCopyTests.swift
//  DiskArchiveTests
//

import AppKit
import Foundation
import Testing
@testable import DiskArchive

struct LayoutCopyTests {
    /// todo.0.4.3.005: Textquelle ist Sektion 20 (`layout/App-Layout 20 Texte.json`, Deutsch und Englisch). Jeder
    /// Katalog-Schlüssel: Der deutsche Wert steht in 20, der englische ist der zu diesem deutschen Text in 20.
    /// Platzhalter `%1$@`/`%lld` gelten als `{1}`; Leerzeichen am Rand zählen nicht (Textteile wie „ belegt“).
    @Test func catalogTextsMatchSectionTwenty() throws {
        let root = Self.projectRoot
        let section = try sectionTwenty(root: root)
        let catalog = try catalogTexts(root: root)
        var mismatches: [String] = []
        for (key, text) in catalog.sorted(by: { $0.key < $1.key }) {
            if pendingPackage[key] != nil || openQuestions.contains(key) { continue }
            let german = Self.normalized(text.de)
            guard let english = section[german] else {
                mismatches.append("\(key): de „\(text.de)“ fehlt in 20")
                continue
            }
            if Self.normalized(text.en) != english {
                mismatches.append("\(key): en „\(text.en)“, laut 20 „\(english)“")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) Abweichungen:\n\(mismatches.joined(separator: "\n"))")
        // Die Listen nennen nur Schlüssel, die es im Katalog gibt.
        let stale = (Array(pendingPackage.keys) + Array(openQuestions)).filter { catalog[$0] == nil }
        #expect(stale.isEmpty, "nicht im Katalog: \(stale.sorted())")
    }

    @Test func columnAndFilterAuditStringsFromLayoutAreInLayoutCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogGerman = try germanCopyStringsFromCatalog(root: root)
        let wanted = [
            "ALLE SPEICHERMEDIEN",
            "DETAIL",
            "Größe gesamt:",
            "Geändert:",
            "Größe:",
            "Zuletzt gesehen:",
            "Filter",
        ]
        let missing = wanted.filter { !catalogGerman.contains($0) }
        #expect(missing.isEmpty, "fehlt in LayoutCopy/xcstrings: \(missing.joined(separator: " | "))")
        #expect(LayoutCopy.columnAllMediaHeading == "ALLE SPEICHERMEDIEN")
        #expect(LayoutCopy.columnOfflineBanner == "Offline")
        #expect(LayoutCopy.columnDetailHeading == "DETAIL")
        #expect(LayoutCopy.filterToolbarButton == "Filter")
    }

    @Test func unlimitedDepthShowsTwoCrumbs() {
        let crumbs = ScanDepthExampleFormatting.crumbs(depth: 5, unlimited: true)
        #expect(crumbs.map(\.text) == [LayoutCopy.diskCrumb, LayoutCopy.maxDepthCrumb])
    }

    @Test func theMediaFilterSaysOffline() {
        #expect(RegistryFilter.offline.label == LayoutCopy.filterOffline)
    }

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Platzhalter vereinheitlichen (`%1$@`, `%lld`, `{1}` → `{}`, `%%` → `%`), Rand-Leerzeichen weg. Die Nummer zählt
    /// nicht: „Dein 1 Speichermedium und {2} Dateien …“ hat im Katalog nur ein Argument.
    private static func normalized(_ text: String) -> String {
        var result = ""
        var rest = Substring(text)
        let pattern = /%(?:\d+\$)?(?:lld|ld|d|@)|\{\d+\}/
        while let match = rest.firstMatch(of: pattern) {
            result += rest[..<match.range.lowerBound]
            result += "{}"
            rest = rest[match.range.upperBound...]
        }
        result += rest
        return result.replacingOccurrences(of: "%%", with: "%").trimmingCharacters(in: .whitespaces)
    }

    /// Deutsch → Englisch aus Sektion 20.
    private func sectionTwenty(root: URL) throws -> [String: String] {
        let data = try Data(contentsOf: root.appendingPathComponent("layout/App-Layout 20 Texte.json"))
        let sections = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        var map: [String: String] = [:]
        for section in sections {
            for row in try #require(section["rows"] as? [[String: Any]]) {
                let de = try #require(row["de"] as? String)
                map[Self.normalized(de)] = Self.normalized(try #require(row["en"] as? String))
            }
        }
        return map
    }

    /// Alle Schlüssel mit deutschem und englischem Wert (Symbole wie „→“ ohne Übersetzung zählen nicht).
    private func catalogTexts(root: URL) throws -> [String: (de: String, en: String)] {
        let url = root.appendingPathComponent("DiskArchive/DiskArchive/Localization/Localizable.xcstrings")
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        var texts: [String: (de: String, en: String)] = [:]
        for (key, payload) in strings {
            guard let localizations = (payload as? [String: Any])?["localizations"] as? [String: Any],
                  let de = Self.value(localizations["de"]), let en = Self.value(localizations["en"])
            else { continue }
            texts[key] = (de, en)
        }
        return texts
    }

    private static func value(_ localization: Any?) -> String? {
        ((localization as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
    }

    /// Schlüssel, deren Text erst ein späteres Paket von 0.4.3 bringt (Schlüssel → Paket); jedes Paket leert seinen Teil.
    private var pendingPackage: [String: Int] {
        [
            // 59: Kachel, „Kein Zugriff …“, Details-Fenster und Benennen
            "copy.indexed.line": 59, "copy.indexed.never": 59, "copy.medium.not_indexed_yet": 59,
            "copy.medium.no_access": 59, "copy.detail.custom_name": 59, "copy.medium.used_free": 59,
            "copy.medium.indexed_value": 59,
            // 60: Popover-Suche, -Leerzustände, Status
            "copy.popover_search.group.files": 60, "copy.popover_search.group.folders": 60,
            "copy.search.popover_no_hits": 60,
            // 61: Spaltenansicht-Zustände, Detail-Labels, Einstellungen Dateien & Ordner
            "copy.column.detail.last_seen": 61, "copy.column.detail.modified": 61, "copy.column.detail.size": 61,
            "copy.column.detail.total_size": 61, "copy.date.today": 61, "copy.column.filter.reset": 61,
            "copy.column.folder_not_indexed_title": 61, "copy.folder.change_exclusions": 61,
            "copy.folder.excluded": 61, "copy.folder.unreadable": 61,
            "copy.settings.artifacts.text": 61, "copy.settings.exclude.text": 61, "copy.settings.hidden.text": 61,
            "copy.settings.scan_depth.text": 61,
            // 62: Banner, Update-Countdown, Fehlerdialoge, Über
            "copy.update.available.beta_countdown": 62, "copy.version_lock.banner.api": 62,
            "copy.version_lock.banner.beta": 62, "copy.version_lock.banner.build": 62, "copy.menubar.about": 62,
        ]
    }

    /// Schlüssel ohne Text in 20 bzw. mit Layout-Querverweis: Frage an den Host (Regel 2), Text bleibt.
    private var openQuestions: Set<String> {
        [
            // Reiter „Speichermedien“ der Einstellungen: in 20 nur „SPEICHERMEDIEN“ (Überschrift)
            "copy.settings.tab.media",
            // Bedienhilfe-Name der Übersicht in der Werkzeugleiste: in 20 nur „Zur Übersicht“ (neu)
            "copy.a11y.overview",
            // Hinweis „Einstellungen konnten nicht gelesen werden …“: nicht in 20
            "copy.settings.unreadable.notice",
            // Deutsch ohne den Satz „Alle Mitteilungstexte und Bedingungen: 18.“ (Verweis auf die Layout-Sektion)
            "copy.settings.notices.text",
        ]
    }

    private func germanCopyStringsFromCatalog(root: URL) throws -> String {
        let url = root.appendingPathComponent("DiskArchive/DiskArchive/Localization/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        var values: [String] = []
        for (key, payload) in strings where key.hasPrefix("copy.") {
            guard let entry = payload as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let de = localizations["de"] as? [String: Any],
                  let unit = de["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String
            else { continue }
            values.append(value)
        }
        return values.joined(separator: "\n")
    }
}

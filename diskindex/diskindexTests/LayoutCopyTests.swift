//
//  LayoutCopyTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import Testing
@testable import diskindex

struct LayoutCopyTests {
    @Test func windowLinesFromTheLayoutAreInLayoutCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        // todo.0.4.049: für 0.4.0 gilt das Layout bis 0.4.1.
        let html = try String(contentsOf: root.appendingPathComponent("layout/bis 0.4.1/Disk Index App.dc.html"), encoding: .utf8)
        let layoutCopySource = try String(
            contentsOf: root.appendingPathComponent("diskindex/diskindex/DesignSystem/LayoutCopy.swift"),
            encoding: .utf8
        )
        let catalogGerman = try germanCopyStringsFromCatalog(root: root)
        let source = layoutCopySource + "\n" + catalogGerman
        // todo.0.4.2.003: Option entfällt (Nutzer 30.10.)
        let wanted = windowLines(from: html).filter { $0 != "Ordner weiterhin anzeigen" }
        let missing = wanted.filter { !source.contains($0) }
        #expect(missing.isEmpty, "fehlt in LayoutCopy: \(missing.joined(separator: " | "))")
    }

    @Test func columnAndFilterAuditStringsFromLayoutAreInLayoutCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogGerman = try germanCopyStringsFromCatalog(root: root)
        let wanted = [
            "ALLE SPEICHERMEDIEN",
            "Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen",
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
        #expect(LayoutCopy.columnOfflineBanner.contains("Offline —"))
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

    private func windowLines(from html: String) -> [String] {
        let sectionMarkers = ["02.", "05.", "06.", "13.", "14."]
        var collected: [String] = []
        for marker in sectionMarkers {
            guard let block = lightSectionBlock(in: html, marker: marker) else { continue }
            var body = block
            if marker == "05.", let stop = body.range(of: "BESTÄTIGUNGSMODUS") {
                body = String(body[..<stop.lowerBound])
            }
            let plain = stripHTML(body)
            for raw in plain.components(separatedBy: .newlines) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.contains("{{") || line.isEmpty { continue }
                if structural.contains(line) || exceptions.contains(line) { continue }
                if line.hasPrefix("TAB ") || line.contains(" — ") { continue }
                if line.hasPrefix("0") && line.contains(" — ") { continue }
                if line == "DARK MODE" { continue }
                if line.hasPrefix("<") || line.contains("<div") { continue }
                if line.count > 120 { continue }
                if line == "1  2  3  4  5+" || line == "! Fehler" { continue }
                if line.hasPrefix("Gesamt ") || line.hasPrefix("Belegt /") || line.hasPrefix("Dateien /") { continue }
                if line.hasPrefix("Zuletzt gesehen  ") { continue }
                if line.hasPrefix("Disk Index  ") { continue }
                collected.append(line)
            }
        }
        return collected
    }

    private func lightSectionBlock(in html: String, marker: String) -> String? {
        let open = "<!-- ============ \(marker)"
        guard let start = html.range(of: open) else { return nil }
        let tail = html[start.lowerBound...]
        guard let dark = tail.range(of: "data-screen-label=\"Dark Mode\"") else {
            guard let next = tail.range(of: "<!-- ============ ", range: tail.index(tail.startIndex, offsetBy: min(80, tail.count))..<tail.endIndex) else {
                return String(tail)
            }
            return String(tail[..<next.lowerBound])
        }
        return String(tail[..<dark.lowerBound])
    }

    private func stripHTML(_ fragment: String) -> String {
        var text = fragment
        let patterns = [
            #"(?s)<script[^>]*>.*?</script>"#,
            #"(?s)<style[^>]*>.*?</style>"#,
            #"<!--.*?-->"#,
        ]
        for pattern in patterns {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</(div|p|h[1-6]|li|tr|button|label)>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8212;", with: "—")
        return text
    }

    private var structural: Set<String> {
        ["MODAL", "ANSICHT", "ANSICHT (POPOVER)", "MACOS-MITTEILUNG", "RUHEZUSTAND"]
    }

    /// Beispielwerte aus dem Layout, keine festen Fenstertexte.
    private func germanCopyStringsFromCatalog(root: URL) throws -> String {
        let url = root.appendingPathComponent("diskindex/diskindex/Localization/Localizable.xcstrings")
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

    private var exceptions: Set<String> {
        [
            "Studio Backup", "Backup SSD", "Archiv 2019–2021", "Foto-SSD", "NAS Klon",
            "Alter USB-Stick", "Externe Platte 5", "Reise-SSD", "node_modules", "*.tmp", "Cache",
            "Studio Backup — HDD", "92 % indiziert", "45 % indiziert, offline", "Online", "Offline",
            "HDD", "SSD", "USB", "Fehler", "Ausstehend", "Nicht erlaubt",
            "HDD · extern angeschlossen", "4,1 TB", "3,77 TB / 0,33 TB · 92%", "238 421 / 12 908", "jetzt",
            "„Externe Platte 5“ (HDD, 2 TB) wurde angeschlossen. Soll sie indiziert werden?",
            "„NAS Klon“ konnte nicht indiziert werden",
            "1", "2", "3", "4", "5+", "→", "!",
            "Einstellungsfenster", "Speichermedium-Detail", "Absturzbericht",
            "Erkennungs-Dialog", "Schnellübersicht bei Klick", "Übersicht", "Spaltenansicht",
            "Speichermedium-Detail", "Absturzbericht", "Indizierungsfehler",
            // Screen 06 — Beispielzahlen im Layout (zwei Zeilen, doppeltes Leerzeichen).
            "Dateien  238.421", "Ordner  12.908",
            // Layout-Mockup noch „Disk Index“; Produkt heißt „Disk Archive“ (185, README).
            "Disk Index", "Disk Index wurde unerwartet beendet",
        ]
    }
}

//
//  LayoutCopyTests.swift
//  DiskArchiveTests
//

import AppKit
import Foundation
import Testing
@testable import DiskArchive

struct LayoutCopyTests {
    @Test func windowLinesFromTheLayoutAreInLayoutCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        // todo.0.4.3.004: ein Layout in Teildateien (`App-Layout 00-03 …` bis `App-Layout 16 …`); „Gesamt“ bindet sie nur ein.
        let html = try layoutParts(root: root)
        let layoutCopySource = try String(
            contentsOf: root.appendingPathComponent("DiskArchive/DiskArchive/DesignSystem/LayoutCopy.swift"),
            encoding: .utf8
        )
        let catalogGerman = try germanCopyStringsFromCatalog(root: root)
        let source = layoutCopySource + "\n" + catalogGerman
        // todo.0.4.2.003: Option entfällt (Nutzer 30.10.)
        let wanted = windowLines(from: html).filter { !notYetReleased.contains($0) && !differsFromApp.contains($0) }
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

    private func layoutParts(root: URL) throws -> String {
        let folder = root.appendingPathComponent("layout", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix("App-Layout ") && $0.hasSuffix(".dc.html") && !$0.hasPrefix("App-Layout Gesamt") }
            .sorted()
        try #require(names.count == 6, "Teildateien des Layouts: \(names)")
        return try names
            .map { try String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")
    }

    private func windowLines(from html: String) -> [String] {
        // Erkennungs-Dialog, Einstellungen, Detail, Indizierungsfehler, Fehlerbericht (Nummern seit dem neuen Layout).
        let sectionMarkers = ["02.", "05.", "06.", "14.", "15."]
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
                // Kopf der macOS-Mitteilung: App-Name und Zeit (Abschnitt 14).
                if line.hasPrefix("Disk Archive  ") { continue }
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

    /// Zeilen des Layouts zu Funktionen, die noch nicht freigegeben sind (Host entscheidet beim Review).
    private var notYetReleased: Set<String> {
        [
            // todo.0.4.2.003: Option entfällt (Nutzer 30.10.)
            "Ordner weiterhin anzeigen",
            // 05 Einstellungen: Reiter „Systeminformationen“ und „Lizenz“
            "Systeminformationen",
            "Lizenz",
            // 05 Einstellungen, Allgemein: Vorschaubilder
            "VORSCHAUBILDER",
            "Vorschaubilder brauchen zusätzlichen Speicherplatz im Index. Es sind klein gerechnete JPGs in reduzierter Qualität.",
            "Vorschaubilder erzeugen",
            // 05 Einstellungen, Speichermedien: eigener Name in der Liste und „Auswerfen“
            "Lauras Platte  · Studio Backup       92 % indiziert    Auswerfen",
            "Daten I    45 % indiziert, offline    Auswerfen",
            "NAS Klon     ! Fehler    Auswerfen",
            "Alter USB-Stick    Nicht erlaubt    Auswerfen",
            "Externe Platte 5    Ausstehend    Auswerfen",
            // 05 Einstellungen, Systeminformationen: Index auf dem Mac
            "Niemals in der Cloud",
            "1.284.906", "96.312", "31.540",
            "Vorschauen",
            "INDEX",
            "Speicherplatz, den der Index auf deinem Mac belegt. Vorschauen brauchen pro Objekt am meisten Platz.",
            "1,42 GB  gesamt",
            "Vorschauen  862 MB · 59 %",
            "Dateien  548 MB · 38 %",
            "Ordner  41 MB · 3 %",
            "DURCHSCHNITT PRO OBJEKT",
            "Durchschnittlicher Speicherbedarf im Index für ein einzelnes Objekt.",
            "0,4 KB",
            "Vorschau",
            "28 KB",
            "INDEX JE SPEICHERMEDIUM",
            "Je dunkler die Fläche, desto mehr Platz belegt der Index des Mediums.",
            "wenig                viel",
            "Unterwegs  410 MB", "Daten I  236 MB", "Studio Backup  182 MB", "Hochzeitsvideos Archiv  96 MB",
            "Masterarbeit Backup  74 MB", "NAS Klon  51 MB", "Zoom H6-01  22 MB", "EOS_R5  9 MB",
            // 05 Einstellungen, Systeminformationen: Programm
            "PROGRAMM",
            "Version  0.4.1 (Beta)",
            "Letzte Update-Prüfung   heute, 09:14  Jetzt prüfen",
            "Indexordner   ~/Library/Application Support/Disk Archive/Index  Im Finder anzeigen",
            // 05 Einstellungen, Lizenz (Lizenz erst ab 1.0)
            "Alles drin. Nur der Platz ist begrenzt.",
            "Jede Funktion steht dir immer zur Verfügung. Eine Lizenz bestimmt nur, wie viele Speichermedien du erfassen kannst.",
            "Aktivieren",
            "Testversion   1   Speichermedium",
            "Vollversion   50   Speichermedien",
            "Vollversion Pro   250   Speichermedien",
            "Lizenz holen  Einmal kaufen, kein Abo",
            "Danke, dass du Disk Archive trägst.",
            "••••-••••-••••-A3F9",
            "Belegt   12  von 50",
            "Belegt   87  von 250",
            "Zur Website  Lizenz deaktivieren",
            // 06 Detail: Untertitel mit Originalname, Zeile „Zuletzt indiziert“
            "Originalname: Studio Backup · extern angeschlossen",
            "Zuletzt indiziert  gestern, 18:42",
        ]
    }

    /// Schon gebaute Texte, die im Layout anders lauten: nicht in der App geändert, Frage an den Host (Regel 2).
    private var differsFromApp: Set<String> {
        [
            // 02 Erkennungs-Dialog: App „(HDD, 2 TB)“, Layout ohne Medientyp
            "„Externe Platte 5“ (2 TB) wurde angeschlossen. Soll sie indiziert werden?",
            // 05 Einstellungen: App „Die Änderung gilt sofort.“
            "Sprache der Benutzeroberfläche. Die Änderung gilt nach einem Neustart von Disk Archive.",
            // 05 Einstellungen: App ohne „in der Menüleiste“ (bug.0.4.198: Hinweis ist der Dialog im Hauptfenster)
            "Disk Archive weist dich in der Menüleiste darauf hin, sobald eine neue Version verfügbar ist.",
        ]
    }

    private var structural: Set<String> {
        // „MEHRERE MEDIEN GLEICHZEITIG“: Erläuterung im Layout (Abschnitt 02), kein Fenstertext.
        ["MODAL", "ANSICHT", "ANSICHT (POPOVER)", "MACOS-MITTEILUNG", "RUHEZUSTAND", "MEHRERE MEDIEN GLEICHZEITIG"]
    }

    /// Beispielwerte aus dem Layout, keine festen Fenstertexte.
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
            // Beispielwerte des neuen Layouts (Abschnitte 05 und 06).
            "Unterwegs    Online", "Masterarbeit Backup    Offline", "Zoom H6-01    Online", "Hochzeitsvideos Archiv    Offline",
            "EOS_R5    Offline", "vor 34 Tagen", "vor 3 Monaten", "vor 12 Tagen", "gestern, 18:02", "heute, 08:52",
            "Lauras Platte", "Indiziert       86 %",
            "Einstellungsfenster", "Speichermedium-Detail", "Absturzbericht",
            "Erkennungs-Dialog", "Schnellübersicht bei Klick", "Übersicht", "Spaltenansicht",
            "Speichermedium-Detail", "Absturzbericht", "Indizierungsfehler",
            // Screen 06 — Beispielzahlen im Layout (zwei Zeilen, doppeltes Leerzeichen).
            "Dateien  238.421", "Ordner  12.908",
        ]
    }
}

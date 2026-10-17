//
//  SearchState.swift
//  diskindex
//

import Foundation

nonisolated enum SearchAgeFilter: String, CaseIterable, Identifiable, Sendable {
    case last24Hours
    case last2Days
    case lastWeek
    case lastMonth
    case last3Months
    case last6Months
    case last9Months
    case lastYear
    case older

    var id: String { rawValue }

    var label: String {
        switch self {
        case .last24Hours: LayoutCopy.ageLast24Hours
        case .last2Days: LayoutCopy.ageLast2Days
        case .lastWeek: LayoutCopy.ageLastWeek
        case .lastMonth: LayoutCopy.ageLastMonth
        case .last3Months: LayoutCopy.ageLast3Months
        case .last6Months: LayoutCopy.ageLast6Months
        case .last9Months: LayoutCopy.ageLast9Months
        case .lastYear: LayoutCopy.ageLastYear
        case .older: LayoutCopy.ageOlder
        }
    }

    func matches(_ date: Date, now: Date = .now) -> Bool {
        let calendar = Calendar.current
        func since(_ component: Calendar.Component, _ value: Int) -> Bool {
            guard let limit = calendar.date(byAdding: component, value: -value, to: now) else { return true }
            return date >= limit
        }
        switch self {
        case .last24Hours: return since(.hour, 24)
        case .last2Days: return since(.day, 2)
        case .lastWeek: return since(.day, 7)
        case .lastMonth: return since(.month, 1)
        case .last3Months: return since(.month, 3)
        case .last6Months: return since(.month, 6)
        case .last9Months: return since(.month, 9)
        case .lastYear: return since(.year, 1)
        case .older: return !since(.year, 1)
        }
    }
}

nonisolated enum SearchFileTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case pdf
    case text
    case documents
    case image
    case video
    case audio
    case archive
    case programs
    case scripts
    case folder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pdf: "PDF"
        case .text: LayoutCopy.kindText
        case .documents: LayoutCopy.kindDocuments
        case .image: LayoutCopy.kindImage
        case .video: LayoutCopy.kindVideo
        case .audio: LayoutCopy.kindAudio
        case .archive: LayoutCopy.kindArchive
        case .programs: LayoutCopy.kindPrograms
        case .scripts: LayoutCopy.kindScripts
        case .folder: LayoutCopy.kindFolder
        }
    }

    private static let officeExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "odt", "ods", "odp",
    ]

    /// Endungen ohne Punkt. Dieselbe Menge nutzt die Datenbanksuche.
    var databaseExtensions: Set<String> {
        switch self {
        case .folder:
            []
        case .pdf:
            ["pdf"]
        case .text:
            ["txt", "md", "rtf", "csv"]
        case .documents:
            // Oberbegriff: Text + PDF + Office-Formate (README 29.09. (3), Aufgabe 29).
            Self.pdf.databaseExtensions
                .union(Self.text.databaseExtensions)
                .union(Self.officeExtensions)
        case .image:
            ["jpg", "jpeg", "png", "gif", "webp", "heic", "tif", "tiff", "svg", "nef", "cr2", "arw", "dng"]
        case .video:
            ["mov", "mp4", "m4v", "avi", "mkv"]
        case .audio:
            ["mp3", "wav", "aac", "m4a", "flac"]
        case .archive:
            ["zip", "rar", "7z", "tar", "gz", "bz2"]
        case .programs:
            ["app", "dmg", "pkg", "exe"]
        case .scripts:
            ["html", "css", "js", "php", "py", "sh", "rb", "command"]
        }
    }

    func matches(fileName: String, isFolder: Bool, isPackage: Bool = false) -> Bool {
        switch self {
        case .folder:
            return isFolder && !isPackage
        case .programs:
            if isPackage { return true }
            if isFolder, fileName.lowercased().hasSuffix(".app") { return true }
            guard !isFolder else { return false }
            let ext = (fileName as NSString).pathExtension.lowercased()
            return databaseExtensions.contains(ext)
        default:
            if isFolder { return false }
            let ext = (fileName as NSString).pathExtension.lowercased()
            return databaseExtensions.contains(ext)
        }
    }
}

nonisolated struct SearchFilters: Equatable, Sendable {
    /// `true` = alle Medien; sonst nur IDs in `mediumIDs`.
    var selectAllMedia: Bool = true
    var mediumIDs: Set<UUID> = []
    var fileTypes: Set<SearchFileTypeFilter> = []
    /// Eigene Dateiendungen (Aufgabe 32), normalisiert (`.psd`), in Eingabereihenfolge, ohne Duplikate.
    var customExtensions: [String] = []
    var age: SearchAgeFilter?
    /// Verknüpfungs-Button (Aufgabe 33): Dateityp-Gruppe und Alter per Und statt Oder.
    var combineWithAnd: Bool = false

    /// Inkl. Medium-Auswahl — wirkt nur in der Suche.
    var hasActiveFilters: Bool {
        !selectAllMedia || hasActiveObjectFilters
    }

    /// Nur Objekt-Filter (Dateityp, Alter, Ordner) — Spaltenansicht und Favoriten (Review K3).
    var hasActiveObjectFilters: Bool {
        !fileTypes.isEmpty || !customExtensions.isEmpty || age != nil
    }

    /// Einzige Stelle für die tatsächliche Verknüpfung (UI-Zustand und Matching):
    /// „Und“ wirkt nicht mit Ordner-Filter und nicht bei abgeschicktem Suchbegriff.
    func effectiveCombineWithAnd(hasSearchTerm: Bool) -> Bool {
        combineWithAnd && !fileTypes.contains(.folder) && !hasSearchTerm
    }

    /// Verknüpfungs-Button deaktiviert: Ordner, Suchbegriff, oder nur eine der beiden Dimensionen gesetzt (33.1, 34).
    func isCombineDisabled(hasSearchTerm: Bool) -> Bool {
        fileTypes.contains(.folder) || hasSearchTerm || !hasFileTypeFilter || age == nil
    }

    /// Link-Button nur sichtbar, wenn „Und“ wirken kann (Aufgabe 86).
    func isCombineButtonVisible(hasSearchTerm: Bool) -> Bool {
        !isCombineDisabled(hasSearchTerm: hasSearchTerm)
    }

    mutating func clampCombineWithAnd(hasSearchTerm: Bool) {
        if !isCombineButtonVisible(hasSearchTerm: hasSearchTerm) {
            combineWithAnd = false
        }
    }

    /// Kategorien und eigene Endungen bilden zusammen die Dateityp-Gruppe (Oder).
    var hasFileTypeFilter: Bool {
        !fileTypes.isEmpty || !customExtensions.isEmpty
    }

    /// Fügt eine eigene Endung hinzu. `false` = ungültig (Feld behält den Text); schon vorhanden zählt als Erfolg.
    @discardableResult
    mutating func addCustomExtension(_ input: String) -> Bool {
        guard let ext = Self.normalizedExtension(input) else { return false }
        if !customExtensions.contains(ext) {
            customExtensions.append(ext)
        }
        fileTypes.remove(.folder) // „Ordner“ und echte Typen/Endungen schließen sich aus (33.4)
        return true
    }

    /// `jpg`, `.jpg`, `*.jpg`, `JPG` → `.jpg`. Erlaubt: Buchstaben, Ziffern, `-`, `_`, innere Punkte (`.tar.gz`);
    /// max. 16 Zeichen ohne führenden Punkt. Ungültig oder leer → `nil`.
    static func normalizedExtension(_ input: String) -> String? {
        var body = Substring(input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        if body.hasPrefix("*") { body = body.dropFirst() }
        while body.hasPrefix(".") { body = body.dropFirst() }

        guard !body.isEmpty, body.count <= 16, !body.hasSuffix("."), !body.contains("..") else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard body.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return "." + body
    }
}

nonisolated enum SearchSortColumn: String, CaseIterable, Sendable {
    case name
    case date
    case medium
    case path
    case status
}

nonisolated enum SortDirection: String, Sendable {
    case ascending
    case descending
}

nonisolated struct SearchSort: Equatable, Sendable {
    var column: SearchSortColumn = .name
    var direction: SortDirection = .ascending

    /// bug.0.4.038: Diese Spalten sortiert die Datenbank (`ORDER BY`), über alle Treffer statt nur die erste Seite.
    static let serverColumns: Set<SearchSortColumn> = [.name, .date, .medium]
    /// Davon kommt die Seite schon in der fertigen Reihenfolge. Name wählt die Datenbank binär nach `slug` aus; der
    /// Client sortiert die Seite natürlich nach („datei 2“ vor „datei 10“, `localizedStandardCompare`).
    static let pageOrderedColumns: Set<SearchSortColumn> = [.date, .medium]

    /// Reihenfolge für die Abfrage: Pfad und Status sortiert der Client (nur, wenn alle Treffer auf der Seite
    /// stehen); die Seite selbst kommt dann nach Name aufsteigend.
    var serverOrder: SearchSort {
        Self.serverColumns.contains(column) ? self : SearchSort()
    }

    /// Gleiche Spalte → Richtung umkehren, andere Spalte → aufsteigend.
    mutating func toggle(_ column: SearchSortColumn) {
        if self.column == column {
            direction = direction == .ascending ? .descending : .ascending
        } else {
            self.column = column
            direction = .ascending
        }
    }
}

/// Live-Eingabe, abgeschickte Suche und Filter.
struct SearchState: Equatable {
    /// Live-Eingabe im Objekt-Suchfeld.
    var query: String = ""
    /// Per Enter (oder programmatisch) abgeschickter Begriff — nur dieser erzeugt Treffer.
    var submittedQuery: String = ""
    var filters = SearchFilters()
    var sort = SearchSort()
    /// Für spätere asynchrone Suche; Mock bleibt synchron (`false`).
    var isSearchInProgress: Bool = false

    var hasActiveFilters: Bool {
        filters.hasActiveFilters
    }
}

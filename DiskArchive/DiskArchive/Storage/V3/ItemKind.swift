//
//  ItemKind.swift
//  DiskArchive
//
//  Schema V3 (Aufgabe 230): feste Zahlen für Typ-Kategorie, Status, Herkunft und Zeit.
//  Die Zuordnung Endung → Kategorie kommt aus `SearchFileTypeFilter.databaseExtensions` (eine Quelle für Filter und Schema).
//

import Foundation

/// Typ-Kategorie eines Eintrags. Genau die Gruppen von `SearchFileTypeFilter`; Ordner stehen in `items.isFolder`.
nonisolated enum ItemKind: Int, CaseIterable, Sendable {
    case other = 0
    case pdf = 1
    case text = 2
    case documents = 3
    case image = 4
    case video = 5
    case audio = 6
    case archive = 7
    case programs = 8
    case scripts = 9

    /// Die Gruppe des Suchfilters zu dieser Kategorie (`other` hat keine).
    var filter: SearchFileTypeFilter? {
        switch self {
        case .other: nil
        case .pdf: .pdf
        case .text: .text
        case .documents: .documents
        case .image: .image
        case .video: .video
        case .audio: .audio
        case .archive: .archive
        case .programs: .programs
        case .scripts: .scripts
        }
    }

    /// Kategorien, die ein Suchfilter umfasst. „Dokumente“ ist der Oberbegriff aus PDF, Text und Office-Formaten.
    static func kinds(for filter: SearchFileTypeFilter) -> Set<ItemKind> {
        switch filter {
        case .folder: []
        case .pdf: [.pdf]
        case .text: [.text]
        case .documents: [.pdf, .text, .documents]
        case .image: [.image]
        case .video: [.video]
        case .audio: [.audio]
        case .archive: [.archive]
        case .programs: [.programs]
        case .scripts: [.scripts]
        }
    }

    /// Endung (ohne Punkt, beliebige Schreibweise) → Kategorie. Nur `.app`-Pakete sind Programme (dazu `.dmg`, `.pkg`);
    /// andere Pakete (`.key`, `.pages`, `.photoslibrary` …) richten sich nach ihrer Endung wie Dateien.
    /// Gewöhnliche Ordner haben keine Kategorie.
    static func classify(ext: String?, isFolder: Bool, isPackage: Bool = false) -> ItemKind {
        guard let ext = ext?.lowercased(), !ext.isEmpty else { return .other }
        if isFolder, !isPackage, ext != "app" { return .other }
        return byExtension[ext] ?? .other
    }

    private static let byExtension: [String: ItemKind] = {
        var map: [String: ItemKind] = [:]
        // Reihenfolge: engere Gruppen zuerst; „Dokumente“ bleibt für die übrigen Office-Endungen.
        let order: [ItemKind] = [.pdf, .text, .image, .video, .audio, .archive, .programs, .scripts, .documents]
        for kind in order {
            guard let filter = kind.filter else { continue }
            for ext in filter.databaseExtensions where map[ext] == nil {
                map[ext] = kind
            }
        }
        return map
    }()
}

nonisolated enum ItemStatus: Int, Sendable {
    case visible = 0
    case toDelete = 1
    /// Beim vollständigen Lesen des Ordners nicht mehr gefunden; wird am Ende des Laufs gelöscht (235 verbindet vorher Umbenanntes).
    case gone = 2
}

nonisolated enum MetaSource: Int, Sendable {
    case read = 0
    case user = 1
    case system = 2
}

/// Zeit im Schema V3: ganze Sekunden seit 1970.
nonisolated enum SchemaTime {
    static func seconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded(.down))
    }

    static func date(_ seconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}

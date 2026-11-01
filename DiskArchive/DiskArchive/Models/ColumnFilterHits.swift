//
//  ColumnFilterHits.swift
//  DiskArchive
//
//  todo.0.4.2.003: Treffermenge der Spaltenansicht – welche Ordner des geöffneten Mediums irgendwo darunter einen
//  Treffer haben. Gilt nur für ihren Schlüssel (Medium und Objekt-Filter).
//

import Foundation

struct ColumnFilterKey: Equatable, Sendable {
    let mediumID: UUID
    /// Nur Objekt-Filter (Dateityp, Endungen, Alter, Und/Oder); die Medium-Auswahl der Suche zählt hier nicht.
    let filters: SearchFilters

    /// `nil` ohne Medium oder ohne Objekt-Filter.
    init?(mediumID: UUID?, filters: SearchFilters) {
        guard let mediumID, filters.hasActiveObjectFilters else { return nil }
        var objects = SearchFilters()
        objects.fileTypes = filters.fileTypes
        objects.customExtensions = filters.customExtensions
        objects.age = filters.age
        objects.combineWithAnd = filters.combineWithAnd
        self.mediumID = mediumID
        self.filters = objects
    }
}

struct ColumnFilterHits: Equatable {
    var key: ColumnFilterKey
    /// Zeilenkennungen der Ordner mit Treffer darunter.
    var folderIDs: Set<Int64>
}

//
//  ProposalCopy.swift
//  diskindex
//
//  Texte ohne Layout-Entsprechung (Aufgabe 119). Layout-Texte bleiben in LayoutCopy.
//

import Foundation

nonisolated struct ProposalCopyEntry: Sendable {
    let name: String
    let text: String
    let location: String
}

nonisolated enum ProposalCopy {
    // MARK: - Leerzustände

    /// MenuBarPopoverView — nichts angeschlossen
    static let popoverNoneConnected = "Kein Speichermedium angeschlossen"

    // MARK: - Suche

    /// SearchView — Ladezustand
    static let searchInProgress = "Suche läuft…"
    /// SearchView / Filter — keine Treffer
    static let noResultsForFilters = "Keine Treffer für die gesetzten Filter"

    static func noResults(for query: String) -> String {
        "Keine Ergebnisse für „\(query)“"
    }

    static func popoverNoHits(for query: String) -> String {
        "Keine Treffer für „\(query)“"
    }

    // MARK: - Favoriten

    static let noFavoritesForFilters = "Keine Favoriten für die gesetzten Filter"
    static let noFavoritedObjects = "Keine favorisierten Objekte"

    // MARK: - Filter / Toolbar

    static let resetAllFiltersHelp = "Alle Filter zurücksetzen"
    static let filterLinkedWithAnd = "Filter mit „Und“ verknüpft"
    static let filterLinkWithAnd = "Filter mit „Und“ verknüpfen"
    static let filterScopeFavorites = "In Favoriten"

    static func filterScopeMedium(name: String) -> String {
        "In „\(name)“"
    }

    static func mediumFilterCount(filtered: Int, total: Int) -> String {
        "\(filtered) von \(total) Medien"
    }

    // MARK: - Aktionen / Hilfe

    static let clearSearchAccessibility = "Suche leeren"
    static let showDetailsHelp = "Details anzeigen"

    /// SettingsGeneralTab — TCC
    static let openSystemSettingsForPermission = "In den Systemeinstellungen freigeben"

    // MARK: - Lesbarkeit / Ausschluss (114-Vorstufe)

    static let folderUnreadable = "Inhalt konnte nicht gelesen werden"
    static let folderExcluded = "Ordner ist ausgeschlossen"

    /// Mitteilungen nach Bestätigung (Vergessen / Bereinigen / Voreinstellungen) — Layout folgt.
    static let noticeForgetAll = "Alle Speichermedien wurden vergessen."
    static let noticePrune = "Index bereinigt."
    static let noticeDefaultsApplied = "Voreinstellungen angewendet."

    /// Einstellungen > Allgemein > Sprache (noch ohne Lokalisierung).
    static let languageSettingDescription = "Legt die Sprache der App-Oberfläche fest."

    // MARK: - Debug-Menü

    static let debugHighlightProposalCopy = "Vorschlagstexte rot"
    static let debugExportProposalCopy = "Vorschlagstexte exportieren"

    // MARK: - Katalog (nur Nicht-Layout-Texte)

    static let catalog: [ProposalCopyEntry] = [
        .init(name: "popoverNoneConnected", text: popoverNoneConnected, location: "MenuBarPopoverView"),
        .init(name: "searchInProgress", text: searchInProgress, location: "SearchView"),
        .init(name: "noResultsForFilters", text: noResultsForFilters, location: "SearchView"),
        .init(name: "noFavoritesForFilters", text: noFavoritesForFilters, location: "FavoritesView"),
        .init(name: "noFavoritedObjects", text: noFavoritedObjects, location: "FavoritesView"),
        .init(name: "resetAllFiltersHelp", text: resetAllFiltersHelp, location: "MainWindowFilterBar"),
        .init(name: "filterLinkedWithAnd", text: filterLinkedWithAnd, location: "MainWindowFilterBar"),
        .init(name: "filterLinkWithAnd", text: filterLinkWithAnd, location: "MainWindowFilterBar"),
        .init(name: "filterScopeFavorites", text: filterScopeFavorites, location: "MainWindowFilterBar"),
        .init(name: "folderUnreadable", text: folderUnreadable, location: "ColumnBrowser (114)"),
        .init(name: "folderExcluded", text: folderExcluded, location: "ColumnBrowser (114)"),
        .init(name: "noticeForgetAll", text: noticeForgetAll, location: "SystemNotice (Bestätigung)"),
        .init(name: "noticePrune", text: noticePrune, location: "SystemNotice (Bestätigung)"),
        .init(name: "noticeDefaultsApplied", text: noticeDefaultsApplied, location: "SystemNotice (Bestätigung)"),
        .init(name: "openSystemSettingsForPermission", text: openSystemSettingsForPermission, location: "SettingsGeneralTab"),
        .init(name: "languageSettingDescription", text: languageSettingDescription, location: "SettingsGeneralTab"),    ]

    static func prefixIfNeeded(_ text: String) -> String {
        ProposalCopyPresentation.prefixIfNeeded(text)
    }
}

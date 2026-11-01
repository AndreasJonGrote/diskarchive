//
//  LayoutCopy+Menus.swift
//  DiskArchive
//
//  Weitere sichtbare Texte (Kontextmenü, Menüleiste, Mitteilungen, Chips, Filter, Fußzeilen) — DE/EN in Localizable.xcstrings.
//  Neue en-Texte: docs/englisch-neu.md.
//

import Foundation

nonisolated extension LayoutCopy {
    static var tableType: String { L10n.string("copy.table.column.type") }
    static var tableStatus: String { L10n.string("copy.table.column.status") }
    static var contextShowContent: String { L10n.string("copy.context.show_content") }
    static var contextDetails: String { L10n.string("copy.context.details") }
    static var contextSetName: String { L10n.string("copy.context.set_name") }
    static var contextShowInFinder: String { L10n.string("copy.context.show_in_finder") }
    static var contextFavorite: String { L10n.string("copy.context.favorite") }
    static var contextSearchName: String { L10n.string("copy.context.search_name") }
    static var contextSearchExtension: String { L10n.string("copy.context.search_extension") }
    static var contextIgnoreName: String { L10n.string("copy.context.ignore_name") }
    static var contextIgnoreType: String { L10n.string("copy.context.ignore_type") }
    static var menuBarShowApp: String { L10n.string("copy.menubar.show_app") }
    static var menuBarLaunchAtLogin: String { L10n.string("copy.menubar.launch_at_login") }
    static var menuBarRevealLog: String { L10n.string("copy.menubar.reveal_log") }
    static var menuBarQuit: String { L10n.string("copy.menubar.quit") }
    static var menuBarAbout: String { L10n.string("copy.menubar.about") }
    static var appMenuSettings: String { L10n.string("copy.appmenu.settings") }
    static func noticeIndexedComplete(_ a0: String, _ a1: String) -> String { L10n.format("copy.notice.indexed_complete", a0, a1) }
    static func noticeFavoritesOnline(_ a0: String, _ a1: String) -> String { L10n.format("copy.notice.favorites_online", a0, a1) }
    static var failureDisconnected: String { L10n.string("copy.failure.disconnected") }
    static var failureTimeout: String { L10n.string("copy.failure.timeout") }
    static var failureUnconfirmed: String { L10n.string("copy.failure.unconfirmed") }
    static var failureDiskSpace: String { L10n.string("copy.failure.disk_space") }
    static var failureDatabase: String { L10n.string("copy.failure.database") }
    static var failureUnreadableFolders: String { L10n.string("copy.failure.unreadable_folders") }
    static var chipNotAllowed: String { L10n.string("copy.chip.not_allowed") }
    static var chipPending: String { L10n.string("copy.chip.pending") }
    static var chipError: String { L10n.string("copy.chip.error") }
    static var chipErrorOffline: String { L10n.string("copy.chip.error_offline") }
    static var chipOffline: String { L10n.string("copy.chip.offline") }
    static var chipOnline: String { L10n.string("copy.chip.online") }
    static func chipPercentIndexedOffline(_ a0: Int) -> String { L10n.format("copy.chip.percent_indexed_offline", a0) }
    static func chipPercentIndexed(_ a0: Int) -> String { L10n.format("copy.chip.percent_indexed", a0) }
    static var mediumDecisionPending: String { L10n.string("copy.medium.decision_pending") }
    static var mediumNoAccess: String { L10n.string("copy.medium.no_access") }
    static var mediumNotIndexedYet: String { L10n.string("copy.medium.not_indexed_yet") }
    static func mediumFilesCount(_ a0: String) -> String { L10n.format("copy.medium.files_count", a0) }
    static func mediumFreeOfTotal(_ a0: String, _ a1: String) -> String { L10n.format("copy.medium.free_of_total", a0, a1) }
    static var menuShowOneResult: String { L10n.string("copy.menu.show_one_result") }
    static func menuShowAllResults(_ a0: Int) -> String { L10n.format("copy.menu.show_all_results", a0) }
    static var ageLast24Hours: String { L10n.string("copy.age.last_24h") }
    static var ageLast2Days: String { L10n.string("copy.age.last_2d") }
    static var ageLastWeek: String { L10n.string("copy.age.last_week") }
    static var ageLastMonth: String { L10n.string("copy.age.last_month") }
    static var ageLast3Months: String { L10n.string("copy.age.3m") }
    static var ageLast6Months: String { L10n.string("copy.age.6m") }
    static var ageLast9Months: String { L10n.string("copy.age.9m") }
    static var ageLastYear: String { L10n.string("copy.age.last_year") }
    static var ageOlder: String { L10n.string("copy.age.older") }
    static var objectOne: String { L10n.string("copy.object.one") }
    static func objectMany(_ a0: String) -> String { L10n.format("copy.object.many", a0) }
    static func objectFiltered(_ a0: String, _ a1: String) -> String { L10n.format("copy.object.filtered", a0, a1) }
    static func columnSelectedOf(_ a0: Int, _ a1: Int) -> String { L10n.format("copy.column.selected_of", a0, a1) }
    static var indexedNever: String { L10n.string("copy.indexed.never") }
    static func indexedLine(_ a0: String, _ a1: String) -> String { L10n.format("copy.indexed.line", a0, a1) }
    static var dateToday: String { L10n.string("copy.date.today") }
    static var dateYesterday: String { L10n.string("copy.date.yesterday") }
    static var searchPlaceholderObjects: String { L10n.string("copy.search.placeholder_objects") }
    static var searchPlaceholderMedium: String { L10n.string("copy.search.placeholder_medium") }
    static var searchPlaceholderExtension: String { L10n.string("copy.search.placeholder_extension") }
    static func scanDepthSubfolder(_ a0: Int) -> String { L10n.format("copy.settings.scan_depth.subfolder", a0) }
    static func menuPauseUntil(_ a0: String) -> String { L10n.format("copy.menu.pause_until", a0) }
    static var searchPlaceholderCompact: String { L10n.string("copy.search.placeholder_compact") }
    static var binaryYes: String { L10n.string("copy.binary.yes") }
    static var binaryNo: String { L10n.string("copy.binary.no") }
    static var scopeAll: String { L10n.string("copy.scope.all") }
    static var kindText: String { L10n.string("copy.kind.text") }
    static var kindDocuments: String { L10n.string("copy.kind.documents") }
    static var kindImage: String { L10n.string("copy.kind.image") }
    static var kindVideo: String { L10n.string("copy.kind.video") }
    static var kindAudio: String { L10n.string("copy.kind.audio") }
    static var kindArchive: String { L10n.string("copy.kind.archive") }
    static var kindPrograms: String { L10n.string("copy.kind.programs") }
    static var kindScripts: String { L10n.string("copy.kind.scripts") }
    static var kindFolder: String { L10n.string("copy.kind.folder") }
    static var tableName: String { L10n.string("copy.table.name") }
    static var tableDate: String { L10n.string("copy.table.date") }
    static var tableMedium: String { L10n.string("copy.table.medium") }
    static var tablePath: String { L10n.string("copy.table.path") }

    static var popoverNoneConnected: String { L10n.string("copy.hint.popover_none_connected") }
    static var popoverNoneIndexedConnected: String { L10n.string("copy.hint.popover_none_indexed_connected") }
    static var noResultsForFilters: String { L10n.string("copy.search.no_results_for_filters") }
    static func noResults(_ a0: String) -> String { L10n.format("copy.search.no_results_for", a0) }
    static func popoverNoHits(_ a0: String) -> String { L10n.format("copy.search.popover_no_hits", a0) }
    static var noFavoritesForFilters: String { L10n.string("copy.favorites.none_for_filters") }
    static var noFavoritedObjects: String { L10n.string("copy.favorites.none") }
    static var resetAllFiltersHelp: String { L10n.string("copy.filter.reset_all") }
    static var filterLinkedWithAnd: String { L10n.string("copy.filter.linked_with_and") }
    static var filterLinkWithAnd: String { L10n.string("copy.filter.link_with_and") }
    static var filterScopeFavorites: String { L10n.string("copy.filter.scope_favorites") }
    static func filterScopeMedium(_ a0: String) -> String { L10n.format("copy.filter.scope_medium", a0) }
    static func mediumFilterCount(_ a0: Int, _ a1: Int) -> String { L10n.format("copy.filter.medium_count", a0, a1) }
    static var clearSearchAccessibility: String { L10n.string("copy.a11y.clear_search") }
    static var showDetailsHelp: String { L10n.string("copy.registry.show_details") }
    static var openSystemSettingsForPermission: String { L10n.string("copy.settings.open_system_settings") }
    static var folderUnreadable: String { L10n.string("copy.folder.unreadable") }
    static var folderExcluded: String { L10n.string("copy.folder.excluded") }
    static var folderChangeExclusions: String { L10n.string("copy.folder.change_exclusions") }
    static var noticeForgetAll: String { L10n.string("copy.notice.forget_all") }
    static var noticePrune: String { L10n.string("copy.notice.prune") }
    static var noticeDefaultsApplied: String { L10n.string("copy.notice.defaults_applied") }
}

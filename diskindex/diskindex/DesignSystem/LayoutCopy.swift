//
//  LayoutCopy.swift
//  diskindex
//
//  Fenstertexte — Keys in Localization/Localizable.xcstrings (DE/EN). Siehe docs/Lokalisierung.md.
//

import Foundation

nonisolated enum LayoutCopy {
    static var newMediumTitle: String { L10n.string("copy.new_medium.title") }
    static var rememberMedium: String { L10n.string("copy.new_medium.remember") }
    static var dontIndex: String { L10n.string("copy.new_medium.dont_index") }
    static var index: String { L10n.string("copy.new_medium.index") }

    static var diskIndex: String { L10n.string("copy.app.name") }

    /// Leerzustand Dashboard / Spalten / Einstellungen › Speichermedien (Layout 04/05).
    static var emptyNoMediaTitle: String { L10n.string("copy.empty.no_media.title") }
    static var emptyNoMediaMessage: String { L10n.string("copy.empty.no_media.message") }
    /// Favoriten leer (Layout 11).
    static var emptyNoFavoritesTitle: String { L10n.string("copy.empty.no_favorites.title") }
    static var emptyNoFavoritesMessage: String { L10n.string("copy.empty.no_favorites.message") }
    static var autoIndex: String { L10n.string("copy.menu.auto_index") }
    static var on: String { L10n.string("copy.menu.on") }
    static var paused: String { L10n.string("copy.menu.paused") }
    static var openApp: String { L10n.string("copy.menu.open_app") }
    static var pauseFor: String { L10n.string("copy.menu.pause_for") }
    static var changeTo: String { L10n.string("copy.menu.change_to") }
    static var minutes30: String { L10n.string("copy.menu.minutes_30") }
    static var oneHour: String { L10n.string("copy.menu.one_hour") }
    static var untilTomorrow: String { L10n.string("copy.menu.until_tomorrow") }
    static var forever: String { L10n.string("copy.menu.forever") }

    static var tabGeneral: String { L10n.string("copy.settings.tab.general") }
    static var tabFiles: String { L10n.string("copy.settings.tab.files") }
    static var tabMedia: String { L10n.string("copy.settings.tab.media") }
    static var tabAdvanced: String { L10n.string("copy.settings.tab.advanced") }

    static var appearanceTitle: String { L10n.string("copy.settings.appearance.title") }
    static var appearanceText: String { L10n.string("copy.settings.appearance.text") }
    static var appearanceLight: String { L10n.string("copy.settings.appearance.light") }
    static var appearanceDark: String { L10n.string("copy.settings.appearance.dark") }
    static var appearanceAuto: String { L10n.string("copy.settings.appearance.auto") }

    static var languageTitle: String { L10n.string("copy.settings.language.title") }
    static var languageText: String { L10n.string("copy.settings.language.text") }
    static var languageGerman: String { L10n.string("copy.settings.language.german") }
    static var languageEnglish: String { L10n.string("copy.settings.language.english") }

    static var autostartTitle: String { L10n.string("copy.settings.autostart.title") }
    static var autostartText: String { L10n.string("copy.settings.autostart.text") }
    static var autostartToggle: String { L10n.string("copy.settings.autostart.toggle") }

    static var scanDepthTitle: String { L10n.string("copy.settings.scan_depth.title") }
    static var scanDepthText: String { L10n.string("copy.settings.scan_depth.text") }
    static var depthLabel: String { L10n.string("copy.settings.scan_depth.label") }
    static var exampleHeading: String { L10n.string("copy.settings.scan_depth.example_heading") }
    static var diskCrumb: String { L10n.string("copy.settings.scan_depth.disk_crumb") }
    static var maxDepthCrumb: String { L10n.string("copy.settings.scan_depth.max_depth_crumb") }

    static var columnFilterTitle: String { L10n.string("copy.settings.column_filter.title") }
    static var columnFilterText: String { L10n.string("copy.settings.column_filter.text") }
    static var showFolders: String { L10n.string("copy.settings.column_filter.show_folders") }
    static var showFoldersHint: String { L10n.string("copy.settings.column_filter.show_folders_hint") }

    static var excludeTitle: String { L10n.string("copy.settings.exclude.title") }
    static var excludeText: String { L10n.string("copy.settings.exclude.text") }
    static var add: String { L10n.string("copy.settings.exclude.add") }
    static var excludePatternPlaceholder: String { L10n.string("copy.settings.exclude.placeholder") }

    static var hiddenTitle: String { L10n.string("copy.settings.hidden.title") }
    static var hiddenText: String { L10n.string("copy.settings.hidden.text") }
    static var ignore: String { L10n.string("copy.settings.hidden.ignore") }

    static var artifactsTitle: String { L10n.string("copy.settings.artifacts.title") }
    static var artifactsText: String { L10n.string("copy.settings.artifacts.text") }

    static var searchIdleTitle: String { L10n.string("copy.search.idle.title") }
    static var searchIdleSubtitle: String { L10n.string("copy.search.idle.subtitle") }
    static var searchFilterAllMedia: String { L10n.string("copy.search.filter_all_media") }
    static var filterToolbarButton: String { L10n.string("copy.filter.toolbar") }
    static var revealInFinder: String { L10n.string("copy.reveal_in_finder") }

    static var columnAllMediaHeading: String { L10n.string("copy.column.all_media_heading") }
    static var columnOfflineBanner: String { L10n.string("copy.column.offline_banner") }
    static var columnDetailHeading: String { L10n.string("copy.column.detail_heading") }

    static func columnDetailTotalSize(_ formatted: String) -> String {
        L10n.format("copy.column.detail.total_size", formatted)
    }

    static func columnDetailModified(_ formatted: String) -> String {
        L10n.format("copy.column.detail.modified", formatted)
    }

    static func columnDetailSize(_ formatted: String) -> String {
        L10n.format("copy.column.detail.size", formatted)
    }

    static func columnDetailLastSeen(_ formatted: String) -> String {
        L10n.format("copy.column.detail.last_seen", formatted)
    }

    static var a11yOverview: String { L10n.string("copy.a11y.overview") }
    static var a11yFavorites: String { L10n.string("copy.a11y.favorites") }
    static var a11ySettings: String { L10n.string("copy.a11y.settings") }
    static var a11yFilter: String { L10n.string("copy.a11y.filter") }
    static var a11ySearch: String { L10n.string("copy.a11y.search") }
    static var a11yClose: String { L10n.string("copy.a11y.close") }

    static var filterAll: String { L10n.string("copy.registry.filter.all") }
    static var filterIndexed: String { L10n.string("copy.registry.filter.indexed") }
    static var filterOffline: String { L10n.string("copy.registry.filter.offline") }
    static var filterNotAllowed: String { L10n.string("copy.registry.filter.not_allowed") }
    static var yes: String { L10n.string("copy.yes") }
    static var no: String { L10n.string("copy.no") }

    static var noticesTitle: String { L10n.string("copy.settings.notices.title") }
    static var noticesText: String { L10n.string("copy.settings.notices.text") }
    static var noticesTextLead: String { L10n.string("copy.settings.notices.text_lead") }
    static var noticesTextTail: String { L10n.string("copy.settings.notices.text_tail") }
    static var noticesSystemAndPauses: String { L10n.string("copy.settings.notices.system_and_pauses") }
    static var noticesToggle: String { L10n.string("copy.settings.notices.toggle") }
    static var noticesTurnedOn: String { L10n.string("copy.settings.notices.turned_on") }
    static var noticesTurnedOff: String { L10n.string("copy.settings.notices.turned_off") }
    static var noticeSystem: String { L10n.string("copy.settings.notices.system") }
    static var noticeIndexed: String { L10n.string("copy.settings.notices.indexed") }
    static var noticeFavorites: String { L10n.string("copy.settings.notices.favorites") }
    static var previewSystem: String { L10n.string("copy.settings.notices.preview_system") }
    static var noticePauseForever: String { L10n.string("copy.settings.notices.pause_forever") }
    static var noticePauseResumedManual: String { L10n.string("copy.settings.notices.pause_resumed") }

    static func noticePauseUntil(time: String) -> String {
        L10n.format("copy.settings.notices.pause_until", time)
    }

    static var previewIndexed: String { L10n.string("copy.settings.notices.preview_indexed") }
    static var previewFavorites: String { L10n.string("copy.settings.notices.preview_favorites") }

    static var pruneTitle: String { L10n.string("copy.settings.prune.title") }
    static var pruneText: String { L10n.string("copy.settings.prune.text") }
    static var pruneButton: String { L10n.string("copy.settings.prune.button") }

    static var defaultsTitle: String { L10n.string("copy.settings.defaults.title") }
    static var defaultsText: String { L10n.string("copy.settings.defaults.text") }
    static var defaultsButton: String { L10n.string("copy.settings.defaults.button") }

    static var mediaTitle: String { L10n.string("copy.settings.media.title") }
    static var mediaText: String { L10n.string("copy.settings.media.text") }
    static var mediaWarning: String { L10n.string("copy.settings.media.warning") }
    static var forgetAll: String { L10n.string("copy.settings.media.forget_all") }

    static var reportsTitle: String { L10n.string("copy.settings.reports.title") }
    static var reportsText: String { L10n.string("copy.settings.reports.text") }
    static var autoSend: String { L10n.string("copy.settings.reports.auto_send") }

    static var total: String { L10n.string("copy.medium.total") }
    static var usedFree: String { L10n.string("copy.medium.used_free") }
    static var filesFolders: String { L10n.string("copy.medium.files_folders") }
    static var files: String { L10n.string("copy.medium.files") }
    static var folders: String { L10n.string("copy.medium.folders") }
    static var lastSeen: String { L10n.string("copy.medium.last_seen") }
    static var dashboardErrorRetry: String { L10n.string("copy.dashboard.error_retry") }
    static var dashboardOccupiedSuffix: String { L10n.string("copy.dashboard.occupied_suffix") }
    static var shouldIndex: String { L10n.string("copy.medium.should_index") }
    static var forget: String { L10n.string("copy.medium.forget") }
    static var reindex: String { L10n.string("copy.medium.reindex") }
    static var showContent: String { L10n.string("copy.medium.show_content") }

    static var crashTitle: String { L10n.string("copy.crash.title") }
    static var crashBody: String { L10n.string("copy.crash.body") }
    static var crashDiscard: String { L10n.string("copy.crash.discard") }
    static var crashSend: String { L10n.string("copy.crash.send") }

    static var storeOpenFailedTitle: String { L10n.string("copy.store.open_failed.title") }
    static var storeOpenFailedBody: String { L10n.string("copy.store.open_failed.body") }

    static var indexFailedBody: String { L10n.string("copy.index.failed.body") }
    static var close: String { L10n.string("copy.action.close") }
    static var retry: String { L10n.string("copy.action.retry") }
    static var confirm: String { L10n.string("copy.action.confirm") }
    static var confirmed: String { L10n.string("copy.action.confirmed") }
    static var permissionLine: String { L10n.string("copy.permission.line") }

    static func newMediumBody(name: String, type: String, size: String) -> String {
        L10n.format("copy.new_medium.body", name, type, size)
    }

    static func indexFailedTitle(name: String) -> String {
        L10n.format("copy.index.failed.title", name)
    }

    static func pausedFor(_ span: String) -> String {
        L10n.format("copy.menu.paused_for", span)
    }

    static var columnContentsLoading: String { L10n.string("copy.column.loading_contents") }
    static var indexingInProgress: String { L10n.string("copy.column.indexing_in_progress") }
    static var folderPendingIndexingBody: String { L10n.string("copy.column.folder_pending_body") }
    static var folderNotIndexedTitle: String { L10n.string("copy.column.folder_not_indexed_title") }
    static var uncapturedContentNotCaptured: String { L10n.string("copy.column.uncaptured_title") }
    static var uncapturedScanDepthHint: String { L10n.string("copy.column.uncaptured_scan_depth") }
    static var changeScanDepth: String { L10n.string("copy.column.change_scan_depth") }
    static var folderLoadingManyObjects: String { L10n.string("copy.column.folder_loading_many") }
    static var folderLoadingProgressExample: String { L10n.string("copy.column.folder_loading_progress_example") }

    static func folderLoadingProgress(loaded: Int, total: Int) -> String {
        L10n.format(
            "copy.column.folder_loading_progress",
            DisplayNumberFormat.groupedInteger(loaded),
            DisplayNumberFormat.groupedInteger(total)
        )
    }

}

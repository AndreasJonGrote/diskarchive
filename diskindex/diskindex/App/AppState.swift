//
//  AppState.swift
//  diskindex
//
//  Kernzustand. Favoriten/Medien/Live-Sync/Pause in Erweiterungen (Aufgabe 111).
//

import SwiftUI

@Observable
final class AppState {
    var media: [Medium] = []
    var searchState = SearchState() {
        didSet {
            if oldValue.filters != searchState.filters {
                DiskIndexLog.shared.ui("filters changed")
            }
            if oldValue.submittedQuery != searchState.submittedQuery, !searchState.submittedQuery.isEmpty {
                DiskIndexLog.shared.ui("search query=\(searchState.submittedQuery)")
            }
        }
    }
    var columnBrowserState = ColumnBrowserState()
    var appSettings = AppSettings() {
        didSet {
            let newScope = IndexScope.from(appSettings)
            indexRepository.scope = indexScope
            guard settingsReady, appSettings != oldValue else { return }
            if persistsSettings {
                if oldValue.displayLanguage != appSettings.displayLanguage {
                    AppLanguagePolicy.syncFromSettings(appSettings, defaults: settingsDefaults)
                    DiskIndexLog.shared.ui("language=\(appSettings.displayLanguage.rawValue)")
                } else {
                    DiskIndexLog.shared.ui("settings changed")
                    scheduleSettingsSave()
                }
            }
            if IndexSchedule.shrinks(from: oldValue, to: appSettings) {
                armPrune(now: Date())
            }
            if IndexSchedule.grows(from: oldValue, to: appSettings) {
                for medium in media where medium.connectionStatus == .connected && medium.indexStatus == .indexing {
                    onReindexMedium?(medium.id)
                }
            }
            let scopeChanged = IndexScope.from(oldValue) != newScope
            if scopeChanged {
                indexRepository.invalidateAll()
                Task { [weak self] in
                    await self?.reloadFavorites()
                    if self?.mainWindowDestination == .search {
                        await self?.runSearch()
                    }
                }
            }
        }
    }
    var favoritesConnectionFilter: FavoritesConnectionFilter = .all
    var contextMenuHighlightObjectID: UUID?
    var settingsTab: SettingsTab = .general
    var settingsScrollTarget: SettingsScrollTarget?
    var heldForSleep = false
    var indexingFailure: IndexingFailureNotice?
    /// Index konnte nicht geöffnet werden (82).
    var indexStoreOpenFailed = false
    var indexStoreOpenFailureAlert = false
    var onRetryIndexStoreOpen: (() -> Void)?
    var globalAutoIndexPaused: Bool = false {
        didSet {
            guard oldValue != globalAutoIndexPaused else { return }
            DiskIndexLog.shared.ui("pause global=\(globalAutoIndexPaused)")
            onAutoIndexPauseChanged?()
        }
    }
    var popoverSearchText: String = ""
    var popoverPauseMenuOpen = false
    /// Pausentimer-Fenster zeigt Nase oben (unter Schalter) oder unten (über Schalter).
    var popoverPauseMenuOpensAbove = false
    var searchMatch = SearchMatch()
    var favoriteObjects: [SearchResultItem] = []
    var popoverResults = PopoverSearchResults()
    let indexRepository: IndexRepository
    private(set) var indexStore: IndexStoreV3?
    /// `true`, sobald die Datenbank offen und angehängt ist (Aufgabe 219). Davor zeigen Fenster und Popover den Ladezustand.
    var storeReady = false
    /// Der Start öffnet die Datenbank gerade (vom `AppDelegate` gesetzt); ohne Start (Tests, Vorschau) bleibt es `false`.
    var storeOpening = false
    var isStoreLoading: Bool { storeOpening && !storeReady && !indexStoreOpenFailed }
    let settingsDefaults: UserDefaults
    let persistsSettings: Bool
    var settingsSaveTask: Task<Void, Never>?
    var settingsReady = false
    private(set) var pruneAt: Date? {
        didSet { indexRepository.scope = indexScope }
    }
    static let pruneAtKey = "diskindex.pruneAt"
    var pendingMediumWrites: [UUID: Task<Void, Never>] = [:]
    var changeLoop: Task<Void, Never>?
    var lastChangeGeneration = 0
    var lastIndexReload: [UUID: ContinuousClock.Instant] = [:]
    var trailingIndexReload: [UUID: Task<Void, Never>] = [:]
    var trailingMediumRefreshOperations: [UUID: [() async -> Void]] = [:]
    var columnInvalidateTasks: [UUID: Task<Void, Never>] = [:]
    /// Vereinigte Spaltenpfade bis zum verzögerten Invalidate (Aufgabe 183 c).
    var pendingColumnFolderPathKeys: [UUID: Set<String>] = [:]
    var pendingColumnInvalidateWholeMedium: Set<UUID> = []
    /// Vereinigte `.items`-Pfade bis zum debounced Refresh (Aufgabe 183 c).
    var accumulatedItemRefreshPathKeys: [UUID: Set<String>] = [:]
    /// Laufender Live-Abgleich (FSEvents), nicht Vollindizierung.
    var mediumLiveSyncIDs: Set<UUID> = []
    /// Menüleisten-Spinner: nur bei tatsächlich laufender Indizierung (nicht DB-Status allein).
    var menuBarIndexingSpinnerIDs: Set<UUID> = []
    var searchGeneration = 0
    var lastLiveSearchAt: ContinuousClock.Instant?
    var trailingLiveSearch: Task<Void, Never>?
    var searchCountTask: Task<Void, Never>?
    var lastCountedSearch: SearchCountRequest?
    var popoverGeneration = 0
    var favoriteGeneration = 0
    static let pauseKey = "diskindex.globalPause"
    static let failureCountsKey = "diskindex.failureModalCounts"
    var storedPause = GlobalPause()
    var pauseExpiryTask: Task<Void, Never>?
    /// Filter gehören zur Ansicht: jeder echte Wechsel schließt die Leiste und leert die Filter (Aufgabe 23.2).
    var mainWindowDestination: MainWindowDestination = .dashboard {
        didSet {
            guard oldValue != mainWindowDestination else { return }
            DiskIndexLog.shared.ui("view destination=\(mainWindowDestination)")
            columnBrowserState.selection = ColumnSelection()
            isFilterBarVisible = false
            searchState.filters = SearchFilters()
            if oldValue == .columnBrowser, mainWindowDestination != .columnBrowser {
                columnBrowserState.selectedMediumID = nil
                columnBrowserState.pathStack = []
                columnBrowserState.selectedUncapturedFolderID = nil
            }
        }
    }
    var mainWindowDestinationBeforeSearch: MainWindowDestination?
    var isFilterBarVisible = false
    /// Hochzählen = Objekt-Suchfeld verliert den Fokus (Scaffold reagiert, Aufgabe 28).
    var searchFieldFocusResetCount = 0
    var detailMediumID: UUID?
    /// FIFO: verbundene Medien, die noch Ja/Nein im Erkennungs-Dialog brauchen (0.3.2).
    var pendingNewMediumDecisionIDs: [UUID] = []
    /// Panels, die der Nutzer ohne Ja/Nein geschlossen hat (Badge/Queue bleiben).
    var dismissedNewMediumPanelIDs: Set<UUID> = []
    /// Vorderstes Medium der Warteschlange (verbunden, unentschieden).
    var newMediumDialogMediumID: UUID? {
        pendingNewMediumDecisionIDs.first { id in
            guard let medium = medium(with: id) else { return false }
            return medium.connectionStatus == .connected && medium.decision == .undecided
        }
    }
    var hasPendingNewMediumDecisions: Bool { newMediumDialogMediumID != nil }
    /// Medium-ID, indizieren ja/nein, „merken“. Gesetzt vom `MediumCoordinator`.
    var onNewMediumChoice: ((UUID, Bool, Bool) -> Void)?
    /// Einstellungen → Speichermedien / Medium-Details: Ja/Nein steuert Lauf und Watcher (`LiveWiring`).
    @ObservationIgnored var onMediumDecisionChanged: ((UUID, StoredIndexDecision, Bool) -> Void)?
    /// „Neu indizieren“. Gesetzt vom `IndexingService`.
    var onReindexMedium: ((UUID) -> Void)?
    /// Klick ist angekommen, der Lauf hat noch nicht begonnen.
    var reindexRequested: Set<UUID> = []
    /// Wechselt, wenn die 59-s-Sperre abläuft, damit die Knöpfe ohne weiteren Klick neu zeichnen.
    var reindexGateTick: Date = .distantPast
    var reindexGateTasks: [UUID: Task<Void, Never>] = [:]
    let indexProgressDisplay = IndexProgressDisplay()
    let noticeThrottle = NoticeThrottle()
    var noticeToggleSequence = 0
    /// Kästchen „Mitteilungen aktivieren“; weicht vom wirksamen Wert nur ab, solange die Aus-Meldung zugestellt wird.
    private var noticeToggleShownOverride: Bool?
    var notificationsToggleShown: Bool {
        get { noticeToggleShownOverride ?? appSettings.notificationsEnabled }
        set { noticeToggleShownOverride = newValue }
    }

    func settleNotificationsToggleShown() {
        noticeToggleShownOverride = nil
    }

    /// Spiegel von `LaunchAtLogin.state`; nur im Hintergrund gelesen.
    var launchAtLoginState: LaunchAtLogin.State = .off

    func refreshLaunchAtLoginState() {
        Task { @MainActor [weak self] in
            let state = await Task.detached { LaunchAtLogin.state }.value
            self?.launchAtLoginState = state
        }
    }
    /// Popover-Schalter „Automatisches Indizieren“.
    var onAutoIndexPauseChanged: (() -> Void)?
    /// Vor dem Löschen in der DB: Überwachung und Läufe stoppen (`LiveWiring`).
    @ObservationIgnored var onMediaForgotten: (([UUID]) async -> Void)?
    /// Einhängepfad eines angeschlossenen Mediums. Der Koordinator setzt das.
    var mountPath: ((UUID) -> String?)?

    init(store: IndexStoreV3? = nil, defaults: UserDefaults? = nil) {
        indexStore = store
        indexRepository = IndexRepository(store: store)
        if let defaults {
            settingsDefaults = defaults
            persistsSettings = true
            appSettings = AppLanguagePolicy.bootstrap(defaults: defaults)
            loadPause(from: defaults)
            loadPruneDeadline()
        } else {
            settingsDefaults = AppDefaults.current
            persistsSettings = false
        }
        indexRepository.scope = indexScope
        AppLanguagePolicy.noteActiveDisplayLanguage(appSettings.displayLanguage)
        settingsReady = true
    }

    func attach(store: IndexStoreV3) {
        indexStore = store
        storeReady = true
        indexRepository.replaceStore(store)
    }

    /// Change-Loop stoppen; Store bleibt angehängt (Retry/Rewire vor neuem `attach`).
    func cancelChangeLoop() {
        changeLoop?.cancel()
        changeLoop = nil
    }

    /// Nach Integritätsfehler oder totem Pool: Loop und Store-Referenz lösen (c.0.3.2.003).
    func detachFromIndexStore() {
        cancelChangeLoop()
        indexStore = nil
        storeReady = false
        lastChangeGeneration = 0
        indexRepository.replaceStore(nil)
    }

    // MARK: - Filter & Suche

    func toggleFilterBarVisible() {
        if isFilterBarVisible {
            isFilterBarVisible = false
            searchState.filters = SearchFilters()
        } else {
            isFilterBarVisible = true
        }
    }

    /// Filter gibt es nur, wo gefiltert werden kann (README 29.09. (2)).
    var isFilterAvailable: Bool {
        switch mainWindowDestination {
        case .columnBrowser, .search, .favorites: true
        case .dashboard, .settings: false
        }
    }

    /// Leiste sichtbar = geöffnet UND in dieser Ansicht verfügbar.
    var showsFilterBar: Bool {
        isFilterBarVisible && isFilterAvailable
    }

    /// Wirken in der aktuellen Ansicht Filter? Die Medium-Auswahl zählt nur in der Suche.
    var hasEffectiveFilters: Bool {
        mainWindowDestination == .search
            ? searchState.filters.hasActiveFilters
            : searchState.filters.hasActiveObjectFilters
    }

    /// Abgeschickter Suchbegriff in der Suche (sperrt die „Und“-Verknüpfung, Aufgabe 33.1).
    var hasActiveSearchTerm: Bool {
        mainWindowDestination == .search
            && !searchState.submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Bildschirmfotos halten Suche und Favoriten auf den gesetzten Treffern.
    var screenshotFrozenLists = false
    /// Mitteilungsvorschau in den Einstellungen fest auf ein Ereignis.
    var noticePreviewPin: DiskNotice?

    /// Such-Icon öffnet die Suche mit geöffneter Filterleiste.
    func toggleSearchFromToolbar() {
        detailMediumID = nil
        if mainWindowDestination == .search {
            mainWindowDestination = mainWindowDestinationBeforeSearch ?? .dashboard
            mainWindowDestinationBeforeSearch = nil
        } else {
            searchState.query = ""
            searchState.submittedQuery = ""
            enterSearch()
            isFilterBarVisible = true
        }
    }

    /// Enter im Objekt-Suchfeld (alle Screens) — einziger Weg, per Tippen in die Suche zu kommen.
    func submitObjectSearch() {
        searchState.submittedQuery = searchState.query
        enterSearch()
    }

    /// Eine Quelle für den Bereich, den Suche, Spalten und Favoriten anwenden.
    /// Namensprüfung nur, solange eine Bereinigung aussteht (`pruneAt`); sonst reines SQL.
    var indexScope: IndexScope { IndexScope.from(appSettings, pruneAwaiting: pruneAt != nil) }

    /// X im Objekt-Suchfeld: Feld und Suche leeren (Leerzustand wie beim ersten Öffnen); laufende Suche verwerfen.
    func clearObjectSearch() {
        searchState.query = ""
        searchState.submittedQuery = ""
        searchGeneration += 1
        searchCountTask?.cancel()
        searchCountTask = nil
        lastCountedSearch = nil
        searchMatch = SearchMatch()
        searchState.isSearchInProgress = false
    }

    /// Vollständig programmatisch gesetzter Begriff (Kontextmenü, Popover) — wird sofort abgeschickt.
    func openSearch(withQuery query: String) {
        searchState.query = query
        searchState.submittedQuery = query
        enterSearch()
    }

    private func enterSearch() {
        detailMediumID = nil
        guard mainWindowDestination != .search else { return }
        mainWindowDestinationBeforeSearch = mainWindowDestination
        mainWindowDestination = .search
    }

    /// „Im Finder anzeigen“ (Detail-Spalte + Kontextmenü). Ohne Wirkung bis zum Backend (echte Pfade),
    /// dann `NSWorkspace.shared.activateFileViewerSelecting(_:)`.
    func revealInFinder(_ target: ObjectContextTarget) {
        DiskIndexLog.shared.ui("revealInFinder kind=\(target.kind) id=\(target.id)")
        guard target.isMediumOnline else { return }
        guard let url = FinderReveal.url(
            mountPath: mountPath?(target.mediumID),
            itemPath: target.itemPath,
            kindIsMedium: target.kind == .medium
        ) else { return }
        let chosen: URL
        if FileManager.default.fileExists(atPath: url.path) {
            chosen = url
        } else {
            let parent = url.deletingLastPathComponent()
            guard parent.path != url.path, FileManager.default.fileExists(atPath: parent.path) else { return }
            chosen = parent
        }
        NSWorkspace.shared.activateFileViewerSelecting([chosen])
    }

    /// „Index jetzt bereinigen“: löscht sofort, was nicht mehr zu den Einstellungen passt.
    func requestIgnoredObjectsPurgeNow() {
        Task { await pruneNow() }
    }

    func armPrune(now: Date) {
        let due = IndexSchedule.deadline(from: now)
        pruneAt = due
        guard persistsSettings else { return }
        settingsDefaults.set(due.timeIntervalSince1970, forKey: Self.pruneAtKey)
    }

    func loadPruneDeadline() {
        let value = settingsDefaults.double(forKey: Self.pruneAtKey)
        pruneAt = value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    func clearPruneDeadline() {
        pruneAt = nil
        guard persistsSettings else { return }
        settingsDefaults.removeObject(forKey: Self.pruneAtKey)
    }

    func pruneIfDue(now: Date = Date()) async {
        guard IndexSchedule.isDue(pruneAt, now: now) else { return }
        await pruneNow()
    }

    func pruneNow() async {
        guard let indexStore else { return }
        do {
            _ = try await indexStore.pruneToMatch(IndexScope.from(appSettings))
            clearPruneDeadline()
            await loadStoredMedia()
            indexRepository.invalidateAll()
            await reloadFavorites()
            if mainWindowDestination == .search { await runSearch() }
            SystemNotice.post(body: LayoutCopy.noticePrune, settings: appSettings)
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.index, .error, "index prune \(error)")
        }
    }

}

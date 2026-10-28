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
    var columnBrowserState = ColumnBrowserState() {
        didSet {
            // Sichtbare Spalten vor dem Verdrängen aus dem Spalten-Cache schützen (bug.0.4.036).
            guard oldValue.selectedMediumID != columnBrowserState.selectedMediumID
                || oldValue.pathStack != columnBrowserState.pathStack else { return }
            indexRepository.pinVisibleColumns(
                mediumID: columnBrowserState.selectedMediumID,
                pathStack: columnBrowserState.pathStack
            )
        }
    }
    var appSettings = AppSettings() {
        didSet {
            let newScope = IndexScope.from(appSettings)
            indexRepository.scope = indexScope
            guard settingsReady, appSettings != oldValue else { return }
            if oldValue.autoSendCrashReports != appSettings.autoSendCrashReports {
                AppSettingsRuntimeCache.setAutoSend(appSettings.autoSendCrashReports)
            }
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
            let scopeChanged = IndexScope.from(oldValue) != newScope
            if scopeChanged {
                hideResultsInPlace(by: newScope)
                let indexingIDs = media.filter { $0.connectionStatus == .connected && $0.indexStatus == .indexing }.map(\.id)
                let scopeGrew = IndexSchedule.grows(from: oldValue, to: appSettings)
                onScopeRulesChanged?(indexingIDs, scopeGrew)
                if mainWindowDestination == .search {
                    pendingSearchAfterRuleReconcile = true
                }
                enqueueRuleReconcile()
            }
        }
    }
    var favoritesConnectionFilter: FavoritesConnectionFilter = .all
    var contextMenuHighlightObjectID: UUID?
    var settingsTab: SettingsTab = .general {
        didSet {
            // bug.0.4.135 (Regel 15): Das Scroll-Ziel gilt nur für den Tab, in den gesprungen wurde; die Ansicht scrollt
            // beim Erscheinen und ändert selbst keinen Zustand.
            if settingsTab != oldValue, settingsTab != .files { settingsScrollTarget = nil }
        }
    }
    var settingsScrollTarget: SettingsScrollTarget?
    var heldForSleep = false
    /// bug.0.4.120: Ablauf des Starts je Instanz (Tests; kein Prozess-Zustand): Einstellungen geladen, bevor der Monitor startet.
    @ObservationIgnored var didHydrateSettingsBeforeRecognition = false
    /// `true`, sobald der Monitor vor `loadStoredMedia` gestartet wurde.
    @ObservationIgnored var didStartCoordinatorBeforeLoad = false
    var indexingFailure: IndexingFailureNotice?
    /// todo.0.4.047: öffnet eine Adresse im Browser (Tests ersetzen das je Instanz).
    @ObservationIgnored var openExternalURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    /// bug.0.4.193/199: Medien mit zugestellter Fehler-Mitteilung – unabhängig davon, ob der Hinweis noch steht; ein
    /// erfolgreicher Lauf, das Aushängen und „Nein“ ziehen sie zurück.
    @ObservationIgnored var failureNoticeMedia: Set<UUID> = []
    /// bug.0.4.199: Rückzug einer Fehler-Mitteilung (Tests ersetzen das je Instanz; der Lauf endet in einem
    /// losgelösten Task, dort gilt der Task-lokale Haken von `SystemNotice` nicht).
    @ObservationIgnored var withdrawIndexingFailureNotice: @MainActor (UUID) -> Void = {
        SystemNotice.withdrawIndexingFailure(mediumID: $0)
    }
    var replaceMediumPrompt: ReplaceMediumPrompt?
    var ignoreConfirmationPrompt: IgnoreConfirmationPrompt?
    /// Wo die Rückfrage-Panels erscheinen; `nil` = kein Panel. Die App setzt `.centered` beim Start
    /// (`configureForApp`, aus `applicationDidFinishLaunching`), ein Test setzt `.offscreen` je Instanz
    /// (bug.0.3.9.005 c, bug.0.3.9.014 d: kein Prozess-Schalter).
    @ObservationIgnored var promptPanelPlacement: PromptPanelPlacement?
    #if DEBUG
    /// Tests (bug.0.4.209): ein Dialog dieser Instanz wird nach vorn geholt und zum Key-Fenster gemacht (im Test
    /// außerhalb des Bildschirms nur gezählt). Wert: Art des Dialogs.
    @ObservationIgnored var promptFocusHookForTesting: ((String) -> Void)?
    /// Tests (bug.0.4.221): statt die App zu aktivieren (`AppWindowPresenter.bringForward` bei `.centered`). Wert: Art
    /// des Dialogs.
    @ObservationIgnored var promptActivationHookForTesting: ((String) -> Void)?
    #endif

    /// Einstellungen, die nur die App-Instanz bekommt (bug.0.3.9.014 d): Rückfragen mittig.
    func configureForApp() {
        promptPanelPlacement = .centered
    }
    var versionLockState: VersionLockState = .unlocked
    var versionLockBannerVisible = false
    var updateNotice: UpdateNotice?
    @ObservationIgnored var onVersionLockEngaged: (() -> Void)?
    /// bug.0.4.063: Übergang gesperrt → entsperrt (LiveWiring nimmt Überwachung und Indizierung wieder auf).
    @ObservationIgnored var onVersionLockReleased: (() -> Void)?
    /// Nach Versions-Check (todo.0.4.011): Anmeldung kann einmal das Hauptfenster öffnen.
    @ObservationIgnored var onVersionCheckEvaluationApplied: (() -> Void)?
    /// Index konnte nicht geöffnet werden (82).
    var indexStoreOpenFailed = false
    var indexStoreOpenFailureAlert = false
    var onRetryIndexStoreOpen: (() -> Void)?
    var globalAutoIndexPaused: Bool = false {
        didSet {
            guard oldValue != globalAutoIndexPaused else { return }
            // Beim Laden im `init` (vor der Einzelinstanz-Prüfung) nichts protokollieren (Review bug.0.4.042).
            guard settingsReady else { return }
            DiskIndexLog.shared.ui("pause global=\(globalAutoIndexPaused)")
            onAutoIndexPauseChanged?()
        }
    }
    var popoverSearchText: String = ""
    var popoverPauseMenuOpen = false
    /// Pausentimer-Fenster zeigt Nase oben (unter Schalter) oder unten (über Schalter).
    var popoverPauseMenuOpensAbove = false
    var searchMatch = SearchMatch()
    /// bug.0.4.132: Zähler je Nutzeraktion (Öffnen über `openObject`, Klick, Taste) – die Spaltenansicht scrollt dann
    /// waagerecht und senkrecht zur Auswahl; Live-Änderungen zählen nicht.
    var columnScrollToken = 0
    var favoriteObjects: [SearchResultItem] = []
    /// bug.0.4.040: Zahl der Favoriten zur Anfrage (`nil` = wird gezählt, „–“) und ohne Dateityp/Alter („x von y“).
    var favoriteItemCount: Int? = 0
    var favoriteUnfilteredCount: Int? = 0
    @ObservationIgnored var lastFavoritesRequest: FavoritesRequest?
    /// bug.0.4.037: alle Favoriten-Kennungen (`items.id`), Quelle für `isFavorite` bei Dateien/Ordnern; `nil` bis geladen.
    var favoriteRowIDs: Set<Int64>?
    /// Umschalten, bevor `favoriteRowIDs` geladen ist.
    var favoriteEditsBeforeLoad: [Int64: Bool] = [:]
    @ObservationIgnored var favoriteEditGeneration = 0
    @ObservationIgnored var favoriteWriteTail: Task<Void, Never>?
    @ObservationIgnored var favoriteIDsLoadTask: Task<Void, Never>?
    @ObservationIgnored var favoritePageReloadTask: Task<Void, Never>?
    /// bug.0.3.9.006 b: Wiederherstellen aus der Datenbank nach fehlgeschlagenem Schreiben (nacheinander).
    @ObservationIgnored var favoriteRestoreTask: Task<Void, Never>?
    var popoverResults = PopoverSearchResults()
    let indexRepository: IndexRepository
    private(set) var indexStore: IndexStoreV3?
    /// `true`, sobald die Datenbank offen und angehängt ist (Aufgabe 219). Davor zeigen Fenster und Popover den Ladezustand.
    var storeReady = false
    /// Der Start öffnet die Datenbank gerade (vom `AppDelegate` gesetzt); ohne Start (Tests, Vorschau) bleibt es `false`.
    var storeOpening = false
    var isStoreLoading: Bool { storeOpening && !storeReady && !indexStoreOpenFailed }
    let settingsDefaults: AppStateStore
    let persistsSettings: Bool
    var settingsSaveTask: Task<Void, Never>?
    var settingsReady = false
    /// bug.0.4.105: Eintrag in `settings` war nicht lesbar → nicht überschreiben (bis zum nächsten Start).
    /// bug.0.4.153: beobachtbar, das Einstellungsfenster zeigt dann den Hinweis; die Sitzung läuft wie pausiert.
    var settingsUnreadable = false
    private var pruneDeadlineGeneration = 0
    private var pruneScheduleTask: Task<Void, Never>?
    @ObservationIgnored var pruneClock: @Sendable () -> Date = { Date() }
    private(set) var pruneAt: Date? {
        didSet { indexRepository.scope = indexScope }
    }
    static let pruneAtKey = "diskindex.pruneAt"
    var isRuleReconcileQueueActive = false
    var ruleReconcileTask: Task<Void, Never>?
    var ruleReconcileNeedsRerun = false
    /// Scope/Regel-Änderung während Versions-Sperre; nach Unlock einmal nachziehen (c.0.3.3.002).
    var ruleReconcileDeferredWhileLocked = false
    var ruleReconcileIdleWaiters: [CheckedContinuation<Void, Never>] = []
    var databaseMaintenanceTask: Task<Void, Never>?
    var pendingSearchAfterRuleReconcile = false
    var pendingMediumWrites: [UUID: Task<Void, Never>] = [:]
    /// Entscheidung in 05/06 geändert, noch nicht geschrieben (bug.0.4.075): nur dann schreibt `writeMedium` die
    /// Entscheidung und setzt „Für dieses Medium merken“. Wert = Zähler der Änderung; die Marke fällt erst nach
    /// erfolgreichem Schreiben derselben Änderung weg (eine spätere Änderung während des Schreibens bleibt stehen).
    @ObservationIgnored var userDecisionIDs: [UUID: Int] = [:]
    /// Favoriten-Schreib- und Prüfsummen-Aufgaben; jede entfernt sich am Ende selbst (bug.0.3.9.006 c).
    @ObservationIgnored var favoriteChecksumTasks: [UUID: Task<Void, Never>] = [:]
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
    /// todo.0.4.042: Anfrage, zu der die sichtbaren Treffer gehören (`nil` = noch keine Suche abgeschlossen).
    var shownSearch: SearchCountRequest?
    var popoverGeneration = 0
    /// bug.0.4.039: laufende Popover-Suche (Seite) und nachgereichte Zahl; neue Eingabe bricht beide ab.
    @ObservationIgnored var popoverSearchTask: Task<Void, Never>?
    @ObservationIgnored var popoverCountTask: Task<Void, Never>?
    /// Entprellung der Popover-Eingabe; Tests dürfen sie je Instanz verkürzen.
    @ObservationIgnored var popoverSearchDebounce: Duration = .milliseconds(150)
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
            if oldValue == .settings { settingsScrollTarget = nil }
            if oldValue == .columnBrowser, mainWindowDestination != .columnBrowser {
                columnBrowserState.selectedMediumID = nil
                columnBrowserState.pathStack = []
                columnBrowserState.selectedUncapturedFolderID = nil
            }
            // bug.0.4.135 (Regel 15): Auswahl und Pfad hier normalisieren, nicht in `onAppear` der Ansicht.
            if mainWindowDestination == .columnBrowser {
                ensureColumnBrowserSelection()
                clampColumnPathToScanDepth()
            }
            // todo.0.4.043: Beim Öffnen der Favoriten sofort die Ladefläche, mindestens 1 s (Ende: erste geladene Seite).
            if mainWindowDestination == .favorites, !screenshotFrozenLists {
                favoritesLoading.begin()
            } else if oldValue == .favorites {
                favoritesLoading.cancel()
            }
            // todo.0.4.042: Verlassen der Suche beendet ihre Ladeansicht.
            if oldValue == .search, mainWindowDestination != .search {
                searchLoading.cancel()
            }
        }
    }
    /// todo.0.4.043: Ladeanzeige der Favoriten (gemeinsamer Baustein mit der Suche, todo.0.4.042).
    /// bug.0.4.163 (e): Mindestdauer über `init` (Standard 1 s), Tests mit kurzer Dauer.
    let favoritesLoading: MinimumLoadingIndicator
    /// todo.0.4.042: Ladeansicht der Suche aus dem Leerzustand (gleicher Baustein, gleiche Mindestdauer wie die Favoriten).
    let searchLoading: MinimumLoadingIndicator
    var mainWindowDestinationBeforeSearch: MainWindowDestination?
    var isFilterBarVisible = false
    /// Filter-Panel unter dem Trichter offen (bug.0.4.212: im Zustand statt in der Ansicht, testbar im Fenster).
    var isFilterPopoverShown = false
    /// Hochzählen = Objekt-Suchfeld verliert den Fokus (Scaffold reagiert, Aufgabe 28).
    var searchFieldFocusResetCount = 0
    var detailMediumID: UUID?
    /// FIFO: verbundene Medien, die noch Ja/Nein im Erkennungs-Dialog brauchen (0.3.2).
    var pendingNewMediumDecisionIDs: [UUID] = []
    /// Panels, die der Nutzer ohne Ja/Nein geschlossen hat (Badge/Queue bleiben).
    var dismissedNewMediumPanelIDs: Set<UUID> = []
    /// Vorderstes Medium der Warteschlange (verbunden; unentschieden oder erneut gefragt, todo.0.4.026).
    var newMediumDialogMediumID: UUID? {
        pendingNewMediumDecisionIDs.first { needsNewMediumDialog($0) }
    }
    var hasPendingNewMediumDecisions: Bool { newMediumDialogMediumID != nil }
    /// Medium-ID, indizieren ja/nein, „merken“. Gesetzt vom `MediumCoordinator`.
    var onNewMediumChoice: ((UUID, Bool, Bool) -> Void)?
    /// bug.0.4.215: Antwort auf „Ersetzt dieses Medium?“ (Rückfrage, „Altes vergessen“). Gesetzt vom `MediumCoordinator`.
    @ObservationIgnored var onReplaceMediumResolved: ((ReplaceMediumPrompt, Bool) -> Void)?
    /// Einstellungen → Speichermedien / Medium-Details: Ja/Nein steuert Lauf und Watcher (`LiveWiring`).
    @ObservationIgnored var onMediumDecisionChanged: ((UUID, StoredIndexDecision, Bool) -> Void)?
    /// „Neu indizieren“. Gesetzt vom `IndexingService`.
    var onReindexMedium: ((UUID) -> Void)?
    /// Regel-Scope geändert: abbrechen und Abgleich neu (bug.0.4.030).
    @ObservationIgnored var onScopeRulesChanged: ((_ indexingIDs: [UUID], _ scopeGrew: Bool) -> Void)?
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
    /// Systemregistrierung „Bei Systemstart“; Tests ersetzen sie je Instanz (bug.0.3.9.001, statt statischem Schalter).
    @ObservationIgnored var launchAtLoginRegister: @Sendable (Bool) -> Void = { LaunchAtLogin.setEnabled($0) }
    /// Systemabfrage „Bei Systemstart“ (nur im Hintergrund); Tests ersetzen sie je Instanz (bug.0.3.9.001).
    @ObservationIgnored var launchAtLoginStateProvider: @Sendable () -> LaunchAtLogin.State = { LaunchAtLogin.state }

    func refreshLaunchAtLoginState() {
        let provider = launchAtLoginStateProvider
        Task { @MainActor [weak self] in
            let state = await Task.detached { provider() }.value
            self?.launchAtLoginState = state
        }
    }
    /// Popover-Schalter „Automatisches Indizieren“.
    var onAutoIndexPauseChanged: (() -> Void)?
    /// Vor dem Löschen in der DB: Überwachung und Läufe stoppen (`LiveWiring`).
    @ObservationIgnored var onMediaForgotten: (([UUID]) async -> Void)?
    /// Einhängepfad eines angeschlossenen Mediums. Der Koordinator setzt das.
    var mountPath: ((UUID) -> String?)?

    /// `loadingMinimum`: Mindestdauer der Ladeansicht von Favoriten und Suche (eine Quelle, todo.0.4.042/043).
    init(store: IndexStoreV3? = nil, defaults: AppStateStore? = nil, loadingMinimum: Duration = .seconds(1)) {
        favoritesLoading = MinimumLoadingIndicator(minimum: loadingMinimum)
        searchLoading = MinimumLoadingIndicator(minimum: loadingMinimum)
        indexStore = store
        indexRepository = IndexRepository(store: store)
        defer {
            indexRepository.onColumnReloaded = { [weak self] mediumID, path, previous, items in
                self?.followOpenPathAfterReload(mediumID: mediumID, path: path, previous: previous, items: items)
                self?.dropVanishedColumnSelection(mediumID: mediumID, path: path, items: items)
            }
        }
        if store != nil {
            storeReady = true
        }
        if let defaults {
            settingsDefaults = defaults
            persistsSettings = true
            appSettings = AppLanguagePolicy.bootstrap(defaults: defaults)
            loadPause(from: defaults)
            // Nur lesen: geplant wird erst nach dem Laden der Einstellungen (`bootstrap`), sonst bereinigt der
            // Task mit Standardwerten und löscht den Termin (bug.0.4.029).
            loadPruneDeadline(schedule: false)
        } else {
            settingsDefaults = AppStateStore.current
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
        // bug.0.4.037: Favoriten-Kennungen gehören zum Store; neu laden, sobald sie gebraucht werden.
        favoriteRowIDs = nil
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
    /// Bereich für Lesezugriffe; Namensregeln laufen über `status`, nicht Swift-Filter (234).
    var indexScope: IndexScope { IndexScope.from(appSettings) }

    /// X im Objekt-Suchfeld: Feld und Suche leeren (Leerzustand wie beim ersten Öffnen); laufende Suche verwerfen.
    func clearObjectSearch() {
        searchState.query = ""
        searchState.submittedQuery = ""
        searchGeneration += 1
        searchCountTask?.cancel()
        searchCountTask = nil
        lastCountedSearch = nil
        // todo.0.4.042 (Selbstprüfung 23): Mit aktiven Filtern bleibt die Anfrage dieselbe (keine neue Suche) – der geleerte
        // Stand gilt als angezeigt, sonst stünde der Wartescreen für immer.
        shownSearch = SearchCountRequest(query: "", filters: searchState.filters)
        searchMatch = SearchMatch()
        searchState.isSearchInProgress = false
        searchLoading.cancel()
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

    /// Existenzprüfung auf dem Medium für „Im Finder anzeigen“; läuft im Hintergrund (bug.0.4.062). Tests ersetzen sie.
    @ObservationIgnored var finderRevealFileExists: @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    /// Öffnet den Finder (main). Tests ersetzen es, damit kein Finder-Fenster aufgeht.
    @ObservationIgnored var finderRevealOpen: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }

    /// „Im Finder anzeigen“ (Detail-Spalte + Kontextmenü): `NSWorkspace.shared.activateFileViewerSelecting(_:)`.
    /// bug.0.4.062 (REPORT 132): `fileExists` auf dem Medium nicht synchron auf main (langsame oder hängende Platte).
    @discardableResult
    func revealInFinder(_ target: ObjectContextTarget) -> Task<Void, Never>? {
        DiskIndexLog.shared.ui("revealInFinder kind=\(target.kind) id=\(target.id)")
        guard isMediumOnline(target.mediumID) else { return nil }
        guard let url = FinderReveal.url(
            mountPath: mountPath?(target.mediumID),
            itemPath: target.itemPath,
            kindIsMedium: target.kind == .medium
        ) else { return nil }
        let exists = finderRevealFileExists
        return Task { [weak self] in
            let chosen = await Task.detached(priority: .userInitiated) {
                Self.finderRevealTarget(for: url, exists: exists)
            }.value
            guard let chosen, let self else { return }
            self.finderRevealOpen(chosen)
        }
    }

    /// Ziel selbst, sonst der Elternordner (falls vorhanden).
    nonisolated static func finderRevealTarget(for url: URL, exists: (String) -> Bool) -> URL? {
        if exists(url.path) { return url }
        let parent = url.deletingLastPathComponent()
        guard parent.path != url.path, exists(parent.path) else { return nil }
        return parent
    }

    /// „Index jetzt bereinigen“: löscht sofort, was nicht mehr zu den Einstellungen passt.
    func requestIgnoredObjectsPurgeNow() {
        Task { await pruneNow() }
    }

    func armPrune(now: Date) {
        pruneDeadlineGeneration += 1
        let due = IndexSchedule.deadline(from: now)
        pruneAt = due
        guard persistsSettings else { return }
        settingsDefaults.set(due, forKey: Self.pruneAtKey)
        schedulePruneTask(from: now)
    }

    func loadPruneDeadline(schedule: Bool = true) {
        pruneAt = settingsDefaults.date(forKey: Self.pruneAtKey)
        guard schedule else { return }
        schedulePruneTask(from: pruneClock())
    }

    /// Start: den gelesenen Termin planen, nachdem die Einstellungen geladen sind.
    func scheduleLoadedPruneDeadline() {
        guard persistsSettings else { return }
        schedulePruneTask(from: pruneClock())
    }

    private func schedulePruneTask(from now: Date) {
        pruneScheduleTask?.cancel()
        pruneScheduleTask = nil
        guard let due = pruneAt else { return }
        let delay = due.timeIntervalSince(now)
        pruneScheduleTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, let self else { return }
            await self.pruneIfDue(now: self.pruneClock())
        }
    }

    func cancelPruneScheduleForTermination() {
        pruneScheduleTask?.cancel()
        pruneScheduleTask = nil
    }

    func clearPruneDeadline() {
        pruneAt = nil
        guard persistsSettings else { return }
        settingsDefaults.remove(forKey: Self.pruneAtKey)
    }

    func pruneIfDue(now: Date = Date()) async {
        guard IndexSchedule.isDue(pruneAt, now: now) else { return }
        await pruneNow()
    }

    func pruneNow() async {
        guard featureAccess.canWriteIndex else { return }
        // bug.0.4.105: Einstellungen nicht lesbar → Voreinstellungen nur im Speicher; nie danach bereinigen (der Termin
        // bleibt stehen).
        guard !settingsUnreadable else {
            DiskIndexLog.shared.record(.index, .info, "prune skipped settings unreadable")
            return
        }
        guard let indexStore else { return }
        let generation = pruneDeadlineGeneration
        do {
            _ = try await indexStore.pruneToMatch(IndexScope.from(appSettings))
            if generation == pruneDeadlineGeneration {
                clearPruneDeadline()
            }
            await loadStoredMedia()
            // bug.0.4.088: veraltet statt leer (die gelöschten Zeilen waren schon ausgeblendet).
            indexRepository.markAllStale()
            await reloadFavorites()
            if mainWindowDestination == .search { await runSearch() }
            SystemNotice.post(body: LayoutCopy.noticePrune, settings: appSettings)
            scheduleDatabaseMaintenance()
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.index, .error, "index prune \(DiskIndexLog.errorSummary(error))")
        }
    }

}

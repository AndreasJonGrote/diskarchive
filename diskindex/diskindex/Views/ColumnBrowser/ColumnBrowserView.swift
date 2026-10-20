//
//  ColumnBrowserView.swift
//  diskindex
//
//  README Screen 06 — Spaltenansicht.
//

import SwiftUI

private struct ColumnBrowserFolderColumn: Identifiable {
    enum Special {
        case uncapturedStatus(folderID: UUID)
    }

    let id: String
    let columnIndex: Int
    let path: [String]
    let items: [IndexedItem]
    /// Einmal pro Spaltenaufbau (107): Filter auf `items`, nicht je Zeile neu.
    let filteredItems: [IndexedItem]
    let special: Special?

    init(
        id: String,
        columnIndex: Int,
        path: [String],
        items: [IndexedItem],
        filteredItems: [IndexedItem],
        special: Special? = nil
    ) {
        self.id = id
        self.columnIndex = columnIndex
        self.path = path
        self.items = items
        self.filteredItems = filteredItems
        self.special = special
    }
}

struct ColumnBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var sidebarMediumFilter = ""
    @FocusState private var focusedColumn: Int?
    /// Nur die gezogene Spalte live breiter/schmaler; Commit erst in `ColumnResizeHandle.onEnded`.
    @State private var columnResizePreview: (columnIndex: Int, width: CGFloat)?
    @Environment(\.columnTableViewMinimum) private var tableViewMinimum
    /// bug.0.4.132: zuletzt vollständig ausgeführter waagerechter Scroll-Auftrag.
    @State private var horizontalScrollDoneToken: Int?

    private var resolvedSelectedMedium: Medium? {
        if let id = appState.columnBrowserState.selectedMediumID,
           let medium = appState.columnBrowserMedia.first(where: { $0.id == id }), !medium.isForgotten {
            return medium
        }
        return appState.columnBrowserMedia.first
    }

    private func makeFolderColumns(for mediumID: UUID) -> [ColumnBrowserFolderColumn] {
        let stack = appState.columnBrowserState.pathStack
        let baseDepth = stack.count + 1
        let filters = appState.searchState.filters
        let keepFolders = appState.appSettings.showFoldersRegardlessOfFilter
        var columns: [ColumnBrowserFolderColumn] = (0..<baseDepth).map { columnIndex in
            let path = Array(stack.prefix(columnIndex))
            // bug.0.4.090: Medium in der Kennung. Vorher hieß die Wurzel jedes Mediums „root“: ihre Ansicht blieb beim
            // Medienwechsel stehen und meldete das Ende eines Ladehinweises für das neue Medium – der Hinweis des alten
            // blieb hängen (Wurzel füllte die Restbreite, keine Trennlinie, keine Details), bis die Ansicht neu entstand.
            let id = ([mediumID.uuidString] + path).joined(separator: "\u{0}")
            let items = appState.indexRepository.children(mediumID: mediumID, path: path)
            let openFolder = columnIndex < stack.count ? stack[columnIndex] : nil
            let filtered = ColumnBrowserFiltering.visibleItems(
                items,
                openFolderName: openFolder,
                filters: filters,
                keepFolders: keepFolders
            )
            return ColumnBrowserFolderColumn(
                id: id,
                columnIndex: columnIndex,
                path: path,
                items: items,
                filteredItems: filtered
            )
        }
        if let uncapturedID = appState.columnBrowserState.selectedUncapturedFolderID {
            let virtualIndex = baseDepth
            columns.append(
                ColumnBrowserFolderColumn(
                    id: "uncaptured-\(uncapturedID.uuidString)",
                    columnIndex: virtualIndex,
                    path: stack,
                    items: [],
                    filteredItems: [],
                    special: .uncapturedStatus(folderID: uncapturedID)
                )
            )
        }
        return columns
    }

    private var filteredMedia: [Medium] {
        let query = sidebarMediumFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.columnBrowserMedia }
        return appState.columnBrowserMedia.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        let medium = resolvedSelectedMedium
        let indexGeneration = appState.indexRepository.generation
        let columns = medium.map { makeFolderColumns(for: $0.id) } ?? []
        let objectCountLabel = footerObjectCountLabel(columns: columns, medium: medium)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar(selectedMedium: medium)

                VStack(spacing: 0) {
                    if medium?.connectionStatus == .offline {
                        offlineBanner
                    }
                    columnsArea(medium: medium, folderColumns: columns)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            ColumnBrowserPathFooter(
                freeCapacityLabel: medium?.freeOfTotalLabel ?? "",
                pathLabel: columnBrowserPathLabel(medium: medium),
                objectCountLabel: objectCountLabel
            )
        }
        // Auswahl wird in `selectMedium` / `MediumNavigation` zurückgesetzt — hier nicht,
        // sonst ginge die Vorauswahl aus Suche/Favoriten verloren.
        .onAppear {
            ensureSelectedMedium()
            clampPathToScanDepth()
        }
        .task(id: columnLoadTaskID(mediumID: medium?.id, columns: columns, indexGeneration: indexGeneration)) {
            guard let medium else { return }
            for column in columns where column.special == nil {
                appState.indexRepository.requestLoad(mediumID: medium.id, path: column.path)
            }
        }
    }

    private func columnLoadTaskID(
        mediumID: UUID?,
        columns: [ColumnBrowserFolderColumn],
        indexGeneration: Int
    ) -> String {
        let paths = columns.filter { $0.special == nil }.map(\.id).joined(separator: "|")
        return "\(mediumID?.uuidString ?? "-")|\(paths)|g\(indexGeneration)"
    }

    private func pruneSelectionToVisibleItems(in column: ColumnBrowserFolderColumn, items: [IndexedItem], mediumID: UUID) {
        guard appState.columnBrowserState.selection.focusColumnIndex == column.columnIndex else { return }
        // Nur wenn der Ordner wirklich geladen ist: fehlender Cache oder laufendes Laden liefert [] (bug.0.4.036).
        guard appState.indexRepository.hasLoadedChildren(mediumID: mediumID, path: column.path) else { return }
        guard !appState.columnBrowserState.selection.ids.isEmpty else { return }
        var selection = appState.columnBrowserState.selection
        let before = selection.ids
        selection.dropInvisible(Set(items.map(\.id)))
        if selection.ids != before {
            commit(selection, column: column)
        }
    }

    private func folderOpenState(
        columnIndex: Int,
        medium: Medium,
        folderName: String? = nil,
        folderListedAt: Date? = nil,
        folderUnreadable: Bool = false
    ) -> ColumnFolderOpenState {
        ColumnFolderOpenState.resolve(
            columnIndex: columnIndex,
            medium: medium,
            settings: appState.appSettings,
            folderName: folderName,
            folderListedAt: folderListedAt,
            folderUnreadable: folderUnreadable
        )
    }

    /// Zustand einer Zeile, einmal je Zeile berechnet und für Farbe und Deckkraft genutzt (bug.0.4.034).
    private func rowOpenState(item: IndexedItem, columnIndex: Int, medium: Medium) -> ColumnFolderOpenState {
        guard item.isFolder else { return .normal }
        return folderOpenState(
            columnIndex: columnIndex,
            medium: medium,
            folderName: item.name,
            folderListedAt: item.listedAt,
            folderUnreadable: item.unreadable
        )
    }

    private func iconColor(item: IndexedItem, openState: ColumnFolderOpenState) -> Color {
        if item.isFolder {
            switch openState {
            case .uncaptured:
                return DesignColor.stateIgnored
            case .pendingIndex:
                return DesignColor.text.opacity(0.45)
            case .normal:
                break
            }
        }
        return item.isFavorite ? DesignColor.favorite : DesignColor.text
    }

    private func rowOpacity(item: IndexedItem, columnIndex: Int, openState: ColumnFolderOpenState) -> Double {
        let state = appState.columnBrowserState
        if ColumnBrowserSelectionHighlight.isRowSelected(
            item: item,
            columnIndex: columnIndex,
            pathStack: state.pathStack,
            selection: state.selection,
            selectedUncapturedFolderID: state.selectedUncapturedFolderID
        ) {
            return 1
        }
        guard item.isFolder, openState == .pendingIndex else { return 1 }
        return 0.55
    }

    private func folderColumnWidth(for columnIndex: Int) -> CGFloat {
        if let preview = columnResizePreview, preview.columnIndex == columnIndex {
            return preview.width
        }
        return appState.columnBrowserState.folderColumnWidth
    }

    private func totalFolderColumnsWidth(depth: Int) -> CGFloat {
        guard depth > 0 else { return 0 }
        let base = appState.columnBrowserState.folderColumnWidth
        guard let preview = columnResizePreview else {
            return CGFloat(depth) * base
        }
        return CGFloat(depth - 1) * base + preview.width
    }

    private func sidebar(selectedMedium: Medium?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MediumSidebarSearchField(text: $sidebarMediumFilter)
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Text(LayoutCopy.columnAllMediaHeading)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(DesignColor.text.opacity(0.45))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 3) {
                    ForEach(filteredMedia) { medium in
                        ColumnBrowserRow(
                            title: medium.name,
                            isSelected: medium.id == selectedMedium?.id,
                            iconAsset: medium.type.iconAssetName,
                            iconColor: medium.iconColor,
                            showsIndexingSpinner: medium.indexStatus == .indexing,
                            fadeTitleWhenSelected: true,
                            fadeTitleOnOverflow: true,
                            contextTarget: sidebarContextTarget(for: medium),
                            onSelect: { selectMedium(medium.id) }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()
                        .opacity(medium.connectionStatus == .offline && medium.id != selectedMedium?.id ? 0.4 : 1)
                    }
                }
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: appState.columnBrowserState.sidebarWidth)
        .clipped()
        .background(DesignColor.text.opacity(0.06))
        .overlay(alignment: .trailing) {
            HStack(spacing: 0) {
                ColumnResizeHandle(
                    committedWidth: sidebarWidthBinding,
                    onPreviewWidthChange: { _ in },
                    minWidth: ColumnBrowserState.sidebarWidthRange.lowerBound,
                    maxWidth: ColumnBrowserState.sidebarWidthRange.upperBound
                )
                Rectangle()
                    .fill(DesignColor.divider)
                    .frame(width: DesignBorder.width)
                    .shadow(color: DesignColor.shadow.opacity(0.16), radius: 5, x: -2)
            }
        }
    }

    private func sidebarContextTarget(for medium: Medium) -> ObjectContextTarget? {
        return ObjectContextTarget.fromMedium(medium)
    }

    private var sidebarWidthBinding: Binding<CGFloat> {
        Binding(
            get: { appState.columnBrowserState.sidebarWidth },
            set: { appState.columnBrowserState.setSidebarWidth($0) }
        )
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .strokeBorder(DesignColor.text.opacity(0.45), lineWidth: 1.5)
                .frame(width: 6, height: 6)
            Text(LayoutCopy.columnOfflineBanner)
                .foregroundStyle(DesignColor.text.opacity(0.55))
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColor.text.opacity(0.05))
    }

    private func columnsArea(medium: Medium?, folderColumns: [ColumnBrowserFolderColumn]) -> some View {
        GeometryReader { geometry in
            let showDetail: Bool = {
                guard let medium else { return false }
                // bug.0.4.090/087: nur die Spalte der Auswahl zählt (README „Detail-Spalte nur bei gewählter Datei
                // oder Mehrfachauswahl“); ein Ladehinweis in einer anderen Spalte blendet die Details nicht aus.
                let selectedColumn = folderColumns.first {
                    $0.columnIndex == appState.columnBrowserState.selection.focusColumnIndex
                }
                return shouldShowDetailColumn(medium: medium, in: geometry, folderColumns: folderColumns)
                    && !(selectedColumn.map { columnShowsStatusRestFill(medium: medium, column: $0) } ?? false)
            }()
            let folderWidth = totalFolderColumnsWidth(depth: folderColumns.count)
            let detailWidth = showDetail
                ? detailColumnWidth(in: geometry, folderColumns: folderColumns)
                : 0
            let horizontalOverflow = folderWidth + detailWidth > geometry.size.width + 0.5
            let scrollInset = horizontalOverflow ? horizontalScrollIndicatorInset : 0
            // Bei Overflow wird die ScrollView um die Scrollerbreite kürzer: im Legacy-Stil
            // hängt SwiftUI den Scroller unten an (Rahmen = Zuteilung + Scrollerbreite).
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        if let medium {
                            ForEach(folderColumns) { column in
                                folderColumn(medium: medium, column: column, isLast: column.id == folderColumns.last?.id)
                                    .id(column.id)
                            }

                            if showDetail {
                                detailColumn(
                                    medium: medium,
                                    width: detailColumnWidth(in: geometry, folderColumns: folderColumns)
                                )
                                .id("detail")
                            }
                        } else {
                            EmptyStateView(title: EmptyStateCopy.noMediumTitle, message: EmptyStateCopy.noMediumMessage)
                        }
                    }
                    // Inhalt = Spaltensumme, mind. sichtbare Breite. minHeight = Viewport, sonst zentriert
                    // der horizontale ScrollView kurze Spalten senkrecht (Aufgabe 143).
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: max(0, geometry.size.height - scrollInset),
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .animation(nil, value: columnResizePreview?.width)
                }
                .scrollIndicators(.automatic)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: max(0, geometry.size.height - scrollInset),
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // bug.0.4.132: Öffnen über einen Treffer (Ansicht entsteht danach) und Nutzeraktionen. Erscheinen die
                // Spalten bzw. die Details-Spalte erst nach dem Laden, wird für denselben Auftrag nachgescrollt; danach
                // (Auftrag erledigt) scrollen Live-Änderungen nicht.
                .onChange(
                    of: HorizontalScrollKey(token: appState.columnScrollToken, columns: folderColumns.count, showDetail: showDetail),
                    initial: true
                ) { _, key in
                    // Token 0: noch keine Nutzeraktion (Start mit gemerktem Pfad) – nicht scrollen.
                    guard key.token > 0, key.token != horizontalScrollDoneToken else { return }
                    scrollToTrailingColumn(
                        proxy: proxy,
                        folderColumns: folderColumns,
                        showDetail: showDetail
                    )
                    if showDetail || !selectionColumnPending {
                        horizontalScrollDoneToken = key.token
                    }
                }
                .onChange(of: appState.columnBrowserState.pathStack) { _, _ in
                    scrollToTrailingColumn(
                        proxy: proxy,
                        folderColumns: folderColumns,
                        showDetail: showDetail
                    )
                }
                .onChange(of: appState.columnBrowserState.selection) { _, _ in
                    scrollToTrailingColumn(
                        proxy: proxy,
                        folderColumns: folderColumns,
                        showDetail: showDetail
                    )
                }
            }
        }
    }

    private var horizontalScrollIndicatorInset: CGFloat { Self.legacyScrollerThickness }

    private static let legacyScrollerThickness: CGFloat =
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)

    private func scrollToTrailingColumn(
        proxy: ScrollViewProxy,
        folderColumns: [ColumnBrowserFolderColumn],
        showDetail: Bool
    ) {
        let target: String? = if showDetail {
            "detail"
        } else {
            folderColumns.last?.id
        }
        guard let target else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .trailing)
        }
    }

    private func shouldShowDetailColumn(
        medium: Medium,
        in geometry: GeometryProxy,
        folderColumns: [ColumnBrowserFolderColumn]
    ) -> Bool {
        appState.columnBrowserState.selection.isMultiple
            || singleSelectedFile(in: folderColumns) != nil
    }

    /// Statusfläche füllt die Restbreite (Aufgabe 139) — kein fester Ordnerspaltenrahmen.
    private func publishLoadingHint(_ visible: Bool, medium: Medium, path: [String]) {
        guard appState.columnBrowserState.loadingHintVisible(mediumID: medium.id, path: path) != visible else { return }
        appState.columnBrowserState.setLoadingHintVisible(visible, mediumID: medium.id, path: path)
    }

    private func columnShowsStatusRestFill(medium: Medium, column: ColumnBrowserFolderColumn) -> Bool {
        if case .uncapturedStatus = column.special { return true }
        if appState.columnBrowserState.loadingHintVisible(mediumID: medium.id, path: column.path) {
            return true
        }
        if showsPendingIndexingContent(in: column, medium: medium) { return true }
        if appState.indexRepository.folderLoadError(mediumID: medium.id, path: column.path) != nil {
            return true
        }
        return false
    }

    private func folderColumn(medium: Medium, column: ColumnBrowserFolderColumn, isLast: Bool) -> some View {
        let items = column.filteredItems
        let header = columnHeaderBase(medium: medium, column: column)
        let columnWidth = folderColumnWidth(for: column.columnIndex)
        // bug.0.4.088: Die Regel-Warteschlange zeigt keinen Ladezustand; die Spalte bleibt stehen (ausgeblendet wird
        // an Ort und Stelle über `IndexRepository.scope`).
        let loadingContents = appState.indexRepository.isLoading(mediumID: medium.id, path: column.path)
        let progress = appState.indexRepository.loadingProgress(mediumID: medium.id, path: column.path)
        let pendingContents = showsPendingIndexingContent(in: column, medium: medium) && !loadingContents
        let statusRest = columnShowsStatusRestFill(medium: medium, column: column)

        return VStack(alignment: .leading, spacing: 0) {
            ColumnBrowserColumnHeader(title: header, showsLoadingContents: false)

            Group {
                if case .uncapturedStatus(let folderID) = column.special {
                    uncapturedStatusPanel(medium: medium, folderID: folderID)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if pendingContents {
                    FolderPendingIndexingHint()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if let loadError = appState.indexRepository.folderLoadError(mediumID: medium.id, path: column.path) {
                    FolderContentsLoadErrorHint(message: loadError)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else {
                    // Ein Exemplar für Laden und Liste (bug.0.4.061): sonst verwirft das Ladeende den
                    // Zustand samt Mindestanzeige (400 ms) des Hinweises.
                    // Einmal je Body statt je Zeile (bug.0.4.035).
                    let selectedIDs = loadingContents ? [] : selectedIDs(in: items, column: column)
                    ColumnFolderContents(
                        mediumID: medium.id,
                        path: column.path,
                        filteredItems: items,
                        selectedIDs: selectedIDs,
                        isLoading: loadingContents,
                        loaded: progress.loaded,
                        total: progress.total,
                        tableViewMinimum: tableViewMinimum,
                        onLoadingHintVisible: { visible in
                            publishLoadingHint(visible, medium: medium, path: column.path)
                        },
                        hintInsets: EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16),
                        scrollTarget: scrollTarget(for: column)
                    ) { item in
                        let openState = rowOpenState(item: item, columnIndex: column.columnIndex, medium: medium)
                        ColumnBrowserRow(
                            title: item.name,
                            isSelected: selectedIDs.contains(item.id),
                            iconAsset: item.fileKind.assetName,
                            iconColor: iconColor(item: item, openState: openState),
                            fadeTitleOnOverflow: true,
                            contextTarget: .fromIndexedItem(item, medium: medium),
                            resolveTargets: { clicked in
                                contextTargets(for: clicked, column: column, medium: medium)
                            },
                            onSelect: { select(item: item, column: column) }
                        )
                        .opacity(rowOpacity(item: item, columnIndex: column.columnIndex, openState: openState))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: statusRest ? nil : columnWidth)
        .frame(maxWidth: statusRest ? .infinity : nil, alignment: .top)
        .clipped()
        // Kein `.compositingGroup()`: AppKit-`NSTableView` bleibt darin oft unsichtbar (Aufgabe 122).
        .focusable()
        .focused($focusedColumn, equals: column.columnIndex)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handleColumnKey(press, column: column)
        }
        .onChange(of: appState.searchState.filters) { _, _ in
            pruneSelectionToVisibleItems(in: column, items: items, mediumID: medium.id)
        }
        .onChange(of: column.items.count) { _, _ in
            pruneSelectionToVisibleItems(in: column, items: items, mediumID: medium.id)
        }
        .overlay(alignment: .trailing) {
            // bug.0.4.089: Trennlinie in jedem Zustand (auch Ladehinweis/Statusfläche); nur am rechten Ende einer
            // letzten Spalte, die die Restbreite füllt, folgt keine Spalte. Ziehen nur bei fester Breite.
            if !statusRest || !isLast {
                HStack(spacing: 0) {
                    if !statusRest {
                        ColumnResizeHandle(
                            committedWidth: folderColumnWidthBinding,
                            onPreviewWidthChange: { preview in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    if let preview {
                                        let next = (columnIndex: column.columnIndex, width: preview)
                                        if columnResizePreview?.columnIndex != next.columnIndex
                                            || columnResizePreview?.width != next.width {
                                            columnResizePreview = next
                                        }
                                    } else if columnResizePreview?.columnIndex == column.columnIndex {
                                        columnResizePreview = nil
                                    }
                                }
                            }
                        )
                    }
                    Rectangle()
                        .fill(DesignColor.divider)
                        .frame(width: DesignBorder.width)
                }
            }
        }
    }

    private func selectedIDs(in items: [IndexedItem], column: ColumnBrowserFolderColumn) -> Set<UUID> {
        let state = appState.columnBrowserState
        return ColumnBrowserSelectionHighlight.selectedIDs(
            items: items,
            columnIndex: column.columnIndex,
            pathStack: state.pathStack,
            selection: state.selection,
            selectedUncapturedFolderID: state.selectedUncapturedFolderID
        )
    }

    private func select(item: IndexedItem, column: ColumnBrowserFolderColumn) {
        focusedColumn = column.columnIndex
        let flags = NSEvent.modifierFlags
        var selection = appState.columnBrowserState.selection
        let visible = column.filteredItems.map(\.id)
        if flags.contains(.command) {
            selection.commandClick(id: item.id, column: column.columnIndex)
        } else if flags.contains(.shift) {
            selection.shiftClick(id: item.id, column: column.columnIndex, visible: visible)
        } else {
            selection.replace(id: item.id, column: column.columnIndex)
        }
        commit(selection, column: column)
    }

    /// bug.0.4.132: Die Spalte der Auswahl lädt noch – erst danach steht fest, ob eine Details-Spalte erscheint; bis
    /// dahin bleibt der waagerechte Auftrag offen.
    private var selectionColumnPending: Bool {
        let selection = appState.columnBrowserState.selection
        guard !selection.ids.isEmpty, let medium = resolvedSelectedMedium, let column = selection.focusColumnIndex else {
            return false
        }
        let path = Array(appState.columnBrowserState.pathStack.prefix(column))
        if appState.indexRepository.isLoading(mediumID: medium.id, path: path) { return true }
        return !appState.indexRepository.hasLoadedChildren(mediumID: medium.id, path: path)
    }

    /// bug.0.4.132: Zeile, zu der diese Spalte nach einer Nutzeraktion scrollt (Auswahl der Fokus-Spalte).
    private func scrollTarget(for column: ColumnBrowserFolderColumn) -> ColumnScrollTarget {
        let selection = appState.columnBrowserState.selection
        guard selection.focusColumnIndex == column.columnIndex else { return ColumnScrollTarget() }
        return ColumnScrollTarget(id: selection.lastClickedID ?? selection.ids.last, token: appState.columnScrollToken)
    }

    private func commit(_ selection: ColumnSelection, column: ColumnBrowserFolderColumn) {
        guard let medium = resolvedSelectedMedium else { return }
        var state = appState.columnBrowserState
        let ordered = selection.ordered(in: column.items)
        let folder = ordered.count == 1 ? ordered[0] : nil
        let open = folderOpenState(
            columnIndex: column.columnIndex,
            medium: medium,
            folderName: folder?.name,
            folderListedAt: folder?.listedAt,
            folderUnreadable: folder?.unreadable ?? false
        )
        let uncaptured: Bool = {
            guard ordered.count == 1, ordered[0].isFolder else { return false }
            if case .uncaptured = open { return true }
            return false
        }()
        let effect = ColumnPathEffect.make(
            columnIndex: column.columnIndex,
            existingPath: state.pathStack,
            selected: ordered,
            uncapturedFolder: uncaptured
        )
        state.selection = selection
        state.pathStack = effect.path
        state.selectedUncapturedFolderID = effect.uncapturedID
        appState.columnBrowserState = state
        // bug.0.4.132: Nutzeraktion (Klick, Taste) → zur Auswahl scrollen.
        appState.columnScrollToken += 1
        DiskIndexLog.shared.ui("selection count=\(selection.ids.count) column=\(column.columnIndex)")
    }

    private func handleColumnKey(_ press: KeyPress, column: ColumnBrowserFolderColumn) -> KeyPress.Result {
        let visible = column.filteredItems
        if press.modifiers.contains(.command), press.characters == "a" {
            var selection = appState.columnBrowserState.selection
            selection.selectAll(visible: visible.map(\.id), column: column.columnIndex)
            commit(selection, column: column)
            return .handled
        }
        if press.key == .escape {
            var selection = appState.columnBrowserState.selection
            selection.collapseToLastClicked()
            commit(selection, column: column)
            return .handled
        }
        if press.key == .downArrow || press.key == .upArrow {
            var selection = appState.columnBrowserState.selection
            selection.move(step: press.key == .downArrow ? 1 : -1, extend: press.modifiers.contains(.shift), visible: visible.map(\.id), column: column.columnIndex)
            commit(selection, column: column)
            return .handled
        }
        return .ignored
    }

    private func contextTargets(for clicked: ObjectContextTarget, column: ColumnBrowserFolderColumn, medium: Medium) -> [ObjectContextTarget] {
        let state = appState.columnBrowserState
        if state.selection.focusColumnIndex == column.columnIndex,
           state.selection.contains(clicked.id),
           state.selection.isMultiple {
            return state.selection.ordered(in: column.items).map { ObjectContextTarget.fromIndexedItem($0, medium: medium) }
        }
        var selection = ColumnSelection()
        selection.replace(id: clicked.id, column: column.columnIndex)
        commit(selection, column: column)
        return [clicked]
    }

    private func singleSelectedFile(in columns: [ColumnBrowserFolderColumn]) -> IndexedItem? {
        let state = appState.columnBrowserState
        guard state.selection.ids.count == 1, let id = state.selection.ids.first, state.selectedUncapturedFolderID == nil else { return nil }
        guard let column = columns.first(where: { $0.columnIndex == state.selection.focusColumnIndex }) else { return nil }
        guard let item = column.items.first(where: { $0.id == id }), !item.isFolder else { return nil }
        return item
    }

    private func detailColumnWidth(
        in geometry: GeometryProxy,
        folderColumns: [ColumnBrowserFolderColumn]
    ) -> CGFloat {
        let depth = folderColumns.count
        let folderTotal = totalFolderColumnsWidth(depth: depth)
        let remaining = geometry.size.width - folderTotal
        return max(DesignSpacing.columnBrowserDetailWidth, remaining)
    }

    private func detailColumn(medium: Medium, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LayoutCopy.columnDetailHeading)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(DesignColor.text.opacity(0.45))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if let many = multipleSelectionItems(for: medium) {
                VStack(alignment: .leading, spacing: 10) {
                    Image("FileTypeFiles")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(DesignColor.text)
                    Text(ColumnSizeSummary.objectLine(count: many.count))
                        .font(.system(size: 13, weight: .semibold))
                    Text(LayoutCopy.columnDetailTotalSize(
                        ByteCountFormatter.storage.string(fromByteCount: ColumnSizeSummary.totalBytes(many))
                    ))
                    .font(.system(size: 12.5))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
                }
                .padding(.horizontal, 16)
            } else if let file = selectedDetailFile(for: medium) {
                VStack(alignment: .leading, spacing: 8) {
                    FileTypeIcon(
                        kind: file.fileKind,
                        size: 26,
                        color: iconColor(item: file, openState: rowOpenState(item: file, columnIndex: file.parentPath.count, medium: medium))
                    )
                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 5) {
                        if let modified = file.modifiedAt {
                            Text(LayoutCopy.columnDetailModified(
                                IndexedDateFormatting.abbreviatedDay(modified)
                            ))
                        }
                        if let size = file.sizeBytes {
                            Text(LayoutCopy.columnDetailSize(
                                ByteCountFormatter.storage.string(fromByteCount: size)
                            ))
                        }
                        // „Zuletzt gesehen“ ist der Zeitpunkt des Mediums, nicht der einzelnen Datei (Aufgabe 233).
                        if let seen = ColumnDetailText.lastSeen(medium: medium) {
                            Text(seen)
                        }
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(DesignColor.text.opacity(0.6))

                    if medium.connectionStatus == .connected {
                        RevealInFinderButton {
                            appState.revealInFinder(.fromIndexedItem(file, medium: medium))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignColor.text.opacity(0.04))
    }

    private func selectMedium(_ id: UUID) {
        appState.columnBrowserState.selectedMediumID = id
        appState.columnBrowserState.pathStack = []
        appState.columnBrowserState.selection = ColumnSelection()
        appState.columnBrowserState.selectedUncapturedFolderID = nil
        DiskIndexLog.shared.ui("medium id=\(id)")
    }

    /// Nach Verringern der Scan-Tiefe (Einstellungen) keinen Pfad jenseits der Grenze offen lassen.
    /// `indexedMaxDepth` = tiefster noch indizierter Ordner; dessen Inhalt (Kinder jenseits der Tiefe)
    /// bleibt sichtbar — inkl. Hinweisfläche „Inhalt wird nicht indiziert“.
    private func clampPathToScanDepth() {
        guard let medium = resolvedSelectedMedium else { return }
        let limit = appState.appSettings.indexedMaxDepth.map { min(medium.completedDepth, $0) } ?? medium.completedDepth
        var state = appState.columnBrowserState
        let maxPathLength = max(0, limit)
        guard state.pathStack.count > maxPathLength else { return }
        state.pathStack = Array(state.pathStack.prefix(maxPathLength))
        state.selection = ColumnSelection()
        state.selectedUncapturedFolderID = nil
        appState.columnBrowserState = state
    }

    private func ensureSelectedMedium() {
        if appState.columnBrowserState.selectedMediumID == nil {
            appState.columnBrowserState.selectedMediumID = appState.columnBrowserMedia.first?.id
        }
    }

    private var folderColumnWidthBinding: Binding<CGFloat> {
        Binding(
            get: { appState.columnBrowserState.folderColumnWidth },
            set: { appState.columnBrowserState.folderColumnWidth = $0 }
        )
    }

    /// Detail nur, wenn die Datei in der aktuell sichtbaren Spalte/Pfad existiert.
    private func selectedDetailFile(for medium: Medium) -> IndexedItem? {
        let state = appState.columnBrowserState
        guard state.selection.ids.count == 1, let fileID = state.selection.ids.first, state.selectedUncapturedFolderID == nil else { return nil }
        let path = Array(state.pathStack.prefix(state.selection.focusColumnIndex ?? state.pathStack.count))
        guard let item = appState.indexRepository.children(mediumID: medium.id, path: path).first(where: { $0.id == fileID }),
              !item.isFolder else { return nil }
        return item
    }

    private func multipleSelectionItems(for medium: Medium) -> [IndexedItem]? {
        let state = appState.columnBrowserState
        guard state.selection.isMultiple else { return nil }
        let path = Array(state.pathStack.prefix(state.selection.focusColumnIndex ?? 0))
        let items = appState.indexRepository.children(mediumID: medium.id, path: path)
        let chosen = state.selection.ordered(in: items)
        return chosen.count > 1 ? chosen : nil
    }

    private func selectedUncapturedFolderItem(for medium: Medium) -> IndexedItem? {
        guard let id = appState.columnBrowserState.selectedUncapturedFolderID else { return nil }
        return selectedUncapturedFolderItem(for: medium, id: id)
    }

    private func columnBrowserPathLabel(medium: Medium?) -> String {
        guard let medium else { return "" }
        var parts = [medium.name]
        parts += appState.columnBrowserState.pathStack
        if let file = selectedDetailFile(for: medium) {
            parts.append(file.name)
        } else if let folder = selectedUncapturedFolderItem(for: medium) {
            parts.append(folder.name)
        }
        return parts.joined(separator: " › ")
    }

    private func columnHeaderBase(medium: Medium, column: ColumnBrowserFolderColumn) -> String {
        if case .uncapturedStatus(let folderID) = column.special,
           let folder = selectedUncapturedFolderItem(for: medium, id: folderID) {
            return folder.name.uppercased()
        }
        return (column.path.last ?? medium.name).uppercased()
    }

    @ViewBuilder
    private func uncapturedStatusPanel(medium: Medium, folderID: UUID) -> some View {
        // Spaltenindex = Elternpfad-Länge (Ordner liegt in der letzten realen Spalte).
        let columnIndex = appState.columnBrowserState.pathStack.count
        if let folder = selectedUncapturedFolderItem(for: medium, id: folderID),
           case .uncaptured(let reason) = folderOpenState(
               columnIndex: columnIndex,
               medium: medium,
               folderName: folder.name,
               folderListedAt: folder.listedAt,
               folderUnreadable: folder.unreadable
           ) {
            FolderUncapturedColumnHint(reason: reason)
        }
    }

    private func showsPendingIndexingContent(in column: ColumnBrowserFolderColumn, medium: Medium) -> Bool {
        guard column.special == nil else { return false }
        let stack = appState.columnBrowserState.pathStack
        guard !stack.isEmpty, column.path == stack else { return false }
        let folderName = stack.last!
        let folderIndex = stack.count - 1
        let parentPath = Array(stack.dropLast())
        guard let folder = appState.indexRepository.children(mediumID: medium.id, path: parentPath)
            .first(where: { $0.isFolder && $0.name == folderName }) else { return false }
        return folderOpenState(
            columnIndex: folderIndex,
            medium: medium,
            folderName: folder.name,
            folderListedAt: folder.listedAt,
            folderUnreadable: folder.unreadable
        ) == .pendingIndex
    }

    private func footerObjectCountLabel(columns: [ColumnBrowserFolderColumn], medium: Medium?) -> String {
        guard let medium, !columns.isEmpty else { return "" }
        if footerUsesDash(columns: columns, medium: medium) {
            return "–"
        }
        let countColumn = footerCountColumn(in: columns, medium: medium) ?? columns.last!
        let allItems = countColumn.items
        let items = countColumn.filteredItems
        let selectionCount = appState.columnBrowserState.selection.focusColumnIndex == countColumn.columnIndex
            ? appState.columnBrowserState.selection.ids.count
            : 0
        return ColumnFooterLabel.text(
            selectedCount: selectionCount,
            visibleCount: items.count,
            filteredCount: items.count,
            totalCount: allItems.count
        )
    }

    private func footerUsesDash(columns: [ColumnBrowserFolderColumn], medium: Medium) -> Bool {
        guard let last = columns.last else { return false }
        guard last.special == nil else { return false }
        guard last.path == appState.columnBrowserState.pathStack else { return false }
        return appState.indexRepository.isLoading(mediumID: medium.id, path: last.path)
    }

    private func footerCountColumn(in columns: [ColumnBrowserFolderColumn], medium: Medium) -> ColumnBrowserFolderColumn? {
        guard let last = columns.last else { return nil }
        if last.special != nil || showsPendingIndexingContent(in: last, medium: medium) {
            return columns.count >= 2 ? columns[columns.count - 2] : last
        }
        return last
    }

    private func selectedUncapturedFolderItem(for medium: Medium, id: UUID) -> IndexedItem? {
        appState.indexRepository.children(mediumID: medium.id, path: appState.columnBrowserState.pathStack)
            .first { $0.id == id }
    }
}

enum ColumnBrowserFiltering {
    static func visibleItems(
        _ items: [IndexedItem],
        openFolderName: String?,
        filters: SearchFilters,
        keepFolders: Bool
    ) -> [IndexedItem] {
        guard filters.hasActiveObjectFilters else { return items }
        return items.filter { item in
            if let openFolderName, item.isFolder, item.name == openFolderName { return true }
            return SearchItemFilter.matches(item, filters: filters, foldersIgnoreTypeFilter: keepFolders)
        }
    }

}

#Preview {
    ColumnBrowserView()
        .environment(AppState())
        .frame(width: 1100, height: 520)
}

/// Texte der Detailspalte, die aus dem Medium kommen (testbar ohne Fenster).
enum ColumnDetailText {
    /// „Zuletzt gesehen: …“ mit dem Datum, an dem das Medium zuletzt gesehen wurde.
    static func lastSeen(medium: Medium) -> String? {
        medium.lastSeenAt.map { LayoutCopy.columnDetailLastSeen(IndexedDateFormatting.abbreviatedDay($0)) }
    }
}

/// bug.0.4.132: Auslöser des waagerechten Scrolls (Auftrag, Spaltenzahl, Details-Spalte).
private struct HorizontalScrollKey: Equatable {
    var token: Int
    var columns: Int
    var showDetail: Bool
}

//
//  MainWindowFilterBar.swift
//  diskindex
//
//  Filterleiste unter der Toolbar (19.7 / 19.11).
//

import SwiftUI

/// Anker des Filter-Buttons für das Filter-Popover (Aufgabe 22.5).
/// `anchorPreference` statt Frame-in-Koordinatenraum: kein `.zero`-Überschreiben durch andere Beiträge.
struct FilterButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

struct MainWindowFilterBar: View {
    @Environment(AppState.self) private var appState
    @Binding var showFilterPopover: Bool

    var body: some View {
        let filters = appState.searchState.filters

        HStack(spacing: 8) {
            filterButtonCombo(isFiltering: appState.hasEffectiveFilters)
            if filters.isCombineButtonVisible(hasSearchTerm: appState.hasActiveSearchTerm) {
                combineButton(filters: appState.searchStateBinding(\.filters))
            }

            FlowLayout(spacing: 6) {
                filterValueChips(filters: appState.searchStateBinding(\.filters))
            }

            Spacer(minLength: 8)

            if let scope = filterScopeLabel {
                Text(scope)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(DesignColor.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignColor.neutral300).frame(height: DesignBorder.width)
        }
        .onChange(of: appState.searchState.filters) { _, filters in
            var next = filters
            next.clampCombineWithAnd(hasSearchTerm: appState.hasActiveSearchTerm)
            if next != filters {
                appState.searchStateBinding(\.filters).wrappedValue = next
            }
        }
        .onChange(of: appState.hasActiveSearchTerm) { _, _ in
            var next = appState.searchState.filters
            next.clampCombineWithAnd(hasSearchTerm: appState.hasActiveSearchTerm)
            if next != appState.searchState.filters {
                appState.searchStateBinding(\.filters).wrappedValue = next
            }
        }
    }

    /// „Filter“-Button + (bei gesetzten Filtern) schwarzes ✕-Segment, das alle Filter zurücksetzt (Aufgaben 23.3/24.2).
    private func filterButtonCombo(isFiltering: Bool) -> some View {
        HStack(spacing: 0) {
            filterButton(isFiltering: isFiltering)
                .zIndex(1)

            if isFiltering {
                resetAllFiltersSegment
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Ohne Filter: blauer Rand, blaue Schrift. Mit Filtern: blaue Fläche, weiße Schrift.
    private func filterButton(isFiltering: Bool) -> some View {
        Button {
            showFilterPopover.toggle()
        } label: {
            HStack(spacing: 3) {
                Image("IconFunnel")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                Text(LayoutCopy.filterToolbarButton)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isFiltering ? DesignColor.onSelection : DesignColor.filterSearch)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                if isFiltering {
                    RoundedRectangle(cornerRadius: DesignRadius.sm).fill(DesignColor.filterSearch)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .strokeBorder(DesignColor.filterSearch, lineWidth: DesignBorder.width)
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .anchorPreference(key: FilterButtonAnchorKey.self, value: .bounds) { $0 }
    }

    /// Schiebt sich mit Radius + 1 (7 pt) unter den Filter-Button, damit dessen runde rechte Ecke
    /// auf Schwarz sichtbar bleibt; sichtbarer Teil 25 pt. Leiste bleibt offen (anders als das Toolbar-Icon).
    private var resetAllFiltersSegment: some View {
        let underlap = DesignRadius.sm + 1
        let shape = UnevenRoundedRectangle(bottomTrailingRadius: DesignRadius.sm, topTrailingRadius: DesignRadius.sm)

        return Button {
            appState.searchState.filters = SearchFilters()
            showFilterPopover = false
        } label: {
            Image("IconX")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .foregroundStyle(DesignColor.onSelection)
                .frame(width: 25)
                .frame(maxHeight: .infinity)
                .padding(.leading, underlap)
                .background(shape.fill(DesignColor.sidebarActiveBackground))
                .overlay(shape.strokeBorder(DesignColor.sidebarActiveBackground, lineWidth: DesignBorder.width))
                .contentShape(shape)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .padding(.leading, -underlap)
        .help(LayoutCopy.resetAllFiltersHelp)
        .accessibilityLabel(LayoutCopy.resetAllFiltersHelp)
    }

    /// Verknüpfung Dateityp ⇄ Alter (Aufgabe 33.1 / 86): nur sichtbar wenn Und wirken kann; inaktiv = Oder, aktiv = Und.
    private func combineButton(filters: Binding<SearchFilters>) -> some View {
        let isAnd = filters.wrappedValue.combineWithAnd
        let label = isAnd ? LayoutCopy.filterLinkedWithAnd : LayoutCopy.filterLinkWithAnd
        let shape = RoundedRectangle(cornerRadius: DesignRadius.sm)

        return Button {
            filters.wrappedValue.combineWithAnd.toggle()
        } label: {
            Image("IconLink")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(isAnd ? DesignColor.onSelection : DesignColor.text)
                .frame(width: 27, height: 27)
                .background(shape.fill(isAnd ? DesignColor.filterSearch : DesignColor.bg))
                .overlay(shape.strokeBorder(isAnd ? DesignColor.filterSearch : DesignColor.neutral500, lineWidth: DesignBorder.width))
                .contentShape(shape)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .help(label)
        .accessibilityLabel(label)
    }

    /// Wirkungsbereich rechts in der Leiste: Suche global (kein Label), sonst Ordner bzw. Favoriten.
    private var filterScopeLabel: String? {
        switch appState.mainWindowDestination {
        case .favorites:
            return LayoutCopy.filterScopeFavorites
        case .columnBrowser:
            guard let mediumID = appState.columnBrowserState.selectedMediumID,
                  let medium = appState.medium(with: mediumID) else { return nil }
            return LayoutCopy.filterScopeMedium(medium.shownName)
        default:
            return nil
        }
    }

    @ViewBuilder
    private func filterValueChips(filters: Binding<SearchFilters>) -> some View {
        // Medium-Auswahl wirkt nur in der Suche.
        if appState.mainWindowDestination == .search, !filters.wrappedValue.selectAllMedia {
            ForEach(appState.indexedMedia.filter { filters.wrappedValue.mediumIDs.contains($0.id) }) { medium in
                FilterValueChip(label: medium.shownName) {
                    var ids = filters.wrappedValue.mediumIDs
                    ids.remove(medium.id)
                    if ids.isEmpty {
                        filters.wrappedValue.selectAllMedia = true
                        filters.wrappedValue.mediumIDs.removeAll()
                    } else {
                        filters.wrappedValue.mediumIDs = ids
                    }
                }
            }
        }

        ForEach(filters.wrappedValue.fileTypes.sorted(by: { $0.label < $1.label })) { type in
            FilterValueChip(label: type.label) {
                filters.wrappedValue.fileTypes.remove(type)
            }
        }

        ForEach(filters.wrappedValue.customExtensions, id: \.self) { ext in
            FilterValueChip(label: ext) {
                filters.wrappedValue.customExtensions.removeAll { $0 == ext }
            }
        }

        if let age = filters.wrappedValue.age {
            FilterValueChip(label: age.label) {
                filters.wrappedValue.age = nil
            }
        }
    }
}

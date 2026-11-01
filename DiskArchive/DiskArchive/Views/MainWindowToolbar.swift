//
//  MainWindowToolbar.swift
//  DiskArchive
//
//  Aufgabe 19.7 — Navigation links, Filter/Suche rechts vor dem Suchfeld.
//  Aufgabe 132 — aktive Icons Duotone über ToolbarNavIcon.
//

import SwiftUI

struct MainWindowToolbar: View {
    @Environment(AppState.self) private var appState

    @Binding var searchQuery: String
    @FocusState.Binding var isSearchFocused: Bool
    var onSearchSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            overviewNavButton
            favoritesNavButton
            Rectangle()
                .fill(DesignColor.divider)
                .frame(width: DesignBorder.width, height: 20)
            settingsNavButton

            Spacer(minLength: 8)

            filterToolButton
            searchToolButton

            ObjectSearchField(
                text: $searchQuery,
                isFocused: $isSearchFocused,
                onSubmit: onSearchSubmit,
                onClear: { appState.clearObjectSearch() }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignColor.toolbar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignColor.divider)
                .frame(height: DesignBorder.width)
        }
    }

    private var overviewNavButton: some View {
        let isActive = appState.mainWindowDestination == .dashboard
        return navButton(
            fill: "NavHouseLineFill",
            stroke: "NavHouseLineStroke",
            role: .home,
            isActive: isActive,
            accessibilityLabel: LayoutCopy.a11yOverview
        ) {
            MediumNavigation.openDashboard(appState: appState)
        }
    }

    private var favoritesNavButton: some View {
        let isActive = appState.mainWindowDestination == .favorites
        return navButton(
            fill: "NavBookmarksFill",
            stroke: "NavBookmarksStroke",
            role: .favorites,
            isActive: isActive,
            accessibilityLabel: LayoutCopy.a11yFavorites
        ) {
            MediumNavigation.openFavorites(appState: appState)
        }
    }

    private var settingsNavButton: some View {
        navButton(
            fill: "NavGearFill",
            stroke: "NavGearStroke",
            role: .settings,
            isActive: appState.mainWindowDestination == .settings,
            accessibilityLabel: LayoutCopy.a11ySettings
        ) {
            MediumNavigation.openSettings(appState: appState)
        }
    }

    private var filterToolButton: some View {
        toolButton(
            fill: "IconFunnelFill",
            stroke: "IconFunnelStroke",
            role: .filter,
            isActive: appState.showsFilterBar,
            isEnabled: appState.isFilterAvailable,
            accessibilityLabel: LayoutCopy.a11yFilter
        ) {
            appState.toggleFilterBarVisible()
        }
    }

    private var searchToolButton: some View {
        toolButton(
            fill: "IconMagnifyingGlassFill",
            stroke: "IconMagnifyingGlassStroke",
            role: .search,
            isActive: appState.mainWindowDestination == .search,
            accessibilityLabel: LayoutCopy.a11ySearch
        ) {
            appState.toggleSearchFromToolbar()
        }
    }

    private func navButton(
        fill: String,
        stroke: String,
        role: ToolbarNavIconRole,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ToolbarNavIcon(fillAsset: fill, strokeAsset: stroke, role: role, isActive: isActive)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .accessibilityLabel(accessibilityLabel)
    }

    private func toolButton(
        fill: String,
        stroke: String,
        role: ToolbarNavIconRole,
        isActive: Bool,
        isEnabled: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ToolbarNavIcon(fillAsset: fill, strokeAsset: stroke, role: role, isActive: isActive && isEnabled)
                .opacity(isEnabled ? 1 : 0.3)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .disabled(!isEnabled)
        .pointerCursor(isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

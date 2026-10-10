//
//  MainWindowScreenScaffold.swift
//  diskindex
//
//  Gemeinsamer Rahmen aller Hauptfenster-Screens: Toolbar mit Objekt-Suchfeld, Filterleiste,
//  Filter-Popover. Liegt EINMAL im Host (nicht pro Screen), damit Suchfeld, Fokus und Cursor
//  beim Wechsel in die Suche erhalten bleiben (Aufgabe 20.1).
//

import SwiftUI

struct MainWindowScreenScaffold<Content: View>: View {
    @Environment(AppState.self) private var appState
    @ViewBuilder var content: () -> Content

    @FocusState private var isSearchFocused: Bool
    @State private var showFilterPopover = false

    var body: some View {
        VStack(spacing: 0) {
            MainWindowToolbar(
                searchQuery: appState.searchStateBinding(\.query),
                isSearchFocused: $isSearchFocused,
                onSearchSubmit: { appState.submitObjectSearch() }
            )

            if appState.showsFilterBar {
                MainWindowFilterBar(showFilterPopover: $showFilterPopover)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignColor.bg)
        }
        .overlayPreferenceValue(FilterButtonAnchorKey.self, alignment: .topLeading) { anchor in
            if showFilterPopover, let anchor {
                filterPopover(anchor: anchor)
            }
        }
        .dismissObjectSearchFocusOnOutsideClick(isFocused: $isSearchFocused)
        .onChange(of: appState.mainWindowDestination) { _, _ in
            showFilterPopover = false
        }
        .onChange(of: appState.searchFieldFocusResetCount) { _, _ in
            isSearchFocused = false
        }
        .onChange(of: appState.showsFilterBar) { _, isShown in
            if !isShown { showFilterPopover = false }
        }
    }

    /// Über allem: transparente Klickfläche (Klick daneben schließt) + Panel unter dem Filter-Button.
    private func filterPopover(anchor: Anchor<CGRect>) -> some View {
        GeometryReader { proxy in
            let buttonFrame = proxy[anchor]
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { showFilterPopover = false }

                SearchFilterPopoverPanel()
                    .fixedSize()
                    // Nasenspitze ca. 4 pt unter dem Filter-Button.
                    .offset(x: buttonFrame.minX, y: buttonFrame.maxY + 4 + SearchFilterPopoverPanel.noseHeight)
            }
        }
        .zIndex(1)
        .onEscapeKey { showFilterPopover = false }
    }
}

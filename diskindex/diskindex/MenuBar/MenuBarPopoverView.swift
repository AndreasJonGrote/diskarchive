//
//  MenuBarPopoverView.swift
//  diskindex
//
//  README Screen 03 — Popover (Ruhe- & Suchzustand).
//

import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    var highlightFirstRow = false

    @FocusState private var searchFocused: Bool
    private var isSearching: Bool {
        !appState.popoverSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let coreHeight = MenuBarPopoverLayout.corePanelHeight(appState: appState)

        popoverContent
        .id(appState.appSettings.displayLanguage)
        .frame(width: MenuBarPopoverLayout.panelWidth, height: coreHeight, alignment: .top)
        .menuBarPopoverChrome()
        .overlayPreferenceValue(PauseToggleAnchorKey.self, alignment: .topLeading) { anchor in
            pauseToggleFrameReporter(anchor: anchor)
        }
        .onChange(of: appState.popoverSearchText) { _, _ in
            searchFocused = true
            appState.schedulePopoverSearch()
            if !appState.popoverSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appState.popoverPauseMenuOpen = false
            }
            requestPopoverLayoutUpdate()
        }
        .onDisappear {
            appState.popoverSearchText = ""
            appState.popoverPauseMenuOpen = false
            searchFocused = false
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if appState.isStoreLoading {
            StoreLoadingView()
        } else {
            popoverBody(
                searchText: appState.popoverSearchTextBinding,
                isPaused: appState.globalAutoIndexPausedBinding
            )
        }
    }

    private func requestPopoverLayoutUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
        }
    }

    /// Meldet Toggle-Rahmen an `MenuBarController` (eigenes Pausentimer-Fenster).
    @ViewBuilder
    private func pauseToggleFrameReporter(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            Color.clear
                .allowsHitTesting(false)
                .onAppear { postToggleFrame(anchor: anchor, proxy: proxy) }
                .onChange(of: proxy.size) { _, _ in postToggleFrame(anchor: anchor, proxy: proxy) }
                .onChange(of: appState.popoverPauseMenuOpen) { _, _ in postToggleFrame(anchor: anchor, proxy: proxy) }
        }
    }

    private func postToggleFrame(anchor: Anchor<CGRect>?, proxy: GeometryProxy) {
        guard let anchor else { return }
        let frame = proxy[anchor]
        NotificationCenter.default.post(
            name: .menuBarPauseToggleFrameInHosting,
            object: nil,
            userInfo: ["frame": frame]
        )
    }

    private func popoverBody(searchText: Binding<String>, isPaused: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            header(searchText: searchText)

            if isSearching {
                MenuBarPopoverSearchContent(query: searchText.wrappedValue)
                searchResultsFooter
            } else {
                idleContent
                autoIndexFooter(isPaused: isPaused)
                openAppFooter
            }
        }
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(LayoutCopy.menuConnectedHeader)
                .padding(.horizontal, MenuBarPopoverLayout.idleContentHorizontalInset)
                .frame(height: MenuBarPopoverLayout.sectionLabelHeight, alignment: .leading)
                .padding(.top, MenuBarPopoverLayout.contentTopPadding)

            let media = appState.connectedMedia
            if let scrollHeight = MenuBarPopoverLayout.idleScrollAreaHeight(media: media) {
                ScrollView {
                    connectedRows(media: media)
                }
                .frame(height: scrollHeight)
            } else {
                connectedRows(media: media)
            }
        }
        .padding(.bottom, MenuBarPopoverLayout.contentBottomPadding)
    }

    private func connectedRows(media: [Medium]) -> some View {
        VStack(spacing: 0) {
            if media.isEmpty {
                Text(EmptyStateCopy.popoverNoneConnected)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .padding(.horizontal, MenuBarPopoverLayout.idleContentHorizontalInset)
                    .frame(maxWidth: .infinity, minHeight: MenuBarPopoverLayout.emptyStateHeight, alignment: .leading)
            } else {
                ForEach(media) { medium in
                    MenuBarConnectedMediumRow(medium: medium, forceHover: highlightFirstRow && medium.id == media.first?.id)
                }
                .padding(.horizontal, MenuBarPopoverLayout.idleContentHorizontalInset)
            }
        }
    }

    private var openAppFooter: some View {
        MenuBarPopoverActionFooter {
            popoverCompactSecondaryButton(LayoutCopy.openApp) {
                MenuBarPopoverDismiss.openMainWindow(destination: .dashboard, appState: appState)
            }
        }
    }

    @ViewBuilder
    private var searchResultsFooter: some View {
        let total = appState.popoverResults.totalCount
        if total > 0 {
            MenuBarPopoverActionFooter {
                popoverCompactSecondaryButton(
                    total == 1 ? LayoutCopy.menuShowOneResult : LayoutCopy.menuShowAllResults(total)
                ) {
                    appState.openSearch(withQuery: appState.popoverSearchText)
                    MenuBarPopoverDismiss.openMainWindow(destination: .search, appState: appState)
                }
            }
        }
    }

    private func popoverCompactSecondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(SecondaryButtonStyle(compactFooter: true))
            .lineLimit(1)
            .pointerCursor()
    }

    @ViewBuilder
    private func header(searchText: Binding<String>) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                HardDrivesGlyph(size: 16)
                Text(LayoutCopy.diskIndex)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: isSearching ? 0 : .infinity, alignment: .leading)
            .opacity(isSearching ? 0 : 1)
            .clipped()
            .allowsHitTesting(!isSearching)

            Spacer(minLength: 0)

            MediumCompactSearchField(
                text: searchText,
                width: isSearching
                    ? MenuBarPopoverLayout.panelWidth - MenuBarPopoverLayout.panelHorizontalInset * 2
                    : DesignSearchField.mediumCompactWidth,
                focus: $searchFocused
            )
            .id("popoverHeaderSearch")
        }
        .padding(.horizontal, MenuBarPopoverLayout.panelHorizontalInset)
        .frame(height: MenuBarPopoverLayout.headerHeight)
        .background(DesignColor.text.opacity(0.06))
        .overlay(alignment: .bottom) {
            MenuBarPopoverSeparator.horizontal
        }
    }

    private func autoIndexFooter(isPaused: Binding<Bool>) -> some View {
        let selection = Binding<BinaryButtonGroupSelection>(
            get: { isPaused.wrappedValue ? .second : .first },
            set: { value in
                guard value != .none else { return }
                if value == .first {
                    DiskIndexLog.shared.ui(
                        "pause toggle click selection=first paused=\(isPaused.wrappedValue) menuOpen=\(appState.popoverPauseMenuOpen)"
                    )
                    appState.resumeIndexing()
                    appState.popoverPauseMenuOpen = false
                } else {
                    DiskIndexLog.shared.ui(
                        "pause toggle click selection=second paused=\(isPaused.wrappedValue) menuOpen=\(appState.popoverPauseMenuOpen)"
                    )
                    appState.popoverPauseMenuOpen = MenuBarPauseToggleLogic.toggledMenuOpen(
                        appState.popoverPauseMenuOpen
                    )
                }
            }
        )
        return HStack {
            Text(LayoutCopy.autoIndex)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            BinaryButtonGroup(
                firstTitle: LayoutCopy.on,
                secondTitle: LayoutCopy.paused,
                selection: selection,
                onReselectTrailing: {
                    DiskIndexLog.shared.ui(
                        "pause toggle click selection=second paused=true menuOpen=\(appState.popoverPauseMenuOpen)"
                    )
                    appState.popoverPauseMenuOpen = MenuBarPauseToggleLogic.toggledMenuOpen(
                        appState.popoverPauseMenuOpen
                    )
                }
            )
            .anchorPreference(key: PauseToggleAnchorKey.self, value: .bounds) { $0 }
        }
        .padding(.horizontal, MenuBarPopoverLayout.panelHorizontalInset)
        .frame(height: MenuBarPopoverLayout.footerAutoIndexHeight)
        .background(MenuBarPopoverLayout.footerBandBackground)
        .overlay(alignment: .top) {
            MenuBarPopoverSeparator.horizontal
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .kerning(1)
            .foregroundStyle(DesignColor.text.opacity(0.55))
    }
}

#if DEBUG
#Preview("Ruhe") {
    MenuBarPopoverView()
        .environment(AppState())
        .padding()
        .background(Color.gray.opacity(0.2))
}

#Preview("Suche") {
    let state = AppState()
    state.popoverSearchText = "rechnung"
    return MenuBarPopoverView()
        .environment(state)
        .padding()
        .background(Color.gray.opacity(0.2))
}
#endif

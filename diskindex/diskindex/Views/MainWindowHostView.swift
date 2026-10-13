//
//  MainWindowHostView.swift
//  diskindex
//

import SwiftUI

enum MainWindowDestination: Equatable {
    case dashboard
    case search
    case columnBrowser
    case settings
    case favorites
}

struct MainWindowHostView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            MainWindowScreenScaffold {
                VStack(spacing: 0) {
                    if let banner = appState.versionLockBannerText(), appState.updateNotice == nil {
                        versionLockBanner(banner)
                    }
                    if appState.isStoreLoading {
                        StoreLoadingView()
                    } else {
                        screenContent
                    }
                }
            }
            .id(appState.appSettings.displayLanguage)

            if let detailID = appState.detailMediumID {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.detailMediumID = nil
                    }

                MediumDetailModalView(mediumID: detailID)
            }

            if let update = appState.updateNotice {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.dismissUpdateNotice(saveSkip: update.skipUpdate)
                    }

                UpdateAvailableDialog(notice: update)
            }

            if let failure = appState.indexingFailure {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.indexingFailure = nil
                    }

                IndexingFailureDialog(notice: failure)
            }

            if appState.indexStoreOpenFailureAlert {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.indexStoreOpenFailureAlert = false
                    }

                StoreOpenFailureDialog()
            }
        }
    }

    private func versionLockBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(DesignColor.text)
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignColor.neutral100)
    }

    @ViewBuilder
    private var screenContent: some View {
        switch appState.mainWindowDestination {
        case .dashboard:
            DashboardView()
        case .search:
            SearchView()
        case .columnBrowser:
            ColumnBrowserView()
        case .settings:
            SettingsView()
        case .favorites:
            FavoritesView()
        }
    }
}

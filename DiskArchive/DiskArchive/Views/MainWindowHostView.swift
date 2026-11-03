//
//  MainWindowHostView.swift
//  DiskArchive
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
                        appState.dismissUpdateNotice()
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

            // todo.0.4.3.011 (Layout 16): „Unerwarteter Fehler“ (z. B. Auswerfen abgelehnt).
            if let error = appState.unexpectedError {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.unexpectedError = nil
                    }

                UnexpectedErrorDialog(notice: error)
            }
        }
    }

    private func versionLockBanner(_ text: String) -> some View {
        WarningBanner(text: text)
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

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
                screenContent
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

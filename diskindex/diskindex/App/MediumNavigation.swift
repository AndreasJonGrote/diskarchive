//
//  MediumNavigation.swift
//  diskindex
//
//  Wiederverwendbare Navigation im Hauptfenster.
//

import SwiftUI

enum MediumNavigation {
    static func openColumnBrowser(for mediumID: UUID, appState: AppState) {
        appState.columnBrowserState.selectedMediumID = mediumID
        appState.columnBrowserState.pathStack = []
        appState.columnBrowserState.selection = ColumnSelection()
        appState.columnBrowserState.selectedUncapturedFolderID = nil
        appState.detailMediumID = nil
        appState.mainWindowDestination = .columnBrowser
        requestLoadForPathColumns(mediumID: mediumID, pathStack: [], appState: appState)
    }

    static func openDetails(for mediumID: UUID, appState: AppState) {
        appState.detailMediumID = mediumID
    }

    static func openDashboard(appState: AppState) {
        appState.detailMediumID = nil
        appState.mainWindowDestination = .dashboard
    }

    static func openSettings(appState: AppState, tab: SettingsTab = .general, scrollTarget: SettingsScrollTarget? = nil) {
        appState.detailMediumID = nil
        appState.settingsTab = tab
        appState.settingsScrollTarget = scrollTarget
        appState.mainWindowDestination = .settings
    }

    static func openFavorites(appState: AppState) {
        appState.detailMediumID = nil
        appState.mainWindowDestination = .favorites
    }

    /// Objekt (Suche, Favoriten, Popover) in der Spaltenansicht zeigen: Datei markiert, Ordner geöffnet.
    static func openObject(_ result: SearchResultItem, appState: AppState) {
        openColumnBrowser(for: result.mediumID, appState: appState)
        let parentPath = result.pathFolderComponents
        let completed = appState.medium(with: result.mediumID)?.completedDepth ?? 0

        guard result.isFolder else {
            appState.columnBrowserState.pathStack = parentPath
            appState.columnBrowserState.selection.replace(id: result.id, column: parentPath.count)
            requestLoadForPathColumns(mediumID: result.mediumID, pathStack: parentPath, appState: appState)
            return
        }

        if appState.appSettings.isFolderContentUncaptured(columnIndex: parentPath.count, completedDepth: completed) {
            appState.columnBrowserState.pathStack = parentPath
            appState.columnBrowserState.selection.replace(id: result.id, column: parentPath.count)
            appState.columnBrowserState.selectedUncapturedFolderID = result.id
            requestLoadForPathColumns(mediumID: result.mediumID, pathStack: parentPath, appState: appState)
        } else {
            let stack = parentPath + [result.name]
            appState.columnBrowserState.pathStack = stack
            appState.columnBrowserState.selection.replace(id: result.id, column: parentPath.count)
            requestLoadForPathColumns(mediumID: result.mediumID, pathStack: stack, appState: appState)
        }
    }

    /// Jede Ordnerspalte entlang des Pfads laden (Wurzel `[]`, dann Präfixe).
    static func requestLoadForPathColumns(mediumID: UUID, pathStack: [String], appState: AppState) {
        appState.indexRepository.requestLoad(mediumID: mediumID, path: [])
        if pathStack.isEmpty { return }
        for depth in 1...pathStack.count {
            appState.indexRepository.requestLoad(
                mediumID: mediumID,
                path: Array(pathStack.prefix(depth))
            )
        }
    }
}

/// Hauptfenster aus dem Menüleisten-Popover öffnen (Popover ist kein Teil des SwiftUI-Scene-Baums).
enum MenuBarPopoverDismiss {
    /// Öffnet das Hauptfenster und schließt das Popover; `destination == nil` behält die aktuelle Ansicht.
    static func openMainWindow(destination: MainWindowDestination? = nil, appState: AppState) {
        AppWindowPresenter.openMain(appState: appState, destination: destination)
        MenuBarController.shared.closePanel()
    }
}

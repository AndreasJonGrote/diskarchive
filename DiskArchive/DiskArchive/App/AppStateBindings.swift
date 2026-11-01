//
//  AppStateBindings.swift
//  DiskArchive
//
//  Explizite Bindings statt `@Bindable`/`$state` in verschachtelten ViewBuildern (Swift 6).
//

import SwiftUI

extension AppState {
    var appSettingsBinding: Binding<AppSettings> {
        Binding(
            get: { self.appSettings },
            set: { self.appSettings = $0 }
        )
    }

    var settingsTabBinding: Binding<SettingsTab> {
        Binding(
            get: { self.settingsTab },
            set: { self.settingsTab = $0 }
        )
    }

    var popoverSearchTextBinding: Binding<String> {
        Binding(
            get: { self.popoverSearchText },
            set: { self.popoverSearchText = $0 }
        )
    }

    var globalAutoIndexPausedBinding: Binding<Bool> {
        Binding(
            get: { self.globalAutoIndexPaused },
            set: { self.globalAutoIndexPaused = $0 || self.settingsUnreadable }
        )
    }

    func searchStateBinding<T>(_ keyPath: WritableKeyPath<SearchState, T>) -> Binding<T> {
        Binding(
            get: { self.searchState[keyPath: keyPath] },
            set: { newValue in
                var copy = self.searchState
                copy[keyPath: keyPath] = newValue
                self.searchState = copy
            }
        )
    }
}

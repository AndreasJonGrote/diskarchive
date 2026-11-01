//
//  AppDelegateBridge.swift
//  DiskArchive
//

import SwiftUI

@MainActor
enum AppDelegateBridge {
    static let appState = AppState(defaults: AppStateStore.current)
}

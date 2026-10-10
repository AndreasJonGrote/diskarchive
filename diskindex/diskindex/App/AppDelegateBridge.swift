//
//  AppDelegateBridge.swift
//  diskindex
//

import SwiftUI

@MainActor
enum AppDelegateBridge {
    static let appState = AppState(defaults: AppDefaults.current)
}

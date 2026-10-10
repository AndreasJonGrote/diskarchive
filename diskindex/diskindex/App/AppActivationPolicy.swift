//
//  AppActivationPolicy.swift
//  diskindex
//
//  Dock bleibt sichtbar, solange der Prozess läuft (README §7, Zweiklick-Start).
//

import AppKit

@MainActor
enum AppActivationPolicy {
    static func showDockIconForMainWindow() {
        NSApp.setActivationPolicy(.regular)
    }
}

//
//  IgnoreConfirmationTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.006 (Nutzer 02.11., Layout 12): die Rückfrage „{n} Einträge ignorieren?“ entfällt – Ignorieren vieler
//  Objekte über das Kontextmenü wirkt sofort wie bei einem (früher bug.0.4.035, todo.0.4.031: Rückfrage ab 500).
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
private func targets(_ count: Int) -> [ObjectContextTarget] {
    let medium = Medium(
        id: UUID(), name: "Viele", type: .usb, connectionStatus: .connected, indexStatus: .indexed,
        allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0,
        fileCount: count, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
        isForgotten: false, indexingProgress: 1
    )
    return (0..<count).map { index in
        ObjectContextTarget.fromIndexedItem(
            IndexedItem(
                id: IndexedItem.stableID(mediumID: medium.id, rowID: Int64(index + 1)),
                rowID: Int64(index + 1),
                name: "eintrag-\(index).txt",
                kind: .file,
                parentPath: [],
                modifiedAt: nil,
                sizeBytes: 1,
                listedAt: nil
            ),
            medium: medium
        )
    }
}

@MainActor
private func entry(_ id: String, _ targets: [ObjectContextTarget], app: AppState) throws -> ContextMenuEntry {
    let entries = multipleContextMenuGroups(targets, appState: app).flatMap { $0 }
    return try #require(entries.first { $0.id == id })
}

@Suite(.serialized) @MainActor
struct IgnoreConfirmationTests {
    @Test func manyTargetsAreIgnoredAtOnce() throws {
        let app = AppState()
        app.appSettings.excludedPatterns = []
        try entry("ignoreName", targets(600), app: app).action()
        #expect(app.appSettings.excludedPatterns.count == 600)
        // Zweiter Klick hebt wieder auf, ebenfalls ohne Rückfrage.
        try entry("ignoreName", targets(600), app: app).action()
        #expect(app.appSettings.excludedPatterns.isEmpty)
    }

    @Test func manyFileTypesAreIgnoredAtOnce() throws {
        let app = AppState()
        app.appSettings.excludedPatterns = []
        try entry("ignoreType", targets(600), app: app).action()
        #expect(app.appSettings.excludedPatterns == ["*.txt"])
    }
}

// Gemeinsame Hilfen der Dialog-Tests (Erkennung, Ersetzen).

/// Esc als Tastenereignis an das eigene Testfenster (Regel 21).
@MainActor
func escapeKey(in window: NSWindow) throws -> NSEvent {
    try #require(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        characters: "\u{1b}",
        charactersIgnoringModifiers: "\u{1b}",
        isARepeat: false,
        keyCode: 53
    ))
}

/// Esc an das Panel: `sendEvent` (Fenster) oder `performKeyEquivalent` (wie NSApp beim Key-Fenster).
@MainActor
func sendEscape(to window: NSWindow, viaKeyEquivalent: Bool) throws {
    let event = try escapeKey(in: window)
    if viaKeyEquivalent {
        #expect(window.performKeyEquivalent(with: event), "Esc als Tastenkürzel nicht behandelt")
    } else {
        window.sendEvent(event)
    }
}

/// Höhe eines Textblocks bei der Innenbreite des Dialogs (340 − 2 × 17).
@MainActor
func dialogTextHeight<V: View>(_ text: V) -> CGFloat {
    NSHostingView(rootView: text.frame(width: 340 - 2 * 17, alignment: .leading)).fittingSize.height
}

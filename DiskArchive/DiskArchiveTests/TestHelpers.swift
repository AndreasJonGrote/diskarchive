//
//  TestHelpers.swift
//  DiskArchiveTests
//
//  Regel 20 (bug.0.4.123/124): Hilfen ohne `!`. bug.0.4.208: App-Zustand im Speicher, nie in den Voreinstellungen.
//

import AppKit
import Foundation
import Testing
@testable import DiskArchive

enum TestDefaults {
    /// Eigener, leerer App-Zustand im Speicher (bug.0.4.208: kein `cfprefsd`, keine Datei).
    static func make() -> AppStateStore {
        AppStateStore()
    }
}

/// Feste Kennung aus einem Literal; ein Tippfehler meldet „rot“ statt den Prozess zu beenden.
func testUUID(_ string: String) -> UUID {
    if let id = UUID(uuidString: string) { return id }
    Issue.record("ungültige UUID im Test: \(string)")
    return UUID()
}

func testAppearance(_ name: NSAppearance.Name) -> NSAppearance {
    if let appearance = NSAppearance(named: name) { return appearance }
    Issue.record("Erscheinungsbild \(name.rawValue) fehlt")
    return NSAppearance.currentDrawing()
}

var gmtTimeZone: TimeZone { TimeZone.gmt }

/// Beispielmedium aus `PreviewData` ohne Feldzugriff außerhalb des Bereichs: fehlt die Zeile, meldet der Test „rot“ und
/// bekommt die nächste vorhandene bzw. bei leerer Liste einen Platzhalter (bug.0.4.162 b: nie `media[0]` auf leer).
@MainActor
func previewMedium(_ index: Int) -> Medium {
    let media = PreviewData.media
    if !media.indices.contains(index) { Issue.record("PreviewData.media hat keine Zeile \(index)") }
    return safeMedium(media, index: index)
}

@MainActor
func firstMedium(of app: AppState) -> Medium {
    if app.media.isEmpty { Issue.record("AppState.media ist leer") }
    return safeMedium(app.media, index: 0)
}

/// Zeile `index` (bzw. die letzte vorhandene); bei leerer Liste ein Platzhalter statt Absturz (Regel 20).
func safeMedium(_ media: [Medium], index: Int) -> Medium {
    if media.indices.contains(index) { return media[index] }
    if let last = media.last { return last }
    return Medium(
        id: UUID(), name: "Platzhalter", type: .usb, connectionStatus: .offline, indexStatus: .pending,
        allowIndexing: false, autoIndexPaused: false, capacityTotalBytes: 0, capacityUsedBytes: 0,
        fileCount: 0, folderCount: 0, lastSeenAt: nil, firstIndexedAt: nil, lastIndexedAt: nil,
        isForgotten: false, indexingProgress: 0
    )
}

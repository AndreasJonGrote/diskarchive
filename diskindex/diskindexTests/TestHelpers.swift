//
//  TestHelpers.swift
//  diskindexTests
//
//  Regel 20 (bug.0.4.123/124): Hilfen ohne `!` und Einstellungs-Suiten, die der nächste Testlauf aufräumt.
//

import AppKit
import Foundation
import Testing
@testable import diskindex

enum TestDefaults {
    /// Eigene Suite `app.diskarchive.tests.<pid>.<Name>-<uuid>`; `AppDefaults.removeStaleTestDomains` räumt sie
    /// samt Datei auf, sobald der Prozess beendet ist.
    static func make(_ label: String = "t") -> UserDefaults {
        let name = suiteName(label)
        let defaults = UserDefaults(suiteName: name) ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func suiteName(_ label: String) -> String {
        "\(AppDefaults.testDomainPrefix)\(ProcessInfo.processInfo.processIdentifier).\(label)-\(UUID().uuidString)"
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

/// Beispielmedium aus `PreviewData` ohne Feldzugriff außerhalb des Bereichs (leere Liste meldet „rot“ und liefert die
/// erste Zeile, die es gibt).
@MainActor
func previewMedium(_ index: Int) -> Medium {
    let media = PreviewData.media
    if !media.indices.contains(index) { Issue.record("PreviewData.media hat keine Zeile \(index)") }
    return media[max(0, min(index, media.count - 1))]
}

@MainActor
func firstMedium(of app: AppState) -> Medium {
    if app.media.isEmpty { Issue.record("AppState.media ist leer") }
    return app.media[max(0, min(0, app.media.count - 1))]
}

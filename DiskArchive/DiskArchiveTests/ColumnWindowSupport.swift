//
//  ColumnWindowSupport.swift
//  DiskArchiveTests
//
//  Regel 18: Ein Test, der „die Spalte zeigt es“ beweisen soll, öffnet die Spaltenansicht in einem echten Fenster
//  (außerhalb des Bildschirms) und liest nur den Zwischenspeicher – die Spalte lädt selbst.
//

import SwiftUI
@testable import DiskArchive

@MainActor
func openColumnWindow(app: AppState, mediumID: UUID, path: [String] = []) -> PixelProbe.Session {
    app.mainWindowDestination = .columnBrowser
    app.columnBrowserState.selectedMediumID = mediumID
    app.columnBrowserState.pathStack = path
    let size = CGSize(width: 1280, height: 800)
    return PixelProbe.open(
        ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
        size: size,
        appearance: .aqua
    )
}

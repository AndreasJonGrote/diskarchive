//
//  ColumnBrowserState.swift
//  diskindex
//

import Foundation

struct ColumnBrowserState: Equatable {
    var selectedMediumID: UUID?
    var pathStack: [String] = []
    var selection = ColumnSelection()
    /// Ordner jenseits der Scan-Tiefe — Detail statt weiterer Spalte (19.10). Nur bei Einzelauswahl.
    var selectedUncapturedFolderID: UUID?
    /// Gemeinsame Breite aller Ordner-Spalten (Nutzer per Drag-Handle, Standard 230pt).
    var folderColumnWidth: CGFloat = DesignSpacing.columnBrowserColumnWidth
    /// Medien-Seitenleiste (200–420 pt, Aufgabe 123).
    var sidebarWidth: CGFloat = DesignSpacing.columnBrowserSidebarWidth
    /// Pfade, deren Ladehinweis gerade sichtbar ist (Aufgabe 156). Nicht schon ab `isLoading`.
    var visibleLoadingHintKeys: Set<String> = []

    func loadingHintVisible(mediumID: UUID, path: [String]) -> Bool {
        visibleLoadingHintKeys.contains(Self.hintKey(mediumID, path))
    }

    mutating func setLoadingHintVisible(_ visible: Bool, mediumID: UUID, path: [String]) {
        let key = Self.hintKey(mediumID, path)
        if visible {
            visibleLoadingHintKeys.insert(key)
        } else {
            visibleLoadingHintKeys.remove(key)
        }
    }

    private static func hintKey(_ mediumID: UUID, _ path: [String]) -> String {
        ([mediumID.uuidString] + path).joined(separator: "\u{0}")
    }

    static let sidebarWidthRange: ClosedRange<CGFloat> = 200...420

    mutating func setSidebarWidth(_ width: CGFloat) {
        sidebarWidth = min(Self.sidebarWidthRange.upperBound, max(Self.sidebarWidthRange.lowerBound, width))
    }
}

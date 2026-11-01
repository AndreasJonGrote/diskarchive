//
//  ColumnBrowserState.swift
//  DiskArchive
//

import Foundation

struct ColumnBrowserState: Equatable {
    var selectedMediumID: UUID?
    var pathStack: [String] = [] {
        didSet {
            if openFolderRowIDs.count > pathStack.count { openFolderRowIDs.removeSubrange(pathStack.count...) }
            // bug.0.4.218: Spalte `i` zeigt `pathStack.prefix(i)`. Ändert sich der Pfad davor, zeigt sie etwas anderes
            // (oder schließt) – ihre gezogene Breite fällt weg.
            let kept = zip(oldValue, pathStack).prefix { $0 == $1 }.count
            folderColumnWidths = folderColumnWidths.filter { $0.key <= kept }
        }
    }
    /// bug.0.4.147: Zeilenkennung des offenen Ordners je Pfadebene (soweit durch Klick/Taste bekannt). Damit folgt der
    /// Pfad einem Umbenennen auch dann, wenn der alte Spaltenstand nicht mehr im Zwischenspeicher liegt.
    var openFolderRowIDs: [Int64] = []
    var selection = ColumnSelection()
    /// Ordner jenseits der Scan-Tiefe — Detail statt weiterer Spalte (19.10). Nur bei Einzelauswahl.
    var selectedUncapturedFolderID: UUID?
    /// bug.0.4.218: gezogene Breite je Ordnerspalte (Index); sonst Standard 230 pt. Nicht gespeichert.
    private(set) var folderColumnWidths: [Int: CGFloat] = [:]
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

    func folderColumnWidth(at columnIndex: Int) -> CGFloat {
        folderColumnWidths[columnIndex] ?? DesignSpacing.columnBrowserColumnWidth
    }

    mutating func setFolderColumnWidth(_ width: CGFloat, at columnIndex: Int) {
        folderColumnWidths[columnIndex] = width
    }

    /// bug.0.4.234: Der offene Ordner der Ebene `level` wurde umbenannt (gleiche Zeile): Pfad folgt dem neuen Namen.
    /// Gleiche Zeile: Name oder Zeilenkennung bleibt → die Breiten dahinter bleiben. Ist für die Ebene eine andere Zeile
    /// bekannt, gilt sie als anderer Ordner (bug.0.4.218).
    mutating func renameOpenFolder(at level: Int, to name: String, rowID: Int64?) {
        let known = level < openFolderRowIDs.count ? openFolderRowIDs[level] : nil
        let sameRow = known == nil || rowID == nil || known == rowID
        let widths = folderColumnWidths
        pathStack[level] = name
        if sameRow { folderColumnWidths = widths }
    }

    mutating func setSidebarWidth(_ width: CGFloat) {
        sidebarWidth = min(Self.sidebarWidthRange.upperBound, max(Self.sidebarWidthRange.lowerBound, width))
    }
}

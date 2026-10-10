//
//  ScreenshotPlan.swift
//  diskindex
//
//  Debug: Screenshot-Plan und Pixelhilfen (Aufgabe 111).
//

import AppKit
import Foundation

#if DEBUG

nonisolated enum ScreenshotPlan {
    static let argument = "--screenshots"

    static func folder(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static let bases = [
        "02-erkennung",
        "03-ruhe", "03-pause-an", "03-pause-pausiert", "03-suche", "03-hover",
        "04-uebersicht", "04-uebersicht-einzeln", "04-uebersicht-leer",
        "04-dashboard-chips-zaehlt", "04-dashboard-chips-9", "04-dashboard-chips-47", "04-dashboard-chips-99",
        "05-allgemein", "05-erscheinung-hell", "05-erscheinung-dunkel",
        "05-dateien", "05-dateien-chips", "05-medien", "05-medien-leer", "04-dashboard-chips",
        "05-erweitert", "05-erweitert-indiziert", "05-erweitert-favoriten",
        "05-bestaetigung-alle-1", "05-bestaetigung-alle-2", "05-bestaetigung-alle-3",
        "05-bestaetigung-detail-1", "05-bestaetigung-detail-2", "05-bestaetigung-detail-3",
        "05-bestaetigung-bereinigen-1", "05-bestaetigung-bereinigen-2", "05-bestaetigung-bereinigen-3",
        "05-bestaetigung-voreinstellungen-1", "05-bestaetigung-voreinstellungen-2", "05-bestaetigung-voreinstellungen-3",
        "06-detail",
        "07-spalten", "07-spalten-langname", "07-tiefe", "07-kontext", "07-mehrfach", "07-nicht-erfasst", "07-wird-indiziert", "07-inhalte-geladen",
        "08-filter", "08-filter-und-sichtbar", "08-filter-und-aus",
        "09-filterpopover",
        "10-suche-1", "10-suche-2", "10-suche-3", "10-suche-4", "10-suche-5", "10-suche-6", "10-suche-leer",
        "11-favoriten", "11-favoriten-leer", "11-favoriten-kontext",
        "12-kontext",
        "13-absturz",
        "14-fehler", "14-mitteilung",
        "10-suche-vorschlag", "10-suche-keine-vorschlag",
        "11-favoriten-vorschlag",
        "05-erweitert-vorschlag",
        "toolbar-dashboard", "toolbar-favorites", "toolbar-settings", "toolbar-search", "toolbar-filter",
    ]

    static var names: [String] {
        bases.flatMap { ["\($0)-hell", "\($0)-dunkel"] }
    }
}

enum ScreenshotPixels {
    static func isUniform(_ rep: NSBitmapImageRep) -> Bool {
        guard let data = rep.bitmapData else { return true }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let row = rep.bytesPerRow
        let samples = rep.samplesPerPixel
        guard width > 2, height > 2, samples >= 3 else { return true }
        let step = max(1, min(40, width / 4))
        func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
            let offset = y * row + x * samples
            return (data[offset], data[offset + 1], data[offset + 2])
        }
        let first = pixel(0, 0)
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                if pixel(x, y) != first { return false }
                x += step
            }
            y += step
        }
        return true
    }

    /// Genug unterschiedliche Pixel für sichtbaren Zeilentext (nicht nur Fläche/Rahmen).
    static func hasDistinctInk(_ rep: NSBitmapImageRep) -> Bool {
        guard let data = rep.bitmapData else { return false }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let row = rep.bytesPerRow
        let samples = rep.samplesPerPixel
        guard width > 2, height > 2, samples >= 3 else { return false }
        let step = max(1, min(24, width / 10))
        var colors = Set<UInt32>()
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let offset = y * row + x * samples
                let packed = UInt32(data[offset]) << 16 | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2])
                colors.insert(packed)
                if colors.count >= 12 { return true }
                x += step
            }
            y += step
        }
        return colors.count >= 8
    }
}

#endif

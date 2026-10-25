//
//  ScopeLoadingTestSupport.swift
//  diskindexTests
//
//  todo.0.4.042/046: Pixelhilfen für die Ladeansicht von Suche und Favoriten (Spinner in der Farbe der Ansicht, Titel an
//  der Stelle des Leerzustands-Titels).
//

import AppKit
import Testing

enum ScopeLoadingPixels {
    /// Blau der Suche (`filterSearch`, hell #3986E4, dunkel #65A7FA): Blau klar über Rot und Grün.
    static func isBlue(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Bool {
        b - r > 0.3 && b - g > 0.12
    }

    /// Violett der Favoriten (`favorite`, hell #9D69D2, dunkel #B98CEA): Blau und Rot klar über Grün.
    static func isViolet(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Bool {
        b - g > 0.25 && r - g > 0.08 && b > r
    }

    /// Rahmen (in Punkten) aller Pixel in `region`, die `match` erfüllen; `nil` = keiner.
    static func bounds(
        _ bitmap: NSBitmapImageRep,
        region: CGRect,
        _ match: (CGFloat, CGFloat, CGFloat) -> Bool
    ) -> CGRect? {
        let scale = CGFloat(bitmap.pixelsWide) / max(1, bitmap.size.width)
        let x0 = max(0, Int(region.minX * scale)), x1 = min(bitmap.pixelsWide, Int(region.maxX * scale))
        let y0 = max(0, Int(region.minY * scale)), y1 = min(bitmap.pixelsHigh, Int(region.maxY * scale))
        guard x0 < x1, y0 < y1 else { return nil }
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                guard match(color.redComponent, color.greenComponent, color.blueComponent) else { continue }
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard minX <= maxX else { return nil }
        return CGRect(
            x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale
        )
    }

    static func count(_ bitmap: NSBitmapImageRep, region: CGRect, _ match: (CGFloat, CGFloat, CGFloat) -> Bool) -> Int {
        let scale = CGFloat(bitmap.pixelsWide) / max(1, bitmap.size.width)
        let x0 = max(0, Int(region.minX * scale)), x1 = min(bitmap.pixelsWide, Int(region.maxX * scale))
        let y0 = max(0, Int(region.minY * scale)), y1 = min(bitmap.pixelsHigh, Int(region.maxY * scale))
        guard x0 < x1, y0 < y1 else { return 0 }
        var hits = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if match(color.redComponent, color.greenComponent, color.blueComponent) { hits += 1 }
            }
        }
        return hits
    }

    /// Text (Titel, Untertitel): Graustufe mit Abstand zum Hintergrund (hell: dunkler, dunkel: heller).
    static func ink(dark: Bool) -> (CGFloat, CGFloat, CGFloat) -> Bool {
        { r, g, b in
            let gray = abs(r - g) < 0.08 && abs(g - b) < 0.08
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return gray && (dark ? luminance > 0.55 : luminance < 0.5)
        }
    }

    /// Prüft den Spinner: Rahmen ca. 32 pt (Strich und Kantenglättung ±3), innen hohl.
    static func expectSpinner(
        _ bitmap: NSBitmapImageRep,
        region: CGRect,
        _ match: (CGFloat, CGFloat, CGFloat) -> Bool,
        _ label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> CGRect? {
        guard let box = bounds(bitmap, region: region, match) else {
            Issue.record("\(label): kein Spinner in der Farbe der Ansicht", sourceLocation: sourceLocation)
            return nil
        }
        #expect(abs(box.width - 32) <= 3 && abs(box.height - 32) <= 3, "\(label): Spinner \(box.size) statt 32 pt", sourceLocation: sourceLocation)
        let hole = CGRect(x: box.midX - 6, y: box.midY - 6, width: 12, height: 12)
        #expect(count(bitmap, region: hole, match) == 0, "\(label): Spinner nicht hohl (Icon statt Spinner?)", sourceLocation: sourceLocation)
        return box
    }

    /// Oberkante der ersten Textzeile unterhalb von `y` in `region` (Titel unter dem Icon bzw. Spinner).
    static func firstTextTop(_ bitmap: NSBitmapImageRep, region: CGRect, below y: CGFloat, dark: Bool) -> CGFloat? {
        let band = CGRect(x: region.minX, y: y, width: region.width, height: region.maxY - y)
        return bounds(bitmap, region: band, ink(dark: dark))?.minY
    }
}

//
//  AppIconTests.swift
//  diskindexTests
//
//  bug.0.4.1.002: Ab macOS 26 setzt das System Symbole, die nicht aus einer Icon-Composer-Datei stammen, verkleinert
//  auf eine helle Platte. Das App-Symbol kommt deshalb aus `AppIcon.icon` (Verlauf #575757 → #1F1F1F, Motiv #F2F2F2);
//  macOS 15 bekommt daraus weiter `AppIcon.icns` mit dunkler Kachel.
//

import AppKit
import Foundation
import Testing

struct AppIconTests {
    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// `actool` legt in `AppIcon.icns` nur 16 und 128 pt ab (so schon beim alten `AppIcon.appiconset`); die großen
    /// Größen für macOS 15 stehen im `Assets.car` unter `CFBundleIconName`.
    @Test func bundleCarriesTheDarkIconForOlderSystems() throws {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String == "AppIcon")
        let url = try #require(Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), "AppIcon.icns fehlt im Bundle")
        let icns = try #require(NSImage(contentsOf: url))
        #expect(icns.representations.contains { $0.size.width >= 128 }, "AppIcon.icns ohne 128 pt: \(icns.representations.map(\.size))")
        let image = try #require(NSImage(named: "AppIcon"), "AppIcon fehlt im Asset-Katalog")
        #expect(image.representations.contains { $0.size.width >= 512 }, "keine Größe ≥ 512 pt: \(image.representations.map(\.size))")

        // 512er-Darstellung, Mitte oben: in der Kachel, über dem Motiv – also Hintergrund.
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512))
        NSGraphicsContext.restoreGraphicsState()
        let color = try #require(rep.colorAt(x: 256, y: 92)?.usingColorSpace(.sRGB))
        #expect(color.alphaComponent > 0.9, "Mitte oben durchsichtig (Alpha \(color.alphaComponent))")
        #expect(color.brightnessComponent < 0.45, "Mitte oben hell (Helligkeit \(color.brightnessComponent))")
    }

    @Test func iconComesFromTheIconComposerFile() throws {
        let root = Self.projectRoot
        let json = root.appendingPathComponent("diskindex/AppIcon.icon/icon.json")
        #expect(FileManager.default.fileExists(atPath: json.path), "AppIcon.icon/icon.json fehlt")
        let appiconset = root.appendingPathComponent("diskindex/Assets.xcassets/AppIcon.appiconset")
        #expect(!FileManager.default.fileExists(atPath: appiconset.path), "AppIcon.appiconset gibt es noch (zwei Quellen)")
        // Der Ordner `diskindex` ist mit dem App-Ziel synchronisiert; eine Ausnahme nähme die Datei heraus.
        let project = try String(
            contentsOf: root.appendingPathComponent("diskindex.xcodeproj/project.pbxproj"), encoding: .utf8
        )
        #expect(!project.contains("AppIcon.icon,") && !project.contains("AppIcon.icon;"), "AppIcon.icon nicht im App-Ziel")
    }
}

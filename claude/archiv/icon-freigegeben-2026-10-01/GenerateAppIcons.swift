#!/usr/bin/env swift
//
//  AppIcon.appiconset.
//  Kachel wie das Apple-Raster: 824 von 1024, Rand 100, Radius 185,4.
//  Kein eigener Schatten: der vergrößert die sichtbare Fläche, den Schatten setzt das Dock.
//  Verlauf 160° #2B2B2D → #1F1F1F.
//  Glyph `hard-drives` #F2F2F2: Rahmen 58/72 der Kachel, sichtbare Breite 60 % der Kachel
//  (der Phosphor-Pfad füllt 75 % seines Rahmens).
//
//  Ausführung: swift Scripts/GenerateAppIcons.swift [Ausgabeordner]
//  Ohne Argument wird direkt in Assets.xcassets/AppIcon.appiconset geschrieben, dazu
//  DockIcon.imageset/DockIcon.png (= 1024er Variante), damit Dock-Bild und App-Icon nie auseinanderlaufen.
//  Mit Ausgabeordner landen alle Dateien (inkl. DockIcon.png) dort — z. B. zum Pixelvergleich.
//

import AppKit

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let svgURL = repoRoot
    .appendingPathComponent("diskindex/Assets.xcassets/MenuBarHardDrives.imageset/hard-drives.svg")

let customOutDir = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1]) : nil
let outDir = customOutDir ?? repoRoot.appendingPathComponent("diskindex/Assets.xcassets/AppIcon.appiconset")
let dockIconURL = (customOutDir ?? repoRoot.appendingPathComponent("diskindex/Assets.xcassets/DockIcon.imageset"))
    .appendingPathComponent("DockIcon.png")

let specs: [(filename: String, pixelSize: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

guard let glyphSource = NSImage(contentsOf: svgURL) else {
    fputs("SVG nicht gefunden: \(svgURL.path)\n", stderr)
    exit(1)
}

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: Int, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func makeContext(pixelSize: Int) -> CGContext? {
    CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

/// Glyph als eigene Ebene einfärben — `sourceIn` nur auf der Glyph-Ebene, nicht auf dem Hintergrund.
func tintedGlyph(side: Int) -> CGImage? {
    var rect = NSRect(x: 0, y: 0, width: side, height: side)
    guard let glyph = glyphSource.cgImage(forProposedRect: &rect, context: nil, hints: nil),
          let context = makeContext(pixelSize: side) else {
        return nil
    }
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    context.interpolationQuality = .high
    context.draw(glyph, in: bounds)
    context.setBlendMode(.sourceIn)
    context.setFillColor(color(0xF2F2F2))
    context.fill(bounds)
    return context.makeImage()
}

func renderIcon(pixelSize: Int) -> CGImage? {
    guard let context = makeContext(pixelSize: pixelSize) else { return nil }

    let side = CGFloat(pixelSize)
    let unit = side / 1024
    let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let radius = 185.4 * unit
    let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    // CSS `linear-gradient(160deg, …)`: CSS misst mit y nach unten, Quartz mit y nach oben → y-Komponente gespiegelt.
    let radians = 160 * CGFloat.pi / 180
    let dx = sin(radians)
    let dy = cos(radians)
    let halfLength = (abs(sin(radians)) + abs(cos(radians))) * tile.width / 2
    if let gradient = CGGradient(colorsSpace: srgb, colors: [color(0x2B2B2D), color(0x1F1F1F)] as CFArray, locations: [0, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: tile.midX - dx * halfLength, y: tile.midY - dy * halfLength),
            end: CGPoint(x: tile.midX + dx * halfLength, y: tile.midY + dy * halfLength),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    context.restoreGState()

    // Phosphor-Pfad x 32…224 von 256 → 75 % des Rahmens. 58/72 der Kachel ergeben 60 % sichtbare Breite.
    let glyphSide = Int((tile.width * 58 / 72).rounded())
    if let glyph = tintedGlyph(side: glyphSide) {
        let origin = (side - CGFloat(glyphSide)) / 2
        context.draw(glyph, in: CGRect(x: origin, y: origin, width: CGFloat(glyphSide), height: CGFloat(glyphSide)))
    }

    return context.makeImage()
}

for spec in specs {
    guard let image = renderIcon(pixelSize: spec.pixelSize),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fputs("Render fehlgeschlagen: \(spec.filename)\n", stderr)
        exit(1)
    }
    do {
        try png.write(to: outDir.appendingPathComponent(spec.filename))
        print("Wrote \(spec.filename) (\(spec.pixelSize)px)")
        if spec.pixelSize == 1024 {
            try png.write(to: dockIconURL)
            print("Wrote DockIcon.png (1024px)")
        }
    } catch {
        fputs("Schreiben fehlgeschlagen: \(error)\n", stderr)
        exit(1)
    }
}

print("Done.")

func measure(_ url: URL, canvas: Int) {
    guard let image = NSImage(contentsOf: url),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("Messen fehlgeschlagen: \(url.lastPathComponent)\n", stderr)
        return
    }
    let width = cg.width
    let height = cg.height
    guard let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return }
    let row = cg.bytesPerRow
    let bpp = cg.bitsPerPixel / 8
    func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let offset = y * row + x * bpp
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
    var minX = width, maxX = 0
    var glyphMinX = width, glyphMaxX = 0
    let midY = height / 2
    for x in 0..<width {
        let (_, _, _, a) = pixel(x, midY)
        if a > 200 {
            minX = min(minX, x)
            maxX = max(maxX, x)
        }
    }
    for y in 0..<height {
        for x in 0..<width {
            let (r, g, b, a) = pixel(x, y)
            if a > 16, r > 180, g > 180, b > 180 {
                glyphMinX = min(glyphMinX, x)
                glyphMaxX = max(glyphMaxX, x)
            }
        }
    }
    let tileWidth = maxX >= minX ? maxX - minX + 1 : 0
    let glyphWidth = glyphMaxX >= glyphMinX ? glyphMaxX - glyphMinX + 1 : 0
    let corner = pixel(0, 0)
    let tileRatio = Double(tileWidth) / Double(width)
    let glyphOfTile = tileWidth > 0 ? Double(glyphWidth) / Double(tileWidth) : 0
    print(String(
        format: "%@ %dx%d Kachel %.1f%% Symbol/Kachel %.1f%% Ecke alpha %d",
        url.lastPathComponent, width, height, tileRatio * 100, glyphOfTile * 100, corner.3
    ))
    _ = canvas
}

if customOutDir == nil {
    for spec in specs {
        measure(outDir.appendingPathComponent(spec.filename), canvas: spec.pixelSize)
    }
    measure(dockIconURL, canvas: 1024)
}

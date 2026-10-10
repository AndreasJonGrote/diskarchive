#!/usr/bin/env swift
//
//  AppIcon.appiconset.
//  Kachel wie das Apple-Raster: 824 von 1024, Rand 100, Radius 185,4.
//  Kein eigener Schatten: der vergrößert die sichtbare Fläche, den Schatten setzt das Dock.
//  Kandidat (Aufgabe 62, final): Verlauf von #575757 oben links nach #1F1F1F unten rechts.
//  Die Endfarbe ist auf dem letzten Viertel der Diagonale schon erreicht.
//  Glyph `hard-drives` #F2F2F2, Rahmen 58/72 der Kachel.
//  Jede Größe einzeln, 4× überabgetastet. Bei 16 und 32 px Strich nach innen kräftiger.
//
//  Ausführung: swift Scripts/GenerateAppIcons.swift <Ausgabeordner>
//  Ohne Ausgabeordner bricht das Skript ab. Die freigegebenen Dateien im
//  Asset-Katalog dürfen so nicht ersetzt werden.
//

import AppKit
import CoreText

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let svgURL = repoRoot
    .appendingPathComponent("diskindex/Assets.xcassets/MenuBarHardDrives.imageset/hard-drives.svg")

guard CommandLine.arguments.count > 1 else {
    fputs("Ausgabeordner fehlt. Beispiel: swift Scripts/GenerateAppIcons.swift Werkzeuge/icon-kandidat\n", stderr)
    exit(1)
}
let customOutDir = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = customOutDir
let lightIcon = outDir.lastPathComponent == "icon-kandidat-hell"
let tileEnd = lightIcon ? 0xD9D8D8 : 0x1F1F1F
let tileStart = lightIcon ? 0xF4F4F4 : 0x575757
let glyphInk = lightIcon ? 0x1F1F1F : 0xF2F2F2
let dockIconURL = customOutDir.appendingPathComponent("DockIcon.png")
let approvedDir = repoRoot
    .deletingLastPathComponent()
    .appendingPathComponent("archiv/icon-freigegeben-2026-10-01/AppIcon.appiconset")

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
    context.setFillColor(color(glyphInk))
    context.fill(bounds)
    return context.makeImage()
}

func drawTile(in context: CGContext, pixelSize: Int) {
    let side = CGFloat(pixelSize)
    let unit = side / 1024
    let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let radius = 185.4 * unit
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    // Hell oben links, dunkel unten rechts, auf den sichtbaren Ecken der Rundung.
    let along = radius / 2.squareRoot()
    let light = CGPoint(x: tile.minX + radius - along, y: tile.maxY - radius + along)
    let dark = CGPoint(x: tile.maxX - radius + along, y: tile.minY + radius - along)
    if let gradient = CGGradient(
        colorsSpace: srgb,
        colors: [color(tileEnd), color(tileEnd), color(tileStart)] as CFArray,
        locations: [0, 0.25, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: dark,
            end: light,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    context.restoreGState()
}

func drawGlyph(in context: CGContext, pixelSize: Int) {
    let side = CGFloat(pixelSize)
    let tileWidth = 824 * side / 1024
    let glyphSide = Int((tileWidth * 58 / 72).rounded())
    guard let glyph = tintedGlyph(side: max(glyphSide, 1)) else { return }
    let origin = (side - CGFloat(glyphSide)) / 2
    context.draw(glyph, in: CGRect(x: origin, y: origin, width: CGFloat(glyphSide), height: CGFloat(glyphSide)))
}

func renderGlyphLayer(pixelSize: Int) -> CGImage? {
    guard let context = makeContext(pixelSize: pixelSize) else { return nil }
    context.interpolationQuality = .high
    drawGlyph(in: context, pixelSize: pixelSize)
    return context.makeImage()
}

func downsample(_ image: CGImage, to pixelSize: Int) -> CGImage? {
    guard let context = makeContext(pixelSize: pixelSize) else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    return context.makeImage()
}

func isGlyph(_ r: Int, _ g: Int, _ b: Int, _ a: Int) -> Bool {
    if lightIcon { return a > 16 && r < 90 && g < 90 && b < 90 }
    return a > 16 && r > 140 && g > 140 && b > 140
}

/// Bei 16 und 32 px den Strich nach innen kräftigen, Abstand der Kästen halten, LEDs bei 16 px entfernen.
func refineSmallGlyph(_ image: CGImage, pixelSize: Int) -> CGImage {
    guard pixelSize <= 32 else { return image }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let raw = rep.bitmapData else { return image }
    let rowBytes = rep.bytesPerRow
    let step = max(1, rep.bitsPerPixel / 8)
    func sample(_ x: Int, _ y: Int) -> (Int, Int, Int, Int) {
        let o = y * rowBytes + x * step
        return (Int(raw[o]), Int(raw[o + 1]), Int(raw[o + 2]), Int(raw[o + 3]))
    }
    func paint(_ x: Int, _ y: Int, _ rgba: (Int, Int, Int, Int)) {
        let o = y * rowBytes + x * step
        raw[o] = UInt8(rgba.0)
        raw[o + 1] = UInt8(rgba.1)
        raw[o + 2] = UInt8(rgba.2)
        raw[o + 3] = UInt8(rgba.3)
    }
    var minX = pixelSize, maxX = 0, minY = pixelSize, maxY = 0
    for y in 0..<pixelSize {
        for x in 0..<pixelSize {
            let p = sample(x, y)
            if isGlyph(p.0, p.1, p.2, p.3) {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    guard maxX >= minX else { return image }
    let passes = pixelSize <= 16 ? 1 : 1
    for _ in 0..<passes {
        var grow: [(Int, Int)] = []
        for y in (minY + 1)..<maxY {
            for x in (minX + 1)..<maxX {
                let p = sample(x, y)
                if isGlyph(p.0, p.1, p.2, p.3) { continue }
                let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                if neighbors.contains(where: { isGlyph(sample($0.0, $0.1).0, sample($0.0, $0.1).1, sample($0.0, $0.1).2, sample($0.0, $0.1).3) }) {
                    grow.append((x, y))
                }
            }
        }
        for point in grow {
            paint(point.0, point.1, ((glyphInk >> 16) & 0xFF, (glyphInk >> 8) & 0xFF, glyphInk & 0xFF, 255))
        }
    }
    func glyphCount(_ y: Int) -> Int {
        var count = 0
        for x in minX...maxX {
            let p = sample(x, y)
            if isGlyph(p.0, p.1, p.2, p.3) { count += 1 }
        }
        return count
    }
    var bands: [(Int, Int)] = []
    var start: Int?
    for y in minY...maxY {
        if glyphCount(y) > 0 {
            if start == nil { start = y }
        } else if let s = start {
            bands.append((s, y - 1))
            start = nil
        }
    }
    if let s = start { bands.append((s, maxY)) }
    if bands.count >= 2 {
        let upper = bands[0]
        let lower = bands[bands.count - 1]
        var topEdge = upper.1
        var bottomEdge = lower.0
        while bottomEdge - topEdge - 1 < 2, topEdge > upper.0, bottomEdge < lower.1 {
            topEdge -= 1
            bottomEdge += 1
        }
        let tile = sample(max(0, minX - 2), max(0, minY - 2))
        let fill = tile.3 > 16 ? tile : (0x1F, 0x1F, 0x1F, 255)
        if bottomEdge - topEdge > 1 {
            for y in (topEdge + 1)..<bottomEdge {
                for x in minX...maxX {
                    paint(x, y, fill)
                }
            }
        }
    }
    if pixelSize <= 16 {
        for y in minY...maxY {
            for x in minX...maxX where x > minX + (maxX - minX) * 2 / 3 {
                let p = sample(x, y)
                guard isGlyph(p.0, p.1, p.2, p.3) else { continue }
                let left = sample(x - 1, y)
                let up = sample(x, max(0, y - 1))
                let down = sample(x, min(pixelSize - 1, y + 1))
                let isolated = !isGlyph(left.0, left.1, left.2, left.3)
                    && !isGlyph(up.0, up.1, up.2, up.3)
                    && !isGlyph(down.0, down.1, down.2, down.3)
                if isolated {
                    let tile = sample(max(0, minX - 2), y)
                    paint(x, y, tile.3 > 16 ? tile : (0x1F, 0x1F, 0x1F, 255))
                }
            }
        }
    }
    return rep.cgImage ?? image
}

func renderIcon(pixelSize: Int) -> CGImage? {
    guard let context = makeContext(pixelSize: pixelSize) else { return nil }
    context.interpolationQuality = .high
    drawTile(in: context, pixelSize: pixelSize)
    let scale = 4
    if let large = renderGlyphLayer(pixelSize: pixelSize * scale),
       let glyph = downsample(large, to: pixelSize) {
        context.draw(glyph, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    }
    guard let image = context.makeImage() else { return nil }
    return refineSmallGlyph(image, pixelSize: pixelSize)
}

if outDir.lastPathComponent.hasPrefix("icon-kandidat") {
    try? FileManager.default.removeItem(at: outDir)
}
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

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

for spec in specs {
    measure(outDir.appendingPathComponent(spec.filename), canvas: spec.pixelSize)
}
measure(dockIconURL, canvas: 1024)

func loadPNG(_ url: URL) -> CGImage? {
    guard let image = NSImage(contentsOf: url) else { return nil }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func comparisonSheet() {
    let shown = [1024, 512, 256, 128, 64, 32, 16]
    let names = [
        1024: "icon_512x512@2x.png",
        512: "icon_512x512.png",
        256: "icon_256x256.png",
        128: "icon_128x128.png",
        64: "icon_32x32@2x.png",
        32: "icon_32x32.png",
        16: "icon_16x16.png",
    ]
    let pad = 24
    let label = 72
    var width = label + pad
    var height = pad
    for size in shown {
        width += size * 2 + pad * 2
        height = max(height, size + pad * 2)
    }
    height = pad
    for size in shown { height += size + pad }
    height += 140
    let sheet = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    guard let sheet else { return }
    sheet.setFillColor(color(0xFFFFFF))
    sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))
    var y = height - pad
    for size in shown {
        y -= size
        var x = label
        for background in [0xF4F1EC, 0x1A1A1A] {
            for source in [approvedDir, outDir] {
                sheet.setFillColor(color(background))
                sheet.fill(CGRect(x: x, y: y, width: size, height: size))
                if let icon = loadPNG(source.appendingPathComponent(names[size]!)) {
                    sheet.interpolationQuality = .none
                    sheet.draw(icon, in: CGRect(x: x, y: y, width: size, height: size))
                }
                x += size + pad
            }
        }
        y -= pad
    }
    let dockY = 24
    let slot = 96
    sheet.setFillColor(color(0x2C2C2E))
    sheet.fill(CGRect(x: label, y: dockY, width: slot * 3 + 48, height: slot + 16))
    for index in 0..<3 {
        let origin = label + 16 + index * slot
        if index == 1, let icon = loadPNG(dockIconURL) {
            sheet.interpolationQuality = .high
            sheet.draw(icon, in: CGRect(x: origin + 8, y: dockY + 16, width: slot - 16, height: slot - 16))
        } else {
            let neighbor = CGRect(x: origin + 14, y: dockY + 22, width: slot - 28, height: slot - 28)
            sheet.setFillColor(color(index == 0 ? 0x8E8E93 : 0x636366))
            sheet.addPath(CGPath(roundedRect: neighbor, cornerWidth: 18, cornerHeight: 18, transform: nil))
            sheet.fillPath()
        }
    }
    guard let image = sheet.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fputs("Vergleichsblatt fehlgeschlagen\n", stderr)
        return
    }
    let url = outDir.appendingPathComponent("vergleich.png")
    try? png.write(to: url)
    print("Wrote vergleich.png")
}

func drawLine(_ text: String, x: CGFloat, baseline: CGFloat, size: CGFloat, hex: Int, in context: CGContext) {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    let string = NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: color(hex)) ?? .black,
    ])
    let line = CTLineCreateWithAttributedString(string)
    context.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(line, context)
}

func tileSwatch(_ url: URL, x: Int, y: Int) -> (Int, Int, Int)? {
    guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: url)) ?? Data()),
          let raw = rep.bitmapData,
          x >= 0, y >= 0, x < rep.pixelsWide, y < rep.pixelsHigh else { return nil }
    let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
    return (Int(raw[offset]), Int(raw[offset + 1]), Int(raw[offset + 2]))
}

func labeledSheet() {
    let width = 1280
    let height = 980
    guard let sheet = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }
    sheet.setFillColor(color(0xFFFFFF))
    sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))
    drawLine("Disk Index — Icon-Vergleich", x: 48, baseline: 920, size: 28, hex: 0x1F1F1F, in: sheet)
    if lightIcon {
        drawLine("Links: GESETZT. Dunkle Kachel, helles Symbol.", x: 48, baseline: 880, size: 18, hex: 0x1F1F1F, in: sheet)
        drawLine("Rechts: KANDIDAT HELL. Oben #F4F4F4, unten #D9D8D8, dunkles Symbol #1F1F1F. Endfarbe 25 % früher.", x: 48, baseline: 852, size: 16, hex: 0x1F1F1F, in: sheet)
    } else {
        drawLine("Links: FREIGEGEBEN. Die bisherige Kachel.", x: 48, baseline: 880, size: 18, hex: 0x1F1F1F, in: sheet)
        drawLine("Rechts: KANDIDAT. Hell #575757 oben links, dunkel #1F1F1F unten rechts. Die Endfarbe beginnt 25 % früher.", x: 48, baseline: 852, size: 16, hex: 0x1F1F1F, in: sheet)
    }

    let iconSide: CGFloat = 420
    let tops: [(title: String, file: URL, x: CGFloat)] = [
        (lightIcon ? "GESETZT" : "FREIGEGEBEN", lightIcon ? repoRoot.deletingLastPathComponent().appendingPathComponent("Werkzeuge/icon-kandidat/icon_512x512@2x.png") : approvedDir.appendingPathComponent("icon_512x512@2x.png"), 48),
        (lightIcon ? "KANDIDAT HELL" : "KANDIDAT", outDir.appendingPathComponent("icon_512x512@2x.png"), 640),
    ]
    for item in tops {
        drawLine(item.title, x: item.x, baseline: 800, size: 22, hex: 0x1F1F1F, in: sheet)
        sheet.setFillColor(color(0xF4F1EC))
        sheet.fill(CGRect(x: item.x, y: 340, width: iconSide, height: iconSide))
        if let icon = loadPNG(item.file) {
            sheet.interpolationQuality = .high
            sheet.draw(icon, in: CGRect(x: item.x, y: 340, width: iconSide, height: iconSide))
        }
    }

    let candidateFile = outDir.appendingPathComponent("icon_512x512@2x.png")
    let rows: [(String, (Int, Int, Int)?)] = [
        ("Kandidat, oben links (hell)", tileSwatch(candidateFile, x: 170, y: 170)),
        ("Kandidat, unten rechts (dunkel)", tileSwatch(candidateFile, x: 850, y: 850)),
    ]
    var swatchY: CGFloat = 250
    for row in rows {
        if let rgb = row.1 {
            sheet.setFillColor(color((rgb.0 << 16) | (rgb.1 << 8) | rgb.2))
        }
        sheet.fill(CGRect(x: 48, y: swatchY, width: 72, height: 36))
        sheet.setStrokeColor(color(0x1F1F1F))
        sheet.stroke(CGRect(x: 48, y: swatchY, width: 72, height: 36))
        let text: String
        if let rgb = row.1 {
            text = String(format: "%@   #%02X%02X%02X", row.0, rgb.0, rgb.1, rgb.2)
        } else {
            text = row.0
        }
        drawLine(text, x: 136, baseline: swatchY + 10, size: 16, hex: 0x1F1F1F, in: sheet)
        swatchY -= 52
    }
    let note = lightIcon
        ? "Gemessen. Der dunkle Satz ist im Projekt. Dieser helle Satz ist nur der Entwurf."
        : "Die Farbfelder sind gemessen, nicht geschätzt."
    drawLine(note, x: 48, baseline: 36, size: 14, hex: 0x1F1F1F, in: sheet)

    guard let image = sheet.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fputs("Beschriftetes Blatt fehlgeschlagen\n", stderr)
        return
    }
    let url = outDir.appendingPathComponent("vergleich-beschriftet.png")
    try? png.write(to: url)
    print("Wrote vergleich-beschriftet.png")
}

comparisonSheet()
labeledSheet()

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for spec in specs {
    let source = outDir.appendingPathComponent(spec.filename)
    let target = iconset.appendingPathComponent(spec.filename)
    try? FileManager.default.removeItem(at: target)
    try? FileManager.default.copyItem(at: source, to: target)
}
let icns = outDir.appendingPathComponent("AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try? task.run()
task.waitUntilExit()
if task.terminationStatus == 0 {
    print("Wrote AppIcon.icns")
}

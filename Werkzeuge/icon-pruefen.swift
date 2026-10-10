#!/usr/bin/env swift
// Vergleicht Werkzeuge/icon-kandidat mit archiv/icon-freigegeben-2026-10-01.
// Abbruch, sobald eine Grenze aus Aufgabe 62 verletzt ist.

import AppKit
import Foundation

let workspace = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let approved = workspace.appendingPathComponent("archiv/icon-freigegeben-2026-10-01/AppIcon.appiconset")
let candidate = workspace.appendingPathComponent("Werkzeuge/icon-kandidat")
let projectIcons = workspace.appendingPathComponent("diskindex/diskindex/Assets.xcassets/AppIcon.appiconset")
let projectDock = workspace.appendingPathComponent("diskindex/diskindex/Assets.xcassets/DockIcon.imageset/DockIcon.png")
let archiveDock = workspace.appendingPathComponent("archiv/icon-freigegeben-2026-10-01/DockIcon.imageset/DockIcon.png")

let names = [
    "icon_16x16.png", "icon_16x16@2x.png", "icon_32x32.png", "icon_32x32@2x.png",
    "icon_128x128.png", "icon_128x128@2x.png", "icon_256x256.png", "icon_256x256@2x.png",
    "icon_512x512.png", "icon_512x512@2x.png",
]

var failed = false
func fail(_ message: String) {
    failed = true
    fputs("FAIL \(message)\n", stderr)
}

/// Pixelgenau über ImageIO — nicht `NSImage.cgImage` (kann je nach AppKit-Zustand
/// andere Rastergröße/Farbverwaltung liefern und den Kachel-Scan verfälschen).
func load(_ url: URL) -> CGImage? {
    let options: CFDictionary = [
        kCGImageSourceShouldCache: true,
        kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, options)
}

func bytes(_ image: CGImage) -> (UnsafePointer<UInt8>, Int, Int, Int, Int)? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }
    let bytesPerRow = width * 4
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
    buffer.initialize(repeating: 0, count: height * bytesPerRow)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else {
        buffer.deallocate()
        return nil
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    // Puffer lebt bis Prozessende (Skript); Zeiger für den Scan freigeben.
    return (UnsafePointer(buffer), width, height, bytesPerRow, 4)
}

func pixel(_ raw: UnsafePointer<UInt8>, _ row: Int, _ step: Int, _ x: Int, _ y: Int) -> (Int, Int, Int, Int) {
    let o = y * row + x * step
    return (Int(raw[o]), Int(raw[o + 1]), Int(raw[o + 2]), Int(raw[o + 3]))
}

func linear(_ channel: Double) -> Double {
    channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
}

func oklab(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
    let R = linear(r), G = linear(g), B = linear(b)
    let l = cbrt(0.4122214708 * R + 0.5363325363 * G + 0.0514459929 * B)
    let m = cbrt(0.2119034982 * R + 0.6806995451 * G + 0.1073969566 * B)
    let s = cbrt(0.0883024619 * R + 0.2817188376 * G + 0.6299787005 * B)
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    )
}

func deltaE(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
    let dl = a.0 - b.0, da = a.1 - b.1, db = a.2 - b.2
    return (dl * dl + da * da + db * db).squareRoot() * 100
}

struct Box {
    var minX: Int
    var maxX: Int
    var minY: Int
    var maxY: Int
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var midX: Double { Double(minX + maxX) / 2 }
    var midY: Double { Double(minY + maxY) / 2 }
}

struct Reading {
    var tile: Box
    var glyph: Box?
    var mean: (Double, Double, Double)
    var radius: Double
    var cornerAlpha: Int
}

func read(_ url: URL) -> Reading? {
    guard let image = load(url), let (raw, width, height, row, step) = bytes(image) else { return nil }
    var tileMinX = width, tileMaxX = 0, tileMinY = height, tileMaxY = 0
    for y in 0..<height {
        for x in 0..<width where pixel(raw, row, step, x, y).3 > 200 {
            tileMinX = min(tileMinX, x)
            tileMaxX = max(tileMaxX, x)
            tileMinY = min(tileMinY, y)
            tileMaxY = max(tileMaxY, y)
        }
    }
    guard tileMaxX >= tileMinX else { return nil }
    let tile = Box(minX: tileMinX, maxX: tileMaxX, minY: tileMinY, maxY: tileMaxY)
    var glyphMinX = width, glyphMaxX = -1, glyphMinY = height, glyphMaxY = -1
    for y in tile.minY...tile.maxY {
        for x in tile.minX...tile.maxX {
            let p = pixel(raw, row, step, x, y)
            guard p.3 > 200, p.0 > 160, p.1 > 160, p.2 > 160 else { continue }
            glyphMinX = min(glyphMinX, x)
            glyphMaxX = max(glyphMaxX, x)
            glyphMinY = min(glyphMinY, y)
            glyphMaxY = max(glyphMaxY, y)
        }
    }
    var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0.0
    let sampleX = min(tile.maxX, tile.minX + max(2, tile.width / 10))
    let sampleY = (tile.minY + tile.maxY) / 2
    for y in (sampleY - 1)...(sampleY + 1) {
        for x in (sampleX - 1)...(sampleX + 1) where y >= 0 && x >= 0 && y < height && x < width {
            let p = pixel(raw, row, step, x, y)
            guard p.3 > 200, p.0 < 160 else { continue }
            sumR += Double(p.0)
            sumG += Double(p.1)
            sumB += Double(p.2)
            count += 1
        }
    }
    if count == 0 { count = 1 }
    var topLeft = tile.maxX
    for x in tile.minX...tile.maxX where pixel(raw, row, step, x, tile.minY).3 > 200 {
        topLeft = min(topLeft, x)
    }
    let glyph = glyphMaxX >= glyphMinX
        ? Box(minX: glyphMinX, maxX: glyphMaxX, minY: glyphMinY, maxY: glyphMaxY)
        : nil
    return Reading(
        tile: tile,
        glyph: glyph,
        mean: (sumR / count, sumG / count, sumB / count),
        radius: Double(topLeft - tile.minX),
        cornerAlpha: pixel(raw, row, step, 0, 0).3
    )
}

for name in names {
    let approvedURL = approved.appendingPathComponent(name)
    let candidateURL = candidate.appendingPathComponent(name)
    guard let left = read(approvedURL), let right = read(candidateURL) else {
        fail("\(name) nicht lesbar")
        continue
    }
    let pixels = load(approvedURL)?.width ?? 0
    guard pixels > 0 else {
        fail("\(name) genehmigte Pixelbreite 0")
        continue
    }
    let ratio = Double(right.tile.width) / Double(pixels)
    if pixels == 1024, abs(ratio - 0.805) > 0.003 {
        fail("\(name) Kachel \(String(format: "%.3f", ratio * 100)) % statt 80,5 ± 0,3")
    }
    let centerSlack = pixels >= 128 ? 0.5 : 1.0
    if abs(right.tile.midX - left.tile.midX) > centerSlack || abs(right.tile.midY - left.tile.midY) > centerSlack {
        fail("\(name) Mittelpunkt \(right.tile.midX),\(right.tile.midY) gegen \(left.tile.midX),\(left.tile.midY)")
    }
    let widthSlack = pixels >= 1024 ? 2.0 : (pixels >= 128 ? 0.5 : 1.0)
    if abs(Double(right.tile.width - left.tile.width)) > widthSlack || abs(Double(right.tile.height - left.tile.height)) > widthSlack {
        fail("\(name) Kachelabmessung \(right.tile.width)x\(right.tile.height) gegen \(left.tile.width)x\(left.tile.height)")
    }
    if pixels == 1024, abs(right.radius - left.radius) > 0.5 {
        fail("\(name) Eckradius \(right.radius) gegen \(left.radius)")
    } else if pixels < 1024, abs(right.radius - left.radius) > max(1, Double(pixels) / 1024 * 2) {
        fail("\(name) Eckradius \(right.radius) gegen \(left.radius)")
    }
    if let approvedGlyph = left.glyph, let candidateGlyph = right.glyph {
        let slack = pixels >= 128 ? 0.5 : 2.0
        let dw = abs(Double(candidateGlyph.width - approvedGlyph.width))
        let dh = abs(Double(candidateGlyph.height - approvedGlyph.height))
        let dx = abs(candidateGlyph.midX - approvedGlyph.midX)
        let dy = abs(candidateGlyph.midY - approvedGlyph.midY)
        if dw > slack || dh > slack || dx > slack || dy > slack {
            fail("\(name) Symbol \(candidateGlyph.width)x\(candidateGlyph.height) gegen \(approvedGlyph.width)x\(approvedGlyph.height)")
        }
    } else if pixels >= 128 {
        fail("\(name) Symbol fehlt")
    }
    let distance = deltaE(
        oklab(right.mean.0 / 255, right.mean.1 / 255, right.mean.2 / 255),
        oklab(left.mean.0 / 255, left.mean.1 / 255, left.mean.2 / 255)
    )
    _ = distance
    if right.cornerAlpha != 0 {
        fail("\(name) Ecke alpha \(right.cornerAlpha)")
    }
    if let candidateImage = load(candidateURL),
       let (candidateRaw, width, height, crow, cstep) = bytes(candidateImage) {
        let margin = 2
        var leaked = false
        for y in 0..<height where !leaked {
            for x in 0..<width {
                let outside = x < left.tile.minX - margin || x > left.tile.maxX + margin
                    || y < left.tile.minY - margin || y > left.tile.maxY + margin
                if outside, pixel(candidateRaw, crow, cstep, x, y).3 > 0 {
                    fail("\(name) Farbe außerhalb der Kachel bei \(x),\(y)")
                    leaked = true
                    break
                }
            }
        }
    }
    print(String(
        format: "%@ Kachel %.1f%% Mitte %.1f/%.1f Radius %.1f ΔE %.2f",
        name,
        ratio * 100,
        right.tile.midX,
        right.tile.midY,
        right.radius,
        deltaE(
            oklab(right.mean.0 / 255, right.mean.1 / 255, right.mean.2 / 255),
            oklab(left.mean.0 / 255, left.mean.1 / 255, left.mean.2 / 255)
        )
    ))
}

let dock = try? Data(contentsOf: candidate.appendingPathComponent("DockIcon.png"))
let icon = try? Data(contentsOf: candidate.appendingPathComponent("icon_512x512@2x.png"))
if dock != icon {
    fail("DockIcon.png ist nicht die 1024er Datei")
}

if let rep = NSBitmapImageRep(data: (try? Data(contentsOf: candidate.appendingPathComponent("icon_512x512@2x.png"))) ?? Data()),
   let raw = rep.bitmapData {
    func sample(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
        return (Int(raw[offset]), Int(raw[offset + 1]), Int(raw[offset + 2]))
    }
    let light = sample(170, 170)
    let dark = sample(850, 850)
    if light.0 < 70 || dark.0 > 48 || light.0 < dark.0 + 30 {
        fail("Verlauf oben links \(light) unten rechts \(dark), erwartet hell #575757 nach dunkel #1F1F1F")
    }
} else {
    fail("1024er Kandidat nicht lesbar")
}

for name in names {
    let project = try? Data(contentsOf: projectIcons.appendingPathComponent(name))
    let chosen = try? Data(contentsOf: candidate.appendingPathComponent(name))
    if project != chosen {
        fail("Projektdatei \(name) ist nicht der gesetzte Kandidat")
    }
}
let projectDockData = try? Data(contentsOf: projectDock)
let chosenDock = try? Data(contentsOf: candidate.appendingPathComponent("DockIcon.png"))
if projectDockData != chosenDock {
    fail("Projekt-DockIcon ist nicht der gesetzte Kandidat")
}

if failed { exit(1) }
print("OK")

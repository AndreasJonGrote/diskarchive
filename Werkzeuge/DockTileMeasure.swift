#!/usr/bin/env swift
// Dock-Kachel gegen einen Nachbarn messen (Aufgabe 60).
// Das Dock muss sichtbar sein. Braucht die Bildschirmaufnahme-Erlaubnis.
// Aufruf: swift Werkzeuge/DockTileMeasure.swift

import AppKit
import CoreGraphics
import Foundation

struct Tile {
    var minX: Int
    var maxX: Int
    var width: Int { maxX - minX + 1 }
}

let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let docks = info.filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" }
guard let dock = docks.max(by: { windowArea($0) < windowArea($1) }),
      let number = dock[kCGWindowNumber as String] as? CGWindowID,
      let image = CGWindowListCreateImage(.null, .optionIncludingWindow, number, [.boundsIgnoreFraming, .bestResolution])
else {
    fputs("Dock-Fenster nicht gefunden. Das Dock muss sichtbar sein.\n", stderr)
    exit(1)
}

let width = image.width
let height = image.height
guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
    fputs("Dock-Bild nicht lesbar.\n", stderr)
    exit(1)
}
let rowBytes = image.bytesPerRow
var columns = [Int](repeating: 0, count: width)
for x in 0..<width {
    var ink = 0
    for y in 0..<height {
        let pixel = bytes + y * rowBytes + x * 4
        let alpha = pixel[3]
        if alpha > 20 { ink += 1 }
    }
    columns[x] = ink
}
let limit = max(4, height / 20)
var tiles: [Tile] = []
var start: Int?
for x in 0..<width {
    if columns[x] > limit {
        if start == nil { start = x }
    } else if let origin = start {
        if x - origin > 8 { tiles.append(Tile(minX: origin, maxX: x - 1)) }
        start = nil
    }
}
if let origin = start, width - origin > 8 {
    tiles.append(Tile(minX: origin, maxX: width - 1))
}
guard tiles.count >= 2 else {
    fputs("Weniger als zwei Kacheln erkannt (\(tiles.count)).\n", stderr)
    exit(1)
}

let own = bestMatch(image: image, bytes: bytes, rowBytes: rowBytes, tiles: tiles)
let neighborIndex = own == 0 ? 1 : own - 1
let ownWidth = tiles[own].width
let neighborWidth = tiles[neighborIndex].width
let ratio = Double(ownWidth) / Double(neighborWidth)
print(String(format: "kachel-disk-index %d px", ownWidth))
print(String(format: "kachel-nachbar %d px (index %d)", neighborWidth, neighborIndex))
print(String(format: "verhältnis %.3f", ratio))
print(String(format: "ziel 1.00 ± 0.03: %@", abs(ratio - 1) <= 0.03 ? "ja" : "nein"))

func windowArea(_ window: [String: Any]) -> CGFloat {
    guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return 0 }
    return (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
}

func bestMatch(image: CGImage, bytes: UnsafePointer<UInt8>, rowBytes: Int, tiles: [Tile]) -> Int {
    guard let icon = NSImage(named: "AppIcon")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            ?? loadBundleIcon() else {
        return tiles.count - 1
    }
    var best = 0
    var bestScore = Int.max
    for (index, tile) in tiles.enumerated() {
        let score = difference(imageBytes: bytes, rowBytes: rowBytes, height: image.height, tile: tile, icon: icon)
        if score < bestScore {
            bestScore = score
            best = index
        }
    }
    return best
}

func loadBundleIcon() -> CGImage? {
    let path = CommandLine.arguments.dropFirst().first
        ?? "/Applications/Disk Index.app/Contents/Resources/AppIcon.icns"
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func difference(imageBytes: UnsafePointer<UInt8>, rowBytes: Int, height: Int, tile: Tile, icon: CGImage) -> Int {
    let sample = 8
    var total = 0
    for y in 0..<sample {
        for x in 0..<sample {
            let imageX = tile.minX + (tile.width * x) / sample
            let imageY = (height * y) / sample
            let pixel = imageBytes + imageY * rowBytes + imageX * 4
            let iconX = (icon.width * x) / sample
            let iconY = (icon.height * y) / sample
            guard let iconPixel = iconColor(icon, x: iconX, y: iconY) else { continue }
            total += abs(Int(pixel[0]) - iconPixel.0) + abs(Int(pixel[1]) - iconPixel.1) + abs(Int(pixel[2]) - iconPixel.2)
        }
    }
    return total
}

func iconColor(_ image: CGImage, x: Int, y: Int) -> (Int, Int, Int)? {
    guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
    let pixel = bytes + y * image.bytesPerRow + x * 4
    return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
}

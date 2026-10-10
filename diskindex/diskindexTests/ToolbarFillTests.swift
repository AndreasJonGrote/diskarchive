//
//  ToolbarFillTests.swift
//  diskindexTests
//
//  Aufgabe 163: Füllung der aktiven Nicht-Home-Icons ist 50 %. Vergleichsbogen für die Auswahl.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@MainActor
@Suite
struct ToolbarFillTests {
    @Test func activeFillIsHalfNotNearlySolid() async {
        let production = await render(
            ToolbarNavIcon(fillAsset: "NavGearFill", strokeAsset: "NavGearStroke", role: .settings, isActive: true),
            scheme: .light,
            size: CGSize(width: 80, height: 80)
        )
        let half = await render(icon(opacity: 0.50), scheme: .light, size: CGSize(width: 80, height: 80))
        let solid = await render(icon(opacity: 0.95), scheme: .light, size: CGSize(width: 80, height: 80))
        #expect(distance(production, half) < distance(production, solid))
    }

    @Test func comparisonSheets() async {
        let folder = URL(fileURLWithPath: "/Users/jon/Projekte/Disk Index/Werkzeuge/screenshots/2026-10-08-163", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sheet = CGSize(width: 520, height: 360)
        let light = await render(IconFillComparison(), scheme: .light, size: sheet)
        let dark = await render(IconFillComparison(), scheme: .dark, size: sheet)
        try? light.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("icons-vergleich-hell.png"))
        try? dark.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("icons-vergleich-dunkel.png"))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("icons-vergleich-hell.png").path))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("icons-vergleich-dunkel.png").path))
    }

    private func icon(opacity: Double) -> some View {
        ComparisonIcon(
            fill: "NavGearFill",
            stroke: "NavGearStroke",
            role: .settings,
            opacity: opacity,
            scale: 1
        )
    }

    private func render<V: View>(_ view: V, scheme: ColorScheme, size: CGSize) async -> NSBitmapImageRep {
        await PixelProbe.render(
            view.environment(\.colorScheme, scheme).frame(width: size.width, height: size.height),
            size: size,
            appearance: scheme == .dark ? .darkAqua : .aqua
        )
    }

    private func distance(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep) -> CGFloat {
        var total: CGFloat = 0
        var y: CGFloat = 8
        while y < 70 {
            var x: CGFloat = 8
            while x < 70 {
                let left = srgb(PixelProbe.color(in: a, at: CGPoint(x: x, y: y)))
                let right = srgb(PixelProbe.color(in: b, at: CGPoint(x: x, y: y)))
                total += abs(left.redComponent - right.redComponent)
                total += abs(left.greenComponent - right.greenComponent)
                total += abs(left.blueComponent - right.blueComponent)
                x += 4
            }
            y += 4
        }
        return total
    }

    private func srgb(_ color: NSColor) -> NSColor {
        color.usingColorSpace(.sRGB) ?? color
    }
}

private struct IconFillComparison: View {
    private let rows: [(String, String, String, ToolbarNavIconRole)] = [
        ("Einstellungen", "NavGearFill", "NavGearStroke", .settings),
        ("Filter", "IconFunnelFill", "IconFunnelStroke", .filter),
        ("Suche", "IconMagnifyingGlassFill", "IconMagnifyingGlassStroke", .search),
        ("Favoriten", "NavBookmarksFill", "NavBookmarksStroke", .favorites),
    ]
    private let fills: [Double] = [0.30, 0.50, 0.70, 0.95]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(" ").frame(width: 110, alignment: .leading)
                ForEach(fills, id: \.self) { value in
                    Text("\(Int(value * 100)) %")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 88)
                }
            }
            ForEach(rows, id: \.0) { row in
                HStack(spacing: 8) {
                    Text(row.0)
                        .font(.system(size: 12))
                        .frame(width: 110, alignment: .leading)
                    ForEach(fills, id: \.self) { value in
                        ComparisonIcon(fill: row.1, stroke: row.2, role: row.3, opacity: value, scale: 4)
                            .frame(width: 88, height: 72)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 520, height: 360, alignment: .topLeading)
        .background(DesignColor.bg)
        .foregroundStyle(DesignColor.text)
    }
}

private struct ComparisonIcon: View {
    let fill: String
    let stroke: String
    let role: ToolbarNavIconRole
    let opacity: Double
    var scale: CGFloat = 4
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = role.activeColor(scheme: colorScheme)
        ZStack {
            Image(fill)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .opacity(opacity)
            Image(stroke)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
        .foregroundStyle(color)
        .frame(width: 17, height: 17)
        .scaleEffect(scale)
        .frame(width: 17 * scale, height: 17 * scale)
    }
}
}

//
//  ToolbarFillTests.swift
//  DiskArchiveTests
//
//  Aufgabe 163: Füllung der aktiven Nicht-Home-Icons ist 50 %.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

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

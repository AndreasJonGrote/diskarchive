//
//  SidebarSpinnerSizeTests.swift
//  DiskArchiveTests
//
//  bug.0.4.217 — Spinner in der Medienspalte (Seitenleiste) 12 × 12 pt mit 2 pt Strich, mittig in der 16er-Icon-Box; die
//  Zeile springt nicht (gleiche Höhe mit und ohne Spinner). Echtes Fenster außerhalb des Bildschirms, Pixel; die gewählte
//  Zeile zeigt ihren Rahmen über die Auswahlfläche. ±0,5 pt, hell und dunkel.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct SidebarSpinnerSizeTests {
    private static let size = CGSize(width: 240, height: 60)

    /// Rahmen der Zeile (Auswahlfläche) und Tinte im Icon-Bereich.
    private static func measure(spinner: Bool, appearance: NSAppearance.Name) async throws -> (row: CGRect, icon: CGRect) {
        let app = AppState()
        let bitmap = await PixelProbe.render(
            ColumnBrowserRow(
                title: "Medium", isSelected: true, iconAsset: MediumType.ssd.iconAssetName,
                showsIndexingSpinner: spinner, onSelect: {}
            )
            .frame(width: 200)
            .padding(.leading, 20).padding(.top, 15)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(DesignColor.bg)
            .environment(app)
            .environment(\.spinnerFrozenAngle, 0)
            .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light),
            size: size, appearance: appearance
        )
        let row = try #require(PixelProbe.inkBounds(in: bitmap, rect: CGRect(origin: .zero, size: size), background: CGPoint(x: 2, y: 2)))
        let iconArea = CGRect(x: row.minX + 2, y: row.minY + 2, width: ColumnBrowserRow.horizontalPadding + ColumnBrowserRow.iconBox + 2, height: row.height - 4)
        let icon = try #require(PixelProbe.inkBounds(in: bitmap, rect: iconArea, background: CGPoint(x: row.minX + 3, y: row.minY + 3)))
        return (row, icon)
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func spinnerIsTwelvePointsCenteredInTheIconBox(appearance: NSAppearance.Name) async throws {
        let spinning = try await Self.measure(spinner: true, appearance: appearance)
        let still = try await Self.measure(spinner: false, appearance: appearance)
        let ink = spinning.icon
        #expect(abs(ink.width - 12) <= 0.5 && abs(ink.height - 12) <= 0.5, "Spinner \(ink.width) × \(ink.height) statt 12 × 12")
        let boxCenter = CGPoint(x: spinning.row.minX + ColumnBrowserRow.horizontalPadding + ColumnBrowserRow.iconBox / 2, y: spinning.row.midY)
        #expect(abs(ink.midX - boxCenter.x) <= 0.5 && abs(ink.midY - boxCenter.y) <= 0.5,
                "Spinner-Mitte \(ink.midX), \(ink.midY) statt \(boxCenter.x), \(boxCenter.y)")
        #expect(abs(spinning.row.height - still.row.height) <= 0.5, "Zeile springt: \(spinning.row.height) mit, \(still.row.height) ohne Spinner")
    }

    /// Strich 2 pt: waagerechter Schnitt durch die Mitte trifft links den Ring auf 2 pt Breite.
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func spinnerStrokeIsTwoPoints(appearance: NSAppearance.Name) async throws {
        let spinning = try await Self.measure(spinner: true, appearance: appearance)
        let ink = spinning.icon
        // Linke Hälfte der Mittelzeile: nur der linke Ringabschnitt.
        let app = AppState()
        let bitmap = await PixelProbe.render(
            ColumnBrowserRow(title: "Medium", isSelected: true, iconAsset: MediumType.ssd.iconAssetName, showsIndexingSpinner: true, onSelect: {})
                .frame(width: 200)
                .padding(.leading, 20).padding(.top, 15)
                .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
                .background(DesignColor.bg)
                .environment(app)
                .environment(\.spinnerFrozenAngle, 0)
                .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light),
            size: Self.size, appearance: appearance
        )
        let band = try #require(PixelProbe.inkBounds(
            in: bitmap, rect: CGRect(x: ink.minX - 1, y: ink.midY - 0.25, width: ink.width / 2, height: 0.5),
            background: CGPoint(x: ink.midX, y: ink.midY), tolerance: 0.3
        ))
        #expect(abs(band.width - 2) <= 0.5, "Strich \(band.width) statt 2")
    }
}
}

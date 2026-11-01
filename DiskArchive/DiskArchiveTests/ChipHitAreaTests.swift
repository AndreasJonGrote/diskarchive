//
//  ChipHitAreaTests.swift
//  DiskArchiveTests
//
//  Aufgabe 189 b — Chip-Klickfläche per Mausereignis.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite
struct ChipHitAreaTests {
    @Test func neutralFilterChipHitsPaddingNotOnlyText() throws {
        var hits = 0
        let session = openChip(
            NeutralFilterChip(title: "Offline", isSelected: false) { hits += 1 }
        )
        defer { session.close() }
        try clickInsidePadding(session: session)
        #expect(hits == 1)
        hits = 0
        try clickOutside(session: session)
        #expect(hits == 0)
    }

    /// bug.0.4.133: Typ-Chip im Filter-Popover ist auf der ganzen Fläche klickbar (Ecke unten links im Innenabstand),
    /// Maße nach Katalog „Chips“ (Höhe 23,5 ± 0,5).
    @Test func filterTypeChipHitsPaddingNotOnlyText() throws {
        var hits = 0
        let session = openChip(
            FilterTypeChipButton(label: "Dokumente", isSelected: false) { hits += 1 }
        )
        defer { session.close() }
        let bitmap = session.bitmap()
        let ink = try #require(PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: 0, y: 0, width: 280, height: 80),
            background: CGPoint(x: 10, y: 10)
        ))
        #expect(abs(ink.height - 23.5) <= 0.5, "Chiphöhe \(ink.height)")
        session.click(at: CGPoint(x: ink.minX + 3, y: ink.maxY - 2))
        #expect(hits == 1, "Klick in den Innenabstand ohne Wirkung")
        hits = 0
        try clickOutside(session: session)
        #expect(hits == 0)
    }

    @Test func favoritesConnectionChipHitsPadding() throws {
        var hits = 0
        let session = openChip(
            FavoritesConnectionChipProbe(title: "Alle", isSelected: false) { hits += 1 }
        )
        defer { session.close() }
        try clickInsidePadding(session: session)
        #expect(hits == 1)
    }

    @Test func ignoredPatternChipRemoveButtonHitsPadding() throws {
        var hits = 0
        let session = openChip(
            IgnoredPatternChip(pattern: "*.tmp") { hits += 1 }
                .frame(maxWidth: 220, alignment: .leading)
        )
        defer { session.close() }
        let point = try #require(removeButtonPaddingPoint(in: session.window))
        session.click(at: point)
        #expect(hits == 1)
    }

    @Test func binaryButtonGroupUnselectedSegmentHitsPadding() throws {
        var selection = BinaryButtonGroupSelection.none
        let session = openChip(
            BinaryButtonGroup(firstTitle: "Ja", secondTitle: "Nein", selection: Binding(
                get: { selection },
                set: { selection = $0 }
            ))
            .frame(width: 200, alignment: .leading)
        )
        defer { session.close() }
        let bitmap = session.bitmap()
        let ink = try #require(PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: 0, y: 0, width: 200, height: 80),
            background: CGPoint(x: 10, y: 10)
        ))
        session.click(at: CGPoint(x: ink.maxX - 8, y: ink.maxY - 4))
        #expect(selection == .second)
    }

    @Test func designCheckboxLabelHitsPadding() throws {
        var isOn = false
        let session = openChip(
            Toggle("Mitteilungen aktivieren", isOn: Binding(get: { isOn }, set: { isOn = $0 }))
                .toggleStyle(DesignCheckbox())
        )
        defer { session.close() }
        let bitmap = session.bitmap()
        let ink = try #require(PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: 0, y: 0, width: 280, height: 80),
            background: CGPoint(x: 10, y: 10)
        ))
        session.click(at: CGPoint(x: ink.minX + 4, y: ink.maxY - 4))
        #expect(isOn)
    }

    private func openChip<V: View>(_ view: V) -> PixelProbe.Session {
        PixelProbe.open(
            view
                .padding(20)
                .frame(width: 280, height: 80, alignment: .topLeading),
            size: CGSize(width: 280, height: 80),
            appearance: .aqua
        )
    }

    private func clickInsidePadding(session: PixelProbe.Session) throws {
        let bitmap = session.bitmap()
        let ink = try #require(PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: 0, y: 0, width: 280, height: 80),
            background: CGPoint(x: 10, y: 10)
        ))
        session.click(at: CGPoint(x: ink.minX + 4, y: ink.maxY - 4))
    }

    private func removeButtonPaddingPoint(in window: NSWindow) -> CGPoint? {
        guard let root = window.contentView else { return nil }
        let height = root.bounds.height
        func walk(_ view: NSView) -> CGRect? {
            for child in view.subviews {
                let frame = child.convert(child.bounds, to: nil)
                if abs(frame.width - 10) <= 1.5, abs(frame.height - 10) <= 1.5 {
                    return frame
                }
                if let found = walk(child) { return found }
            }
            return nil
        }
        guard let frame = walk(root) else { return nil }
        return CGPoint(x: frame.minX + 3, y: height - frame.maxY + frame.height - 3)
    }

    private func clickOutside(session: PixelProbe.Session) throws {
        let bitmap = session.bitmap()
        let ink = try #require(PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: 0, y: 0, width: 280, height: 80),
            background: CGPoint(x: 10, y: 10)
        ))
        session.click(at: CGPoint(x: ink.maxX + 8, y: ink.midY))
    }
}

private struct FavoritesConnectionChipProbe: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .frame(minHeight: 23.5)
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .background(Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(DesignColor.neutral500, lineWidth: DesignBorder.width)
                }
        }
        .buttonStyle(.plainFullHit)
    }
}
}

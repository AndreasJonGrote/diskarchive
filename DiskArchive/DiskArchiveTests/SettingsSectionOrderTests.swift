//
//  SettingsSectionOrderTests.swift
//  DiskArchiveTests
//
//  Aufgabe 191 d — Abschnittsreihenfolge: je Titel Referenzbreite (isolierter Titel) + Y-Lage im Tab.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite @MainActor
struct SettingsSectionOrderTests {
    private static let generalTitles = [
        LayoutCopy.languageTitle,
        LayoutCopy.appearanceTitle,
        LayoutCopy.noticesTitle,
    ]

    private static let advancedTitles = [
        LayoutCopy.autostartTitle,
        LayoutCopy.reportsTitle,
        LayoutCopy.pruneTitle,
        LayoutCopy.defaultsTitle,
        LayoutCopy.mediaTitle,
    ]

    @Test func generalTabSectionOrderMatchesSpec() throws {
        let app = AppState()
        let session = openTab(section: .general, app: app)
        defer { session.close() }
        try assertTitlesAppearInOrder(Self.generalTitles, in: session.bitmap())
    }

    @Test func advancedTabSectionOrderMatchesSpec() throws {
        let app = AppState()
        let session = openTab(section: .advanced, app: app)
        defer { session.close() }
        try assertTitlesAppearInOrder(Self.advancedTitles, in: session.bitmap())
    }

    /// Sabotage: falsche Titelfolge (Erscheinung vor Sprache) scheitert an der Y-Reihenfolge.
    @Test func sabotageSwappedTitleSequenceFails() throws {
        let app = AppState()
        let session = openTab(section: .general, app: app)
        defer { session.close() }
        let wrong = [
            LayoutCopy.appearanceTitle,
            LayoutCopy.languageTitle,
            LayoutCopy.noticesTitle,
        ]
        #expect(titlesMatchSequentialOrder(wrong, in: session.bitmap()) == nil)
    }

    private func openTab(section: SettingsGeneralTab.Section, app: AppState) -> PixelProbe.Session {
        let session = PixelProbe.open(
            SettingsGeneralTab(section: section)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: 860, height: 900, alignment: .top)
                .background(Color.white),
            size: CGSize(width: 860, height: 900),
            appearance: .aqua
        )
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        Thread.sleep(forTimeInterval: 0.15)
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        return session
    }

    private struct HeaderInk {
        let width: CGFloat
        let height: CGFloat
    }

    @discardableResult
    private func assertTitlesAppearInOrder(_ titles: [String], in bitmap: NSBitmapImageRep) throws -> CGFloat {
        let endY = try #require(titlesMatchSequentialOrder(titles, in: bitmap))
        return endY
    }

    private func titlesMatchSequentialOrder(_ titles: [String], in bitmap: NSBitmapImageRep) -> CGFloat? {
        var below: CGFloat = -1
        for title in titles {
            guard let ref = referenceHeaderInk(for: title) else { return nil }
            guard let y = scanNextHeader(ref: ref, in: bitmap, below: below) else { return nil }
            below = y
        }
        return below
    }

    private func scanNextHeader(ref: HeaderInk, in bitmap: NSBitmapImageRep, below: CGFloat) -> CGFloat? {
        let limit = bitmap.size.height - 8
        guard below < limit else { return nil }
        var y = max(8, below + 1)
        while y < limit {
            let backgroundY = min(y + 12, limit - 1)
            let background = CGPoint(x: 780, y: backgroundY)
            guard let ink = PixelProbe.inkBounds(
                in: bitmap,
                rect: CGRect(x: 36, y: y, width: 320, height: 16),
                background: background
            ) else {
                y += 3
                continue
            }
            let widthOK = abs(ink.width - ref.width) <= max(12, ref.width * 0.22)
            let heightOK = abs(ink.height - ref.height) <= 3
            if ink.height >= 4, ink.height <= 18, widthOK, heightOK {
                return ink.minY
            }
            y += 3
        }
        return nil
    }

    /// Titel-Tinte aus isoliert gerendertem `SettingsSectionTitle` (PixelProbe).
    private func referenceHeaderInk(for title: String) -> HeaderInk? {
        let session = PixelProbe.open(
            ZStack(alignment: .topLeading) {
                Color.white
                SettingsSectionTitle(title: title).padding(24)
            }
            .environment(\.colorScheme, .light)
            .frame(width: 420, height: 56),
            size: CGSize(width: 420, height: 56),
            appearance: .aqua
        )
        defer { session.close() }
        let refBitmap = session.bitmap()
        if let ink = PixelProbe.inkBounds(
            in: refBitmap,
            rect: CGRect(x: 0, y: 0, width: 420, height: 56),
            background: CGPoint(x: 400, y: 48)
        ) {
            return HeaderInk(width: ink.width, height: ink.height)
        }
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: 0.6]
        let width = ceil((title as NSString).size(withAttributes: attrs).width)
        return HeaderInk(width: width, height: 12)
    }
}
}

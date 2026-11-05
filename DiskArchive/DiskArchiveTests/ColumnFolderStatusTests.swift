//
//  ColumnFolderStatusTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.016 (Layout 07.02.03–08, 07.03.02): Zustände der Spaltenansicht – je Zustand Titel, Text, Icon und Link;
//  gelbe bzw. rote Glyphe im Bild; Medium-Suche ohne Treffer.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct ColumnFolderStatusTests {
    @Test func eachStateHasItsTitleIconAndLink() {
        L10n.$languageOverride.withValue(.german) {
            let indexing = ColumnFolderStatus.indexing
            #expect(indexing.title == "Wird indiziert")
            #expect(indexing.icon == .spinner(online: true))
            #expect(indexing.link == nil)

            let loading = ColumnFolderStatus.loading
            #expect(loading.title == "Inhalte werden geladen")
            #expect(loading.icon == .spinner(online: false))
            #expect(loading.link == nil)
            #expect(LayoutCopy.folderLoadingProgress(loaded: 12_480, total: 41_902) == "12.480 von 41.902 Objekten geladen")

            let depth = ColumnFolderStatus(.scanDepth)
            #expect(depth.title == "Inhalt nicht erfasst")
            #expect(depth.message == "Der Inhalt dieses Ordners wird wegen der Scan-Tiefe nicht indiziert.")
            #expect(depth.icon == .glyph(asset: "IconFolderDuotone", red: false))
            #expect(depth.link?.title == "Scan-Tiefe ändern")
            #expect(depth.link?.target == .scanDepth)

            let excluded = ColumnFolderStatus(.excluded)
            #expect(excluded.title == "Ordner ausgeschlossen")
            #expect(excluded.message == "Dieser Ordner wurde ausgeschlossen. Sein Inhalt wird daher nicht indiziert.")
            #expect(excluded.icon == .glyph(asset: "IconEyeSlash", red: false))
            #expect(excluded.link?.title == "Einstellungen öffnen")
            #expect(excluded.link?.target == .filesSettings)

            let unreadable = ColumnFolderStatus(.unreadable)
            #expect(unreadable.title == "Ordner nicht lesbar")
            #expect(unreadable.message == "Der Inhalt dieses Ordners konnte beim Indizieren nicht gelesen werden.")
            #expect(unreadable.icon == .glyph(asset: "IconWarningBold", red: true))
            #expect(unreadable.link == nil, "nicht lesbar ohne Link")

            #expect(LayoutCopy.columnFilterNoMatchesTitle == "Keine passenden Objekte")
            #expect(LayoutCopy.columnFilterReset == "Alle Filter zurücksetzen")
            #expect(LayoutCopy.columnMediaSearchNoResults == "Kein Speichermedium mit diesem Namen bekannt")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(ColumnFolderStatus(.excluded).link?.title == "Open Settings")
            #expect(LayoutCopy.columnFilterReset == "Reset All Filters")
        }
    }

    /// Gelbe Glyphe bei Scan-Tiefe und „ausgeschlossen“, rote bei „nicht lesbar“ (Layout `#EDA12D` / `#E04830`).
    @Test func glyphColorsFollowTheLayout() async throws {
        let app = AppState()
        for (reason, red) in [(ColumnFolderUncapturedReason.scanDepth, false), (.excluded, false), (.unreadable, true)] {
            let size = CGSize(width: 280, height: 140)
            let bitmap = await PixelProbe.render(
                FolderUncapturedColumnHint(reason: reason).environment(app).background(Color.white),
                size: size
            )
            // Kräftigster Farbton im Icon-Kasten (Kantenglättung mischt Weiß hinein).
            var best: NSColor?
            var y: CGFloat = 2
            while y < 40 {
                var x: CGFloat = 2
                while x < 40 {
                    let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                    if sample.redComponent - sample.blueComponent > (best.map { $0.redComponent - $0.blueComponent } ?? 0.2) {
                        best = sample
                    }
                    x += 0.5
                }
                y += 0.5
            }
            let found: Bool = {
                guard let best else { return false }
                // Farbton statt exakter Werte: die dünnen Striche erreichen nie volle Deckung (rund 20 % Weiß).
                let ratio = best.greenComponent / max(best.redComponent, 0.01)
                return red
                    ? ratio < 0.55 && best.blueComponent < 0.4
                    : ratio > 0.6 && ratio < 0.85 && best.blueComponent < 0.45
            }()
            #expect(found, "\(reason): Glyphe nicht \(red ? "rot" : "gelb"): \(String(describing: best))")
        }
    }
}

//
//  MenuBarPopoverLayout.swift
//  DiskArchive
//
//  Feste Popover-Maße (Mockup Screen 03) — keine AppKit-Messung.
//

import Foundation
import SwiftUI

enum MenuBarPopoverLayout {
    static let panelWidth: CGFloat = 340
    static let panelHorizontalInset: CGFloat = 16
    /// Listenblock Ruhe: Mockup `padding: 12px 12px 8px` (horizontal `--space-3`).
    static let idleContentHorizontalInset: CGFloat = 12
    /// Wie Mockup: `color-mix(text 7%)` — Automatisches Indizieren + Aktions-Fuß.
    static var footerBandBackground: Color { DesignColor.text.opacity(0.07) }

    static let headerHeight: CGFloat = 50
    static let contentTopPadding: CGFloat = 12
    static let contentBottomPadding: CGFloat = 8
    static let sectionLabelHeight: CGFloat = 24
    static let rowHeightStandard: CGFloat = 56
    static let footerAutoIndexHeight: CGFloat = 48
    static let footerOpenAppVerticalPadding: CGFloat = 12
    /// `SecondaryButtonStyle(compactFooter:)`: 12 pt Semibold (~16 pt Zeile) + 4×12 pt.
    static let footerOpenAppButtonHeight: CGFloat = 26
    static var footerOpenAppHeight: CGFloat {
        footerOpenAppVerticalPadding * 2 + footerOpenAppButtonHeight
    }
    static let panelMaxHeight: CGFloat = 480
    static let panelMinHeight: CGFloat = 130

    static let pauseMenuWidth: CGFloat = 210
    /// Layout: Pfeil `right: 24px` am Pause-Menü — Spitze auf Schaltermitte.
    static let pauseMenuArrowInsetFromTrailing: CGFloat = 24
    static let pauseMenuGapBelowToggle: CGFloat = 4
    static let pauseMenuArrowRise: CGFloat = 6
    /// Kopfzeile im Pausentimer-Fenster für die sichtbare Nase (11 pt gedreht ≈ 8 pt).
    static let pauseMenuArrowHeadroom: CGFloat = 8
    /// Inkl. 5 pt Container-Padding (Mockup Screen 03).
    static let pauseMenuHeightWhenChoosing: CGFloat = 184
    static let pauseMenuHeightWhenPaused: CGFloat = 244
    static let pauseMenuContainerPadding: CGFloat = 5

    static func pauseMenuHeight(paused: Bool) -> CGFloat {
        paused ? pauseMenuHeightWhenPaused : pauseMenuHeightWhenChoosing
    }

    // Suchzustand (3b) — Mockup `padding: var(--space-4)`, Gruppen-`gap: var(--space-3)`.
    static let searchVerticalPadding: CGFloat = 16
    static let searchHorizontalPadding: CGFloat = 16
    static let searchSectionLabelBottomMargin: CGFloat = 6
    /// Zeilen-`minHeight` (Mockup ~28 pt Inhalt).
    static let searchRowMinHeight: CGFloat = 28
    static let searchRowVerticalPadding: CGFloat = 5
    /// Wie `PopoverSearchResultRow`: minHeight + vertikales Padding.
    static var searchRowBlockHeight: CGFloat { searchRowMinHeight + searchRowVerticalPadding * 2 }
    static let searchSectionGap: CGFloat = 12
    static let searchInnerGroupSpacing: CGFloat = 6
    static let searchRowHoverHorizontalOutset: CGFloat = 6

    static func rowHeight(for medium: Medium) -> CGFloat {
        rowHeightStandard
    }

    static let emptyStateHeight: CGFloat = 36

    static func idleRowsHeight(media: [Medium]) -> CGFloat {
        if media.isEmpty { return emptyStateHeight }
        return media.reduce(0) { $0 + rowHeight(for: $1) }
    }

    static func idleFullHeight(media: [Medium]) -> CGFloat {
        // todo.0.4.3.014 (Layout 03.09/03.10): ohne angeschlossene Medien die Fläche statt Überschrift und Liste.
        if media.isEmpty {
            return headerHeight + searchStateHeight + footerAutoIndexHeight + footerOpenAppHeight
        }
        return headerHeight
            + contentTopPadding
            + sectionLabelHeight
            + idleRowsHeight(media: media)
            + contentBottomPadding
            + footerAutoIndexHeight
            + footerOpenAppHeight
    }

    /// todo.0.4.3.014 (Layout 03.03/03.04): Mindesthöhe der Fläche „Suche läuft“ / „Keine Suchergebnisse“.
    static let searchStateHeight: CGFloat = 180

    static func searchContentHeight(groups: [PopoverSearchGroup], phase: PopoverSearchPhase = .settled) -> CGFloat {
        guard !groups.isEmpty, phase != .hint else {
            return searchStateHeight
        }

        var height = searchVerticalPadding * 2
        for (index, group) in groups.enumerated() {
            height += searchSectionLabelBlockHeight
            let hitCount = group.hits.count
            height += CGFloat(hitCount) * searchRowBlockHeight
            if hitCount > 1 {
                height += CGFloat(hitCount - 1) * searchInnerGroupSpacing
            }
            if index < groups.count - 1 {
                height += searchSectionGap
            }
        }
        return height
    }

    /// Kategorie-Label (10 pt ≈ 12 pt Zeile) + `margin-bottom: 6px` + Abstand zur ersten Zeile (`searchInnerGroupSpacing`).
    static var searchSectionLabelBlockHeight: CGFloat {
        searchSectionLabelLineHeight + searchSectionLabelBottomMargin + searchInnerGroupSpacing
    }

    static let searchSectionLabelLineHeight: CGFloat = 12

    static func searchActionFooterHeight(totalCount: Int) -> CGFloat {
        totalCount > 0 ? footerOpenAppHeight : 0
    }

    static func searchFullHeight(groups: [PopoverSearchGroup], totalCount: Int, phase: PopoverSearchPhase = .settled) -> CGFloat {
        headerHeight
            + searchContentHeight(groups: groups, phase: phase)
            + searchActionFooterHeight(totalCount: totalCount)
    }

    static func corePanelHeight(appState: AppState) -> CGFloat {
        let searching = !appState.popoverSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let raw = searching
            ? searchFullHeight(
                groups: appState.popoverResults.groups,
                totalCount: appState.popoverSearchPhase == .hint ? 0 : appState.popoverResults.totalCount,
                phase: appState.popoverSearchPhase
            )
            : idleFullHeight(media: appState.popoverConnectedMedia)
        if searching {
            return min(raw, panelMaxHeight)
        }
        return min(max(raw, panelMinHeight), panelMaxHeight)
    }

    /// Panel-Höhe = Einstiegskachel allein; Pausentimer ist eigenes Fenster (Aufgabe 87).
    static func panelHeight(appState: AppState) -> CGFloat {
        corePanelHeight(appState: appState)
    }

    static func idleScrollAreaHeight(media: [Medium]) -> CGFloat? {
        let raw = idleFullHeight(media: media)
        guard raw > panelMaxHeight else { return nil }
        let fixed = headerHeight
            + contentTopPadding
            + sectionLabelHeight
            + contentBottomPadding
            + footerAutoIndexHeight
            + footerOpenAppHeight
        return panelMaxHeight - fixed
    }

    static func searchScrollAreaHeight(groups: [PopoverSearchGroup], totalCount: Int) -> CGFloat? {
        let raw = searchFullHeight(groups: groups, totalCount: totalCount)
        guard raw > panelMaxHeight else { return nil }
        let fixed = headerHeight + searchActionFooterHeight(totalCount: totalCount)
        return panelMaxHeight - fixed
    }
}

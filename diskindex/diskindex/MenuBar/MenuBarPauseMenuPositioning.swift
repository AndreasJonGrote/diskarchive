//
//  MenuBarPauseMenuPositioning.swift
//  diskindex
//
//  Bildschirm-Position des Pausentimer-Fensters (Aufgabe 87/88).
//

import CoreGraphics
import Foundation

enum MenuBarPauseMenuPositioning {
    struct Input: Equatable {
        var dropdownMaxX: CGFloat
        var toggleMidX: CGFloat
        var toggleMinX: CGFloat
        var toggleMaxX: CGFloat
        var toggleBottomY: CGFloat
        var toggleTopY: CGFloat
        var menuContentHeight: CGFloat
        var visibleMinY: CGFloat
        var visibleMaxY: CGFloat
        var trailingInset: CGFloat
        var gapBelowToggle: CGFloat
        var arrowRise: CGFloat
        var margin: CGFloat = 8
    }

    struct Result: Equatable {
        var origin: CGPoint
        var opensAbove: Bool
        var windowSize: CGSize
        /// Nasenspitze (Bildschirm, y nach oben).
        var arrowTip: CGPoint
    }

    static var arrowHeadroom: CGFloat { MenuBarPopoverLayout.pauseMenuArrowHeadroom }

    static func menuContentHeight(paused: Bool) -> CGFloat {
        MenuBarPopoverLayout.pauseMenuHeight(paused: paused)
    }

    static func windowSize(paused: Bool) -> CGSize {
        CGSize(
            width: MenuBarPopoverLayout.pauseMenuWidth,
            height: menuContentHeight(paused: paused) + arrowHeadroom
        )
    }

    /// Menü-Oberkante bleibt unter dem Schalter (+6 pt); Fenster inkl. Kopfzeile für die Nase.
    static func layout(for input: Input) -> Result {
        let menuWidth = MenuBarPopoverLayout.pauseMenuWidth
        let contentH = input.menuContentHeight
        let windowH = contentH + arrowHeadroom

        // Mockup 03: Pause-Menü rechts bündig mit An/Pausiert (wie `right: 16px` = Schalter-Trailing).
        let originX = input.toggleMaxX - menuWidth

        let menuContentTopY = input.toggleBottomY - input.gapBelowToggle - input.arrowRise
        let belowOriginY = menuContentTopY - contentH

        if belowOriginY >= input.visibleMinY + input.margin {
            let origin = CGPoint(x: originX, y: belowOriginY)
            let tip = arrowTip(
                origin: origin,
                windowWidth: menuWidth,
                windowHeight: windowH,
                opensAbove: false
            )
            return Result(
                origin: origin,
                opensAbove: false,
                windowSize: CGSize(width: menuWidth, height: windowH),
                arrowTip: tip
            )
        }

        // Fensterunterkante = Kopfzeile für nach-unten zeigende Nase; Spitze ≈ Schalter-Oberkante.
        let aboveOriginY = input.toggleTopY - 1
        let clampedY = min(
            aboveOriginY,
            input.visibleMaxY - input.margin - windowH
        )
        let originY = max(input.visibleMinY + input.margin, clampedY)
        let origin = CGPoint(x: originX, y: originY)
        let tip = arrowTip(
            origin: origin,
            windowWidth: menuWidth,
            windowHeight: windowH,
            opensAbove: true
        )
        return Result(
            origin: origin,
            opensAbove: true,
            windowSize: CGSize(width: menuWidth, height: windowH),
            arrowTip: tip
        )
    }

    /// Spitze der nach oben zeigenden Nase (Menü unter dem Schalter).
    private static func arrowTip(
        origin: CGPoint,
        windowWidth: CGFloat,
        windowHeight: CGFloat,
        opensAbove: Bool
    ) -> CGPoint {
        let arrowCenterX = origin.x + windowWidth - MenuBarPopoverLayout.pauseMenuArrowInsetFromTrailing
        if opensAbove {
            return CGPoint(x: arrowCenterX, y: origin.y + 1)
        }
        return CGPoint(x: arrowCenterX, y: origin.y + windowHeight - 1)
    }

}

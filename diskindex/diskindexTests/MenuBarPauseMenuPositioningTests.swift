//
//  MenuBarPauseMenuPositioningTests.swift
//  diskindexTests
//

import CoreGraphics
import Testing
@testable import diskindex

@Suite struct MenuBarPauseMenuPositioningTests {
    /// Prüf-Prädikat: Pfeilspitze sitzt auf dem Schalter (zuvor in der App, nur von Tests benutzt).
    private func arrowTipAlignsWithToggle(
        _ result: MenuBarPauseMenuPositioning.Result,
        input: MenuBarPauseMenuPositioning.Input
    ) -> Bool {
        let tip = result.arrowTip
        guard tip.x >= input.toggleMinX - 1, tip.x <= input.toggleMaxX + 1 else { return false }
        if result.opensAbove {
            return abs(tip.y - input.toggleTopY) <= 2
        }
        // Menü-Oberkante bleibt bei gap+arrowRise unter dem Schalter; Spitze sitzt oben im Headroom.
        let maxBelow = input.gapBelowToggle + input.arrowRise - MenuBarPauseMenuPositioning.arrowHeadroom + 1
        return tip.y >= input.toggleBottomY - maxBelow && tip.y <= input.toggleBottomY + 2
    }

    private func sampleInput(
        toggleBottomY: CGFloat,
        toggleTopY: CGFloat,
        visibleMinY: CGFloat = 0,
        visibleMaxY: CGFloat = 900
    ) -> MenuBarPauseMenuPositioning.Input {
        MenuBarPauseMenuPositioning.Input(
            dropdownMaxX: 500,
            toggleMidX: 460,
            toggleMinX: 420,
            toggleMaxX: 500,
            toggleBottomY: toggleBottomY,
            toggleTopY: toggleTopY,
            menuContentHeight: MenuBarPauseMenuPositioning.menuContentHeight(paused: false),
            visibleMinY: visibleMinY,
            visibleMaxY: visibleMaxY,
            trailingInset: 16,
            gapBelowToggle: 4,
            arrowRise: 6
        )
    }

    @Test func windowHeightIncludesArrowHeadroom() {
        let window = MenuBarPauseMenuPositioning.windowSize(paused: false)
        let content = MenuBarPauseMenuPositioning.menuContentHeight(paused: false)
        #expect(window.height == content + MenuBarPauseMenuPositioning.arrowHeadroom)
        #expect(window.width == MenuBarPopoverLayout.pauseMenuWidth)
    }

    @Test func menuOpensBelowToggleByDefault() {
        let input = sampleInput(toggleBottomY: 400, toggleTopY: 428)
        let result = MenuBarPauseMenuPositioning.layout(for: input)
        let contentH = input.menuContentHeight

        #expect(!result.opensAbove)
        #expect(result.windowSize.height == contentH + MenuBarPauseMenuPositioning.arrowHeadroom)
        #expect(result.origin.x == input.toggleMaxX - MenuBarPopoverLayout.pauseMenuWidth)
        #expect(result.origin.x + MenuBarPopoverLayout.pauseMenuWidth == input.toggleMaxX)
        #expect(result.origin.y == 400 - 4 - 6 - contentH)
        #expect(arrowTipAlignsWithToggle(result, input: input))
    }

    @Test func menuFlipsAboveWhenNoRoomBelow() {
        let input = sampleInput(toggleBottomY: 40, toggleTopY: 68)
        let contentH = input.menuContentHeight
        #expect(contentH == MenuBarPopoverLayout.pauseMenuHeightWhenChoosing)

        let belowOriginY = input.toggleBottomY - input.gapBelowToggle - input.arrowRise - contentH
        #expect(belowOriginY < input.visibleMinY + input.margin)

        let result = MenuBarPauseMenuPositioning.layout(for: input)

        #expect(result.opensAbove)
        #expect(result.origin.y == input.toggleTopY - 1)
        #expect(arrowTipAlignsWithToggle(result, input: input))
    }
}

//
//  Task86Tests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite struct Task86Tests {
    @Test func combineButtonVisibility() {
        var filters = SearchFilters()
        #expect(!filters.isCombineButtonVisible(hasSearchTerm: false))

        filters.fileTypes = [.pdf]
        #expect(!filters.isCombineButtonVisible(hasSearchTerm: false))

        filters.age = .lastYear
        #expect(filters.isCombineButtonVisible(hasSearchTerm: false))

        filters.combineWithAnd = true
        filters.clampCombineWithAnd(hasSearchTerm: true)
        #expect(!filters.combineWithAnd)

        filters.combineWithAnd = true
        filters.fileTypes.insert(.folder)
        filters.clampCombineWithAnd(hasSearchTerm: false)
        #expect(!filters.combineWithAnd)
    }

    @Test func pauseNoticeCopy() {
        let now = Date(timeIntervalSince1970: 0)
        let until = now.addingTimeInterval(3_600)
        #expect(PauseNoticeCopy.began(until: nil, now: now) == LayoutCopy.noticePauseForever)
        let timed = PauseNoticeCopy.began(until: until, now: now)
        #expect(timed.hasPrefix("Indizierung pausiert bis "))
        #expect(timed.hasSuffix(" Uhr."))
    }

    @Test func dropdownReopenGuard() {
        let now = Date(timeIntervalSince1970: 100)
        let closed = now.addingTimeInterval(-0.1)
        #expect(MenuBarDropdownLogic.shouldSuppressReopen(afterClose: closed, now: now))
        #expect(!MenuBarDropdownLogic.shouldSuppressReopen(afterClose: closed.addingTimeInterval(-1), now: now))
    }

    @Test func pausiertSegmentTogglesPauseMenu() {
        #expect(MenuBarPauseToggleLogic.toggledMenuOpen(false))
        #expect(!MenuBarPauseToggleLogic.toggledMenuOpen(true))
    }

    @Test func popoverClickDoesNotClosePauseMenuOnToggle() {
        #expect(!MenuBarPauseToggleLogic.shouldCloseMenuOnPopoverClick(menuOpen: true, clickOnPauseToggle: true))
        #expect(MenuBarPauseToggleLogic.shouldCloseMenuOnPopoverClick(menuOpen: true, clickOnPauseToggle: false))
        #expect(!MenuBarPauseToggleLogic.shouldCloseMenuOnPopoverClick(menuOpen: false, clickOnPauseToggle: false))
    }

    @Test func resumeSkipsNoticeWhenAlreadyActive() {
        var pause = GlobalPause()
        pause.resume()
        #expect(!pause.isPaused)
        pause.resume()
        #expect(!pause.isPaused)
    }
}

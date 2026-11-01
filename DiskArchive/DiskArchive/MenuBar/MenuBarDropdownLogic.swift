//
//  MenuBarDropdownLogic.swift
//  DiskArchive
//

import AppKit
import Foundation

nonisolated enum MenuBarDropdownLogic {
    static let reopenSuppressInterval: TimeInterval = 0.25

    static func shouldSuppressReopen(afterClose closedAt: Date?, now: Date) -> Bool {
        guard let closedAt else { return false }
        return now.timeIntervalSince(closedAt) < reopenSuppressInterval
    }

    static func isClickOnStatusItem(eventWindow: NSWindow?, buttonWindow: NSWindow?) -> Bool {
        guard let eventWindow, let buttonWindow else { return false }
        return eventWindow === buttonWindow
    }
}

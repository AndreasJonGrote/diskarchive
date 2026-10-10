//
//  AppNotifications.swift
//  diskindex
//

import Foundation

extension Notification.Name {
    static let menuBarPopoverLayoutInvalidated = Notification.Name("diskindex.menuBarPopoverLayoutInvalidated")
    /// `userInfo["frame"]` = `CGRect` — Toggle „An|Pausiert“ in Koordinaten des Popover-Hosting-Views (SwiftUI, oben links).
    static let menuBarPauseToggleFrameInHosting = Notification.Name("diskindex.menuBarPauseToggleFrameInHosting")
}

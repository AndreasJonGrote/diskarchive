//
//  MenuBarPauseToggleLogic.swift
//  DiskArchive
//
//  Pausentimer per „Pausiert“-Segment toggeln (An bleibt unverändert bis Dauer gewählt).
//

import Foundation

enum MenuBarPauseToggleLogic {
    static func toggledMenuOpen(_ menuOpen: Bool) -> Bool {
        !menuOpen
    }

    /// Außenklick im Popover: Pause-Menü schließen, Klicks auf An/Pausiert ausnehmen (Segment toggelt selbst).
    static func shouldCloseMenuOnPopoverClick(menuOpen: Bool, clickOnPauseToggle: Bool) -> Bool {
        menuOpen && !clickOnPauseToggle
    }
}

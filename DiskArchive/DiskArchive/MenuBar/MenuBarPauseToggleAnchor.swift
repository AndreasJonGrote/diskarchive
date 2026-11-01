//
//  MenuBarPauseToggleAnchor.swift
//  DiskArchive
//
//  Anker für Pause-Untermenü — wie FilterButtonAnchorKey am Filter-Popover.
//

import SwiftUI

struct PauseToggleAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

//
//  HardDrivesTemplateIcon.swift
//  diskindex
//
//  Template-NSImage für das Menüleisten-Icon (Asset-Catalog-SVG, isTemplate = true).
//

import AppKit
import SwiftUI

enum HardDrivesTemplateIcon {
    private struct SizeKey: Hashable {
        let w: CGFloat
        let h: CGFloat
    }

    private static var cached: [SizeKey: NSImage] = [:]

    static func make(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let key = SizeKey(w: size.width, h: size.height)
        if let cached = cached[key] { return cached }

        guard let original = NSImage(named: "MenuBarHardDrives") else {
            return NSImage(size: size)
        }

        let image = NSImage(size: size)
        image.lockFocus()
        original.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: original.size),
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = true
        cached[key] = image
        return image
    }
}

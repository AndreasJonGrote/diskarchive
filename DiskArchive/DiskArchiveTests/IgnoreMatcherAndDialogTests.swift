//
//  IgnoreMatcherAndDialogTests.swift
//  DiskArchiveTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

@Test @MainActor func newMediumDialogRendersAsCard() throws {
    let medium = Medium(
        id: UUID(),
        name: "Neues Medium",
        type: .usb,
        connectionStatus: .connected,
        indexStatus: .pending,
        allowIndexing: true,
        autoIndexPaused: false,
        capacityTotalBytes: 64_000_000_000,
        capacityUsedBytes: 0,
        fileCount: 0,
        folderCount: 0,
        lastSeenAt: Date(),
        firstIndexedAt: nil,
        lastIndexedAt: nil,
        isForgotten: false,
        indexingProgress: 0
    )
    let renderer = ImageRenderer(
        content: NewMediumDetectedDialog(medium: medium)
            .environment(AppState())
    )
    renderer.scale = 2
    let image = try #require(renderer.nsImage)
    #expect(abs(image.size.width - 300) < 2)
    let url = URL(fileURLWithPath: "/tmp/diskarchive-new-medium-dialog.png")
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        return
    }
    try png.write(to: url)
}

@Test(arguments: [
    ("file.LOG", false, true),
    ("filelog", false, false),
    ("Node_Modules", false, true),
    ("node", false, false),
    (".DS_Store", true, true),
    (".DS_Store", false, true),
    ("._Resource", false, true),
    (".Spotlight-V100", false, true),
    (".Trashes", false, true),
])
func ignoreMatcherSkips(name: String, hiddenFiles: Bool, skipped: Bool) {
    let matcher = IgnoreMatcher(
        ignoreHiddenFiles: hiddenFiles,
        excludedPatterns: ["*.log", "node_modules"]
    )
    let hidden = name.hasPrefix(".")
    #expect(matcher.shouldSkip(name: name, isHidden: hidden) == skipped)
}


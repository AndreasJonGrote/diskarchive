//
//  ColumnFilterAndAppearanceTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor struct ColumnFilterTests {
    @Test func audioFilterKeepsFoldersAndHidesOtherFiles() {
        var filters = SearchFilters()
        filters.fileTypes = [.audio]
        let root = ColumnBrowserFiltering.visibleItems(rootItems, openFolderName: nil, filters: filters, keepFolders: true)
        let sub = ColumnBrowserFiltering.visibleItems(subItems, openFolderName: nil, filters: filters, keepFolders: true)
        #expect(root.map(\.name) == ["HipHop", "track.mp3"])
        #expect(sub.map(\.name) == ["inner.mp3"])
    }

    @Test func hiddenFoldersKeepTheOpenFolder() {
        var filters = SearchFilters()
        filters.fileTypes = [.audio]
        let root = ColumnBrowserFiltering.visibleItems(
            rootItems,
            openFolderName: "HipHop",
            filters: filters,
            keepFolders: false
        )
        #expect(root.map(\.name) == ["HipHop", "track.mp3"])
    }

    @Test func filterCountsStayInFooterNotColumnHeaders() {
        var filters = SearchFilters()
        filters.fileTypes = [.audio]
        let root = ColumnBrowserFiltering.visibleItems(rootItems, openFolderName: nil, filters: filters, keepFolders: true)
        let sub = ColumnBrowserFiltering.visibleItems(subItems, openFolderName: nil, filters: filters, keepFolders: true)
        #expect(ObjectCountFormatting.label(filtered: sub.count, total: subItems.count) == "1 von 2 Objekten")
        #expect(root.count == 2)
    }

    @Test func clearingTheFilterShowsEverything() {
        let filters = SearchFilters()
        let root = ColumnBrowserFiltering.visibleItems(rootItems, openFolderName: nil, filters: filters, keepFolders: true)
        #expect(root.map(\.name) == rootItems.map(\.name))
    }
}

@Suite struct AppearanceColorTests {
    @Test func darkValuesMatchTheTable() {
        #expect(near(DesignColor.bg, dark: true, hex: 0x1F1F1F))
        #expect(near(DesignColor.text, dark: true, hex: 0xEAE9E9))
        #expect(near(DesignColor.control, dark: true, hex: 0xEAE9E9))
        #expect(near(DesignColor.stateOnline, dark: true, hex: 0x5BBD74))
        #expect(near(DesignColor.bg, dark: false, hex: 0xF3F2F2))
        let fill = components(DesignColor.chipFill(DesignColor.stateOnline), dark: true)
        #expect(abs(fill.a - 0.12) < 0.01)
        let lightFill = components(DesignColor.chipFill(DesignColor.stateOnline), dark: false)
        #expect(abs(lightFill.a - 0.05) < 0.01)
    }
}

private let rootItems = [
    item("HipHop", .folder),
    item("track.mp3", .file),
    item("cover.png", .file),
]

private let subItems = [
    item("inner.mp3", .file),
    item("notes.txt", .file),
]

private func item(_ name: String, _ kind: IndexedItem.Kind) -> IndexedItem {
    IndexedItem(
        id: UUID(),
        name: name,
        kind: kind,
        parentPath: [],
        modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
        sizeBytes: 1)
}

private func near(_ color: Color, dark: Bool, hex: UInt32) -> Bool {
    let sample = components(color, dark: dark)
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return abs(sample.r - red) < 0.01 && abs(sample.g - green) < 0.01 && abs(sample.b - blue) < 0.01
}

private func components(_ color: Color, dark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    let appearance = testAppearance(dark ? .darkAqua : .aqua)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    appearance.performAsCurrentDrawingAppearance {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    }
    return (red, green, blue, alpha)
}

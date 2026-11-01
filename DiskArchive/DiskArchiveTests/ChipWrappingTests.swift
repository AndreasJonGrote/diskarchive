//
//  ChipWrappingTests.swift
//  DiskArchiveTests
//
//  Aufgabe 116 / 118 — Chips kürzen Text nicht; kurze Chips einzeilig.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

struct ChipWrappingTests {
    @Test(arguments: [200.0, 600.0])
    @MainActor
    func shortLogPatternStaysSingleLineAtWidth(_ containerWidth: Double) {
        let naturalSize = naturalChipSize(pattern: "*.log")
        #expect(naturalSize.height < 32, "Einzelchip-Höhe \(naturalSize.height)")
        let flowSize = chipSize(pattern: "*.log", containerWidth: containerWidth)
        #expect(flowSize.height < 32, "Flow-Höhe \(flowSize.height) bei Breite \(containerWidth)")
        #expect(flowSize.width <= containerWidth + 1)
        #expect(naturalSize.width < containerWidth)
    }

    @Test @MainActor func longPatternWrapsInsideContainer() {
        let pattern = String(repeating: "M", count: 200)
        let size = chipSize(pattern: pattern, containerWidth: 200)
        #expect(size.width <= 200.5)
        #expect(size.height > 32)
    }

    @Test @MainActor func ignoredPatternChipGrowsVerticallyInFlowLayout() {
        let pattern = String(repeating: "A", count: 80)
        let size = chipSize(pattern: pattern, containerWidth: 200)
        #expect(size.height > 28)
        #expect(size.width <= 200.5)
    }

    @Test func chipSourcesAvoidSingleLineTruncation() throws {
        let paths = [
            "DiskArchive/DesignSystem/IgnoredPatternChip.swift",
            "DiskArchive/DesignSystem/FilterValueChip.swift",
            "DiskArchive/DesignSystem/StatusChip.swift",
            "DiskArchive/DesignSystem/NeutralFilterChip.swift",
        ]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for relative in paths {
            let url = root.appendingPathComponent(relative)
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(!source.contains("lineLimit(1)"), "lineLimit(1) in \(relative)")
            #expect(!source.contains("truncationMode"), "truncationMode in \(relative)")
        }
    }

    @MainActor
    private func chipSize(pattern: String, containerWidth: CGFloat) -> CGSize {
        let host = NSHostingView(
            rootView: FlowLayout(spacing: 8) {
                IgnoredPatternChip(pattern: pattern, onRemove: {})
            }
            .frame(width: containerWidth, alignment: .leading)
        )
        host.setFrameSize(NSSize(width: containerWidth, height: 400))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    @MainActor
    private func naturalChipSize(pattern: String) -> CGSize {
        let lone = NSHostingView(rootView: IgnoredPatternChip(pattern: pattern, onRemove: {}))
        lone.layoutSubtreeIfNeeded()
        return lone.fittingSize
    }
}

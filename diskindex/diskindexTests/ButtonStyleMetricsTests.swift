//
//  ButtonStyleMetricsTests.swift
//  diskindexTests
//
//  Aufgabe 113 — gemeinsame Knopfhöhen und Bestätigungsbreite.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@Suite struct ButtonStyleMetricsTests {
    @Test func standardActionButtonsShareHeight() {
        #expect(DesignButtonSize.standard.height == 38.8)
        #expect(DesignButtonSize.compact.height == 24.4)
        #expect(ConfirmButton.layoutHeight == DesignButtonSize.standard.height)
        #expect(PrimaryButtonStyle().size.height == SecondaryButtonStyle().size.height)
        #expect(DestructiveButtonStyle().size.height == DesignButtonSize.standard.height)
    }

    @Test func confirmButtonWidthUsesLongestStageLabel() {
        let font = NSFont.systemFont(ofSize: DesignButtonSize.standard.fontSize, weight: .semibold)
        let padding = DesignButtonSize.standard.horizontalPadding * 2
        let iconAndSpacing: CGFloat = 14 + 6

        func textWidth(_ string: String) -> CGFloat {
            (string as NSString).size(withAttributes: [.font: font]).width
        }

        let widths = [
            textWidth(LayoutCopy.forget),
            textWidth(LayoutCopy.confirm),
            textWidth(LayoutCopy.confirmed),
        ]
        let longest = widths.max() ?? 0
        let narrowest = widths.min() ?? 0
        #expect(longest > narrowest)
        #expect(longest + padding + iconAndSpacing > narrowest + padding)
    }

    @Test func dialogButtonsMatchStandardHeight() {
        #expect(DesignButtonSize.dialog.height == DesignButtonSize.standard.height)
    }

    @Test func viewGroupsUseUniformButtonSizes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("diskindex")

        struct Group {
            let name: String
            let files: [String]
            let expectedTokens: Set<String>
            let forbidStretchAfterButtonStyle: Bool
        }

        let groups: [Group] = [
            Group(
                name: "06-detail",
                files: ["Views/Detail/MediumDetailModalView.swift"],
                expectedTokens: ["PrimaryButtonStyle()", "SecondaryButtonStyle()", "ConfirmButton"],
                forbidStretchAfterButtonStyle: true
            ),
            Group(
                name: "05-settings",
                files: [
                    "Views/Settings/SettingsGeneralTab.swift",
                    "Views/Settings/SettingsIgnoredObjectsTab.swift",
                ],
                expectedTokens: ["SecondaryButtonStyle()", "ConfirmButton"],
                forbidStretchAfterButtonStyle: true
            ),
            Group(
                name: "02-erkennung",
                files: ["Views/Registry/NewMediumDetectedDialog.swift"],
                expectedTokens: ["PrimaryButtonStyle()", "SecondaryButtonStyle()"],
                forbidStretchAfterButtonStyle: true
            ),
            Group(
                name: "13-14-dialoge",
                files: [
                    "Views/CrashReportDialog.swift",
                    "Views/Registry/IndexingFailureDialog.swift",
                    "Views/Registry/StoreOpenFailureDialog.swift",
                ],
                expectedTokens: [
                    "PrimaryButtonStyle(size: .dialog)",
                    "SecondaryButtonStyle(size: .dialog)",
                ],
                forbidStretchAfterButtonStyle: false
            ),
            Group(
                name: "03-popover",
                files: ["MenuBar/MenuBarPopoverView.swift"],
                expectedTokens: ["SecondaryButtonStyle(compactFooter: true)"],
                forbidStretchAfterButtonStyle: true
            ),
        ]

        for group in groups {
            var found = Set<String>()
            var stretchAfterStyle = false
            for relative in group.files {
                let source = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
                for token in group.expectedTokens where source.contains(token) {
                    found.insert(token)
                }
                if source.range(of: #"\.buttonStyle\([^\n]+\)\s*\n\s*\.frame\(maxWidth: \.infinity\)"#, options: .regularExpression) != nil {
                    stretchAfterStyle = true
                }
            }
            #expect(found == group.expectedTokens, "\(group.name): Styles \(found.sorted()) ≠ \(group.expectedTokens.sorted())")
            if group.forbidStretchAfterButtonStyle {
                #expect(!stretchAfterStyle, "\(group.name): gestreckter Knopf (.frame maxWidth nach buttonStyle)")
            }

            let hasStandard = found.contains {
                $0 == "ConfirmButton"
                    || ($0.contains("ButtonStyle") && !$0.contains("size:") && !$0.contains("compactFooter"))
            }
            let hasCompact = found.contains { $0.contains("compact") }
            let hasDialog = found.contains { $0.contains(".dialog") }
            #expect(!(hasStandard && hasCompact), "\(group.name): Standard und Compact gemischt")
            #expect(!(hasStandard && hasDialog), "\(group.name): Standard und Dialog gemischt")
            #expect(!(hasCompact && hasDialog), "\(group.name): Compact und Dialog gemischt")
        }
    }
}

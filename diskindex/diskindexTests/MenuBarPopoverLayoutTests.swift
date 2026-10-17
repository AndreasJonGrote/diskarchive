//
//  MenuBarPopoverLayoutTests.swift
//  diskindexTests
//

import CoreGraphics
import Foundation
import Testing
@testable import diskindex

@Suite struct MenuBarPopoverLayoutTests {
    @Test func panelHorizontalInsetMatchesLayout() {
        #expect(MenuBarPopoverLayout.panelHorizontalInset == 16)
        #expect(MenuBarPopoverLayout.idleContentHorizontalInset == 12)
        #expect(MenuBarPopoverLayout.searchVerticalPadding == 16)
    }

    @Test func searchContentHeightMatchesVStackLayout() {
        let mediumID = UUID()
        let hit = PopoverSearchHit(
            kind: .file,
            title: "a.pdf",
            location: "Disk",
            target: ObjectContextTarget(
                id: UUID(),
                name: "a.pdf",
                kind: .file,
                mediumID: mediumID
            ),
            result: nil
        )
        let group = PopoverSearchGroup(title: "DATEIEN", hits: [hit])
        let expected = MenuBarPopoverLayout.searchVerticalPadding * 2
            + MenuBarPopoverLayout.searchSectionLabelBlockHeight
            + MenuBarPopoverLayout.searchRowBlockHeight
        #expect(MenuBarPopoverLayout.searchContentHeight(groups: [group]) == expected)
    }

    @Test func searchPanelHeightIsNotFlooredToMinimum() {
        let short = MenuBarPopoverLayout.searchFullHeight(groups: [], totalCount: 0)
        #expect(short < MenuBarPopoverLayout.panelMinHeight)
    }

    @Test func openAppFooterHeightMatchesLayout() {
        #expect(MenuBarPopoverLayout.footerOpenAppHeight == 50)
    }

    @Test func searchFullHeightMatchesTwoGroupPreview() {
        let mediumID = UUID()
        func hit(name: String, folder: Bool) -> PopoverSearchHit {
            PopoverSearchHit(
                kind: folder ? .folder : .file,
                title: name,
                location: "NO NAME",
                target: ObjectContextTarget(
                    id: UUID(),
                    name: name,
                    kind: folder ? .folder : .file,
                    mediumID: mediumID
                ),
                result: nil
            )
        }
        let files = PopoverSearchGroup(
            title: "DATEIEN",
            hits: (0..<3).map { hit(name: "file\($0).wav", folder: false) }
        )
        let folders = PopoverSearchGroup(title: "ORDNER", hits: [hit(name: "Ceres", folder: true)])
        let groups = [files, folders]
        let expectedContent = MenuBarPopoverLayout.searchVerticalPadding * 2
            + MenuBarPopoverLayout.searchSectionLabelBlockHeight
            + 3 * MenuBarPopoverLayout.searchRowBlockHeight
            + 2 * MenuBarPopoverLayout.searchInnerGroupSpacing
            + MenuBarPopoverLayout.searchSectionGap
            + MenuBarPopoverLayout.searchSectionLabelBlockHeight
            + MenuBarPopoverLayout.searchRowBlockHeight
        #expect(MenuBarPopoverLayout.searchContentHeight(groups: groups) == expectedContent)
        #expect(
            MenuBarPopoverLayout.searchFullHeight(groups: groups, totalCount: 6964)
                == MenuBarPopoverLayout.headerHeight + expectedContent + MenuBarPopoverLayout.footerOpenAppHeight
        )
    }

    @Test func searchFooterHeightOnlyWhenResultsExist() {
        #expect(MenuBarPopoverLayout.searchActionFooterHeight(totalCount: 0) == 0)
        #expect(MenuBarPopoverLayout.searchActionFooterHeight(totalCount: 9) == MenuBarPopoverLayout.footerOpenAppHeight)
    }
}

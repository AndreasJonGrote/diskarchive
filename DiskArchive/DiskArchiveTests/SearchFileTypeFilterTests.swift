//
//  SearchFileTypeFilterTests.swift
//  DiskArchiveTests
//

import Testing
@testable import DiskArchive

@Suite struct SearchFileTypeFilterTests {
    @Test func programsMatchesAppPackage() {
        #expect(SearchFileTypeFilter.programs.matches(fileName: "Safari.app", isFolder: true, isPackage: true))
        #expect(!SearchFileTypeFilter.folder.matches(fileName: "Safari.app", isFolder: true, isPackage: true))
        #expect(SearchFileTypeFilter.folder.matches(fileName: "Projekte", isFolder: true, isPackage: false))
    }

    @Test func programsMatchesDmgFile() {
        #expect(SearchFileTypeFilter.programs.matches(fileName: "setup.dmg", isFolder: false, isPackage: false))
    }
}

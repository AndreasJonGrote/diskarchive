//
//  ColumnStateSimulationTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite struct ColumnStateSimulationTests {
    @Test func mediumIDIsValidAtLoadTime() {
        #expect(UUID(uuidString: "D0600001-0000-4000-8000-000000000001") != nil)
        #expect(ColumnStateSimulation.isSimulationMedium(ColumnStateSimulation.mediumID))
    }

    @Test func folderNamesDriveOpenState() {
        let medium = ColumnStateSimulation.makeMedium()
        let settings = AppSettings()
        if case .pendingIndex = ColumnFolderOpenState.resolve(
            columnIndex: 0,
            medium: medium,
            settings: settings,
            folderName: ColumnStateSimulation.FolderName.pendingIndexing,
            folderListedAt: Date()
        ) {
            #expect(Bool(true))
        } else {
            Issue.record("pending folder should stay pending even with listedAt")
        }
        if case .uncaptured(.scanDepth) = ColumnFolderOpenState.resolve(
            columnIndex: 0,
            medium: medium,
            settings: settings,
            folderName: ColumnStateSimulation.FolderName.uncapturedScanDepth,
            folderListedAt: Date()
        ) {
            #expect(Bool(true))
        } else {
            Issue.record("scan-depth demo folder should be uncaptured")
        }
    }

    @MainActor
    @Test func loadingColumnPathStartsEmptyWhileLoading() async {
        let repository = IndexRepository(store: nil)
        let mediumID = ColumnStateSimulation.mediumID
        repository.requestLoad(mediumID: mediumID, path: [])
        let loadingPath = [ColumnStateSimulation.FolderName.projects, ColumnStateSimulation.FolderName.loadingContents]
        _ = await repository.loadChildren(mediumID: mediumID, path: loadingPath)
        let after = repository.children(mediumID: mediumID, path: loadingPath)
        #expect(after.isEmpty)
        #expect(repository.isLoading(mediumID: mediumID, path: loadingPath))
        let progress = repository.loadingProgress(mediumID: mediumID, path: loadingPath)
        #expect(progress.loaded == ColumnStateSimulation.simulatedLoadingFrozenCount)
        #expect(progress.total == ColumnStateSimulation.simulatedLoadingTotal)
    }
}

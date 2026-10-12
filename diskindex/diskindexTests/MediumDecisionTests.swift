//
//  MediumDecisionTests.swift
//  diskindexTests
//
//  Sichtbarkeit und Entscheidungen (Aufgabe 69 / 80 B).
//

import Foundation
import Testing
@testable import diskindex

struct MediumDecisionUnitTests {
    @Test func legacyDecisionStringsMigrateToDontIndex() {
        #expect(StoredIndexDecision.resolved("ignore") == .dontIndex)
        #expect(StoredIndexDecision.resolved("dontIndex") == .dontIndex)
        #expect(StoredIndexDecision.resolved("index") == .index)
    }

    @Test func undecidedWithoutIndexIsOnlyInRegistry() {
        var medium = PreviewData.media[0]
        medium.decision = .undecided
        medium.completedDepth = 0
        medium.fileCount = 0
        medium.folderCount = 0
        let app = AppState()
        app.media = [medium]
        #expect(app.registryMedia.count == 1)
        #expect(app.indexedMedia.isEmpty)
    }

    @Test func dontIndexWithoutIndexIsOnlyInRegistry() {
        var medium = PreviewData.media[0]
        medium.decision = .dontIndex
        medium.completedDepth = 0
        medium.fileCount = 0
        medium.folderCount = 0
        let app = AppState()
        app.media = [medium]
        #expect(app.registryMedia.count == 1)
        #expect(app.indexedMedia.isEmpty)
    }

    @Test func dontIndexWithIndexStaysBrowsable() {
        var medium = PreviewData.media[0]
        medium.decision = .dontIndex
        medium.completedDepth = 3
        medium.fileCount = 10
        let app = AppState()
        app.media = [medium]
        #expect(app.indexedMedia.contains { $0.id == medium.id })
    }

    @Test func menuBarBadgeShowsErrorWhenStoreUnavailable() {
        let app = AppState()
        app.globalAutoIndexPaused = true
        app.reportIndexStoreOpenFailure()
        #expect(app.effectiveMenuBarBadge == .error)
    }

    @Test func undecidedMediumCannotReindex() {
        var medium = PreviewData.media[0]
        medium.decision = .undecided
        medium.indexStatus = .pending
        let app = AppState()
        app.media = [medium]
        #expect(!app.canReindex(medium.id))
    }

    @Test func menuBarBadgeFollowsPriority() {
        let app = AppState()
        var online = PreviewData.media[0]
        online.connectionStatus = .connected
        online.indexStatus = .indexing
        app.media = [online]
        let id = online.id
        app.noteMenuBarIndexingSpinner(id, active: true)

        #expect(app.effectiveMenuBarBadge == .indexing)

        app.globalAutoIndexPaused = true
        #expect(app.effectiveMenuBarBadge == .paused)

        app.updateMedium(id: id) { $0.decision = .undecided }
        app.enqueueNewMediumDecision(id)
        #expect(app.effectiveMenuBarBadge == .newlyDetected)

        app.updateMedium(id: id) { $0.indexStatus = .error }
        #expect(app.effectiveMenuBarBadge == .error)
    }
}

//
//  DashboardTileTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.008 (Layout 04) und bug.0.4.3.002: Zeilen der Kachel je Zustand, „Kein Zugriff …“ entfällt, Link
//  „erneut versuchen“ startet die Indizierung neu, kein Link bei „Fehler, offline“; „1 Datei“ in der Ladeansicht.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct DashboardTileTests {
    private static func medium(
        _ status: IndexStatus,
        connected: Bool = true,
        files: Int = 238_421,
        gaps: Bool = false
    ) -> Medium {
        var medium = Medium(
            id: UUID(), name: "Studio Backup", type: .ssd, connectionStatus: connected ? .connected : .offline,
            indexStatus: status, allowIndexing: true, autoIndexPaused: false,
            capacityTotalBytes: 4_100_000_000_000, capacityUsedBytes: 3_770_000_000_000, fileCount: files,
            folderCount: 12, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(), isForgotten: false,
            indexingProgress: 1
        )
        medium.hasIndexGaps = gaps
        return medium
    }

    @Test func linesForEveryState() {
        L10n.$languageOverride.withValue(.german) {
            let online = Self.medium(.indexed)
            #expect(online.dashboardSpecLine == "\(online.totalCapacityLabel) · 238.421 Dateien")
            #expect(online.dashboardMetaLine == .lastSeen(occupancy: "92 %"))

            let offline = Self.medium(.indexed, connected: false)
            #expect(offline.dashboardMetaLine == .lastSeen(occupancy: nil))

            let error = Self.medium(.error)
            #expect(error.dashboardSpecLine == error.specLine, "„Kein Zugriff …“ statt der Zeile")
            #expect(error.dashboardMetaLine == .retry)
            #expect(error.menuBarSecondaryLine == "Speichermedium fehlerhaft")

            let gap = Self.medium(.error, gaps: true)
            #expect(gap.dashboardMetaLine == .lastSeen(occupancy: "92 %"))

            let errorOffline = Self.medium(.error, connected: false)
            #expect(errorOffline.dashboardMetaLine == .lastSeen(occupancy: nil), "Link bei „Fehler, offline“")

            let pending = Self.medium(.pending, files: 0)
            #expect(pending.dashboardSpecLine == "\(pending.totalCapacityLabel) · 0 Dateien")
            #expect(Self.medium(.indexed, files: 1).dashboardSpecLine.hasSuffix(" · 1 Datei"))
        }
        #expect(DashboardRetryLine.status == LayoutCopy.chipError)
        L10n.$languageOverride.withValue(.english) {
            #expect(DashboardRetryLine.status == "Error" && DashboardRetryLine.link == "try again")
        }
    }

    @Test func retryLinkStartsIndexingAndClosesTheDialog() {
        let app = AppState()
        let medium = Self.medium(.error)
        app.media = [medium]
        var started: [UUID] = []
        app.onReindexMedium = { started.append($0) }
        app.indexingFailure = IndexingFailureNotice(id: medium.id, name: medium.name, reason: .permission)
        app.retryIndexing(mediumID: medium.id)
        #expect(started == [medium.id])
        #expect(app.indexingFailure == nil)
    }

    @Test func loadingTitleSaysOneFile() {
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.loadingSearchTitle(media: 1, files: 1) == "Dein 1 Speichermedium und 1 Datei werden durchsucht …")
            #expect(LayoutCopy.loadingFavoritesTitle(media: 3, files: 1) == "Deine 3 Speichermedien und 1 Datei werden gefiltert …")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(LayoutCopy.loadingSearchTitle(media: 1, files: 1) == "Searching your 1 storage medium and 1 file …")
        }
    }
}

//
//  MediumChipTests.swift
//  DiskArchiveTests
//
//  Aufgabe 115 — Chip-Texte nur nach Layout.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct MediumChipTests {
    private static let allowedTexts: Set<String> = [
        "Online",
        "Offline",
        "Fehler",
        "Fehler, offline",
        "Ausstehend",
        "Nicht erlaubt",
        // todo.0.4.3.013 (Layout 04): neu, „Indizieren“ entschieden, vor dem Start.
        "Wird geprüft",
    ]

    @Test func chipTextsMatchAllowlistPattern() {
        var samples: [Medium] = []
        for status in IndexStatus.allCases {
            for connection in [ConnectionStatus.connected, .offline] {
                for decision in StoredIndexDecision.allCases {
                    var base = previewMedium(0)
                    base.indexStatus = status
                    base.connectionStatus = connection
                    base.decision = decision
                    base.indexingProgress = 0.47
                    base.completedDepth = status == .indexed ? 3 : 1
                    base.fileCount = 100
                    samples.append(base)

                    var empty = base
                    empty.completedDepth = 0
                    empty.fileCount = 0
                    empty.folderCount = 0
                    empty.lastIndexedAt = nil
                    samples.append(empty)
                }
            }
        }
        for medium in samples {
            let text = MediumChip.presentation(medium).text
            if allowedStaticTexts.contains(text) { continue }
            #expect(text.contains(" % indiziert"), "Unerwarteter Chip-Text: \(text)")
        }
    }

    @Test func pendingWithPartialIndexShowsPercentOffline() {
        var medium = previewMedium(0)
        medium.indexStatus = .pending
        medium.connectionStatus = .offline
        medium.indexingProgress = 0.47
        medium.completedDepth = 1
        // bug.0.4.210: offline zählt der gespeicherte Stand (470 von 1.000), nicht der Restwert des Laufs.
        medium.fileCount = 470
        medium.folderCount = 0
        medium.scanTotal = 1_000
        let chip = MediumChip.presentation(medium)
        #expect(chip.text == "47 % indiziert, offline")
        #expect(chip.offlineGray)
        #expect(chip.dashed)
        #expect(!chip.spinner)
    }

    @Test func unplugMidRunKeepsSamePercentOnChip() {
        var running = previewMedium(0)
        running.indexStatus = .indexing
        running.connectionStatus = .connected
        running.indexingProgress = 0.47
        running.fileCount = 470
        running.folderCount = 0
        running.scanTotal = 1_000
        let before = MediumChip.presentation(running).text

        var unplugged = running
        unplugged.indexStatus = .pending
        unplugged.connectionStatus = .offline
        let after = MediumChip.presentation(unplugged).text

        #expect(before == "47 % indiziert")
        #expect(after == "47 % indiziert, offline")
    }

    @Test func indexedOnlineAndOffline() {
        var online = previewMedium(1)
        online.connectionStatus = .connected
        online.indexStatus = .indexed
        #expect(MediumChip.presentation(online).text == "Online")

        var offline = online
        offline.connectionStatus = .offline
        #expect(MediumChip.presentation(offline).text == "Offline")
    }

    @Test func spinnerOnlyWhileIndexingAndNotPaused() {
        var medium = previewMedium(0)
        medium.indexStatus = .indexing
        medium.connectionStatus = .connected
        medium.indexingProgress = 0.2
        #expect(MediumChip.presentation(medium, globalAutoIndexPaused: false).spinner)
        #expect(!MediumChip.presentation(medium, globalAutoIndexPaused: true).spinner)

        medium.indexStatus = .pending
        #expect(!MediumChip.presentation(medium).spinner)
    }

    @Test func percentUsesFloorNotRound() {
        var medium = previewMedium(0)
        medium.indexStatus = .indexing
        medium.indexingProgress = 0.999
        #expect(medium.indexProgressPercent == 99)
        #expect(MediumChip.presentation(medium).text == "99 % indiziert")
    }

    private var allowedStaticTexts: Set<String> { Self.allowedTexts }
}

private extension StoredIndexDecision {
    static var allCases: [StoredIndexDecision] { [.undecided, .index, .dontIndex] }
}

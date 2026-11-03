//
//  MediumDetailHeaderTests.swift
//  DiskArchiveTests
//
//  bug.0.4.3.003: Kopfzeile im Details-Fenster ohne feste deutsche Wörter und ohne Medientyp (Wortlaut aus dem Katalog,
//  Sektion 20).
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct MediumDetailHeaderTests {
    private static func medium(_ type: MediumType, _ status: ConnectionStatus) -> Medium {
        Medium(
            id: UUID(), name: "Stick", type: type, connectionStatus: status, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0,
            fileCount: 1, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )
    }

    @Test func headerHasNoTypeAndFollowsTheLanguage() {
        for type in MediumType.allCases {
            for status in [ConnectionStatus.connected, .offline] {
                let medium = Self.medium(type, status)
                let english = L10n.$languageOverride.withValue(.english) { medium.connectionDescription }
                let deutsch = L10n.$languageOverride.withValue(.german) { medium.connectionDescription }
                for text in [english, deutsch] {
                    #expect(!["HDD", "SSD", "USB"].contains { text.contains($0) }, "Medientyp in „\(text)“")
                    #expect(!text.contains(type.displayName), "Medientyp in „\(text)“")
                }
                #expect(!["angeschlossen", "extern"].contains { english.contains($0) }, "Deutsch im Englischen: \(english)")
                let expected = status == .connected ? "Online" : "Offline"
                #expect(english == expected && deutsch == expected, "\(english) / \(deutsch)")
            }
        }
    }
}

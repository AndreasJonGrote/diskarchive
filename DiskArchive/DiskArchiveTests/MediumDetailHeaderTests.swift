//
//  MediumDetailHeaderTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.010 (Layout 06.01, 06.03), bug.0.4.3.003: Details-Fenster – Werte der Flächen, keine zweite Kopfzeile und
//  kein Typ, Fehlergrund unter „Indiziert“ nur bei Status „Fehler“ und bekanntem Grund; der Grund wird am Medium
//  gespeichert (`storage_meta` `failureReason`) und nach einem gelungenen Lauf gelöscht.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct MediumDetailHeaderTests {
    private static func medium(_ status: IndexStatus = .indexed, reason: IndexFailureReason? = nil) -> Medium {
        var medium = Medium(
            id: UUID(), name: "Stick", type: .usb, connectionStatus: .connected, indexStatus: status,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 2_000_000_000_000,
            capacityUsedBytes: 1_240_000_000_000, fileCount: 18_442, folderCount: 2_316, lastSeenAt: Date(),
            firstIndexedAt: Date(), lastIndexedAt: Date(), isForgotten: false, indexingProgress: 1
        )
        medium.failureReason = reason
        return medium
    }

    @Test func figuresAndNoType() {
        L10n.$languageOverride.withValue(.german) {
            let medium = Self.medium()
            #expect(medium.totalCapacityLabel == ByteCountFormatter.storage.string(fromByteCount: 2_000_000_000_000))
            #expect(medium.usedLabel == ByteCountFormatter.storage.string(fromByteCount: 1_240_000_000_000))
            #expect(medium.freeLabel == ByteCountFormatter.storage.string(fromByteCount: 760_000_000_000))
            #expect(medium.filesLabel == "18.442" && medium.foldersLabel == "2.316")
            #expect(medium.lastIndexedValue.hasPrefix("heute, "), "\(medium.lastIndexedValue)")
            for text in [medium.usedLabel, medium.freeLabel, medium.lastIndexedValue, medium.indexedLabel] {
                #expect(!["HDD", "SSD", "USB"].contains { text.contains($0) }, "Typ in „\(text)“")
            }
        }
    }

    @Test func failureLineOnlyWhileErrorAndKnown() {
        #expect(Self.medium(.error, reason: .permission).detailFailureLine == LayoutCopy.permissionLine)
        #expect(Self.medium(.error, reason: .unknown).detailFailureLine == nil, "Zeile bei unbekanntem Grund")
        #expect(Self.medium(.error).detailFailureLine == nil)
        #expect(Self.medium(.indexed, reason: .permission).detailFailureLine == nil, "Zeile ohne Fehler")
    }

    /// Der Grund überlebt den Neustart (gespeichert am Medium) und ist nach dem Löschen weg.
    @Test func failureReasonIsStoredAtTheMedium() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-failure-reason-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Stick", decision: .index, indexStatus: .error, completedDepth: 1)
        try await store.upsertMedium(stored)

        try await store.setFailureReason(mediumUUID: stored.uuid, code: IndexFailureReason.permission.notificationCode)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        #expect(app.medium(with: stored.uuid)?.failureReason == .permission)
        #expect(app.medium(with: stored.uuid)?.detailFailureLine == LayoutCopy.permissionLine)

        try await store.setFailureReason(mediumUUID: stored.uuid, code: nil)
        let reloaded = AppState(store: store)
        await reloaded.loadStoredMedia()
        #expect(reloaded.medium(with: stored.uuid)?.failureReason == nil)
    }
}

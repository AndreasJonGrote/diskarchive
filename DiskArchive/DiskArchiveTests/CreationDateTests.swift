//
//  CreationDateTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.024 (Layout 07, Host 05.11.): Erstellungsdatum jeder Datei – beim Lesen eines echten Ordners erfasst
//  (Bulk-Weg und Rückfallweg), im Index gespeichert und in der Detailspalte bei „Erstellt“ gezeigt; Altbestand ohne Wert
//  „—“. Mehrfachauswahl: „Im Finder anzeigen“ markiert alle gewählten Objekte, nur online.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct CreationDateTests {
    @Test func scanReadsTheCreationDate() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-crtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("brief.txt")
        try Data("x".utf8).write(to: file)
        let created = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: file.path)

        let bulk = try await Task.detached { try BulkDirectoryReader.readEntries(at: root) }.value
        let viaBulk = try #require(bulk.first { $0.name == "brief.txt" }?.createdAt, "Bulk-Weg ohne Erstellungsdatum")
        #expect(abs(viaBulk.timeIntervalSince(created)) < 1)
        let fallback = try BulkDirectoryReader.readUsingFileManager(at: root)
        let viaFallback = try #require(fallback.first { $0.name == "brief.txt" }?.createdAt, "Rückfallweg ohne Erstellungsdatum")
        #expect(abs(viaFallback.timeIntervalSince(created)) < 1)
    }

    @Test func storedAfterScanAndOldEntriesStayEmpty() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let created = Date(timeIntervalSince1970: 1_600_000_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [
                ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 1, createdAt: created),
                ScannedEntry(name: "alt.txt", isFolder: false, sizeBytes: 1),
            ],
            seenAt: Date()
        )
        let rows = try await harness.store.children(mediumUUID: medium.uuid, parentID: nil)
        let fresh = try #require(rows.first { $0.name == "neu.txt" })
        let old = try #require(rows.first { $0.name == "alt.txt" })
        #expect(fresh.createdAt == created)
        #expect(old.createdAt == nil)

        let online = Medium(
            id: medium.uuid, name: "Platte", type: .ssd, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 0, fileCount: 2,
            folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(), isForgotten: false,
            indexingProgress: 1
        )
        L10n.$languageOverride.withValue(.german) {
            let shown = ColumnDetailFacts.file(IndexedItem(stored: fresh), medium: online)
            #expect(shown.first?.label == "Erstellt")
            #expect(shown.first?.value == IndexedDateFormatting.abbreviatedDay(created))
            #expect(ColumnDetailFacts.file(IndexedItem(stored: old), medium: online).first?.value == "—", "Altbestand")
        }
    }

    @Test func multipleSelectionRevealsAllOnlyWhenOnline() async throws {
        let app = AppState()
        let id = UUID()
        func medium(_ online: Bool) -> Medium {
            Medium(
                id: id, name: "Platte", type: .ssd, connectionStatus: online ? .connected : .offline, indexStatus: .indexed,
                allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1, capacityUsedBytes: 0, fileCount: 2,
                folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(), isForgotten: false,
                indexingProgress: 1
            )
        }
        app.media = [medium(true)]
        app.mountPath = { $0 == id ? "/Volumes/Platte" : nil }
        app.finderRevealFileExists = { _ in true }
        var opened: [URL] = []
        app.finderRevealOpenMany = { opened = $0 }
        let items = ["a.png", "b.png"].map {
            IndexedItem(id: UUID(), name: $0, kind: .file, parentPath: ["Fotos"], modifiedAt: nil, sizeBytes: 1)
        }
        let targets = items.map { ObjectContextTarget.fromIndexedItem($0, medium: medium(true)) }
        await app.revealInFinder(targets)?.value
        #expect(opened.map(\.lastPathComponent) == ["a.png", "b.png"], "nicht alle markiert: \(opened)")
        opened = []
        app.media = [medium(false)]
        #expect(app.revealInFinder(targets) == nil, "offline kein Finder")
        #expect(opened.isEmpty)
    }
}

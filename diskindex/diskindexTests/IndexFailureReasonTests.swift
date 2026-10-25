//
//  IndexFailureReasonTests.swift
//  diskindexTests
//
//  Aufgabe 202 — Fehlergrund kommt aus dem Fehlerobjekt bis in den Dialog.
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import diskindex

private struct OtherFailure: Error {}

extension WindowTestGroup {
@Suite @MainActor
struct IndexFailureReasonTests {
    @Test func classifyUsesTheErrorObjectNotText() {
        let table: [(Error, IndexFailureReason)] = [
            (POSIXError(.EACCES), .permission),
            (POSIXError(.EPERM), .permission),
            (CocoaError(.fileReadNoPermission), .permission),
            (NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue, userInfo: [
                NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
            ]), .permission),
            (POSIXError(.ENXIO), .disconnected),
            (NSError(domain: NSPOSIXErrorDomain, code: Int(ENODEV)), .disconnected),
            (POSIXError(.ENOENT), .disconnected),
            (CocoaError(.fileReadNoSuchFile), .disconnected),
            (DirectoryReadStalled(), .timeout),
            (POSIXError(.ENOSPC), .diskSpace),
            (CocoaError(.fileWriteOutOfSpace), .diskSpace),
            (DatabaseError(resultCode: .SQLITE_FULL, message: "full"), .diskSpace),
            (DatabaseError(resultCode: .SQLITE_IOERR, message: "io"), .database),
            (IndexStoreError.directoryWriteFailed, .database),
            (OtherFailure(), .unknown),
            // Text im Fehler zählt nicht.
            (NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "permission denied"]), .unknown),
        ]
        for (error, expected) in table {
            #expect(IndexFailureReason.classify(error) == expected, "\(error)")
        }
    }

    @Test(arguments: [
        IndexFailureReason.permission, .disconnected, .diskSpace, .database, .unknown,
    ])
    func indexerRunCarriesTheReason(_ expected: IndexFailureReason) async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b.txt")
        switch expected {
        case .permission: access.markUnreadable("")
        case .disconnected: access.failRoot(with: POSIXError(.ENXIO))
        case .diskSpace: access.failRoot(with: POSIXError(.ENOSPC))
        case .database: await harness.store.setDirectoryWritesFailing(true)
        case .unknown: access.failRoot(with: OtherFailure())
        case .timeout: Issue.record("timeout wird in classifyUsesTheErrorObjectNotText geprüft")
        case .unconfirmed: Issue.record("unconfirmed wird in EjectDuringRunTests geprüft")
        case .unreadableFolders: Issue.record("unreadableFolders wird in UnreadableFoldersErrorTests geprüft")
        }
        var limits = IndexingRunLimits.standard
        limits.readRetryDelays = [.milliseconds(1)]
        let outcome = try await harness.run(access: access, maxDepth: nil, limits: limits)
        #expect(outcome.status == .error)
        #expect(outcome.failureReason == expected)
    }

    /// Dienst-Lauf bis in den Dialog (Datenbankfehler: kein Lese-Wiederholen, daher schnell).
    @Test func serviceRunPassesTheReasonToTheDialog() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "FEHLER", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b.txt")
        await store.setDirectoryWritesFailing(true)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        // Pausenzustand kommt aus den geteilten UserDefaults; hier ausdrücklich nicht pausiert.
        app.globalAutoIndexPaused = false
        app.heldForSleep = false
        let service = IndexingService(store: store, access: access, appState: app)
        let volume = ScanHarness(store: store, mediumID: medium.uuid).volume(at: "/Volumes/T")
        service.start(mediumUUID: medium.uuid, volume: volume, fromScratch: true)
        await service.waitUntilIdle(medium.uuid)

        // `waitUntilIdle` kehrt schon zurück, bevor `finish` den Dialog gesetzt hat (Befund F11) → warten.
        let shown = await waitUntil { app.indexingFailure != nil }
        // bug.0.3.8.007: Bei Fehlschlag Stand des Mediums und Grund mitschreiben (bug.0.4.070, nur parallel rot).
        let status = app.media.first { $0.id == medium.uuid }.map { "\($0.indexStatus)" } ?? "kein Medium"
        let reason = app.indexingFailure.map { "\($0.reason)" } ?? "kein Dialog"
        #expect(shown, "Dialog nicht gesetzt: status=\(status) reason=\(reason)")
        let notice = try #require(app.indexingFailure, "status=\(status)")
        #expect(notice.reason == .database, "status=\(status) reason=\(reason)")
        // bug.0.3.8.007: Pixelprüfung entfernt — dass die Grundzeile im Dialog steht, prüft `dialogShowsTheReasonLine`.
    }

    /// bug.0.4.182: Das Medium ist am Ende des Laufs nicht zu bestätigen (ohne Aushängen) → der Dialog nennt den Grund.
    @Test func serviceRunPassesTheUnconfirmedReasonToTheDialog() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-unconfirmed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "UNBESTAETIGT", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("a/b.txt")
        access.scriptMountChecks([false, false])
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.globalAutoIndexPaused = false
        app.heldForSleep = false
        let service = IndexingService(store: store, access: access, appState: app)
        let volume = ScanHarness(store: store, mediumID: medium.uuid).volume(at: "/Volumes/T")
        service.start(mediumUUID: medium.uuid, volume: volume, fromScratch: true)
        await service.waitUntilIdle(medium.uuid)
        let shown = await waitUntil { app.indexingFailure != nil }
        #expect(shown, "Dialog nicht gesetzt")
        #expect(app.indexingFailure?.reason == .unconfirmed)
    }

    /// Die Grundzeile steht im Dialog: mit Grund ist der Inhalt höher als ohne.
    @Test(arguments: [IndexFailureReason.permission, .disconnected, .timeout, .unconfirmed, .diskSpace, .database, .unreadableFolders])
    func dialogShowsTheReasonLine(_ reason: IndexFailureReason) async throws {
        let app = AppState()
        let notice = IndexingFailureNotice(id: UUID(), name: "Stick", reason: reason)
        let line = try #require(reason.line)
        #expect(!line.isEmpty)
        let with = try await dialogInkHeight(notice, reason: reason, app: app)
        let without = try await dialogInkHeight(notice, reason: .unknown, app: app)
        #expect(with > without + 8)
    }

    private func dialogInkHeight(_ notice: IndexingFailureNotice, reason: IndexFailureReason, app: AppState) async throws -> CGFloat {
        let size = CGSize(width: 360, height: 400)
        var shown = notice
        shown.reason = reason
        let bitmap = await PixelProbe.render(
            IndexingFailureDialog(notice: shown).environment(app).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height, alignment: .topLeading),
            size: size,
            appearance: .aqua
        )
        let ink = PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(origin: .zero, size: size),
            background: CGPoint(x: size.width - 2, y: size.height - 2)
        )
        return try #require(ink).height
    }
}
}

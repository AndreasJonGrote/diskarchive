//
//  MediumEjectTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.011: Auswerfen nur auf Klick und nur bei angeschlossenen Medien. Ein laufender Lauf wird zuerst
//  abgebrochen (wie beim Abziehen), dann wird genau die eine Stelle gerufen; lehnt macOS ab, zeigt die App Dialog 16.
//  Kein Knopf in Seitenleisten und Medienspalten. Das echte Auswerfen ersetzt der Haken `ejectVolume`.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct MediumEjectTests {
    private struct Refused: Error {}

    private static func app(connected: Bool) -> (AppState, UUID) {
        let app = AppState()
        let medium = Medium(
            id: UUID(), name: "Studio Backup", type: .ssd, connectionStatus: connected ? .connected : .offline,
            indexStatus: .indexing, allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000,
            capacityUsedBytes: 0, fileCount: 1, folderCount: 0, lastSeenAt: Date(), firstIndexedAt: Date(),
            lastIndexedAt: Date(), isForgotten: false, indexingProgress: 0.4
        )
        app.media = [medium]
        app.mountPath = { $0 == medium.id ? "/Volumes/Studio Backup" : nil }
        return (app, medium.id)
    }

    @Test func ejectCancelsTheRunFirstThenEjectsOnce() async {
        let (app, id) = Self.app(connected: true)
        var steps: [String] = []
        app.onCancelBeforeEject = { steps.append("abbruch \($0 == id)") }
        app.ejectVolume = { steps.append("auswerfen \($0)") }
        await app.ejectMedium(id: id)
        #expect(steps == ["abbruch true", "auswerfen /Volumes/Studio Backup"])
        #expect(app.unexpectedError == nil)
    }

    /// Doppelklick: das zweite Auswerfen läuft nicht, solange das erste noch läuft (kein falscher Dialog 16).
    @Test func secondClickWhileEjectingDoesNothing() async {
        let (app, id) = Self.app(connected: true)
        var ejects = 0
        app.ejectVolume = { _ in
            ejects += 1
            await app.ejectMedium(id: id)
        }
        await app.ejectMedium(id: id)
        #expect(ejects == 1)
        #expect(app.unexpectedError == nil)
    }

    @Test func offlineMediumIsNotEjected() async {
        let (app, id) = Self.app(connected: false)
        var calls = 0
        app.onCancelBeforeEject = { _ in calls += 1 }
        app.ejectVolume = { _ in calls += 1 }
        await app.ejectMedium(id: id)
        #expect(calls == 0)
    }

    @Test func refusalShowsTheUnexpectedErrorDialog() async throws {
        let (app, id) = Self.app(connected: true)
        app.ejectVolume = { _ in throw Refused() }
        await app.ejectMedium(id: id)
        let notice = try #require(app.unexpectedError, "Dialog 16 fehlt")
        #expect(notice.message.contains("Studio Backup"))
        #expect(app.medium(with: id)?.connectionStatus == .connected, "Medium gilt nach Ablehnung als ausgeworfen")
    }

    /// Kein Knopf in Seitenleisten und Medienspalten: nur Kachel und Tabelle „Speichermedien“ nutzen `EjectButton`.
    @Test func ejectButtonOnlyInTileAndTable() throws {
        let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DiskArchive", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
        var users: [String] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            if text.contains("EjectButton(") { users.append(file.lastPathComponent) }
        }
        #expect(users.sorted() == ["MediumDashboardCard.swift", "RegistryTableRow.swift"])
    }
}

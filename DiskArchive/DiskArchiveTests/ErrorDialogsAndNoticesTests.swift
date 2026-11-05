//
//  ErrorDialogsAndNoticesTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.021 (Layout 14, 15, 16, 18): Datenbank beim Start nicht zu öffnen → Dialog 16 mit „Erneut versuchen“;
//  Indizierungsfehler höchstens dreimal pro Stunde und Medium; Absturzbericht mit rotem Icon; Mitteilungstexte aus 20.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct ErrorDialogsAndNoticesTests {
    @Test func unavailableDatabaseUsesDialogSixteenWithRetry() throws {
        let app = AppState()
        var retries = 0
        app.onRetryIndexStoreOpen = { retries += 1 }
        app.reportIndexStoreOpenFailure()
        let notice = try #require(app.unexpectedError, "Dialog 16 fehlt")
        L10n.$languageOverride.withValue(.german) {
            #expect(notice.message == "Die Index-Datenbank konnte nicht geöffnet werden. Disk Archive kann Speichermedien derzeit nicht verarbeiten.")
            #expect(LayoutCopy.unexpectedErrorTitle == "Unerwarteter Fehler")
        }
        #expect(notice.actionTitle == LayoutCopy.retry)
        notice.action?()
        #expect(retries == 1)
        // Geht die Datenbank auf, schließt nur dieser Dialog – ein anderer Fehler bleibt stehen.
        app.clearIndexStoreOpenFailure()
        #expect(app.unexpectedError == nil)
        app.reportIndexStoreOpenFailure()
        let other = UnexpectedErrorNotice(message: "anderer Fehler")
        app.unexpectedError = other
        app.clearIndexStoreOpenFailure()
        #expect(app.unexpectedError?.id == other.id)
    }

    @Test func indexingFailureAtMostThreeTimesPerHourAndMedium() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("drossel-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: file) }
        let defaults = AppStateStore(fileURL: file)
        let app = AppState()
        let medium = UUID()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var shown = 0
        for minute in 0..<5 {
            app.indexingFailure = nil
            app.presentIndexingFailure(
                mediumID: medium, name: "Stick", reason: .timeout, now: start.addingTimeInterval(Double(minute) * 60), defaults: defaults
            )
            if app.indexingFailure != nil { shown += 1 }
        }
        #expect(shown == 3)
        app.indexingFailure = nil
        app.presentIndexingFailure(mediumID: UUID(), name: "Anderes", reason: .timeout, now: start.addingTimeInterval(300), defaults: defaults)
        #expect(app.indexingFailure != nil, "Zählung je Medium")
        app.indexingFailure = nil
        app.presentIndexingFailure(mediumID: medium, name: "Stick", reason: .timeout, now: start.addingTimeInterval(3_700), defaults: defaults)
        #expect(app.indexingFailure != nil, "nach einer Stunde wieder")
    }

    @Test func reasonLinesAndUnknownWithoutLine() {
        L10n.$languageOverride.withValue(.german) {
            #expect(IndexFailureReason.timeout.line == "Das Medium reagiert nicht.")
            #expect(IndexFailureReason.disconnected.line == "Die Verbindung zum Medium wurde unterbrochen.")
            #expect(IndexFailureReason.database.line == "Der Index auf diesem Mac lässt sich gerade nicht beschreiben.")
            #expect(IndexFailureReason.unknown.line == nil, "unbekannter Grund ohne Zeile")
        }
    }

    /// Layout 15: Icon des Absturzberichts rot.
    @Test func crashReportIconIsRed() async {
        let size = CGSize(width: 480, height: 320)
        let bitmap = await PixelProbe.render(
            CrashReportDialog(onClose: {}).environment(AppState()).frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(Color.white),
            size: size
        )
        var reddest: CGFloat = 0
        var y: CGFloat = 0
        while y < 90 {
            var x: CGFloat = 0
            while x < 90 {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                reddest = max(reddest, sample.redComponent - sample.greenComponent)
                x += 1
            }
            y += 1
        }
        #expect(reddest > 0.35, "kein rotes Icon (\(reddest))")
    }
}

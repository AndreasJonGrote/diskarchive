//
//  PauseNoticeTextTests.swift
//  diskindexTests
//
//  Aufgabe 171.2: Pausen-Mitteilungen nach Layout 03, exakter Text.
//

import Foundation
import Testing
import UserNotifications
@testable import diskindex

@MainActor
@Suite(.serialized)
struct PauseNoticeTextTests {
    private func posted(_ body: (AppState, UserDefaults) -> Void) -> [String] {
        let defaults = UserDefaults(suiteName: "PauseNoticeTextTests-\(UUID().uuidString)")!
        let app = AppState()
        app.appSettings.notificationsEnabled = true
        app.appSettings.notifySystem = true
        var texts: [String] = []
        SystemNotice.testPostHandler = { request, _ in texts.append(request.content.body) }
        defer { SystemNotice.testPostHandler = nil }
        body(app, defaults)
        return texts
    }

    @Test func pauseUntilTime() {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 10; parts.day = 8; parts.hour = 14; parts.minute = 30
        let until = Calendar.current.date(from: parts)!
        let texts = posted { app, defaults in
            app.pauseIndexing(until: until, defaults: defaults, now: until.addingTimeInterval(-3_600))
        }
        #expect(texts == ["Indizierung pausiert bis 14:30 Uhr."])
    }

    /// Aufgabe 172 c: Beispielkasten „Systemmeldungen“ in Erweitert nach Layout 05.
    @Test func previewCardForSystemNotices() {
        #expect(NoticeCopy.preview(.system) == "Medien werden wieder indiziert.")
        #expect(L10n.string("copy.settings.notices.preview_system", language: .english) == "Media are being indexed again.")
    }

    @Test func pauseForever() {
        let texts = posted { app, defaults in
            app.pauseIndexing(until: nil, defaults: defaults)
        }
        #expect(texts == ["Indizierung pausiert."])
    }

    @Test func endOfPauseAndClickOnAn() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expired = posted { app, defaults in
            app.pauseIndexing(until: now.addingTimeInterval(60), defaults: defaults, now: now)
            app.refreshGlobalPause(now: now.addingTimeInterval(61), defaults: defaults)
        }
        #expect(expired.last == "Medien werden wieder indiziert.")
        let resumed = posted { app, defaults in
            app.pauseIndexing(until: nil, defaults: defaults)
            app.resumeIndexing(defaults: defaults)
        }
        #expect(resumed.last == "Medien werden wieder indiziert.")
    }
}

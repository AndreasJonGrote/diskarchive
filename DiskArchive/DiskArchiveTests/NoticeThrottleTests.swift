//
//  NoticeThrottleTests.swift
//  DiskArchiveTests
//
//  Aufgabe 166: Mitteilung beim Schalter, gleiche Art frühestens nach 5 s.
//

import Foundation
import Testing
import UserNotifications
@testable import DiskArchive

@MainActor
@Suite(.serialized)
struct NoticeThrottleTests {
    @Test func sameKindWaitsFiveSeconds() {
        let app = AppState()
        app.appSettings.notificationsEnabled = false
        var posted: [String] = []
        let hooks = NoticeTestHooks(post: { request, _ in posted.append(request.content.body) })
        SystemNotice.$testHooks.withValue(hooks) {
            let start = Date(timeIntervalSince1970: 20_000)
            app.setNotificationsEnabled(true, now: start)
            app.setNotificationsEnabled(false, now: start.addingTimeInterval(0.4))
            app.setNotificationsEnabled(true, now: start.addingTimeInterval(0.8))
            #expect(posted == [LayoutCopy.noticesTurnedOn, LayoutCopy.noticesTurnedOff])
            app.setNotificationsEnabled(true, now: start.addingTimeInterval(5))
            #expect(posted == [
                LayoutCopy.noticesTurnedOn,
                LayoutCopy.noticesTurnedOff,
                LayoutCopy.noticesTurnedOn,
            ])
        }
    }
}

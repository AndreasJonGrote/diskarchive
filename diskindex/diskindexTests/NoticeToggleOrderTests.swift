//
//  NoticeToggleOrderTests.swift
//  diskindexTests
//
//  Aufgabe 168: „Mitteilungen sind ausgeschaltet.“ wird zugestellt, bevor der wirksame Wert fällt.
//

import Foundation
import Testing
import UserNotifications
@testable import diskindex

@MainActor
private final class DelayedCenter: NoticePosting {
    struct Entry { let kind: String; let effectiveAtAdd: Bool; let at: Date }
    var log: [Entry] = []
    weak var app: AppState?

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        let kind = request.content.userInfo["diskindex.noticeEvent"] as? String ?? ""
        log.append(Entry(kind: kind, effectiveAtAdd: app?.appSettings.notificationsEnabled ?? false, at: Date()))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { completionHandler?(nil) }
    }

    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {}
}

extension WindowTestGroup {
@MainActor
@Suite
struct NoticeToggleOrderTests {
    private func withCenter(_ body: (AppState, DelayedCenter) async -> Void) async {
        let previousCenter = SystemNotice.center
        let previousHandler = SystemNotice.testPostHandler
        SystemNotice.testPostHandler = nil
        defer {
            SystemNotice.center = previousCenter
            SystemNotice.testPostHandler = previousHandler
        }
        let app = AppState()
        let center = DelayedCenter()
        center.app = app
        SystemNotice.center = center
        await body(app, center)
    }

    private func spin(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    @Test func offPostsBeforeEffectiveFalls() async {
        await withCenter { app, center in
            app.appSettings.notificationsEnabled = true
            app.setNotificationsEnabled(false)
            #expect(center.log.map(\.kind) == [SystemNotice.noticesOffKind])
            #expect(center.log.first?.effectiveAtAdd == true)
            await spin(0.1)
            #expect(app.appSettings.notificationsEnabled == true)
            #expect(app.notificationsToggleShown == false)
            await spin(0.25)
            #expect(app.appSettings.notificationsEnabled == false)
            #expect(app.notificationsToggleShown == false)
        }
    }

    @Test func onSetsEffectiveBeforePosting() async {
        await withCenter { app, center in
            app.appSettings.notificationsEnabled = false
            app.setNotificationsEnabled(true)
            #expect(center.log.map(\.kind) == [SystemNotice.noticesOnKind])
            #expect(center.log.first?.effectiveAtAdd == true)
            #expect(app.notificationsToggleShown == true)
        }
    }

    @Test func rapidToggleEndsWithLastClick() async {
        await withCenter { app, center in
            app.appSettings.notificationsEnabled = false
            let start = Date(timeIntervalSince1970: 50_000)
            app.setNotificationsEnabled(true, now: start)
            app.setNotificationsEnabled(false, now: start.addingTimeInterval(0.05))
            app.setNotificationsEnabled(true, now: start.addingTimeInterval(0.1))
            await spin(0.35)
            #expect(app.appSettings.notificationsEnabled == true)
            #expect(app.notificationsToggleShown == true)
            let kinds = center.log.map(\.kind)
            #expect(kinds.filter { $0 == SystemNotice.noticesOnKind }.count <= 1)
            #expect(kinds.filter { $0 == SystemNotice.noticesOffKind }.count <= 1)
        }
    }

    @Test func willPresentShowsToggleNoticesEvenWhenOff() {
        let full: UNNotificationPresentationOptions = [.banner, .list, .sound]
        #expect(SystemNotice.presentationOptions(kind: SystemNotice.noticesOffKind, notificationsEnabled: false) == full)
        #expect(SystemNotice.presentationOptions(kind: SystemNotice.noticesOnKind, notificationsEnabled: false) == full)
        #expect(SystemNotice.presentationOptions(kind: "system", notificationsEnabled: false) == [])
        #expect(SystemNotice.presentationOptions(kind: "system", notificationsEnabled: true) == full)
    }
}
}

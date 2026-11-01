//
//  NoticeToggleOrderTests.swift
//  DiskArchiveTests
//
//  Aufgabe 168: „Mitteilungen sind ausgeschaltet.“ wird zugestellt, bevor der wirksame Wert fällt.
//

import Foundation
import Testing
import UserNotifications
@testable import DiskArchive

@MainActor
private final class DelayedCenter: NoticePosting {
    struct Entry { let kind: String; let effectiveAtAdd: Bool; let at: Date }
    var log: [Entry] = []
    weak var app: AppState?
    /// bug.0.3.8.007: Zustellbestätigungen werden gehalten, bis der Test sie mit `completeAll()` auslöst
    /// (statt fester 0,2 s per `asyncAfter`).
    private var pending: [@Sendable (Error?) -> Void] = []

    var pendingCount: Int { pending.count }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        let kind = request.content.userInfo["diskarchive.noticeEvent"] as? String ?? ""
        log.append(Entry(kind: kind, effectiveAtAdd: app?.appSettings.notificationsEnabled ?? false, at: Date()))
        if let completionHandler { pending.append(completionHandler) }
    }

    /// Meldet alle gehaltenen Mitteilungen als zugestellt und wartet, bis die daraus auf dem Main Actor
    /// eingereihten Folgeschritte gelaufen sind (Main Actor arbeitet seine Aufträge der Reihe nach ab).
    func completeAll() async {
        let handlers = pending
        pending.removeAll()
        for handler in handlers { handler(nil) }
        await Task { @MainActor in }.value
    }

    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {}
}

extension WindowTestGroup {
@MainActor
@Suite
struct NoticeToggleOrderTests {
    /// bug.0.3.9.001: Attrappe nur für diesen Task (`@TaskLocal`), kein prozessweites `SystemNotice.center`.
    private func withCenter(_ body: (AppState, DelayedCenter) async -> Void) async {
        let app = AppState()
        let center = DelayedCenter()
        center.app = app
        await SystemNotice.$testHooks.withValue(NoticeTestHooks(center: center)) {
            await body(app, center)
        }
    }

    @Test func offPostsBeforeEffectiveFalls() async {
        await withCenter { app, center in
            app.appSettings.notificationsEnabled = true
            app.setNotificationsEnabled(false)
            #expect(center.log.map(\.kind) == [SystemNotice.noticesOffKind])
            #expect(center.log.first?.effectiveAtAdd == true)
            // bug.0.3.8.007: Vor der Zustellbestätigung bleibt der wirksame Wert stehen — ohne Zeitfenster,
            // die Bestätigung wird gehalten.
            await Task.yield()
            #expect(center.pendingCount == 1)
            #expect(app.appSettings.notificationsEnabled == true)
            #expect(app.notificationsToggleShown == false)
            await center.completeAll()
            let fell = await waitUntil { !app.appSettings.notificationsEnabled }
            #expect(fell, "der wirksame Wert ist nach der Zustellung nicht gefallen")
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
            // bug.0.3.8.007: statt 0,35 s zu warten, die gehaltene „Aus“-Bestätigung ausdrücklich zustellen; sie
            // gehört zu einem überholten Klick und darf den letzten Stand nicht mehr kippen.
            await center.completeAll()
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

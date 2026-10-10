//
//  SystemNoticePostingTests.swift
//  diskindexTests
//
//  Aufgabe 135 — Mitteilungen nur wenn erlaubt; eine Anfrage je Ereignis.
//

import Foundation
import Testing
import UserNotifications
@testable import diskindex

@Suite(.serialized) @MainActor
struct SystemNoticePostingTests {
    @Test func eachEventPostsOnceWhenAllowedAndSkipsWhenOff() {
        var requests: [(UNNotificationRequest, String)] = []
        SystemNotice.testPostHandler = { request, kind in
            requests.append((request, kind))
        }
        defer { SystemNotice.testPostHandler = nil }

        var settings = AppSettings()
        settings.notificationsEnabled = true
        settings.notifySystem = true
        settings.notifyIndexed = true
        settings.notifyFavorites = true

        SystemNotice.post(body: "Pause began", settings: settings, event: .system, kind: "pause-began")
        SystemNotice.post(body: "Pause resumed", settings: settings, event: .system, kind: "pause-resumed")
        SystemNotice.post(body: "Pause expired", settings: settings, event: .system, kind: "pause-expired")
        SystemNotice.postIndexedComplete(
            name: "Stick",
            objectCount: 100,
            durationSeconds: 60,
            settings: settings
        )
        SystemNotice.postFavoritesOnline(name: "Stick", favoriteCount: 3, settings: settings)
        SystemNotice.postIndexingFailure(
            mediumID: UUID(),
            name: "Stick",
            reason: .timeout,
            settings: settings
        )

        #expect(requests.count == 6)
        #expect(requests.map(\.1) == [
            "pause-began", "pause-resumed", "pause-expired", "indexed", "favorites", "indexing-failure"
        ])

        requests.removeAll()
        settings.notificationsEnabled = false
        SystemNotice.post(body: "x", settings: settings, event: .system, kind: "pause-began")
        SystemNotice.postIndexedComplete(name: "X", objectCount: 1, durationSeconds: 60, settings: settings)
        SystemNotice.postFavoritesOnline(name: "X", favoriteCount: 1, settings: settings)
        SystemNotice.postIndexingFailure(mediumID: UUID(), name: "X", reason: .timeout, settings: settings)
        #expect(requests.isEmpty)

        requests.removeAll()
        settings.notificationsEnabled = true
        settings.notifySystem = false
        settings.notifyIndexed = false
        settings.notifyFavorites = false
        SystemNotice.post(body: "sys", settings: settings, event: .system, kind: "pause-began")
        SystemNotice.postIndexedComplete(name: "X", objectCount: 1, durationSeconds: 60, settings: settings)
        SystemNotice.postFavoritesOnline(name: "X", favoriteCount: 1, settings: settings)
        #expect(requests.isEmpty)
    }

    @Test func indexedNoticeRespectsDurationThreshold() {
        var count = 0
        SystemNotice.testPostHandler = { _, _ in count += 1 }
        defer { SystemNotice.testPostHandler = nil }

        var settings = AppSettings()
        settings.notificationsEnabled = true
        settings.notifyIndexed = true
        SystemNotice.postIndexedComplete(name: "Kurz", objectCount: 10, durationSeconds: 59, settings: settings)
        #expect(count == 0)
        SystemNotice.postIndexedComplete(name: "Lang", objectCount: 10, durationSeconds: 59.1, settings: settings)
        #expect(count == 1)
    }
}

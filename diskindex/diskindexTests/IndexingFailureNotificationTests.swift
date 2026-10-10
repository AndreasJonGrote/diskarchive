//
//  IndexingFailureNotificationTests.swift
//  diskindexTests
//
//  Aufgabe 112 Punkt 2 — Mitteilung öffnet Dialog.
//

import Foundation
import Testing
@testable import diskindex

@Suite @MainActor struct IndexingFailureNotificationTests {
    @Test func notificationUserInfoReopensFailureDialog() {
        let app = AppState()
        let mediumID = UUID()
        let info: [AnyHashable: Any] = [
            DiskIndexNotificationUserInfoKey.action: DiskIndexNotificationAction.indexingFailure.rawValue,
            DiskIndexNotificationUserInfoKey.mediumID: mediumID.uuidString,
            DiskIndexNotificationUserInfoKey.mediumName: "Stick A",
            DiskIndexNotificationUserInfoKey.failureReason: IndexFailureReason.permission.notificationCode,
        ]
        #expect(app.openIndexingFailureFromNotification(userInfo: info))
        #expect(app.indexingFailure?.id == mediumID)
        #expect(app.indexingFailure?.name == "Stick A")
        #expect(app.indexingFailure?.reason == .permission)
    }

    @Test func unknownUserInfoIsIgnored() {
        let app = AppState()
        #expect(!app.openIndexingFailureFromNotification(userInfo: ["foo": "bar"]))
        #expect(app.indexingFailure == nil)
    }
}

//
//  IndexingFailureNotificationTests.swift
//  DiskArchiveTests
//
//  Aufgabe 112 Punkt 2 — Mitteilung öffnet Dialog.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite @MainActor struct IndexingFailureNotificationTests {
    @Test func notificationUserInfoReopensFailureDialog() {
        let app = AppState()
        let mediumID = UUID()
        let info: [AnyHashable: Any] = [
            DiskArchiveNotificationUserInfoKey.action: DiskArchiveNotificationAction.indexingFailure.rawValue,
            DiskArchiveNotificationUserInfoKey.mediumID: mediumID.uuidString,
            DiskArchiveNotificationUserInfoKey.mediumName: "Stick A",
            DiskArchiveNotificationUserInfoKey.failureReason: IndexFailureReason.permission.notificationCode,
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

//
//  NotificationRouting.swift
//  DiskArchive
//
//  Mitteilungen → Hauptfenster (Aufgabe 112 Punkt 2).
//

import Foundation

enum DiskArchiveNotificationAction: String {
    case indexingFailure = "indexingFailure"
}

enum DiskArchiveNotificationUserInfoKey {
    static let action = "diskarchive.action"
    static let mediumID = "diskarchive.mediumID"
    static let mediumName = "diskarchive.mediumName"
    static let failureReason = "diskarchive.failureReason"
}

extension AppState {
    /// Klick auf Indizierungsfehler-Mitteilung: Dialog wieder anzeigen.
    @discardableResult
    func openIndexingFailureFromNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard userInfo[DiskArchiveNotificationUserInfoKey.action] as? String == DiskArchiveNotificationAction.indexingFailure.rawValue,
              let idString = userInfo[DiskArchiveNotificationUserInfoKey.mediumID] as? String,
              let id = UUID(uuidString: idString),
              let name = userInfo[DiskArchiveNotificationUserInfoKey.mediumName] as? String,
              let code = userInfo[DiskArchiveNotificationUserInfoKey.failureReason] as? String,
              let reason = IndexFailureReason(notificationCode: code)
        else { return false }
        indexingFailure = IndexingFailureNotice(id: id, name: name, reason: reason)
        return true
    }
}

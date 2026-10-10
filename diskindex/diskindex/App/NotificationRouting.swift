//
//  NotificationRouting.swift
//  diskindex
//
//  Mitteilungen → Hauptfenster (Aufgabe 112 Punkt 2).
//

import Foundation

enum DiskIndexNotificationAction: String {
    case indexingFailure = "indexingFailure"
}

enum DiskIndexNotificationUserInfoKey {
    static let action = "diskindex.action"
    static let mediumID = "diskindex.mediumID"
    static let mediumName = "diskindex.mediumName"
    static let failureReason = "diskindex.failureReason"
}

extension AppState {
    /// Klick auf Indizierungsfehler-Mitteilung: Dialog wieder anzeigen.
    @discardableResult
    func openIndexingFailureFromNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard userInfo[DiskIndexNotificationUserInfoKey.action] as? String == DiskIndexNotificationAction.indexingFailure.rawValue,
              let idString = userInfo[DiskIndexNotificationUserInfoKey.mediumID] as? String,
              let id = UUID(uuidString: idString),
              let name = userInfo[DiskIndexNotificationUserInfoKey.mediumName] as? String,
              let code = userInfo[DiskIndexNotificationUserInfoKey.failureReason] as? String,
              let reason = IndexFailureReason(notificationCode: code)
        else { return false }
        indexingFailure = IndexingFailureNotice(id: id, name: name, reason: reason)
        return true
    }
}

//
//  SystemNotice.swift
//  diskindex
//

import Foundation
import GRDB
import UserNotifications

/// Dieselbe Meldungsart höchstens alle 5 Sekunden. Die andere Art ist unabhängig.
final class NoticeThrottle {
    private var last: [String: Date] = [:]

    func allow(_ kind: String, now: Date) -> Bool {
        if let previous = last[kind], now.timeIntervalSince(previous) < 5 { return false }
        last[kind] = now
        return true
    }
}

extension AppState {
    /// Aus: Meldung erst zustellen, dann den wirksamen Wert setzen — sonst unterdrückt `willPresent` sie.
    /// An: erst den wirksamen Wert, dann die Meldung. Der letzte Klick bestimmt den Endzustand.
    func setNotificationsEnabled(_ enabled: Bool, now: Date = Date()) {
        noticeToggleSequence += 1
        let sequence = noticeToggleSequence
        notificationsToggleShown = enabled
        if enabled {
            appSettings.notificationsEnabled = true
            settleNotificationsToggleShown()
            if noticeThrottle.allow(SystemNotice.noticesOnKind, now: now) {
                SystemNotice.postUnfiltered(body: LayoutCopy.noticesTurnedOn, kind: SystemNotice.noticesOnKind)
            }
            return
        }
        guard noticeThrottle.allow(SystemNotice.noticesOffKind, now: now) else {
            appSettings.notificationsEnabled = false
            settleNotificationsToggleShown()
            return
        }
        SystemNotice.postUnfiltered(body: LayoutCopy.noticesTurnedOff, kind: SystemNotice.noticesOffKind) { [weak self] in
            guard let self, self.noticeToggleSequence == sequence else { return }
            self.appSettings.notificationsEnabled = false
            self.settleNotificationsToggleShown()
        }
    }
}

nonisolated enum NoticeCopy {
    static func preview(_ event: DiskNotice) -> String {
        switch event {
        case .system: LayoutCopy.previewSystem
        case .indexed: LayoutCopy.previewIndexed
        case .favorites: LayoutCopy.previewFavorites
        }
    }

    static let minimumVisibleSeconds: TimeInterval = 59
}

protocol NoticePosting: AnyObject {
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void)
}

extension UNUserNotificationCenter: NoticePosting {}

#if DEBUG
/// Testattrappe je Task (bug.0.3.9.001, Regel 20): `post` fängt Posts ab, `center` ersetzt die Mitteilungszentrale.
/// Gilt nur innerhalb von `SystemNotice.$testHooks.withValue(…)`, nie prozessweit.
@MainActor
final class NoticeTestHooks {
    let center: NoticePosting?
    let post: ((UNNotificationRequest, String) -> Void)?
    /// bug.0.4.190: fängt das Zurückziehen zugestellter Mitteilungen ab (Kennung).
    let withdraw: ((String) -> Void)?

    init(
        center: NoticePosting? = nil,
        post: ((UNNotificationRequest, String) -> Void)? = nil,
        withdraw: ((String) -> Void)? = nil
    ) {
        self.center = center
        self.post = post
        self.withdraw = withdraw
    }
}
#endif

enum SystemNotice {
    @MainActor
    static let center: NoticePosting = UNUserNotificationCenter.current()

    #if DEBUG
    /// Tests: Attrappe für den laufenden Task (statt eines prozessweiten Schalters).
    @TaskLocal static var testHooks: NoticeTestHooks?
    #endif

    @MainActor
    private static var activeCenter: NoticePosting {
        #if DEBUG
        if let hooked = testHooks?.center { return hooked }
        #endif
        return center
    }

    nonisolated static let noticesOnKind = "notices-on"
    nonisolated static let noticesOffKind = "notices-off"

    /// Entscheidung für `willPresent`: Schalter-Meldungen immer, alle anderen nur bei eingeschalteten Mitteilungen.
    nonisolated static func presentationOptions(kind: String?, notificationsEnabled: Bool) -> UNNotificationPresentationOptions {
        if kind == noticesOnKind || kind == noticesOffKind || notificationsEnabled {
            return [.banner, .list, .sound]
        }
        return []
    }

    /// Ein- und Ausschalten der Mitteilungen: ohne den Unterpunkt „Systemmeldungen“.
    @MainActor
    static func postUnfiltered(body: String, kind: String, added: (@MainActor () -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = LayoutCopy.diskIndex
        content.body = body
        content.userInfo = ["diskindex.noticeEvent": kind]
        let request = UNNotificationRequest(
            identifier: "diskindex.notice-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        submit(request, kind: kind, added: added)
    }

    @MainActor
    static func post(body: String, settings: AppSettings, event: DiskNotice = .system, kind: String = "system") {
        guard event.allowed(by: settings) else { return }
        let content = UNMutableNotificationContent()
        content.title = LayoutCopy.diskIndex
        content.body = body
        content.userInfo = ["diskindex.noticeEvent": kind]
        let request = UNNotificationRequest(
            identifier: "diskindex.notice-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        submit(request, kind: kind)
    }

    /// Speichermedium vollständig indiziert — nur wenn Lauf > 59 s (README).
    @MainActor
    static func postIndexedComplete(
        name: String,
        objectCount: Int,
        durationSeconds: TimeInterval,
        settings: AppSettings
    ) {
        guard durationSeconds > NoticeCopy.minimumVisibleSeconds else { return }
        let count = DisplayNumberFormat.groupedInteger(objectCount)
        let body = LayoutCopy.noticeIndexedComplete(name, count)
        post(body: body, settings: settings, event: .indexed, kind: "indexed")
    }

    /// Speichermedium mit Favoriten angeschlossen.
    @MainActor
    static func postFavoritesOnline(name: String, favoriteCount: Int, settings: AppSettings) {
        guard favoriteCount > 0 else { return }
        let count = DisplayNumberFormat.groupedInteger(favoriteCount)
        let body = LayoutCopy.noticeFavoritesOnline(name, count)
        post(body: body, settings: settings, event: .favorites, kind: "favorites")
    }

    nonisolated static func indexingFailureIdentifier(mediumID: UUID) -> String {
        "diskindex.indexing-failure-\(mediumID.uuidString)"
    }

    /// bug.0.4.190: Der Hinweis wurde zurückgenommen – die schon zugestellte Mitteilung dieses Mediums auch.
    @MainActor
    static func withdrawIndexingFailure(mediumID: UUID) {
        let identifier = indexingFailureIdentifier(mediumID: mediumID)
        #if DEBUG
        if let withdraw = testHooks?.withdraw {
            withdraw(identifier)
            return
        }
        // bug.0.4.193: in Tests nie ins echte Mitteilungszentrum.
        if testHooks?.post != nil || RuntimeEnvironment.isRunningTests { return }
        #endif
        (activeCenter as? UNUserNotificationCenter)?.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    @MainActor
    static func postIndexingFailure(mediumID: UUID, name: String, reason: IndexFailureReason, settings: AppSettings) {
        guard DiskNotice.system.allowed(by: settings) else { return }
        let content = UNMutableNotificationContent()
        content.title = LayoutCopy.diskIndex
        let detail = reason.line ?? LayoutCopy.indexFailedBody
        content.body = "\(name): \(detail)"
        content.userInfo = [
            DiskIndexNotificationUserInfoKey.action: DiskIndexNotificationAction.indexingFailure.rawValue,
            DiskIndexNotificationUserInfoKey.mediumID: mediumID.uuidString,
            DiskIndexNotificationUserInfoKey.mediumName: name,
            DiskIndexNotificationUserInfoKey.failureReason: reason.notificationCode,
        ]
        let request = UNNotificationRequest(
            identifier: indexingFailureIdentifier(mediumID: mediumID),
            content: content,
            trigger: nil
        )
        submit(request, kind: "indexing-failure")
    }

    @MainActor
    static func submit(_ request: UNNotificationRequest, kind: String, added: (@MainActor () -> Void)? = nil) {
        #if DEBUG
        if let testPost = testHooks?.post {
            testPost(request, kind)
            added?()
            return
        }
        #endif
        logAuthorizationStatus()
        activeCenter.add(request) { error in
            if let error {
                DiskIndexLog.shared.record(.app, .error, "notice post failed kind=\(kind) \(DiskIndexLog.errorSummary(error))")
            } else {
                DiskIndexLog.shared.record(.app, .info, "notice posted kind=\(kind)")
            }
            guard let added else { return }
            Task { @MainActor in added() }
        }
    }

    @MainActor
    static func logAuthorizationStatus() {
        #if DEBUG
        if testHooks?.post != nil { return }
        #endif
        activeCenter.getNotificationSettings { settings in
            let status: String
            switch settings.authorizationStatus {
            case .notDetermined: status = "notDetermined"
            case .denied: status = "denied"
            case .authorized: status = "authorized"
            case .provisional: status = "provisional"
            case .ephemeral: status = "ephemeral"
            @unknown default: status = "unknown"
            }
            let alert: String
            switch settings.alertSetting {
            case .enabled: alert = "enabled"
            case .disabled: alert = "disabled"
            case .notSupported: alert = "notSupported"
            @unknown default: alert = "unknown"
            }
            DiskIndexLog.shared.record(.app, .info, "notice auth status=\(status) alert=\(alert)")
        }
    }
}

nonisolated enum DiskNotice: Equatable {
    case system
    case indexed
    case favorites

    func allowed(by settings: AppSettings) -> Bool {
        guard settings.notificationsEnabled else { return false }
        switch self {
        case .system: return settings.notifySystem
        case .indexed: return settings.notifyIndexed
        case .favorites: return settings.notifyFavorites
        }
    }
}

nonisolated enum IndexFailureReason: Equatable {
    case permission
    case disconnected
    case timeout
    /// bug.0.4.182: Das Medium war am Ende des Laufs nicht zu bestätigen, ohne dass es ausgehängt wurde.
    case unconfirmed
    case diskSpace
    case database
    case unknown

    var notificationCode: String {
        switch self {
        case .permission: "permission"
        case .disconnected: "disconnected"
        case .timeout: "timeout"
        case .unconfirmed: "unconfirmed"
        case .diskSpace: "diskSpace"
        case .database: "database"
        case .unknown: "unknown"
        }
    }

    init?(notificationCode: String) {
        switch notificationCode {
        case "permission": self = .permission
        case "disconnected": self = .disconnected
        case "timeout": self = .timeout
        case "unconfirmed": self = .unconfirmed
        case "diskSpace": self = .diskSpace
        case "database": self = .database
        case "unknown": self = .unknown
        default: return nil
        }
    }

    var line: String? {
        switch self {
        case .permission:
            return LayoutCopy.permissionLine
        case .disconnected:
            return LayoutCopy.failureDisconnected
        case .timeout:
            return LayoutCopy.failureTimeout
        case .unconfirmed:
            return LayoutCopy.failureUnconfirmed
        case .diskSpace:
            return LayoutCopy.failureDiskSpace
        case .database:
            return LayoutCopy.failureDatabase
        case .unknown:
            return nil
        }
    }

    /// Grund aus dem Fehlerobjekt (POSIX-/Cocoa-Code, SQLite-Code, Store-Fehler), nie aus Text.
    static func classify(_ error: Error) -> IndexFailureReason {
        if error is DirectoryReadStalled { return .timeout }
        if let store = error as? IndexStoreError {
            return store == .directoryWriteFailed ? .database : .unknown
        }
        if let database = error as? DatabaseError {
            return database.resultCode == .SQLITE_FULL ? .diskSpace : .database
        }
        guard let code = posixCode(of: error) else { return .unknown }
        switch code {
        case EACCES, EPERM: return .permission
        case ENXIO, ENODEV, ENOENT: return .disconnected
        case ENOSPC: return .diskSpace
        default: return .unknown
        }
    }

    private static func posixCode(of error: Error) -> Int32? {
        if let posix = error as? POSIXError { return Int32(posix.errorCode) }
        let ns = error as NSError
        if ns.domain == NSPOSIXErrorDomain { return Int32(ns.code) }
        if ns.domain == NSCocoaErrorDomain {
            switch CocoaError.Code(rawValue: ns.code) {
            case .fileReadNoPermission, .fileWriteNoPermission: return EACCES
            case .fileNoSuchFile, .fileReadNoSuchFile: return ENOENT
            case .fileWriteOutOfSpace: return ENOSPC
            default: break
            }
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            return posixCode(of: underlying)
        }
        return nil
    }
}

nonisolated enum FailureModalThrottle {
    static func allowsAutomatic(shown: Int, hourStart: Date, now: Date) -> Bool {
        if now.timeIntervalSince(hourStart) >= 3_600 { return true }
        return shown < 3
    }
}

nonisolated enum NoticePermission {
    static let askedKey = "diskindex.noticePermissionAsked"

    static func shouldRequest(arguments: [String], defaults: UserDefaults) -> Bool {
        if arguments.contains(AppLaunch.backgroundArgument) {
            return false
        }
        return !defaults.bool(forKey: askedKey)
    }
}

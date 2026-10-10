//
//  SystemNotice.swift
//  diskindex
//

import Foundation
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

enum SystemNotice {
    @MainActor
    static var center: NoticePosting = UNUserNotificationCenter.current()

    #if DEBUG
    /// Tests: fängt Posts ab, ohne `UNUserNotificationCenter` global zu ersetzen (Paralleltests).
    @MainActor
    static var testPostHandler: ((UNNotificationRequest, String) -> Void)?
    #endif

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
        let body = "Medium „\(name)“ ist vollständig indiziert – \(count) Objekte"
        post(body: body, settings: settings, event: .indexed, kind: "indexed")
    }

    /// Speichermedium mit Favoriten angeschlossen.
    @MainActor
    static func postFavoritesOnline(name: String, favoriteCount: Int, settings: AppSettings) {
        guard favoriteCount > 0 else { return }
        let count = DisplayNumberFormat.groupedInteger(favoriteCount)
        let body = "Medium „\(name)“ mit \(count) Favoriten ist online"
        post(body: body, settings: settings, event: .favorites, kind: "favorites")
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
            identifier: "diskindex.indexing-failure-\(mediumID.uuidString)",
            content: content,
            trigger: nil
        )
        submit(request, kind: "indexing-failure")
    }

    @MainActor
    static func submit(_ request: UNNotificationRequest, kind: String, added: (@MainActor () -> Void)? = nil) {
        #if DEBUG
        if let testPostHandler {
            testPostHandler(request, kind)
            added?()
            return
        }
        #endif
        logAuthorizationStatus()
        center.add(request) { error in
            if let error {
                DiskIndexLog.shared.record(.app, .error, "notice post failed kind=\(kind) \(error.localizedDescription)")
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
        if testPostHandler != nil { return }
        #endif
        center.getNotificationSettings { settings in
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
    case diskSpace
    case database
    case unknown

    var notificationCode: String {
        switch self {
        case .permission: "permission"
        case .disconnected: "disconnected"
        case .timeout: "timeout"
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
            return "Die Verbindung zum Medium wurde unterbrochen."
        case .timeout:
            return "Das Medium reagiert nicht."
        case .diskSpace:
            return "Auf diesem Mac ist nicht genug Speicherplatz frei."
        case .database:
            return "Der Index konnte nicht gespeichert werden."
        case .unknown:
            return nil
        }
    }

    static func classify(_ message: String) -> IndexFailureReason {
        let lower = message.lowercased()
        if lower.contains("permission") || lower.contains("zugriff") || lower.contains("not permitted") { return .permission }
        if lower.contains("space") || lower.contains("speicherplatz") || lower.contains("disk full") { return .diskSpace }
        if lower.contains("timeout") || lower.contains("zeit") { return .timeout }
        if lower.contains("database") || lower.contains("sqlite") { return .database }
        if lower.contains("unmount") || lower.contains("disconnect") || lower.contains("unterbrochen") { return .disconnected }
        return .unknown
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
    /// Gleicher Schalter wie `ScreenshotPlan.argument` (DebugTools); hier als Literal für Release.
    private static let screenshotsArgument = "--screenshots"

    static func shouldRequest(arguments: [String], defaults: UserDefaults) -> Bool {
        if arguments.contains(screenshotsArgument) || arguments.contains(AppLaunch.backgroundArgument) {
            return false
        }
        #if BENCH
        if arguments.contains(ColumnLoadBench.argument) { return false }
        #endif
        return !defaults.bool(forKey: askedKey)
    }
}

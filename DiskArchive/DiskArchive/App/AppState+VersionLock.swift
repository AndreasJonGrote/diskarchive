//
//  AppState+VersionLock.swift
//  DiskArchive
//
//  Versions-Sperre und Update-Hinweis (c.0.3.3.001).
//

import Foundation

extension AppState {
    var featureAccess: FeatureAccess {
        FeatureAccess(lockState: versionLockState)
    }

    func applyVersionLockEvaluation(_ evaluation: VersionLockEvaluation) {
        let wasLocked = versionLockState.isLocked
        versionLockState = evaluation.lockState
        versionLockBannerVisible = evaluation.showLockBanner
        betaNoticeDeadline = evaluation.betaNoticeDeadline
        // todo.0.4.047: Mit „Auf Updates hinweisen“ aus erscheint kein Updatedialog – außer Beta-Countdown oder Sperre
        // (die erscheinen immer). Der Haken im Dialog gilt bis zum Schließen; ein neuer Stand behält ihn.
        if let offer = evaluation.updateOffer,
           appSettings.notifyAboutUpdates || offer.showBetaCountdown || offer.urgent || evaluation.showLockBanner {
            let notify = updateNotice?.notifyAboutUpdates ?? appSettings.notifyAboutUpdates
            updateNotice = UpdateNotice(offer: offer, notifyAboutUpdates: notify)
        } else {
            updateNotice = nil
        }
        if wasLocked, !evaluation.lockState.isLocked, ruleReconcileDeferredWhileLocked {
            ruleReconcileDeferredWhileLocked = false
            enqueueRuleReconcile()
        }
    }

    /// todo.0.4.047: Schließen über einen der Knöpfe (oder daneben) speichert den Haken „Auf Updates hinweisen“.
    func dismissUpdateNotice() {
        guard let notice = updateNotice else { return }
        if appSettings.notifyAboutUpdates != notice.notifyAboutUpdates {
            appSettings.notifyAboutUpdates = notice.notifyAboutUpdates
        }
        updateNotice = nil
    }

    /// todo.0.4.047, todo.0.4.2.004: „Zur neuen Version“ – Dialog schließen (Haken speichern), Startseite öffnen.
    func openUpdateWebsite() {
        dismissUpdateNotice()
        openExternalURL(AppLinks.websiteURL)
    }

    /// todo.0.4.3.020 (Layout 04.03a–04.06): Banner zwischen Werkzeugleiste und Inhalt. Rot (Sperre) gewinnt vor Gelb;
    /// gelb nur, solange die Beta-Frist läuft. Während des Update-Dialogs keiner (der Banner folgt ihm).
    func readOnlyBanner(now: Date = .now) -> ReadOnlyBanner? {
        guard updateNotice == nil else { return nil }
        switch versionLockState {
        case .locked(let reason):
            guard versionLockBannerVisible else { return nil }
            switch reason {
            case .betaExpired: return .betaExpired
            case .buildExpired: return .buildExpired
            case .apiUnreachable: return licenseServerCheckInProgress ? .checking : .licenseServerUnreachable
            }
        case .unlocked:
            guard let deadline = betaNoticeDeadline, now < deadline else { return nil }
            let days = Int((deadline.timeIntervalSince(now) / 86_400).rounded(.up))
            return .betaNotice(daysLeft: max(1, days))
        }
    }

    /// todo.0.4.3.020 (Layout 04.04/04.05): „Jetzt prüfen“ – Spinner, bis die Antwort da ist. Antwortet der Lizenzserver,
    /// wertet `VersionCheckCoordinator` neu aus (Banner weg, neue Version meldet der Update-Dialog); sonst bleibt rot.
    func checkLicenseServerNow() {
        guard !licenseServerCheckInProgress, let check = onCheckLicenseServerNow else { return }
        DiskArchiveLog.shared.ui("license server check now")
        licenseServerCheckInProgress = true
        Task { [weak self] in
            _ = await check()
            self?.licenseServerCheckInProgress = false
        }
    }
}

/// todo.0.4.3.020: Inhalt des Banners je Zustand (Layout 04.05).
enum ReadOnlyBanner: Equatable {
    case betaNotice(daysLeft: Int)
    case betaExpired
    case buildExpired
    case licenseServerUnreachable
    case checking

    enum Action: Equatable {
        case website
        case checkNow
    }

    /// Gelb = Hinweis, Rot = Sperre.
    var isLock: Bool {
        if case .betaNotice = self { return false }
        return true
    }

    var iconAsset: String? {
        switch self {
        case .betaNotice: "IconBannerWarning"
        case .betaExpired, .buildExpired: "IconLockSimple"
        case .licenseServerUnreachable: "IconWifiSlash"
        case .checking: nil
        }
    }

    var title: String {
        switch self {
        case .betaNotice: LayoutCopy.bannerBetaNoticeTitle
        case .betaExpired, .buildExpired, .licenseServerUnreachable: LayoutCopy.bannerReadOnlyTitle
        case .checking: LayoutCopy.bannerChecking
        }
    }

    var info: String? {
        switch self {
        case .betaNotice(let days): LayoutCopy.bannerBetaNoticeDays(days)
        case .betaExpired: LayoutCopy.bannerReadOnlyBeta
        case .buildExpired: LayoutCopy.bannerReadOnlyBuild
        case .licenseServerUnreachable: LayoutCopy.bannerReadOnlyLicenseServer
        case .checking: nil
        }
    }

    var action: (title: String, kind: Action)? {
        switch self {
        case .betaNotice, .betaExpired, .buildExpired: (LayoutCopy.updateAvailableDownload, .website)
        case .licenseServerUnreachable: (LayoutCopy.bannerCheckNow, .checkNow)
        case .checking: nil
        }
    }
}

struct UpdateNotice: Equatable {
    var offer: UpdateOffer
    /// Haken „Auf Updates hinweisen“ im Dialog (Vorbelegung: die Einstellung).
    var notifyAboutUpdates: Bool
}

/// todo.0.4.047, todo.0.4.2.004: feste Adressen der App (eine Stelle). Eine Download-Seite gibt es nicht;
/// Update-Knopf und „Über Disk Archive“ führen auf die Startseite.
enum AppLinks {
    nonisolated static let website = "https://diskarchive.app"
    static let websiteURL: URL = {
        guard let url = URL(string: website) else { preconditionFailure("Website-Adresse") }
        return url
    }()
}

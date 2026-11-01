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
        // todo.0.4.047: Mit „Auf Updates hinweisen“ aus erscheint kein Updatedialog – außer Beta-Countdown oder Sperre
        // (die erscheinen immer). Der Haken im Dialog gilt bis zum Schließen; ein neuer Stand behält ihn.
        if let offer = evaluation.updateOffer,
           appSettings.notifyAboutUpdates || offer.showBetaCountdown || evaluation.showLockBanner {
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

    func versionLockBannerText() -> String? {
        guard versionLockBannerVisible else { return nil }
        switch versionLockState {
        case .unlocked:
            return nil
        case .locked(.betaExpired):
            return LayoutCopy.versionLockBannerBetaEnded
        case .locked(.apiUnreachable):
            return LayoutCopy.versionLockBannerApiOffline
        case .locked(.buildExpired):
            return LayoutCopy.versionLockBannerBuildExpired
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

//
//  AppState+VersionLock.swift
//  diskindex
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
        if let offer = evaluation.updateOffer {
            if updateNotice?.offer.targetMajorMinor != offer.targetMajorMinor {
                updateNotice = UpdateNotice(offer: offer, skipUpdate: false)
            } else if let existing = updateNotice {
                updateNotice = UpdateNotice(offer: offer, skipUpdate: existing.skipUpdate)
            } else {
                updateNotice = UpdateNotice(offer: offer, skipUpdate: false)
            }
        } else {
            updateNotice = nil
        }
        if wasLocked, !evaluation.lockState.isLocked, ruleReconcileDeferredWhileLocked {
            ruleReconcileDeferredWhileLocked = false
            enqueueRuleReconcile()
        }
    }

    func dismissUpdateNotice(saveSkip: Bool) {
        guard let notice = updateNotice else { return }
        if saveSkip, notice.offer.showSkipCheckbox, let store = indexStore {
            VersionCheckCoordinator.recordSkippedUpdate(target: notice.offer.targetMajorMinor, store: store)
        }
        updateNotice = nil
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
    var skipUpdate: Bool
}

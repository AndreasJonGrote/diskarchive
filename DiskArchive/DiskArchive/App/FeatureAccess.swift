//
//  FeatureAccess.swift
//  DiskArchive
//
//  Zentrale Schranke „Darf Index geschrieben werden?“ (c.0.3.3.001).
//

import Foundation

nonisolated enum VersionLockReason: Equatable, Sendable {
    case betaExpired
    case apiUnreachable
    case buildExpired
}

nonisolated enum VersionLockState: Equatable, Sendable {
    case unlocked
    case locked(VersionLockReason)

    var isLocked: Bool {
        if case .locked = self { return true }
        return false
    }
}

nonisolated struct UpdateOffer: Equatable, Sendable {
    var currentDisplay: String
    var targetDisplay: String
    var targetMajorMinor: AppVersion
    var showBetaCountdown: Bool
    /// todo.0.4.3.002: dringendes Update – erscheint auch bei „Auf Updates hinweisen: Aus“.
    var urgent: Bool = false
}

nonisolated struct FeatureAccess: Equatable, Sendable {
    var lockState: VersionLockState

    var canWriteIndex: Bool { !lockState.isLocked }
}

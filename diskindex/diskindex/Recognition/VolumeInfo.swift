//
//  VolumeInfo.swift
//  diskindex
//

import Foundation

nonisolated struct VolumeInfo: Sendable, Equatable {
    var mountPath: String
    var name: String
    var fsType: String
    var volumeTotalBytes: Int64
    var volumeFreeBytes: Int64?
    var diskSizeBytes: Int64?
    var volumeUUID: String?
    var createdAt: Date?
    var isRemovable: Bool
    var isEjectable: Bool
    var isInternal: Bool
    var isLocal: Bool
    var deviceProtocol: String?
    var model: String?
    var isTimeMachineSnapshot: Bool

    var identity: VolumeIdentity {
        VolumeIdentity(
            volumeUUID: volumeUUID,
            fsType: fsType,
            volumeTotalBytes: volumeTotalBytes,
            diskSizeBytes: diskSizeBytes,
            name: name,
            createdAt: createdAt
        )
    }

    var candidateInput: VolumeCandidateInput {
        VolumeCandidateInput(
            path: mountPath,
            isLocal: isLocal,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            isInternal: isInternal,
            fileSystem: fsType,
            deviceProtocol: deviceProtocol,
            isTimeMachineSnapshot: isTimeMachineSnapshot
        )
    }

    var mediumType: StoredMediumType {
        isRemovable ? .usb : .hdd
    }
}

nonisolated enum MediumEvent: Sendable, Equatable {
    case appeared(VolumeInfo)
    case willDisappear(path: String)
    case disappeared(path: String)
    /// Volume umbenannt (bug.0.4.031 b): alter Einhängepfad, Volume unter dem neuen Pfad.
    case renamed(oldPath: String, volume: VolumeInfo)
}

nonisolated struct MountEventDebouncer {
    private var lastEmitted: [String: ContinuousClock.Instant] = [:]

    mutating func shouldEmit(path: String, kind: String, now: ContinuousClock.Instant = .now) -> Bool {
        let key = "\(kind)\n\(path)"
        if let previous = lastEmitted[key], now - previous < .seconds(1) {
            return false
        }
        lastEmitted[key] = now
        return true
    }
}

//
//  VolumeInfo.swift
//  DiskArchive
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
    /// bug.0.4.230: macOS-Angabe zum Datenträger („Medium Type“ aus IOKit), `nil` wenn keine.
    var deviceMedium: DeviceMedium? = nil

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
        Self.mediumType(isRemovable: isRemovable, deviceMedium: deviceMedium)
    }

    /// bug.0.4.230 (Konzept `medien.md` 2c): wechselbar = USB; sonst Solid State = SSD, Rotational oder keine Angabe = HDD.
    static func mediumType(isRemovable: Bool, deviceMedium: DeviceMedium?) -> StoredMediumType {
        if isRemovable { return .usb }
        return deviceMedium == .solidState ? .ssd : .hdd
    }
}

/// bug.0.4.230: Art des Datenträgers laut IOKit (`"Device Characteristics"` → `"Medium Type"`).
nonisolated enum DeviceMedium: Sendable, Equatable {
    case solidState
    case rotational
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

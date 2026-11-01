//
//  VolumeCandidateRule.swift
//  DiskArchive
//

import Foundation

/// Eingabe der Kandidatenregel, ohne Plattenzugriff.
nonisolated struct VolumeCandidateInput: Sendable, Equatable {
    var path: String
    var isLocal: Bool
    var isRemovable: Bool
    var isEjectable: Bool
    var isInternal: Bool
    var fileSystem: String
    var deviceProtocol: String?
    var isTimeMachineSnapshot: Bool
}

nonisolated enum VolumeCandidateRule {
    static func isCandidate(_ volume: VolumeCandidateInput) -> Bool {
        guard volume.isLocal else { return false }
        guard volume.path.hasPrefix("/Volumes/") else { return false }
        if volume.path == "/" || volume.path.hasPrefix("/System/Volumes/") || volume.path.hasPrefix("/private/") {
            return false
        }
        if volume.fileSystem == "autofs" { return false }
        if volume.isTimeMachineSnapshot { return false }
        if isDiskImage(volume.deviceProtocol) { return false }
        return volume.isRemovable || volume.isEjectable || !volume.isInternal
    }

    private static func isDiskImage(_ protocolName: String?) -> Bool {
        guard let protocolName else { return false }
        let folded = protocolName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
        return folded.contains("virtual interface") || folded.contains("disk image")
    }
}

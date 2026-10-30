//
//  IndexingVolumeTuning.swift
//  diskindex
//

import Foundation

nonisolated enum IndexingVolumeTuning {
    static func parallelDirectoryReads(for volume: VolumeInfo) -> Int {
        parallelDirectoryReads(
            isRemovable: volume.isRemovable,
            deviceMedium: volume.deviceMedium,
            deviceProtocol: volume.deviceProtocol
        )
    }

    /// todo.0.4.051: drehend = 1, feste SSD = 4; sonst USB = 1 (Sticks, Karten, Gehäuse ohne Angabe), Rest 4.
    static func parallelDirectoryReads(isRemovable: Bool, deviceMedium: DeviceMedium?, deviceProtocol: String?) -> Int {
        if deviceMedium == .rotational { return 1 }
        if deviceMedium == .solidState, !isRemovable { return 4 }
        let proto = deviceProtocol?.lowercased() ?? ""
        return proto.contains("usb") ? 1 : 4
    }
}

//
//  IndexingVolumeTuning.swift
//  diskindex
//

import DiskArbitration
import Foundation

nonisolated enum IndexingVolumeTuning {
    static func parallelDirectoryReads(for volume: VolumeInfo) -> Int {
        if isRotational(mountPath: volume.mountPath) { return 1 }
        if volume.isInternal { return 4 }
        let proto = volume.deviceProtocol?.lowercased() ?? ""
        if proto.contains("nvme") || proto.contains("pci-express") { return 4 }
        return 4
    }

    static func isRotational(mountPath: String) -> Bool {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return false }
        let url = URL(fileURLWithPath: mountPath, isDirectory: true) as CFURL
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url) else { return false }
        guard let description = DADiskCopyDescription(disk) as? [String: Any] else { return false }
        if let solid = description["Media Solid State"] as? Bool {
            return !solid
        }
        if let protocolName = description[kDADiskDescriptionDeviceProtocolKey as String] as? String {
            let lower = protocolName.lowercased()
            if lower.contains("usb") { return true }
        }
        return false
    }
}

//
//  DiskArbitrationLookup.swift
//  DiskArchive
//

import DiskArbitration
import Foundation
import IOKit

nonisolated struct DiskArbitrationAttributes: Sendable, Equatable {
    var volumeUUID: String?
    var mediaSizeBytes: Int64?
    var deviceProtocol: String?
    var model: String?
    var isNetwork: Bool
    var deviceMedium: DeviceMedium? = nil
}

nonisolated enum DiskArbitrationLookup {
    static func attributes(path: String) -> DiskArbitrationAttributes {
        guard let session = DASessionCreate(nil) else {
            return DiskArbitrationAttributes(volumeUUID: nil, mediaSizeBytes: nil, deviceProtocol: nil, model: nil, isNetwork: false)
        }
        let url = URL(fileURLWithPath: path) as CFURL
        guard let disk = DADiskCreateFromVolumePath(nil, session, url),
              let description = DADiskCopyDescription(disk) as NSDictionary? else {
            return DiskArbitrationAttributes(volumeUUID: nil, mediaSizeBytes: nil, deviceProtocol: nil, model: nil, isNetwork: false)
        }
        return DiskArbitrationAttributes(
            volumeUUID: uuidString(description[kDADiskDescriptionVolumeUUIDKey]),
            mediaSizeBytes: (description[kDADiskDescriptionMediaSizeKey] as? NSNumber)?.int64Value,
            deviceProtocol: description[kDADiskDescriptionDeviceProtocolKey] as? String,
            model: description[kDADiskDescriptionDeviceModelKey] as? String,
            isNetwork: (description[kDADiskDescriptionVolumeNetworkKey] as? NSNumber)?.boolValue ?? false,
            deviceMedium: deviceMedium(of: disk)
        )
    }

    /// bug.0.4.230: DiskArbitration kennt kein „Solid State“; die Angabe liegt in IOKit am Gerät, mehrere Ebenen über
    /// dem Volume (bei APFS über Container und Partition).
    static func deviceMedium(of disk: DADisk) -> DeviceMedium? {
        let media = DADiskCopyIOMedia(disk)
        guard media != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(media) }
        let value = IORegistryEntrySearchCFProperty(
            media, kIOServicePlane, "Device Characteristics" as CFString, nil,
            IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively)
        )
        switch (value as? [String: Any])?["Medium Type"] as? String {
        case "Solid State": return .solidState
        case "Rotational": return .rotational
        default: return nil
        }
    }

    private static func uuidString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String { return string }
        let reference = value as CFTypeRef
        guard CFGetTypeID(reference) == CFUUIDGetTypeID() else { return nil }
        let uuid = unsafeBitCast(reference, to: CFUUID.self)
        return CFUUIDCreateString(nil, uuid) as String
    }
}

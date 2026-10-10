//
//  VolumeLookup.swift
//  diskindex
//

import Darwin
import Foundation

nonisolated enum VolumeLookup {
    static func info(at url: URL) -> VolumeInfo? {
        let path = url.path
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeCreationDateKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
            .volumeIsInternalKey, .volumeIsLocalKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let disk = DiskArbitrationLookup.attributes(path: path)
        let fsType = fileSystemType(path: path)
        let name = values.volumeName ?? url.lastPathComponent
        let snapshot = path.contains("com.apple.TimeMachine") || path.contains(".MobileBackups") || name == "Time Machine Backups"
        return VolumeInfo(
            mountPath: path,
            name: name,
            fsType: fsType,
            volumeTotalBytes: Int64(values.volumeTotalCapacity ?? 0),
            volumeFreeBytes: values.volumeAvailableCapacity.map(Int64.init),
            diskSizeBytes: disk.mediaSizeBytes,
            volumeUUID: disk.volumeUUID,
            createdAt: values.volumeCreationDate,
            isRemovable: values.volumeIsRemovable ?? false,
            isEjectable: values.volumeIsEjectable ?? false,
            isInternal: values.volumeIsInternal ?? false,
            isLocal: (values.volumeIsLocal ?? true) && !disk.isNetwork,
            deviceProtocol: disk.deviceProtocol,
            model: disk.model,
            isTimeMachineSnapshot: snapshot
        )
    }

    private static func fileSystemType(path: String) -> String {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return "" }
        return withUnsafeBytes(of: info.f_fstypename) { raw in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }
}

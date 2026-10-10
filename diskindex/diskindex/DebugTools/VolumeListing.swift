#if DEBUG
//
//  VolumeListing.swift
//  diskindex
//
//  Aufgabe 35, Abschnitt A.
//

import AppKit
import Darwin
import DiskArbitration
import Foundation

struct VolumeRow: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var path: String?
    var uuid: String
    var isCandidate: Bool
    var line: String
    var fromDiskArbitration: Bool
}

struct DiskSnapshot: Sendable {
    var line: String
    var uuid: String
    var path: String?
    var isCandidate: Bool
    var event: String
}

enum VolumeListing {
    nonisolated static func mountedRows() -> [VolumeRow] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: []) ?? []
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: keys)
            let rawUUID = values?.volumeUUIDString ?? "—"
            let uuid = displayUUID(rawUUID)
            let path = url.path
            let name = values?.volumeName ?? "—"
            let fsType = fileSystemType(path)
            let candidate = isCandidate(
                path: path,
                fsType: fsType,
                isLocal: values?.volumeIsLocal,
                removable: values?.volumeIsRemovable,
                ejectable: values?.volumeIsEjectable,
                isInternal: values?.volumeIsInternal
            )
            var parts = [
                "Volume",
                "Kandidat=\(candidate ? "ja" : "nein")",
                "Name=\(name)",
                "Pfad=\(path)",
                "UUID=\(uuid)",
                "intern=\(yesNo(values?.volumeIsInternal))",
                "extern=\(yesNo(values?.volumeIsInternal.map { !$0 }))",
                "wechselbar=\(yesNo(values?.volumeIsRemovable))",
                "auswerfbar=\(yesNo(values?.volumeIsEjectable))",
                "lokal=\(yesNo(values?.volumeIsLocal))",
                "gesamt=\(bytes(values?.volumeTotalCapacity))",
                "frei=\(bytes(values?.volumeAvailableCapacity))",
                "Dateisystem=\(fsType)",
            ]
            if candidate {
                parts.append(contentsOf: identityDetails(url: url, path: path))
            }
            return VolumeRow(
                id: "mount:\(path)",
                name: name,
                path: path,
                uuid: uuid,
                isCandidate: candidate,
                line: parts.joined(separator: " | "),
                fromDiskArbitration: false
            )
        }
    }

    nonisolated static func isCandidate(
        path: String?,
        fsType: String,
        isLocal: Bool?,
        removable: Bool?,
        ejectable: Bool?,
        isInternal: Bool?
    ) -> Bool {
        guard isLocal == true, let path, path != "/" else { return false }
        if path == "/System/Volumes" || path.hasPrefix("/System/Volumes/") { return false }
        if fsType == "autofs" { return false }
        return removable == true || ejectable == true || isInternal == false
    }

    nonisolated static func lacksUUID(_ uuid: String) -> Bool {
        let normalized = uuid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || normalized == "—" || normalized == "00000000-0000-0000-0000-000000000000"
    }

    nonisolated static func uuidNotes(mounted: [VolumeRow], disks: [DiskSnapshot]) -> [String] {
        var notes: [String] = []
        for row in mounted where row.isCandidate && lacksUUID(row.uuid) {
            notes.append("OHNE UUID: \(row.path ?? row.line)")
        }
        for disk in disks where disk.isCandidate && lacksUUID(disk.uuid) {
            notes.append("OHNE UUID: \(disk.path ?? disk.line)")
        }
        var byUUID: [String: [String]] = [:]
        for row in mounted where row.isCandidate && !lacksUUID(row.uuid) {
            byUUID[row.uuid, default: []].append(row.path ?? row.line)
        }
        for disk in disks where disk.isCandidate && !lacksUUID(disk.uuid) {
            byUUID[disk.uuid, default: []].append(disk.path ?? disk.line)
        }
        for (uuid, items) in byUUID where Set(items).count > 1 {
            notes.append("GLEICHE UUID \(uuid): \(items.joined(separator: " · "))")
        }
        if notes.isEmpty {
            notes.append("Keine Volumes ohne UUID und keine doppelten UUIDs in der bisherigen Liste.")
        }
        return notes
    }

    nonisolated static func describeDisk(_ disk: DADisk, event: String) -> DiskSnapshot {
        guard let description = DADiskCopyDescription(disk) else {
            return DiskSnapshot(line: "DiskArbitration \(event) | Beschreibung=nil", uuid: "—", path: nil, isCandidate: false, event: event)
        }
        let dict = description as NSDictionary
        let path = (dict[kDADiskDescriptionVolumePathKey] as? URL)?.path
        let uuid = uuidString(dict[kDADiskDescriptionVolumeUUIDKey])
        let fsType = string(dict[kDADiskDescriptionVolumeKindKey])
        let removable = flag(dict[kDADiskDescriptionMediaRemovableKey])
        let ejectable = flag(dict[kDADiskDescriptionMediaEjectableKey])
        let internalDisk = flag(dict[kDADiskDescriptionDeviceInternalKey])
        let network = flag(dict[kDADiskDescriptionVolumeNetworkKey]) == true
        let candidate = isCandidate(
            path: path,
            fsType: fsType,
            isLocal: path != nil && !network,
            removable: removable,
            ejectable: ejectable,
            isInternal: internalDisk
        )
        let line = [
            "DiskArbitration \(event)",
            "Kandidat=\(candidate ? "ja" : "nein")",
            path == nil ? "kein Volume (ganzes Gerät oder nicht eingehängt)" : "Volume",
            "Pfad=\(path ?? "—")",
            "UUID=\(uuid)",
            "Art=\(fsType)",
            "Protokoll=\(string(dict[kDADiskDescriptionDeviceProtocolKey]))",
            "intern=\(bool(dict[kDADiskDescriptionDeviceInternalKey]))",
            "wechselbar=\(bool(dict[kDADiskDescriptionMediaRemovableKey]))",
            "auswerfbar=\(bool(dict[kDADiskDescriptionMediaEjectableKey]))",
            "Modell=\(string(dict[kDADiskDescriptionDeviceModelKey]))",
            "Größe=\(bytes(dict[kDADiskDescriptionMediaSizeKey] as? NSNumber))",
            "mediaUUID=\(uuidString(dict[kDADiskDescriptionMediaUUIDKey]))",
            "mediaName=\(string(dict[kDADiskDescriptionMediaNameKey]))",
            "mediaContent=\(string(dict[kDADiskDescriptionMediaContentKey]))",
            "vendor=\(string(dict[kDADiskDescriptionDeviceVendorKey]))",
            "revision=\(string(dict[kDADiskDescriptionDeviceRevisionKey]))",
        ].joined(separator: " | ")
        return DiskSnapshot(line: line, uuid: uuid, path: path, isCandidate: candidate, event: event)
    }

    nonisolated private static func identityDetails(url: URL, path: String) -> [String] {
        let keys: Set<URLResourceKey> = [
            .volumeCreationDateKey,
            .volumeIdentifierKey,
            .volumeSupportsPersistentIDsKey,
            .volumeLocalizedFormatDescriptionKey,
            .fileResourceIdentifierKey,
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let created = values?.volumeCreationDate.map { ISO8601DateFormatter().string(from: $0) } ?? "—"
        let identifier = describeToken(values?.volumeIdentifier)
        let persistent = yesNo(values?.volumeSupportsPersistentIDs)
        let format = values?.volumeLocalizedFormatDescription ?? "—"
        let rootFileID = describeToken(values?.fileResourceIdentifier)
        return [
            "erstellt=\(created)",
            "volumeIdentifier=\(identifier)",
            "persistenteIDs=\(persistent)",
            "format=\(format)",
            "fsid=\(fsid(path))",
            "wurzelDateiID=\(rootFileID)",
            "ersteDateiID=\(firstFileIdentifier(url))",
        ]
    }

    nonisolated private static func firstFileIdentifier(_ root: URL) -> String {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .fileResourceIdentifierKey, .nameKey]
        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys))
        } catch {
            let ns = error as NSError
            return "Lesefehler \(ns.domain) \(ns.code)"
        }
        for child in children {
            let values = try? child.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true || values?.isDirectory == true { continue }
            return "\(child.lastPathComponent) \(describeToken(values?.fileResourceIdentifier))"
        }
        return "keine Datei"
    }

    nonisolated private static func fsid(_ path: String) -> String {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return "statfs-Fehler \(errno)" }
        return "\(info.f_fsid.val.0),\(info.f_fsid.val.1)"
    }

    nonisolated private static func describeToken(_ value: (any NSCopying & NSSecureCoding & NSObjectProtocol)?) -> String {
        guard let value else { return "—" }
        return clipped(String(describing: value))
    }

    nonisolated private static func clipped(_ text: String) -> String {
        text.count <= 160 ? text : String(text.prefix(160)) + "…"
    }

    nonisolated private static func fileSystemType(_ path: String) -> String {
        var info = statfs()
        guard statfs(path, &info) == 0 else {
            return "statfs-Fehler \(errno)"
        }
        return withUnsafeBytes(of: info.f_fstypename) { raw in
            guard let base = raw.bindMemory(to: CChar.self).baseAddress else { return "—" }
            return String(cString: base)
        }
    }

    nonisolated private static func yesNo(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "ja" : "nein"
    }

    nonisolated private static func flag(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber { return number.boolValue }
        if let value = value as? Bool { return value }
        return nil
    }

    nonisolated private static func bool(_ value: Any?) -> String {
        yesNo(flag(value))
    }

    nonisolated private static func string(_ value: Any?) -> String {
        if let text = value as? String { return text.isEmpty ? "—" : text }
        return "—"
    }

    nonisolated private static func bytes(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    nonisolated private static func bytes(_ value: NSNumber?) -> String {
        guard let value else { return "—" }
        return value.stringValue
    }

    nonisolated private static func displayUUID(_ raw: String) -> String {
        raw.isEmpty ? "—" : raw
    }

    nonisolated private static func uuidString(_ value: Any?) -> String {
        if let text = value as? String, !text.isEmpty { return text }
        if let uuid = value as? UUID { return uuid.uuidString }
        if let uuid = value as? NSUUID { return uuid.uuidString }
        if let value {
            let ref = value as CFTypeRef
            if CFGetTypeID(ref) == CFUUIDGetTypeID() {
                let uuid = unsafeBitCast(ref, to: CFUUID.self)
                return CFUUIDCreateString(nil, uuid) as String
            }
        }
        return "—"
    }
}

@MainActor
final class VolumeEventMonitor {
    var onLog: (String) -> Void = { _ in }
    var onDisk: (DiskSnapshot) -> Void = { _ in }
    var onWillUnmount: (String) -> Void = { _ in }

    private var session: DASession?
    private let queue = DispatchQueue(label: "diskindex.diagnostics.diskarb")
    private var observers: [NSObjectProtocol] = []
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        observeWorkspace()
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            onLog("DASessionCreate fehlgeschlagen")
            return
        }
        self.session = session
        let context = Unmanaged.passUnretained(self).toOpaque()
        DASessionSetDispatchQueue(session, queue)
        DARegisterDiskAppearedCallback(session, nil, VolumeEventMonitor.appeared, context)
        DARegisterDiskDisappearedCallback(session, nil, VolumeEventMonitor.disappeared, context)
    }

    func stop() {
        guard started else { return }
        started = false
        let center = NSWorkspace.shared.notificationCenter
        for token in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        guard let session else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        DAUnregisterCallback(session, unsafeBitCast(VolumeEventMonitor.appeared, to: UnsafeMutableRawPointer.self), context)
        DAUnregisterCallback(session, unsafeBitCast(VolumeEventMonitor.disappeared, to: UnsafeMutableRawPointer.self), context)
        DASessionSetDispatchQueue(session, nil)
        self.session = nil
    }

    private func observeWorkspace() {
        let names: [(Notification.Name, String)] = [
            (NSWorkspace.didMountNotification, "didMount"),
            (NSWorkspace.willUnmountNotification, "willUnmount"),
            (NSWorkspace.didUnmountNotification, "didUnmount"),
        ]
        let center = NSWorkspace.shared.notificationCenter
        for (name, label) in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let path = (note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL)?.path ?? "—"
                    self.onLog("NSWorkspace \(label) | Pfad=\(path)")
                    if name == NSWorkspace.willUnmountNotification {
                        self.onWillUnmount(path)
                    }
                }
            }
            observers.append(token)
        }
    }

    private nonisolated static let appeared: DADiskAppearedCallback = { disk, context in
        deliver(disk, context, event: "erschienen")
    }

    private nonisolated static let disappeared: DADiskDisappearedCallback = { disk, context in
        deliver(disk, context, event: "verschwunden")
    }

    private nonisolated static func deliver(_ disk: DADisk, _ context: UnsafeMutableRawPointer?, event: String) {
        guard let context else { return }
        let monitor = Unmanaged<VolumeEventMonitor>.fromOpaque(context).takeUnretainedValue()
        let snapshot = VolumeListing.describeDisk(disk, event: event)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                monitor.onDisk(snapshot)
            }
        }
    }
}
#endif

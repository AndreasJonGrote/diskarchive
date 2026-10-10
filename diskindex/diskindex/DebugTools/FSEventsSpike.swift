#if DEBUG
//
//  FSEventsSpike.swift
//  diskindex
//
//  Aufgabe 35, Abschnitt D.
//

import CoreServices
import Darwin
import Foundation

struct FSEventsCheckpoint: Codable, Sendable {
    var fsUUID: String
    var lastEventID: UInt64
    var volumeKey: String
}

@MainActor
final class FSEventsSpike {
    var onLog: (String) -> Void = { _ in }

    private(set) var isRunning = false
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "diskindex.diagnostics.fsevents")
    private var watchedPath: String?
    private var volumeKey: String?
    private var fsUUID: String?
    private var lastEventID: UInt64?
    private var replaying = false
    private var replayed = 0
    private static let defaultsKey = "IndexDiagnostics.fsevents.checkpoints"

    func start(path: String, volumeKey: String) {
        stop(save: false)
        watchedPath = path
        self.volumeKey = volumeKey
        replaying = false
        replayed = 0

        var info = stat()
        let statResult = path.withCString { stat($0, &info) }
        let device = statResult == 0 ? String(info.st_dev) : "stat-Fehler \(errno)"
        let uuid = Self.deviceUUID(info.st_dev, valid: statResult == 0)
        fsUUID = uuid
        let current = FSEventsGetCurrentEventId()
        onLog("st_dev=\(device) | FSEvents-UUID=\(uuid ?? "—") | aktuelle Ereignis-ID=\(current)")

        var since = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
        if let uuid, let saved = Self.load()[volumeKey] {
            let same = saved.fsUUID == uuid
            onLog("Gespeicherte UUID=\(saved.fsUUID) | Vergleich=\(same ? "gleich" : "abweichend") | gespeicherte ID=\(saved.lastEventID)")
            if same {
                since = saved.lastEventID
                replaying = true
                onLog("Nachspielen ab Ereignis-ID \(saved.lastEventID)")
            } else {
                onLog("UUID weicht ab, kein Nachspielen")
            }
        } else if uuid == nil {
            onLog("Keine FSEvents-UUID. Historie ist nicht verfügbar, sinceWhen = jetzt.")
        } else {
            onLog("Kein gespeicherter Stand für \(volumeKey). sinceWhen = jetzt.")
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = [path] as CFArray
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(nil, FSEventsSpike.callback, &context, paths, since, 1.0, flags) else {
            onLog("FSEventStreamCreate fehlgeschlagen")
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        if !FSEventStreamStart(stream) {
            onLog("FSEventStreamStart fehlgeschlagen")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            isRunning = false
        } else {
            isRunning = true
            onLog("Strom gestartet | Pfad=\(path)")
        }
    }

    func stop(save: Bool) {
        if save { persist(reason: "Stopp") }
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        isRunning = false
        onLog("Strom gestoppt")
    }

    func volumeWillUnmount(_ path: String) {
        guard path == watchedPath, stream != nil else { return }
        persist(reason: "willUnmount")
        stop(save: false)
    }

    private func persist(reason: String) {
        guard let volumeKey else { return }
        let eventID = lastEventID ?? FSEventsGetCurrentEventId()
        let uuid = fsUUID ?? ""
        var all = Self.load()
        all[volumeKey] = FSEventsCheckpoint(fsUUID: uuid, lastEventID: eventID, volumeKey: volumeKey)
        Self.store(all)
        onLog("Gespeichert (\(reason)) | UUID=\(uuid.isEmpty ? "—" : uuid) | Ereignis-ID=\(eventID)")
    }

    fileprivate func receive(paths: [String], flags: [FSEventStreamEventFlags], ids: [FSEventStreamEventId]) {
        for index in paths.indices {
            let flag = flags[index]
            let id = ids[index]
            lastEventID = max(lastEventID ?? 0, id)
            if replaying && flag & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) == 0 {
                replayed += 1
            }
            onLog("ID=\(id) | \(Self.flagNames(flag)) | \(paths[index])")
            if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) != 0 {
                onLog("HistoryDone | nachgespielte Ereignisse=\(replayed)")
                replaying = false
            }
        }
    }

    private nonisolated static let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, eventIds in
        guard let info, numEvents > 0 else { return }
        let spike = Unmanaged<FSEventsSpike>.fromOpaque(info).takeUnretainedValue()
        let array = unsafeBitCast(eventPaths, to: NSArray.self)
        var paths: [String] = []
        var flags: [FSEventStreamEventFlags] = []
        var ids: [FSEventStreamEventId] = []
        for index in 0..<numEvents {
            paths.append(array[index] as? String ?? "—")
            flags.append(eventFlags[index])
            ids.append(eventIds[index])
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                spike.receive(paths: paths, flags: flags, ids: ids)
            }
        }
    }

    private static func deviceUUID(_ device: dev_t, valid: Bool) -> String? {
        guard valid, let uuid = FSEventsCopyUUIDForDevice(device) else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    private static func flagNames(_ flags: FSEventStreamEventFlags) -> String {
        let pairs: [(Int, String)] = [
            (kFSEventStreamEventFlagItemCreated, "angelegt"),
            (kFSEventStreamEventFlagItemRemoved, "entfernt"),
            (kFSEventStreamEventFlagItemRenamed, "umbenannt"),
            (kFSEventStreamEventFlagItemModified, "geändert"),
            (kFSEventStreamEventFlagMustScanSubDirs, "MustScanSubDirs"),
            (kFSEventStreamEventFlagHistoryDone, "HistoryDone"),
            (kFSEventStreamEventFlagRootChanged, "RootChanged"),
            (kFSEventStreamEventFlagMount, "Mount"),
            (kFSEventStreamEventFlagUnmount, "Unmount"),
            (kFSEventStreamEventFlagItemIsFile, "Datei"),
            (kFSEventStreamEventFlagItemIsDir, "Ordner"),
            (kFSEventStreamEventFlagItemIsSymlink, "Symlink"),
        ]
        let names = pairs.compactMap { bit, name in
            flags & FSEventStreamEventFlags(bit) != 0 ? name : nil
        }
        if names.isEmpty {
            return String(format: "Flags=0x%x", flags)
        }
        return names.joined(separator: ", ")
    }

    private static func load() -> [String: FSEventsCheckpoint] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: FSEventsCheckpoint].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func store(_ value: [String: FSEventsCheckpoint]) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
#endif

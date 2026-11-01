//
//  MountedMediumCheck.swift
//  DiskArchive
//
//  bug.0.4.175: Ist unter einem Pfad wirklich dieses Medium eingehängt? Der Pfad muss ein Einhängepunkt sein (kein
//  leerer Ordner in /Volumes nach Absturz oder unsauberem Auswerfen) und das Volume dort muss nach denselben Regeln wie
//  bei der Erkennung zum gespeicherten Medium passen. Abseits des Hauptfadens mit Zeitgrenze (`VolumeLookup`).
//

import Darwin
import Foundation

nonisolated enum MountedMediumCheck {
    /// `lookup` (nur Tests ersetzen ihn) läuft auf einer Hintergrund-Queue; `completion` meldet, wann er wirklich
    /// zurückkehrt (bug.0.4.179: eine hängende Prüfung zählt wie ein hängender Lesevorgang des Mediums).
    static func isMounted(
        _ medium: StoredMedium,
        at path: String,
        timeout: TimeInterval = VolumeLookup.defaultTimeout,
        lookup: @escaping @Sendable (URL) -> VolumeInfo? = { url in
            guard isMountPoint(url.path) else { return nil }
            return VolumeLookup.infoSyncForFlights(at: url)
        },
        completion: PartialReadCompletion? = nil
    ) async -> Bool {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let info = await VolumeLookup.info(at: url, timeout: timeout, lookup: { url in
            defer { completion?.finish() }
            return lookup(url)
        })
        guard let info else { return false }
        return MediumCodecV3.match(stored: medium, identity: info.identity) != nil
    }

    /// `path` ist selbst ein Einhängepunkt (nicht nur ein Ordner auf einem anderen Volume).
    static func isMountPoint(_ path: String) -> Bool {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return false }
        let mountedOn = withUnsafeBytes(of: info.f_mntonname) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        let canonical = { (value: String) in URL(fileURLWithPath: value).resolvingSymlinksInPath().standardizedFileURL.path }
        return canonical(mountedOn) == canonical(path)
    }

    #if DEBUG
    /// Tests mit einem Ordner als Medium (`IndexStoreV3.setMountCheckForTesting`): Einhängepunkt, solange es ihn gibt.
    static func testFolderExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    #endif
}

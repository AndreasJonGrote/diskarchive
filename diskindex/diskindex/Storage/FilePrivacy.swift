//
//  FilePrivacy.swift
//  diskindex
//
//  Datenbank und Protokoll bleiben dem eigenen Benutzer vorbehalten (Aufgabe 58).
//

import Foundation

nonisolated enum FilePrivacy {
    #if DEBUG
    nonisolated(unsafe) static var restrictCallCountForTesting = 0

    static func resetRestrictCallCountForTesting() {
        restrictCallCountForTesting = 0
    }
    #endif

    /// Ordner `0700`, Dateien darin `0600`. Wirkt auch auf schon vorhandene Dateien.
    static func restrict(_ directory: URL) {
        #if DEBUG
        restrictCallCountForTesting += 1
        #endif
        guard WriteGuard.permitsWrite(to: directory) else { return }
        let manager = FileManager.default
        try? manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        guard let names = try? manager.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names {
            let path = directory.appendingPathComponent(name).path
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            let fileURL = URL(fileURLWithPath: path)
            guard WriteGuard.permitsWrite(to: fileURL) else { continue }
            try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }
}

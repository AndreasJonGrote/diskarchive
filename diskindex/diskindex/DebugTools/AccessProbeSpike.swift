#if DEBUG
//
//  AccessProbeSpike.swift
//  diskindex
//
//  Aufgabe 35, Abschnitt B.
//

import Darwin
import Foundation

enum AccessProbeSpike {
    nonisolated static func probe(path: String) -> String {
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let start = ContinuousClock.now
        do {
            let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let seconds = indexDiagnosticsSeconds(start.duration(to: .now))
            return "Erfolg | sandboxed: \(sandboxed ? "ja" : "nein") | Einträge=\(entries.count) | Dauer=\(indexDiagnosticsFormat(seconds: seconds))"
        } catch {
            let seconds = indexDiagnosticsSeconds(start.duration(to: .now))
            let ns = error as NSError
            return [
                "Fehler",
                "sandboxed: \(sandboxed ? "ja" : "nein")",
                "Domain=\(ns.domain)",
                "Code=\(ns.code)",
                posixDetail(ns),
                "errno=\(errno)",
                "Dauer=\(indexDiagnosticsFormat(seconds: seconds))",
                "Beschreibung=\(ns.localizedDescription)",
            ].joined(separator: " | ")
        }
    }

    nonisolated private static func posixDetail(_ error: NSError) -> String {
        let posix: NSError?
        if error.domain == NSPOSIXErrorDomain {
            posix = error
        } else {
            posix = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        guard let posix, posix.domain == NSPOSIXErrorDomain else {
            return "POSIX=—"
        }
        let text = String(cString: strerror(Int32(posix.code)))
        return "POSIX=\(posix.code) \(text)"
    }
}
#endif

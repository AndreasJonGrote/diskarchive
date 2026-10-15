//
//  MediaMountPath.swift
//  diskindex
//
//  Mount-relative Pfade ohne NFC-Normalisierung der Ereignispfade (bug.0.4.017 d).
//

import Foundation

nonisolated enum MediaMountPath {
    static func normalizedMount(_ mountPath: String) -> String {
        var mount = mountPath
        while mount.hasSuffix("/") { mount.removeLast() }
        return mount
    }

    /// Relativ zum Mount; `eventPath` bleibt unverändert (FSEvents-NFC).
    static func relativeComponents(eventPath: String, mountPath: String) -> [String]? {
        let mount = normalizedMount(mountPath)
        var event = eventPath
        while event.hasSuffix("/") { event.removeLast() }
        if event == mount { return [] }
        let prefix = mount + "/"
        guard event.hasPrefix(prefix) else { return nil }
        let tail = event.dropFirst(prefix.count)
        if tail.isEmpty { return [] }
        return tail.split(separator: "/").map(String.init)
    }

    static func parentDirectory(eventPath: String, mountPath: String) -> String? {
        guard relativeComponents(eventPath: eventPath, mountPath: mountPath) != nil else { return nil }
        var parent = (eventPath as NSString).deletingLastPathComponent
        let mount = normalizedMount(mountPath)
        if parent.count < mount.count { parent = mount }
        return parent
    }
}

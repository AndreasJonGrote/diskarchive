//
//  FinderReveal.swift
//  DiskArchive
//
//  Pfad für „Im Finder anzeigen“ (Aufgabe 51).
//

import Foundation

nonisolated enum FinderReveal {
    /// `nil`, wenn das Medium offline ist (kein Einhängepfad).
    static func url(mountPath: String?, itemPath: String?, kindIsMedium: Bool) -> URL? {
        guard let mountPath, !mountPath.isEmpty else { return nil }
        let mount = URL(fileURLWithPath: mountPath, isDirectory: true)
        if kindIsMedium { return mount }
        guard let itemPath, !itemPath.isEmpty else { return nil }
        let relative = itemPath.hasPrefix("/") ? String(itemPath.dropFirst()) : itemPath
        var url = mount
        for part in relative.split(separator: "/", omittingEmptySubsequences: true) {
            url.appendPathComponent(String(part))
        }
        return url
    }
}

#if DEBUG
//
//  BreadthScanSpike.swift
//  diskindex
//
//  Aufgabe 35, Abschnitt C. Ebene für Ebene, keine Tiefenrekursion.
//

import Foundation

enum BreadthScanSpike {
    nonisolated private static let excluded: Set<String> = [
        ".Spotlight-V100",
        ".fseventsd",
        ".Trashes",
        ".TemporaryItems",
        ".DocumentRevisions-V100",
    ]

    nonisolated private static let keys: [URLResourceKey] = [
        .nameKey,
        .isDirectoryKey,
        .isPackageKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .fileResourceIdentifierKey,
        .isSymbolicLinkKey,
    ]

    nonisolated static func run(
        path: String,
        maxDepth: Int,
        isCancelled: @escaping @Sendable () -> Bool,
        report: @escaping @Sendable (String) async -> Void
    ) async {
        let fm = FileManager()
        let keySet = Set(keys)
        var current = [URL(fileURLWithPath: path, isDirectory: true)]
        var totalObjects = 0
        var totalFolders = 0
        let overall = ContinuousClock.now

        for level in 1...maxDepth {
            if isCancelled() {
                await report("Abbruch vor Ebene \(level).")
                return
            }
            let levelStart = ContinuousClock.now
            var objects = 0
            var folders = 0
            var errors = 0
            var next: [URL] = []
            for directory in current {
                if isCancelled() {
                    await report("Abbruch in Ebene \(level).")
                    await report(summary(objects: totalObjects + objects, folders: totalFolders + folders, since: overall))
                    return
                }
                let children: [URL]
                do {
                    children = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys, options: [])
                } catch {
                    errors += 1
                    if errors <= 20 {
                        let ns = error as NSError
                        await report("Nicht lesbar | \(directory.path) | \(ns.domain) \(ns.code)")
                    }
                    continue
                }
                for child in children {
                    if excluded.contains(child.lastPathComponent) { continue }
                    let values = try? child.resourceValues(forKeys: keySet)
                    _ = values?.name
                    _ = values?.fileSize
                    _ = values?.contentModificationDate
                    _ = values?.fileResourceIdentifier
                    let symlink = values?.isSymbolicLink == true
                    let isDirectory = values?.isDirectory == true && !symlink
                    let isPackage = values?.isPackage == true
                    objects += 1
                    if isDirectory && !isPackage {
                        folders += 1
                        next.append(child)
                    }
                }
            }
            let seconds = indexDiagnosticsSeconds(levelStart.duration(to: .now))
            let rate = seconds > 0 ? Double(objects) / seconds : 0
            totalObjects += objects
            totalFolders += folders
            await report(String(
                format: "Ebene %d: %d Objekte, %d Ordner, %.3f s, %.0f Objekte/s, Lesefehler=%d",
                level, objects, folders, seconds, rate, errors
            ))
            if errors > 20 {
                await report("Weitere Lesefehler auf Ebene \(level): \(errors - 20)")
            }
            if objects > 0 && rate < 5_000 {
                await report("Hinweis: unter 5 000 Objekten/s. Für eine HDD wäre später getattrlistbulk zu prüfen (nicht Teil des Spikes).")
            }
            current = next
            if current.isEmpty {
                await report("Keine weiteren Ordner nach Ebene \(level).")
                break
            }
        }
        await report(summary(objects: totalObjects, folders: totalFolders, since: overall))
    }

    nonisolated private static func summary(objects: Int, folders: Int, since: ContinuousClock.Instant) -> String {
        let seconds = indexDiagnosticsSeconds(since.duration(to: .now))
        let rate = seconds > 0 ? Double(objects) / seconds : 0
        return String(
            format: "Summe: %d Objekte, %d Ordner, %.3f s, %.0f Objekte/s",
            objects, folders, seconds, rate
        )
    }
}
#endif

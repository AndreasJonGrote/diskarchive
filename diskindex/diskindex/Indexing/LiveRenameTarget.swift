//
//  LiveRenameTarget.swift
//  diskindex
//
//  Größe, Änderungsdatum und Teil-Prüfsumme des Ziels eines Live-Umbenennens (235b), abseits des Store-Actors gelesen.
//  bug.0.4.226: Der Actor `IndexStoreV3` greift nie auf ein Medium zu (`konzept/architektur.md`); vorher stand dieses
//  Lesen als statische Funktion im Store.
//

import Foundation

nonisolated enum LiveRenameTarget {
    static func fields(
        toPath: String,
        partialMatching: Bool
    ) async throws -> (Int64?, Date?, Data?) {
        try await Task.detached(priority: .utility) {
            let toURL = URL(fileURLWithPath: toPath)
            guard FileManager.default.fileExists(atPath: toPath) else {
                return (nil, nil, nil)
            }
            var toSizeBytes: Int64?
            var toModifiedAt: Date?
            var isDirectory = false
            if let values = try? toURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]) {
                toSizeBytes = values.fileSize.map(Int64.init)
                toModifiedAt = values.contentModificationDate
                isDirectory = values.isDirectory ?? false
            }
            var partial: Data?
            // bug.0.4.131: keine Teil-Prüfsumme für Ordner (Lesen wirft) – sonst scheitert jedes Live-Umbenennen eines
            // Ordners, und der Abgleich legt eine neue Zeile an (offener Pfad, Favoriten).
            if partialMatching, !isDirectory {
                partial = try PartialChecksum.compute(at: toURL)?.partial
            }
            return (toSizeBytes, toModifiedAt, partial)
        }.value
    }
}

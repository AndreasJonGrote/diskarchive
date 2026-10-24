//
//  VanishedMediumGuard.swift
//  diskindex
//
//  bug.0.4.177/181: eine Regel für Lauf und Live-Überwachung – ein leer gelesener Ordner darf den Index nicht leeren,
//  wenn das Medium gar nicht mehr eingehängt ist.
//

import Foundation

nonisolated enum VanishedMediumGuard {
    /// Nur im Fall „leer gelesen, hatte Inhalt“ (bzw. in der Wurzel „kein bisheriger Eintrag mehr da“) wird das Medium
    /// geprüft – nicht je Ordner. `previousRootNames`: Namen der bisherigen Wurzel (`nil` = nicht lesbar → vorsichtshalber
    /// prüfen). `stored` fehlt es, wird es aus dem Speicher gelesen; ist es nicht da, gilt das Medium als verschwunden.
    static func vanished(
        folderEntries: [ScannedEntry],
        parentID: Int64?,
        previousRootNames: Set<String>?,
        store: IndexStoreV3,
        access: any MediumAccess,
        mediumUUID: UUID,
        stored: StoredMedium?,
        mountPath: String
    ) async -> Bool {
        if folderEntries.isEmpty {
            let previous = try? await store.children(mediumUUID: mediumUUID, parentID: parentID, limit: 1)
            if let previous, previous.isEmpty { return false }
        } else if parentID == nil {
            guard let previous = previousRootNames else {
                return !(await isMounted(store: store, access: access, mediumUUID: mediumUUID, stored: stored, mountPath: mountPath))
            }
            // bug.0.4.187 (b): Verwaltungsdateien gibt es auf jedem Medium – sie sagen nichts über die Identität. Bestand
            // die bisherige Wurzel nur aus ihnen, gilt der Vergleich wie bisher mit allen Namen.
            let allNames = Set(folderEntries.map(\.name))
            let relevant = previous.filter { !isAdministrative($0) }
            let basis = relevant.isEmpty ? previous : relevant
            let names = relevant.isEmpty ? allNames : allNames.filter { !isAdministrative($0) }
            guard !basis.isEmpty, basis.isDisjoint(with: names) else { return false }
        } else {
            return false
        }
        return !(await isMounted(store: store, access: access, mediumUUID: mediumUUID, stored: stored, mountPath: mountPath))
    }

    /// bug.0.4.189: keine eigene Liste, sondern die bestehenden Regeln – `IgnoreMatcher.alwaysSkipped`, die Artefaktgruppen
    /// „System“ und „versteckte Artefakte“ (`ArtifactRules`), verglichen kleingeschrieben wie dort. Dazu die Verwaltungsnamen,
    /// die keine Regel kennt, die aber auf vielen Medien liegen.
    private static let administrativeExact: Set<String> = Set(IgnoreMatcher.alwaysSkipped.map { $0.lowercased() }).union([
        ".volumeicon.icns", ".apdisk", ".metadata_never_index", ".localized", ".hidden", ".com.apple.timemachine.donotpresent",
    ])
    private static let administrativePatterns: [NamePattern] =
        [ArtifactCategory.system, .hiddenArtifacts].flatMap { ArtifactRules.categoryPatterns($0) }

    static func isAdministrative(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasPrefix("._") || administrativeExact.contains(lower) { return true }
        return administrativePatterns.contains { $0.matches(lowercased: lower) }
    }

    private static func isMounted(
        store: IndexStoreV3, access: any MediumAccess, mediumUUID: UUID, stored: StoredMedium?, mountPath: String
    ) async -> Bool {
        let medium: StoredMedium?
        if let stored { medium = stored } else { medium = try? await store.medium(uuid: mediumUUID) }
        guard let medium else { return false }
        return await store.confirmMounted(medium, mountPath: mountPath, access: access)
    }
}

//
//  Slug.swift
//  DiskArchive
//
//  Schema V3 (Aufgabe 230): Suchname. Klein, Umlaute und Akzente → Stammlaut, ß → ss.
//  Dieselbe Funktion für gespeicherte Namen und Suchbegriffe.
//

import Foundation

nonisolated enum Slug {
    static func make(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "ß", with: "ss")
        var result = String.UnicodeScalarView()
        for scalar in lowered.decomposedStringWithCanonicalMapping.unicodeScalars
        where scalar.properties.generalCategory != .nonspacingMark {
            result.append(scalar)
        }
        return String(result)
    }
}

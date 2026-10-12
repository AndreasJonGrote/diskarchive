//
//  NaturalOrder.swift
//  diskindex
//
//  Schema V3 (Aufgabe 230): natürliche Sortierung. Zahlenfolgen zählen als Zahl („datei 2“ < „datei 10“),
//  sonst Byte-Reihenfolge wie beim Suchnamen. Dieselbe Funktion in Swift und als SQLite-Sortierfolge „natural“.
//

import Foundation
import GRDB

nonisolated enum NaturalOrder {
    /// „natural“ ist in SQL ein Schlüsselwort (NATURAL JOIN): in Anweisungen in Anführungszeichen schreiben.
    static let collationName = "natural"

    /// Auf jeder Verbindung zu registrieren (`Configuration.prepareDatabase`).
    static let collation = DatabaseCollation(collationName) { lhs, rhs in
        compare(lhs, rhs)
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var i = 0
        var j = 0
        while i < a.count, j < b.count {
            if isDigit(a[i]), isDigit(b[j]) {
                let startA = i
                let startB = j
                while i < a.count, isDigit(a[i]) { i += 1 }
                while j < b.count, isDigit(b[j]) { j += 1 }
                var sigA = startA
                var sigB = startB
                while sigA < i - 1, a[sigA] == 0x30 { sigA += 1 }
                while sigB < j - 1, b[sigB] == 0x30 { sigB += 1 }
                let lengthA = i - sigA
                let lengthB = j - sigB
                if lengthA != lengthB { return lengthA < lengthB ? .orderedAscending : .orderedDescending }
                for offset in 0..<lengthA where a[sigA + offset] != b[sigB + offset] {
                    return a[sigA + offset] < b[sigB + offset] ? .orderedAscending : .orderedDescending
                }
                // Gleiche Zahl: weniger führende Nullen zuerst, damit die Ordnung vollständig bleibt.
                let zerosA = sigA - startA
                let zerosB = sigB - startB
                if zerosA != zerosB { return zerosA < zerosB ? .orderedAscending : .orderedDescending }
                continue
            }
            if a[i] != b[j] { return a[i] < b[j] ? .orderedAscending : .orderedDescending }
            i += 1
            j += 1
        }
        if i < a.count { return .orderedDescending }
        if j < b.count { return .orderedAscending }
        return .orderedSame
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39
    }
}

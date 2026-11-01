//
//  NaturalOrder.swift
//  DiskArchive
//
//  Schema V3 (Aufgabe 230): natürliche Sortierung. Zahlenfolgen zählen als Zahl („datei 2“ < „datei 10“),
//  sonst Byte-Reihenfolge wie beim Suchnamen. Dieselbe Funktion in Swift und als SQLite-Sortierfolge „natural“.
//  bug.0.4.077: Der Vergleich arbeitet direkt auf den UTF-8-Bytes und legt keinen Speicher an; SQLite ruft ihn ohne
//  Umweg über `String` auf (Indizes `items_children`, `items_search_natural` vergleichen bei jedem Einfügen).
//

import Foundation
import GRDB
import SQLite3

nonisolated enum NaturalOrder {
    /// „natural“ ist in SQL ein Schlüsselwort (NATURAL JOIN): in Anweisungen in Anführungszeichen schreiben.
    static let collationName = "natural"

    /// Auf jeder Verbindung zu registrieren (`Configuration.prepareDatabase`). Direkt über SQLite statt
    /// `DatabaseCollation`, weil GRDB dort je Vergleich zwei `String` erzeugt.
    static func register(on db: Database) throws {
        let code = sqlite3_create_collation_v2(
            db.sqliteConnection, collationName, SQLITE_UTF8, nil,
            { _, lengthA, bufferA, lengthB, bufferB in
                let a = UnsafeBufferPointer(start: bufferA?.assumingMemoryBound(to: UInt8.self), count: Int(max(lengthA, 0)))
                let b = UnsafeBufferPointer(start: bufferB?.assumingMemoryBound(to: UInt8.self), count: Int(max(lengthB, 0)))
                return CInt(NaturalOrder.compare(a, b).rawValue)
            },
            nil
        )
        if code != SQLITE_OK { throw DatabaseError(resultCode: ResultCode(rawValue: code), message: db.lastErrorMessage) }
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        var lhs = lhs
        var rhs = rhs
        return lhs.withUTF8 { a in rhs.withUTF8 { b in compare(a, b) } }
    }

    static func compare(_ a: UnsafeBufferPointer<UInt8>, _ b: UnsafeBufferPointer<UInt8>) -> ComparisonResult {
        let countA = a.count
        let countB = b.count
        var i = 0
        var j = 0
        while i < countA, j < countB {
            let byteA = a[i]
            let byteB = b[j]
            if isDigit(byteA), isDigit(byteB) {
                // Führende Nullen überspringen (eine Null bleibt, wenn die Gruppe nur aus Nullen besteht).
                let startA = i
                let startB = j
                while i + 1 < countA, a[i] == 0x30, isDigit(a[i + 1]) { i += 1 }
                while j + 1 < countB, b[j] == 0x30, isDigit(b[j + 1]) { j += 1 }
                let zerosA = i - startA
                let zerosB = j - startB
                // Signifikante Ziffern gleichzeitig durchlaufen: die erste Abweichung merken, die Länge entscheidet zuerst.
                var firstDifference = ComparisonResult.orderedSame
                while true {
                    let moreA = i < countA && isDigit(a[i])
                    let moreB = j < countB && isDigit(b[j])
                    if moreA != moreB { return moreA ? .orderedDescending : .orderedAscending }
                    if !moreA { break }
                    if firstDifference == .orderedSame, a[i] != b[j] {
                        firstDifference = a[i] < b[j] ? .orderedAscending : .orderedDescending
                    }
                    i += 1
                    j += 1
                }
                if firstDifference != .orderedSame { return firstDifference }
                // Gleiche Zahl: weniger führende Nullen zuerst, damit die Ordnung vollständig bleibt.
                if zerosA != zerosB { return zerosA < zerosB ? .orderedAscending : .orderedDescending }
                continue
            }
            if byteA != byteB { return byteA < byteB ? .orderedAscending : .orderedDescending }
            i += 1
            j += 1
        }
        if i < countA { return .orderedDescending }
        if j < countB { return .orderedAscending }
        return .orderedSame
    }

    @inline(__always)
    private static func isDigit(_ byte: UInt8) -> Bool {
        byte &- 0x30 < 10
    }
}

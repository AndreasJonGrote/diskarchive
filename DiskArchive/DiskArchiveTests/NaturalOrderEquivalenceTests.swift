//
//  NaturalOrderEquivalenceTests.swift
//  DiskArchiveTests
//
//  bug.0.4.077 (Nacharbeit): Der neue Vergleich auf UTF-8-Bytes ohne Speicheranlegen ordnet genau wie der bisherige
//  (`LegacyNaturalOrder`, unveränderte Kopie der alten Fassung), in Swift und als SQLite-Sortierfolge „natural“.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

/// Die bisherige Fassung von `NaturalOrder.compare` (bis 18.10.), nur als Vergleichsmaßstab (auch für die Messung
/// „vorher“ in `NaturalOrderIndexMeasurementTests`).
enum LegacyNaturalOrder {
    /// Wie früher über GRDB registriert (zwei `String` je Vergleich, dann zwei Arrays).
    static let collation = DatabaseCollation(NaturalOrder.collationName) { lhs, rhs in compare(lhs, rhs) }

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

/// Fester Startwert, damit ein Fehlschlag wiederholbar ist.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite(.serialized)
struct NaturalOrderEquivalenceTests {
    /// Bausteine mit vielen Ziffern, Nullen, Umlauten (roh und als Suchname), Satzzeichen und Mehrbyte-Zeichen.
    private static let pieces = [
        "0", "00", "007", "1", "2", "9", "10", "010", "99", "100", "0001", "12345678901234567890", "000000",
        "a", "b", "z", "A", "Z", "datei", "rechnung ", "img_", "dsc", " ", "-", ".", "_", "–",
        "ä", "Ä", "ö", "ü", "ß", "é", "œ", "😀", "日本", "\u{0301}", "~", "/", ":",
    ]

    private static func randomName(_ generator: inout SplitMix64) -> String {
        let count = Int.random(in: 0...6, using: &generator)
        var name = ""
        for _ in 0..<count {
            name += pieces.randomElement(using: &generator) ?? ""
        }
        return name
    }

    @Test func newCompareMatchesLegacyOnRandomPairs() {
        var generator = SplitMix64(state: 0x0077_0418)
        var mismatches: [String] = []
        for _ in 0..<200_000 {
            let lhs = Self.randomName(&generator)
            // Jedes vierte Paar mit gleichem Anfang, damit die Zifferngruppen oft gegeneinander laufen.
            let rhs = Bool.random(using: &generator) && Bool.random(using: &generator)
                ? lhs + Self.randomName(&generator)
                : Self.randomName(&generator)
            for (a, b) in [(lhs, rhs), (rhs, lhs), (lhs, lhs)] where NaturalOrder.compare(a, b) != LegacyNaturalOrder.compare(a, b) {
                mismatches.append("\(a.debugDescription) vs \(b.debugDescription)")
            }
            if mismatches.count >= 5 { break }
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    @Test func newCompareMatchesLegacyOnEdgeCases() {
        let names = [
            "", "0", "00", "000", "1", "01", "001", "10", "010", "a", "a0", "a00", "a0b", "a00b", "a1", "a01", "a1b",
            "a01b", "a10", "a9", "a09", "9a", "09a", "a 2", "a 10", "a 2b", "x99999999999999999999", "x100000000000000000000",
            "ä1", "ä01", "ä 10", "rechnung 600", "rechnung 6", "rechnung 60", "1.2.10", "1.2.9", "1.02.9",
        ]
        var mismatches: [String] = []
        for a in names {
            for b in names where NaturalOrder.compare(a, b) != LegacyNaturalOrder.compare(a, b) {
                mismatches.append("\(a.debugDescription) vs \(b.debugDescription)")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    /// Die Sortierfolge in SQLite (direkter C-Aufruf auf den Bytes) ordnet wie die alte Swift-Fassung.
    @Test func sqlCollationMatchesLegacyOrder() throws {
        var generator = SplitMix64(state: 0x0077_5A1E)
        var names: [String] = []
        for _ in 0..<3_000 { names.append(Self.randomName(&generator)) }
        names += names.prefix(50).map { Slug.make($0) }
        let expected = names.sorted { LegacyNaturalOrder.compare($0, $1) == .orderedAscending }

        let queue = try DatabaseQueue()
        let sqlOrder = try queue.write { db -> [String] in
            try NaturalOrder.register(on: db)
            try db.execute(sql: "CREATE TABLE t (s TEXT NOT NULL)")
            for name in names { try db.execute(sql: "INSERT INTO t (s) VALUES (?)", arguments: [name]) }
            return try String.fetchAll(db, sql: "SELECT s FROM t ORDER BY s COLLATE \"\(NaturalOrder.collationName)\"")
        }
        try #require(sqlOrder.count == expected.count)
        // bug.0.4.085 d): Bytes vergleichen; Swift-`==` auf Strings sieht NFC und NFD als gleich an.
        let firstDifference = zip(sqlOrder, expected).enumerated().first {
            !$0.element.0.utf8.elementsEqual($0.element.1.utf8)
        }
        #expect(firstDifference == nil, "erste Abweichung: \(String(describing: firstDifference))")
    }
}

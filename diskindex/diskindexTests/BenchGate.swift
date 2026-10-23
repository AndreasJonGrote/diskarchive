//
//  BenchGate.swift
//  diskindexTests
//
//  bug.0.4.121: Zeitgrenzen gelten nur in der Messung (`DA_BENCH=1`, Release, Regel 8). Im Debug-Lauf prüft ein Test
//  nur das Ergebnis; die Wartezeit bekommt dort eine großzügige Frist.
//

import Foundation

enum BenchGate {
    static let enabled = ProcessInfo.processInfo.environment["DA_BENCH"] == "1"

    /// Wartefrist für „wird gezeichnet“: scharf in der Messung, sonst mit Reserve.
    static var paintDeadline: TimeInterval { enabled ? 0.5 : 5 }
}

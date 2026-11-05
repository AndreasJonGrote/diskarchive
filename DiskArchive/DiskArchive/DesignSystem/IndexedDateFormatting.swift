//
//  IndexedDateFormatting.swift
//  DiskArchive
//

import Foundation

enum IndexedDateFormatting {
    /// „13. Okt. 2026“ / „Oct 13, 2026“ nach App-Sprache statt Systemsprache (bug.0.4.058).
    nonisolated static func abbreviatedDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale()))
    }
}

//
//  IndexedDateFormatting.swift
//  diskindex
//

import Foundation

enum IndexedDateFormatting {
    /// „13. Okt. 2026“ / „Oct 13, 2026“ nach App-Sprache statt Systemsprache (bug.0.4.058).
    nonisolated static func abbreviatedDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale()))
    }

    /// Popover/Dashboard: „Zuletzt indiziert: heute, 09:14" (Sprache und Zeitformat nach App-Sprache)
    static func lastIndexedLine(date: Date?) -> String {
        guard let date else { return LayoutCopy.indexedNever }
        let locale = L10n.locale()
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        let dayLabel: String
        if Calendar.current.isDateInToday(date) {
            dayLabel = LayoutCopy.dateToday
        } else if Calendar.current.isDateInYesterday(date) {
            dayLabel = LayoutCopy.dateYesterday
        } else {
            dayLabel = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        }
        return LayoutCopy.indexedLine(dayLabel, time)
    }
}

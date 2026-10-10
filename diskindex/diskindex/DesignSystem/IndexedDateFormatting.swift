//
//  IndexedDateFormatting.swift
//  diskindex
//

import Foundation

enum IndexedDateFormatting {
    /// Popover/Dashboard: „Zuletzt indiziert: heute, 09:14"
    static func lastIndexedLine(date: Date?) -> String {
        guard let date else { return "Zuletzt indiziert: —" }
        let time = date.formatted(date: .omitted, time: .shortened)
        let dayLabel: String
        if Calendar.current.isDateInToday(date) {
            dayLabel = "heute"
        } else if Calendar.current.isDateInYesterday(date) {
            dayLabel = "gestern"
        } else {
            dayLabel = date.formatted(date: .abbreviated, time: .omitted)
        }
        return "Zuletzt indiziert: \(dayLabel), \(time)"
    }
}

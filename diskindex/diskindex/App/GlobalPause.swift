//
//  GlobalPause.swift
//  diskindex
//

import Foundation

nonisolated struct GlobalPause: Equatable, Codable {
    var active = false
    var until: Date?
    var forever = false

    static func untilTomorrow(from now: Date, calendar: Calendar = .current) -> Date {
        let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: next) ?? next
    }

    mutating func pause(until date: Date?) {
        active = true
        forever = date == nil
        until = date
    }

    mutating func resume() {
        active = false
        forever = false
        until = nil
    }

    mutating func refresh(now: Date) -> Bool {
        guard active, !forever, let until, now >= until else { return false }
        resume()
        return true
    }

    var isPaused: Bool { active }
}

nonisolated enum PauseNoticeCopy {
    static func began(until: Date?, now: Date) -> String {
        guard let until else { return LayoutCopy.noticePauseForever }
        return LayoutCopy.noticePauseUntil(time: DisplayTimeFormat.clock(until))
    }
}

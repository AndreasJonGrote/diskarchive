//
//  GlobalPause.swift
//  DiskArchive
//

import Foundation

nonisolated struct GlobalPause: Equatable, Codable {
    var active = false
    var until: Date?
    var forever = false
    /// bug.0.4.059: gewählte Dauer; fehlt bei alten gespeicherten Pausen (dann aus `until` abgeleitet).
    var span: PauseSpan? = nil

    static func untilTomorrow(from now: Date, calendar: Calendar = .current) -> Date {
        let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: next) ?? next
    }

    mutating func pause(until date: Date?) {
        active = true
        forever = date == nil
        until = date
        span = nil
    }

    /// bug.0.4.059: Pause mit gewählter Dauer; die Spanne wird mitgespeichert.
    mutating func pause(span chosen: PauseSpan, now: Date) {
        pause(until: chosen.endDate(from: now))
        span = chosen
    }

    mutating func resume() {
        active = false
        forever = false
        until = nil
        span = nil
    }

    mutating func refresh(now: Date) -> Bool {
        guard active, !forever, let until, now >= until else { return false }
        resume()
        return true
    }

    var isPaused: Bool { active }
}

nonisolated extension GlobalPause {
    private enum CodingKeys: String, CodingKey {
        case active, until, forever, span
    }

    /// bug.0.4.068 a): Eine unbekannte Spanne (gespeichert von einer späteren Version) wird als `nil` gelesen,
    /// statt das Dekodieren der ganzen Pause scheitern zu lassen; die Dauer folgt dann aus `until`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decode(Bool.self, forKey: .active)
        until = try container.decodeIfPresent(Date.self, forKey: .until)
        forever = try container.decode(Bool.self, forKey: .forever)
        span = try? container.decodeIfPresent(PauseSpan.self, forKey: .span)
    }
}

nonisolated enum PauseNoticeCopy {
    static func began(until: Date?, now: Date) -> String {
        guard let until else { return LayoutCopy.noticePauseForever }
        return LayoutCopy.noticePauseUntil(time: DisplayTimeFormat.clock(until))
    }
}

//
//  AppVersionTests.swift
//  diskindexTests
//
//  Build-Zeitstempel UTC (c.0.3.246).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized)
struct AppVersionTests {
    @Test func buildTimestampParsesAsUTC() throws {
        let date = try #require(AppVersion.buildTimestamp(from: "202603151430"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026)
        #expect(parts.month == 3)
        #expect(parts.day == 15)
        #expect(parts.hour == 14)
        #expect(parts.minute == 30)
    }
}

//
//  PauseSpanDecodingTests.swift
//  DiskArchiveTests
//
//  bug.0.4.068 a): Eine unbekannte gespeicherte Spanne lässt das Dekodieren der Pause nicht scheitern.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
@Suite(.serialized)
struct PauseSpanDecodingTests {
    @Test func unknownStoredSpanDecodesAsNil() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let until = start.addingTimeInterval(3_600)
        let json = #"{"active":true,"forever":false,"until":\#(until.timeIntervalSinceReferenceDate),"span":"fortnight"}"#
        let decoded = try JSONDecoder().decode(GlobalPause.self, from: Data(json.utf8))
        #expect(decoded.active)
        #expect(decoded.span == nil)
        #expect(decoded.until == until)
        // Ohne bekannte Spanne folgt die Dauer aus der Restzeit.
        #expect(PauseSpan.matching(decoded, now: start) == .hour)
    }

    @Test func knownSpanStillRoundTrips() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var pause = GlobalPause()
        pause.pause(span: .tomorrow, now: start)
        let data = try JSONEncoder().encode(pause)
        let decoded = try JSONDecoder().decode(GlobalPause.self, from: data)
        #expect(decoded == pause)
        #expect(decoded.span == .tomorrow)
    }
}

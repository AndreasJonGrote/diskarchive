//
//  FSEventsResumeTests.swift
//  DiskArchiveTests
//

import CoreServices
import Testing
@testable import DiskArchive

struct FSEventsResumeTests {
    @Test func resumeWhenUUIDMatchesAndIDPositive() {
        let id = FSEventStreamEventId(42)
        let decision = FSEventsResume.streamStart(
            resumeVolumeUUID: "UUID-A",
            resumeLastEventID: id,
            currentVolumeUUID: "UUID-A"
        )
        #expect(decision.usesStoredCursor)
        #expect(decision.sinceEventID == id)
    }

    @Test func sinceNowWhenUUIDMismatch() {
        let decision = FSEventsResume.streamStart(
            resumeVolumeUUID: "UUID-A",
            resumeLastEventID: 99,
            currentVolumeUUID: "UUID-B"
        )
        #expect(!decision.usesStoredCursor)
        #expect(decision.sinceEventID == FSEventStreamEventId(kFSEventStreamEventIdSinceNow))
    }

    @Test func sinceNowWhenStoredIDZero() {
        let decision = FSEventsResume.streamStart(
            resumeVolumeUUID: "UUID-A",
            resumeLastEventID: 0,
            currentVolumeUUID: "UUID-A"
        )
        #expect(!decision.usesStoredCursor)
    }
}

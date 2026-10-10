//
//  FSEventsResume.swift
//  diskindex
//

import CoreServices
import Foundation

nonisolated enum FSEventsResume {
    struct Decision: Equatable {
        var sinceEventID: FSEventStreamEventId
        var usesStoredCursor: Bool
    }

    /// Ob FSEvents ab gespeichertem Stand weiterhört (UUID muss zum Volume passen, ID > 0).
    static func streamStart(
        resumeVolumeUUID: String?,
        resumeLastEventID: FSEventStreamEventId?,
        currentVolumeUUID: String?
    ) -> Decision {
        let sinceNow = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
        guard let resumeLastEventID, resumeLastEventID > 0,
              let resumeVolumeUUID, !resumeVolumeUUID.isEmpty,
              let currentVolumeUUID, resumeVolumeUUID == currentVolumeUUID else {
            return Decision(sinceEventID: sinceNow, usesStoredCursor: false)
        }
        return Decision(sinceEventID: resumeLastEventID, usesStoredCursor: true)
    }
}

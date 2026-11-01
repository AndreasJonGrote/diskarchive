//
//  ApiQueueKind.swift
//  DiskArchive
//
//  API-Warteschlange (0.3.1): Auftragsarten in `api_queue.kind`.
//

import Foundation

nonisolated enum ApiQueueKind: Int, Sendable {
    case issueReport = 0
    case versionCheck = 1
    // Reserviert: updateCheck = 2, licenseCheck = 3 (0.4 / 0.9)
}

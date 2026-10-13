//
//  ApiQueueKind.swift
//  diskindex
//
//  API-Warteschlange (0.3.1): Auftragsarten in `api_queue.kind`.
//

import Foundation

nonisolated enum ApiQueueKind: Int, Sendable {
    case issueReport = 0
    // Reserviert: versionCheck = 1, updateCheck = 2, licenseCheck = 3 (0.4 / 0.9)
}

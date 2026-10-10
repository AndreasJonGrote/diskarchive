//
//  ScriptedChangeSource.swift
//  diskindexTests
//
//  Aufgabe 110 — Testquelle (Produktion: FSEventsChangeSource).
//

import Foundation
@testable import diskindex

final class ScriptedChangeSource: ChangeSource, @unchecked Sendable {
    private let stream: AsyncStream<VolumeChange>
    private let continuation: AsyncStream<VolumeChange>.Continuation

    init() {
        let pair = AsyncStream.makeStream(of: VolumeChange.self)
        stream = pair.stream
        continuation = pair.continuation
    }

    func changes() -> AsyncStream<VolumeChange> { stream }

    func emit(_ change: VolumeChange) {
        continuation.yield(change)
    }
}

//
//  StaleIndexingFailureWithdrawTests.swift
//  diskindexTests
//
//  bug.0.4.197 e — Beim Start werden zugestellte „nicht bestätigt“-Mitteilungen früherer Sitzungen zurückgezogen.
//

import Foundation
import Testing
import UserNotifications
@testable import diskindex

@Suite(.serialized) @MainActor
struct StaleIndexingFailureWithdrawTests {
    /// Zugestellt: zwei `indexing-failure-*` und eine fremde Kennung → genau die zwei werden zurückgezogen.
    @Test func startupWithdrawsOnlyTheStaleIndexingFailureNotices() {
        let first = SystemNotice.indexingFailureIdentifier(mediumID: UUID())
        let second = SystemNotice.indexingFailureIdentifier(mediumID: UUID())
        let foreign = "diskindex.notice-\(UUID().uuidString)"
        var withdrawn: [String] = []
        let hooks = NoticeTestHooks(
            withdraw: { withdrawn.append($0) },
            delivered: [first, foreign, second]
        )
        // Über Schritt 1 des Startablaufs (wie `applicationDidFinishLaunching`), nicht die Funktion direkt.
        let defaults = TestDefaults.make()
        let app = AppState(defaults: defaults)
        SystemNotice.$testHooks.withValue(hooks) {
            StoreLaunchSequence.evaluatePauseAtLaunch(appState: app, defaults: defaults)
        }
        #expect(withdrawn == [first, second], "Zurückgezogen: \(withdrawn)")
        #expect(!withdrawn.contains(foreign), "Fremde Mitteilung zurückgezogen")
    }
}

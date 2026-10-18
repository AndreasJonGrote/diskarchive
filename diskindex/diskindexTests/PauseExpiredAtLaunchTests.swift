//
//  PauseExpiredAtLaunchTests.swift
//  diskindexTests
//
//  todo.0.4.027 (todo.0.4.035): Eine Pause, die bei beendeter App abgelaufen ist, meldet beim Start
//  „Medien werden wieder indiziert.“ wie der Ablauf im Betrieb (gleiche Schalter, gleicher Text), danach Abgleich.
//

import Foundation
import Testing
import UserNotifications
@testable import diskindex

@Suite(.serialized) @MainActor
struct PauseExpiredAtLaunchTests {
    private func defaultsWithExpiredPause() throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: "PauseExpiredAtLaunch-\(UUID().uuidString)"))
        var pause = GlobalPause()
        pause.pause(until: Date().addingTimeInterval(-3_600))
        defaults.set(try JSONEncoder().encode(pause), forKey: AppState.pauseKey)
        return defaults
    }

    private func storedPause(_ defaults: UserDefaults) throws -> GlobalPause {
        let data = try #require(defaults.data(forKey: AppState.pauseKey))
        return try JSONDecoder().decode(GlobalPause.self, from: data)
    }

    /// Start: `AppState(defaults:)` lädt die abgelaufene Pause, das Medium erscheint noch unter der Pause (kein Start),
    /// dann `refreshGlobalPause()` wie in `applicationDidFinishLaunching` → Mitteilung und Lauf.
    @Test func expiredPauseAnnouncesAtLaunchAndReconciles() async throws {
        let defaults = try defaultsWithExpiredPause()
        let harness = try await ScanHarness.make()
        let mediumID = harness.mediumID
        let volume = testVolume(path: "/Volumes/PAUSE", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: mediumID, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/PAUSE")
        inner.file("a.txt")
        let access = RunGateAccess([inner]) { _ in false }

        let app = AppState(store: harness.store, defaults: defaults)
        app.appSettings.notificationsEnabled = true
        app.appSettings.notifySystem = true
        // Erkennung steht, die Pause gilt noch (vor `refreshGlobalPause`): das Medium erscheint, kein Start.
        let rig = WiredRig(store: harness.store, access: access, app: app)
        await rig.coordinator.handle(.appeared(volume))
        try await Task.sleep(for: .milliseconds(200))
        #expect(rig.starts(mediumID).isEmpty)

        var posts: [(body: String, kind: String)] = []
        let hooks = NoticeTestHooks(post: { request, kind in posts.append((request.content.body, kind)) })
        SystemNotice.$testHooks.withValue(hooks) {
            app.refreshGlobalPause(defaults: defaults)
        }
        #expect(posts.count == 1)
        #expect(posts.first?.kind == "pause-expired")
        #expect(posts.first?.body == LayoutCopy.noticePauseResumedManual)
        #expect(!app.globalAutoIndexPaused)
        #expect(try !storedPause(defaults).isPaused)

        // Danach Abgleich wie nach Pausenende: das bekannte Medium wird indiziert.
        #expect(await waitUntil { !rig.starts(mediumID).isEmpty })
        #expect(await waitUntil { app.medium(with: mediumID)?.indexStatus != .indexing && !rig.service.isRunActive(mediumID) })
    }

    /// Gleiche Schalter wie im Betrieb: Mitteilungen aus → keine Meldung, die Pause ist trotzdem vorbei.
    @Test func expiredPauseAtLaunchRespectsTheNoticeSwitch() throws {
        let defaults = try defaultsWithExpiredPause()
        let app = AppState(defaults: defaults)
        app.appSettings.notificationsEnabled = true
        app.appSettings.notifySystem = false
        var kinds: [String] = []
        let hooks = NoticeTestHooks(post: { _, kind in kinds.append(kind) })
        SystemNotice.$testHooks.withValue(hooks) {
            app.refreshGlobalPause(defaults: defaults)
        }
        #expect(kinds.isEmpty)
        #expect(!app.globalAutoIndexPaused)
        #expect(try !storedPause(defaults).isPaused)
    }

    /// Ablauf im Betrieb (Vergleich): dieselbe Meldung mit derselben Art.
    @Test func runtimeExpiryPostsTheSameNotice() throws {
        let defaults = try #require(UserDefaults(suiteName: "PauseExpiredRuntime-\(UUID().uuidString)"))
        let app = AppState(defaults: defaults)
        app.appSettings.notificationsEnabled = true
        app.appSettings.notifySystem = true
        let now = Date()
        var posts: [(body: String, kind: String)] = []
        let hooks = NoticeTestHooks(post: { request, kind in posts.append((request.content.body, kind)) })
        SystemNotice.$testHooks.withValue(hooks) {
            app.pauseIndexing(until: now.addingTimeInterval(60), defaults: defaults, now: now)
            app.refreshGlobalPause(now: now.addingTimeInterval(61), defaults: defaults)
        }
        let expired = posts.filter { $0.kind == "pause-expired" }
        #expect(expired.count == 1)
        #expect(expired.first?.body == LayoutCopy.noticePauseResumedManual)
    }
}

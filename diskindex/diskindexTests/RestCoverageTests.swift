import Foundation
import Testing
@testable import diskindex

struct RestCoverageTests {
    @Test func pauseUntilTomorrowIsNine() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 18))!
        let until = GlobalPause.untilTomorrow(from: now, calendar: calendar)
        let parts = calendar.dateComponents([.day, .hour, .minute], from: until)
        #expect(parts.day == 3)
        #expect(parts.hour == 9)
        #expect(parts.minute == 0)
        var pause = GlobalPause()
        pause.pause(until: until)
        #expect(pause.refresh(now: until.addingTimeInterval(-1)) == false)
        #expect(pause.refresh(now: until) == true)
        #expect(pause.isPaused == false)
    }

    @Test func foreverPauseDoesNotExpire() {
        var pause = GlobalPause()
        pause.pause(until: nil)
        #expect(pause.refresh(now: Date().addingTimeInterval(86_400)) == false)
        #expect(pause.isPaused)
    }

    @Test func cancellationIsNotOperationalFailure() {
        #expect(!DiskIndexLog.isOperationalFailure(CancellationError()))
    }

    @Test func noticesFollowSwitches() {
        var settings = AppSettings()
        settings.notificationsEnabled = false
        #expect(!DiskNotice.favorites.allowed(by: settings))
        settings.notificationsEnabled = true
        settings.notifyIndexed = false
        #expect(!DiskNotice.indexed.allowed(by: settings))
        #expect(DiskNotice.system.allowed(by: settings))
        settings.notifySystem = false
        #expect(!DiskNotice.system.allowed(by: settings))
        #expect(NoticeCopy.minimumVisibleSeconds == 59)
    }

    @Test func oldFavoriteSwitchFillsMissingFavoriteNotice() throws {
        let json = #"{"favoriteOnlineNotificationsEnabled":false,"scanDepth":3}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.notifyFavorites == false)
        #expect(settings.scanDepth == 3)
    }

    @Test func freshSettingsUseDepthFive() {
        #expect(AppSettings().scanDepth == 5)
    }

    @Test func progressNeverFallsAndStopsAtNinetyNine() {
        #expect(IndexRunGuard.nextProgress(previous: 0.4, proposed: 0.2, finished: false) == 0.4)
        #expect(IndexRunGuard.nextProgress(previous: 0.4, proposed: 1, finished: false) == 0.99)
        #expect(IndexRunGuard.nextProgress(previous: 0.4, proposed: 1, finished: true) == 1)
        #expect(IndexRunGuard.resumeDepth(completed: 2) == 2)
        #expect(IndexRunGuard.shouldPending(consecutiveTimeouts: 3))
        #expect(!IndexRunGuard.shouldPending(consecutiveTimeouts: 2))
    }

    @Test func failureReasonsStayGeneric() {
        #expect(IndexFailureReason.classify("permission denied") == .permission)
        #expect(IndexFailureReason.classify("no space left") == .diskSpace)
        #expect(IndexFailureReason.classify("sqlite disk I/O") == .database)
        #expect(IndexFailureReason.unknown.line == nil)
        #expect(IndexFailureReason.permission.line?.contains("/") == false)
    }

    @Test func automaticModalStopsAtThreePerHour() {
        let start = Date()
        #expect(FailureModalThrottle.allowsAutomatic(shown: 2, hourStart: start, now: start))
        #expect(!FailureModalThrottle.allowsAutomatic(shown: 3, hourStart: start, now: start.addingTimeInterval(10)))
        #expect(FailureModalThrottle.allowsAutomatic(shown: 3, hourStart: start, now: start.addingTimeInterval(3600)))
    }

    @Test func undecidedMediumIsHiddenUntilIndexed() {
        var medium = PreviewData.media[0]
        medium.decision = .undecided
        medium.completedDepth = 0
        medium.fileCount = 0
        medium.folderCount = 0
        #expect(!medium.isBrowsable)
        medium.decision = .dontIndex
        #expect(MediumChip.presentation(medium).text == "Nicht erlaubt")
        medium.completedDepth = 2
        medium.fileCount = 4
        #expect(medium.isBrowsable)
        medium.decision = .index
        medium.connectionStatus = .connected
        medium.indexStatus = .indexed
        #expect(MediumChip.presentation(medium).text == "Online")
    }

    @Test func databaseHealthAndScreenshotArgument() {
        #expect(DatabaseCare.isHealthy("ok"))
        #expect(!DatabaseCare.isHealthy("*** in database main ***"))
        #expect(ScreenshotPlan.folder(arguments: ["app", "--screenshots", "/tmp/shots"]) == "/tmp/shots")
        #expect(ScreenshotPlan.folder(arguments: ["app"]) == nil)
        let defaults = UserDefaults(suiteName: "diskindex-notice-\(UUID().uuidString)")!
        #expect(NoticePermission.shouldRequest(arguments: ["app"], defaults: defaults))
        #expect(!NoticePermission.shouldRequest(arguments: ["app", "--screenshots", "/tmp"], defaults: defaults))
    }
}

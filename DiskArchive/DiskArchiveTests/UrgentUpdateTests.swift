//
//  UrgentUpdateTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.002 (Konzept `datenbank.md` „Netz (API)“): `"urgent-update": true` → ganze Version `x.x.x`, Update-Dialog
//  sofort, auch bei „Auf Updates hinweisen: Aus“, nach „Schließen“ bei jeder Prüfung wieder und beim Start (gemerkt);
//  fehlt das Feld oder ist es `false`, gilt `n.n` wie bisher.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct UrgentUpdateTests {
    private let app040 = AppVersion(major: 0, minor: 4, patch: 0)
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var settings: SystemSettingsSnapshot {
        SystemSettingsSnapshot(betaExpiryNoticedAt: nil, apiLastSeen: now, lockedVersion: nil, firstRunAt: now)
    }

    @Test func responseReadsTheUrgentField() throws {
        let urgent = try #require(VersionCheckClient.response(from: Data(#"{"version":"0.4.1", "urgent-update": true}"#.utf8)))
        #expect(urgent.version == AppVersion(major: 0, minor: 4, patch: 1) && urgent.urgentUpdate)
        let plain = try #require(VersionCheckClient.response(from: Data(#"{"version":"0.4.1","neu":1}"#.utf8)))
        #expect(!plain.urgentUpdate, "fehlt = false, unbekannte Felder egal")
        let off = try #require(VersionCheckClient.response(from: Data(#"{"version":"0.4.1","urgent-update":false}"#.utf8)))
        #expect(!off.urgentUpdate)
    }

    @Test func urgentComparesTheWholeVersionPlainComparesMajorMinor() {
        let api = AppVersion(major: 0, minor: 4, patch: 1)
        let urgent = VersionLockEvaluator.evaluate(
            now: now, appVersion: app040, apiVersion: api, settings: settings, isFreshInstall: false, buildDate: nil,
            urgentUpdate: true
        )
        #expect(urgent.updateOffer?.urgent == true)
        #expect(urgent.updateOffer?.targetDisplay == "0.4.1")
        #expect(urgent.mutations.setUrgentUpdateVersion == "0.4.1")
        #expect(!urgent.lockState.isLocked, "dringendes Update sperrt nicht")
        let plain = VersionLockEvaluator.evaluate(
            now: now, appVersion: app040, apiVersion: api, settings: settings, isFreshInstall: false, buildDate: nil
        )
        #expect(plain.updateOffer == nil, "ohne Feld: n.n gleich, kein Dialog")
        #expect(plain.mutations.setUrgentUpdateVersion == "")
        let same = VersionLockEvaluator.evaluate(
            now: now, appVersion: api, apiVersion: api, settings: settings, isFreshInstall: false, buildDate: nil,
            urgentUpdate: true
        )
        #expect(same.updateOffer == nil, "gleiche Version: kein Dialog")
    }

    /// Beim Start (ohne Antwort) gilt die gemerkte dringende Version.
    @Test func rememberedUrgentVersionShowsAtLaunch() {
        var stored = settings
        stored.urgentUpdateVersion = "0.4.1"
        let local = VersionLockEvaluator.evaluate(
            now: now, appVersion: app040, apiVersion: nil, settings: stored, isFreshInstall: false, buildDate: nil
        )
        #expect(local.updateOffer?.urgent == true)
        #expect(local.mutations.setUrgentUpdateVersion == nil, "ohne Antwort bleibt der Merker")
    }

    @Test func dialogEvenWithNotificationsOffAndAgainAfterClosing() {
        let app = AppState()
        app.appSettings.notifyAboutUpdates = false
        let evaluation = VersionLockEvaluator.evaluate(
            now: now, appVersion: app040, apiVersion: AppVersion(major: 0, minor: 4, patch: 1), settings: settings,
            isFreshInstall: false, buildDate: nil, urgentUpdate: true
        )
        app.applyVersionLockEvaluation(evaluation)
        #expect(app.updateNotice?.offer.urgent == true, "Dialog trotz „Auf Updates hinweisen: Aus“")
        app.dismissUpdateNotice()
        #expect(app.updateNotice == nil)
        app.applyVersionLockEvaluation(evaluation)
        #expect(app.updateNotice != nil, "nach „Schließen“ bei der nächsten Prüfung wieder")
        // Ohne dringendes Feld und mit „Aus“ kein Dialog.
        let plain = VersionLockEvaluator.evaluate(
            now: now, appVersion: app040, apiVersion: AppVersion(major: 0, minor: 5, patch: 0), settings: settings,
            isFreshInstall: false, buildDate: nil
        )
        app.dismissUpdateNotice()
        app.applyVersionLockEvaluation(plain)
        #expect(app.updateNotice == nil)
    }
}

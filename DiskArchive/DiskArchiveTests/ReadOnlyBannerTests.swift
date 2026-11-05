//
//  ReadOnlyBannerTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.020 (Layout 04.03a–04.06): Banner im Nur-Lesen-Modus – je Zustand Farbe, Text und Knopf; die Beta-Frist
//  zählt herunter („noch 1 Tag“); Rot gewinnt; „Jetzt prüfen“ mit beiden Ausgängen; kein Banner während des
//  Update-Dialogs. Die Regeln der Sperre (`VersionLockEvaluator`) bleiben, nur die Frist wird für die Anzeige gemeldet.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct ReadOnlyBannerTests {
    private func evaluation(_ lock: VersionLockState, deadline: Date? = nil) -> VersionLockEvaluation {
        VersionLockEvaluation(
            lockState: lock, updateOffer: nil, showLockBanner: lock.isLocked, mutations: VersionLockSettingsMutations(),
            betaNoticeDeadline: deadline
        )
    }

    @Test func eachStateHasColourTextAndButton() {
        L10n.$languageOverride.withValue(.german) {
            let notice = ReadOnlyBanner.betaNotice(daysLeft: 7)
            #expect(!notice.isLock && notice.iconAsset == "IconBannerWarning")
            #expect(notice.title == "Die Betaphase von Disk Archive wurde beendet.")
            #expect(notice.info == "Du kannst Disk Archive noch 7 Tage nutzen.")
            #expect(ReadOnlyBanner.betaNotice(daysLeft: 1).info == "Du kannst Disk Archive noch 1 Tag nutzen.")
            #expect(notice.action?.title == "Zur neuen Version" && notice.action?.kind == .website)

            let beta = ReadOnlyBanner.betaExpired
            #expect(beta.isLock && beta.iconAsset == "IconLockSimple")
            #expect(beta.title == "Disk Archive befindet sich im Nur-Lesen-Modus.")
            #expect(beta.info?.hasPrefix("Die Betaphase ist beendet.") == true)
            #expect(beta.action?.kind == .website)

            let build = ReadOnlyBanner.buildExpired
            #expect(build.isLock && build.info?.hasPrefix("Diese Version ist abgelaufen.") == true)
            #expect(build.action?.kind == .website)

            let server = ReadOnlyBanner.licenseServerUnreachable
            #expect(server.isLock && server.iconAsset == "IconWifiSlash")
            #expect(server.info?.hasPrefix("Der Lizenzserver war seit einem Monat nicht erreichbar.") == true)
            #expect(server.action?.title == "Jetzt prüfen" && server.action?.kind == .checkNow)

            let checking = ReadOnlyBanner.checking
            #expect(checking.isLock && checking.iconAsset == nil && checking.info == nil && checking.action == nil)
            #expect(checking.title == "Versionsprüfung …")
        }
    }

    @Test func lockReasonsMapToRedBanners() {
        let app = AppState()
        for (reason, banner) in [
            (VersionLockReason.betaExpired, ReadOnlyBanner.betaExpired), (.buildExpired, .buildExpired),
            (.apiUnreachable, .licenseServerUnreachable),
        ] {
            app.applyVersionLockEvaluation(evaluation(.locked(reason)))
            #expect(app.readOnlyBanner() == banner)
        }
        app.applyVersionLockEvaluation(evaluation(.unlocked))
        #expect(app.readOnlyBanner() == nil)
    }

    @Test func betaNoticeCountsDownAndRedWins() {
        let app = AppState()
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        app.applyVersionLockEvaluation(evaluation(.unlocked, deadline: deadline))
        #expect(app.readOnlyBanner(now: deadline.addingTimeInterval(-7 * 86_400)) == .betaNotice(daysLeft: 7))
        #expect(app.readOnlyBanner(now: deadline.addingTimeInterval(-2 * 86_400 + 60)) == .betaNotice(daysLeft: 2))
        #expect(app.readOnlyBanner(now: deadline.addingTimeInterval(-3_600)) == .betaNotice(daysLeft: 1))
        #expect(app.readOnlyBanner(now: deadline) == nil, "Frist abgelaufen: kein gelber Banner")
        // Mehrere Gründe: Rot gewinnt (04.05).
        app.applyVersionLockEvaluation(evaluation(.locked(.buildExpired), deadline: deadline))
        #expect(app.readOnlyBanner(now: deadline.addingTimeInterval(-86_400 * 3)) == .buildExpired)
        // Während des Update-Dialogs kein Banner (er folgt ihm).
        app.applyVersionLockEvaluation(evaluation(.unlocked, deadline: deadline))
        app.updateNotice = UpdateNotice(
            offer: UpdateOffer(currentDisplay: "0.4", targetDisplay: "1.0", targetMajorMinor: AppVersion(major: 1, minor: 0, patch: 0), showBetaCountdown: true),
            notifyAboutUpdates: true
        )
        #expect(app.readOnlyBanner(now: deadline.addingTimeInterval(-86_400)) == nil)
    }

    /// Die Frist für die Anzeige: 7 Tage ab dem gemerkten Zeitpunkt, nur für Betaversionen ohne Sperre.
    @Test func evaluatorReportsTheDeadline() throws {
        let noticed = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let settings = SystemSettingsSnapshot(betaExpiryNoticedAt: noticed, apiLastSeen: noticed, lockedVersion: nil, firstRunAt: noticed)
        let beta = AppVersion(major: 0, minor: 4, patch: 3)
        let open = VersionLockEvaluator.evaluate(
            now: noticed.addingTimeInterval(86_400), appVersion: beta, apiVersion: nil, settings: settings,
            isFreshInstall: false, buildDate: nil
        )
        let expected = try #require(Calendar.current.date(byAdding: .day, value: 7, to: noticed))
        #expect(open.betaNoticeDeadline == expected)
        #expect(!open.lockState.isLocked)
        let late = VersionLockEvaluator.evaluate(
            now: noticed.addingTimeInterval(8 * 86_400), appVersion: beta, apiVersion: AppVersion(major: 1, minor: 0, patch: 0),
            settings: settings, isFreshInstall: false, buildDate: nil
        )
        #expect(late.lockState == .locked(.betaExpired))
        #expect(late.betaNoticeDeadline == nil, "gesperrt: kein gelber Banner mehr")
    }

    @Test func checkNowShowsSpinnerThenEitherClearsOrReturnsToRed() async {
        let app = AppState()
        app.applyVersionLockEvaluation(evaluation(.locked(.apiUnreachable)))
        // Ausgang 1: Lizenzserver weiter nicht erreichbar → zurück zum roten Banner.
        let gate = ColumnFilterGate()
        app.onCheckLicenseServerNow = {
            await gate.wait()
            return false
        }
        app.checkLicenseServerNow()
        #expect(app.readOnlyBanner() == .checking)
        gate.open()
        #expect(await waitUntil(timeout: 20) { !app.licenseServerCheckInProgress })
        #expect(app.readOnlyBanner() == .licenseServerUnreachable)
        // Ausgang 2: erreichbar → die Auswertung entsperrt, der Banner ist weg.
        app.onCheckLicenseServerNow = { [weak app] in
            app?.applyVersionLockEvaluation(VersionLockEvaluation(
                lockState: .unlocked, updateOffer: nil, showLockBanner: false, mutations: VersionLockSettingsMutations()
            ))
            return true
        }
        app.checkLicenseServerNow()
        #expect(await waitUntil(timeout: 20) { !app.licenseServerCheckInProgress })
        #expect(app.readOnlyBanner() == nil)
    }

    /// Gelb `#EDA12D` = Hinweis, Rot `#E04830` = Sperre (Fläche im Bild).
    @Test func bannerColours() async {
        let app = AppState()
        let size = CGSize(width: 600, height: 70)
        for (banner, red) in [(ReadOnlyBanner.betaNotice(daysLeft: 3), false), (.licenseServerUnreachable, true)] {
            let bitmap = await PixelProbe.render(
                ReadOnlyBannerView(banner: banner).environment(app)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .background(Color.white),
                size: size
            )
            let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: 300, y: 4))
            // Farbton statt exakter Werte (die Aufnahme rechnet den Farbraum um, wie in `ColumnFolderStatusTests`).
            let ratio = sample.greenComponent / max(sample.redComponent, 0.01)
            if red {
                #expect(sample.redComponent > 0.75 && ratio < 0.55 && sample.blueComponent < 0.4, "nicht rot: \(sample)")
            } else {
                #expect(sample.redComponent > 0.8 && ratio > 0.6 && ratio < 0.85 && sample.blueComponent < 0.45, "nicht gelb: \(sample)")
            }
        }
    }
}

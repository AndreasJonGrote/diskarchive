//
//  DelayedLoadingStateTests.swift
//  DiskArchiveTests
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
@Suite struct DelayedLoadingStateTests {
    private let fastTiming = DelayedLoadingTiming(
        delayBeforeHint: .milliseconds(50),
        minimumHintVisible: .milliseconds(20)
    )

    /// Großer Abstand statt Millisekunden-Rennen: Das Laden ist sofort fertig, die Verzögerung beträgt 400 ms,
    /// danach wird 600 ms gewartet. Last im Parallellauf kann den Test nicht mehr kippen (F21).
    @Test func fastLoadNeverShowsHint() async {
        let state = DelayedLoadingState(timing: DelayedLoadingTiming(
            delayBeforeHint: .milliseconds(400),
            minimumHintVisible: .milliseconds(20)
        ))
        state.beginLoading(total: 10)
        state.finishLoading()
        #expect(!state.showsHint)
        try? await Task.sleep(for: .milliseconds(600))
        #expect(!state.showsHint, "der Hinweis darf nach schnellem Laden nie erscheinen")
    }

    @Test func slowLoadShowsHintAfterDelay() async {
        let state = DelayedLoadingState(timing: fastTiming)
        state.beginLoading(total: 100)
        // Direkt nach dem Start (synchron, vor Ablauf der 50 ms) ist der Hinweis noch aus.
        #expect(!state.showsHint)
        // bug.0.3.8.007: Zeitbudget (Standard 10 s) statt 40 × 10 ms — Last im Parallel-Lauf
        // darf das Erscheinen verzögern, aber nicht den Test kippen.
        let sawHint = await waitUntil { state.showsHint }
        #expect(sawHint)
        state.finishLoading()
        // bug.0.3.8.007: ebenso fürs Ausblenden nach der Mindestanzeige (20 ms) statt 20 × 10 ms.
        let hidden = await waitUntil { !state.showsHint }
        #expect(hidden)
    }

    @Test func resetClearsHint() async {
        let state = DelayedLoadingState(timing: fastTiming)
        state.beginLoading(total: 5)
        state.reset()
        try? await Task.sleep(for: .milliseconds(60))
        #expect(!state.showsHint)
    }
}

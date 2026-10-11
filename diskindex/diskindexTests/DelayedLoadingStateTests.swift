//
//  DelayedLoadingStateTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

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
        var sawHint = false
        for _ in 0..<40 {
            if state.showsHint {
                sawHint = true
                break
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(sawHint)
        state.finishLoading()
        for _ in 0..<20 where state.showsHint {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(!state.showsHint)
    }

    @Test func resetClearsHint() async {
        let state = DelayedLoadingState(timing: fastTiming)
        state.beginLoading(total: 5)
        state.reset()
        try? await Task.sleep(for: .milliseconds(60))
        #expect(!state.showsHint)
    }
}

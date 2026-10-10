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

    @Test func fastLoadNeverShowsHint() async {
        let state = DelayedLoadingState(timing: fastTiming)
        state.beginLoading(total: 10)
        try? await Task.sleep(for: .milliseconds(10))
        state.finishLoading()
        try? await Task.sleep(for: .milliseconds(80))
        #expect(!state.showsHint)
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

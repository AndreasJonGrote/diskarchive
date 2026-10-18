//
//  DelayedLoadingState.swift
//  diskindex
//
//  UX: Ladehinweis erst nach Verzögerung, Mindestanzeige, kein Flackern (Nutzer 06.10., T1).
//

import Foundation
import Observation

nonisolated struct DelayedLoadingTiming: Sendable, Equatable {
    var delayBeforeHint: Duration = .seconds(1)
    var minimumHintVisible: Duration = .milliseconds(400)

    static let standard = DelayedLoadingTiming()
}

@MainActor
@Observable
final class DelayedLoadingState {

    private(set) var showsHint = false
    private(set) var loadedCount = 0
    private(set) var totalCount = 0

    private let timing: DelayedLoadingTiming
    private(set) var isActive = false
    /// `finishLoading` wartet noch auf das Ende der Mindestanzeige (bug.0.4.061).
    private(set) var isFinishPending = false
    private var loadGeneration = 0
    private var hintShownAt: ContinuousClock.Instant?
    private var loadingStartedAt: ContinuousClock.Instant?
    private var delayTask: Task<Void, Never>?
    private var minimumVisibleTask: Task<Void, Never>?

    init(timing: DelayedLoadingTiming = .standard) {
        self.timing = timing
    }

    func beginLoading(total: Int = 0) {
        resetInternal()
        isActive = true
        loadingStartedAt = ContinuousClock.now
        loadGeneration &+= 1
        let generation = loadGeneration
        totalCount = max(0, total)
        loadedCount = 0
        if timing.delayBeforeHint == .zero {
            showsHint = true
            hintShownAt = ContinuousClock.now
        } else {
            delayTask = Task {
                try? await Task.sleep(for: timing.delayBeforeHint)
                guard !Task.isCancelled, generation == loadGeneration else { return }
                showsHint = true
                hintShownAt = ContinuousClock.now
            }
            let comps = timing.delayBeforeHint.components
            let seconds = Double(comps.seconds) + Double(comps.attoseconds) / 1_000_000_000_000_000_000
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, generation == self.loadGeneration, !self.showsHint else { return }
                    self.showsHint = true
                    self.hintShownAt = ContinuousClock.now
                }
            }
        }
    }

    /// Falls der geplante Takt in einem Testfenster nicht läuft: Zeit trotzdem nachziehen.
    func catchUpToClock() {
        guard isActive, !showsHint, let start = loadingStartedAt else { return }
        guard start.duration(to: .now) >= timing.delayBeforeHint else { return }
        showsHint = true
        hintShownAt = ContinuousClock.now
    }

    func updateProgress(loaded: Int, total: Int) {
        loadedCount = max(0, loaded)
        if total > 0 {
            totalCount = total
        } else if loadedCount > totalCount {
            totalCount = loadedCount
        }
    }

    /// Ladevorgang beendet — bei schnellem Laden (< delay) nie `showsHint`.
    func finishLoading() {
        delayTask?.cancel()
        delayTask = nil
        guard showsHint else {
            loadGeneration &+= 1
            isActive = false
            return
        }
        guard let shown = hintShownAt else {
            showsHint = false
            return
        }
        let visible = shown.duration(to: .now)
        if visible >= timing.minimumHintVisible {
            showsHint = false
            hintShownAt = nil
            isActive = false
            return
        }
        let wait = timing.minimumHintVisible - visible
        let generation = loadGeneration
        isFinishPending = true
        minimumVisibleTask = Task {
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, generation == loadGeneration else { return }
            isFinishPending = false
            showsHint = false
            hintShownAt = nil
            isActive = false
        }
    }

    /// Neuer Ladevorgang während der Mindestanzeige (bug.0.4.061, REPORT 107): Der Hinweis bleibt stehen,
    /// das ausstehende Ausblenden entfällt; `showsHint`, `isActive` und `hintShownAt` bleiben erhalten.
    func resumeLoading() {
        guard isFinishPending else { return }
        minimumVisibleTask?.cancel()
        minimumVisibleTask = nil
        isFinishPending = false
    }

    func reset() {
        resetInternal()
        loadGeneration &+= 1
    }

    private func resetInternal() {
        delayTask?.cancel()
        minimumVisibleTask?.cancel()
        delayTask = nil
        minimumVisibleTask = nil
        isFinishPending = false
        showsHint = false
        hintShownAt = nil
        loadingStartedAt = nil
        isActive = false
        loadedCount = 0
        totalCount = 0
    }
}

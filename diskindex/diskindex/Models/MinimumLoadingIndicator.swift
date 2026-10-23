//
//  MinimumLoadingIndicator.swift
//  diskindex
//
//  todo.0.4.043 (gemeinsamer Baustein mit todo.0.4.042, Regel 12): Ladeanzeige von Favoriten und Suche – sofort
//  sichtbar und mindestens `minimum` lang (Konzept „Ladeanzeige von Suche und Favoriten“), danach die Inhalte in einem
//  Schritt. Die Mindestdauer ist ein Parameter je Instanz (Regel 20: kein prozessweiter Schalter).
//

import Foundation
import Observation

@MainActor
@Observable
final class MinimumLoadingIndicator {
    /// Ladefläche zeigen (statt Inhalt oder Leerzustand).
    private(set) var isShowing = false
    @ObservationIgnored let minimum: Duration
    @ObservationIgnored private var shownAt: ContinuousClock.Instant?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    init(minimum: Duration = .seconds(1)) {
        self.minimum = minimum
    }

    /// Laden beginnt: sofort zeigen.
    func begin() {
        hideTask?.cancel()
        hideTask = nil
        shownAt = .now
        isShowing = true
    }

    /// Daten sind da: ausblenden, sobald `minimum` seit `begin` vergangen ist.
    func finish() {
        guard isShowing, hideTask == nil, let shownAt else { return }
        let remaining = minimum - shownAt.duration(to: .now)
        guard remaining > .zero else {
            isShowing = false
            return
        }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: remaining)
            guard !Task.isCancelled, let self else { return }
            self.hideTask = nil
            self.isShowing = false
        }
    }

    /// Sofort ausblenden (Ansicht verlassen, Beenden).
    func cancel() {
        hideTask?.cancel()
        hideTask = nil
        shownAt = nil
        isShowing = false
    }
}

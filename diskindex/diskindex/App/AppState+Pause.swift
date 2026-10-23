//
//  AppState+Pause.swift
//  diskindex
//
//  Aus AppState.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import SwiftUI

extension AppState {
    var pauseSnapshot: GlobalPause { storedPause }

    func loadPause(from defaults: UserDefaults = AppDefaults.current, now: Date = Date()) {
        if let data = defaults.data(forKey: Self.pauseKey),
           let decoded = try? JSONDecoder().decode(GlobalPause.self, from: data) {
            storedPause = decoded
        }
        // todo.0.4.027: Eine Pause, die bei beendeter App abgelaufen ist, wird hier nicht still aufgelöst. Den Ablauf
        // erledigt `refreshGlobalPause` beim Start (`applicationDidFinishLaunching`, nach der Einzelinstanz-Prüfung)
        // wie im Betrieb: Mitteilung „pause-expired“, Speichern, Abgleich über `globalAutoIndexPaused`.
        globalAutoIndexPaused = storedPause.isPaused || settingsUnreadable
        if !pauseExpired(at: now) {
            schedulePauseExpiryCheck(now: now)
        }
    }

    /// Befristete Pause, deren Ende erreicht ist (noch nicht aufgelöst).
    private func pauseExpired(at now: Date) -> Bool {
        guard storedPause.isPaused, !storedPause.forever, let until = storedPause.until else { return false }
        return now >= until
    }

    func pauseIndexing(until date: Date?, defaults: UserDefaults = AppDefaults.current, now: Date = Date()) {
        storedPause.pause(until: date)
        globalAutoIndexPaused = true
        savePause(defaults)
        schedulePauseExpiryCheck(now: now)
        SystemNotice.post(
            body: PauseNoticeCopy.began(until: date, now: now),
            settings: appSettings,
            event: .system,
            kind: "pause-began"
        )
    }

    func resumeIndexing(defaults: UserDefaults = AppDefaults.current) {
        let wasPaused = storedPause.isPaused
        storedPause.resume()
        globalAutoIndexPaused = settingsUnreadable
        savePause(defaults)
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
        // bug.0.4.162 (e): unlesbare Einstellungen halten die Sitzung pausiert – keine Meldung „fortgesetzt“.
        guard wasPaused, !settingsUnreadable else { return }
        SystemNotice.post(
            body: LayoutCopy.noticePauseResumedManual,
            settings: appSettings,
            event: .system,
            kind: "pause-resumed"
        )
    }

    func refreshGlobalPause(now: Date = Date(), defaults: UserDefaults = AppDefaults.current) {
        guard storedPause.refresh(now: now) else { return }
        globalAutoIndexPaused = settingsUnreadable
        savePause(defaults)
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
        guard !settingsUnreadable else { return }
        SystemNotice.post(
            body: LayoutCopy.noticePauseResumedManual,
            settings: appSettings,
            event: .system,
            kind: "pause-expired"
        )
    }

    func schedulePauseExpiryCheck(now: Date = Date()) {
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
        guard storedPause.isPaused, !storedPause.forever, let until = storedPause.until else { return }
        let delay = until.timeIntervalSince(now)
        pauseExpiryTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self?.refreshGlobalPause(now: until)
        }
    }

    /// Store-Fehler bei geöffnetem Store (bug.0.4.052, REPORT 92): Abbau wie beim Beenden, danach Store lösen; die
    /// befristete Pause läuft trotzdem ab (der Abbau bricht `pauseExpiryTask` ab, hier wird er neu geplant).
    func detachAfterStoreFailure(now: Date = Date()) {
        prepareForTermination()
        detachFromIndexStore()
        schedulePauseExpiryCheck(now: now)
    }

    func savePause(_ defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(storedPause) {
            defaults.set(data, forKey: Self.pauseKey)
        }
    }

    func presentIndexingFailure(mediumID: UUID, name: String, reason: IndexFailureReason, now: Date = Date(), defaults: UserDefaults = AppDefaults.current) {
        var counts = (try? JSONDecoder().decode([String: FailureCount].self, from: defaults.data(forKey: Self.failureCountsKey) ?? Data())) ?? [:]
        var count = counts[mediumID.uuidString] ?? FailureCount(shown: 0, hourStart: now)
        if now.timeIntervalSince(count.hourStart) >= 3_600 {
            count = FailureCount(shown: 0, hourStart: now)
        }
        guard FailureModalThrottle.allowsAutomatic(shown: count.shown, hourStart: count.hourStart, now: now) else { return }
        count.shown += 1
        counts[mediumID.uuidString] = count
        if let data = try? JSONEncoder().encode(counts) {
            defaults.set(data, forKey: Self.failureCountsKey)
        }
        indexingFailure = IndexingFailureNotice(id: mediumID, name: name, reason: reason)
        SystemNotice.postIndexingFailure(mediumID: mediumID, name: name, reason: reason, settings: appSettings)
    }

    /// Aufwachen nach dem Ruhezustand (bug.0.4.028): Pause neu bewerten, die Indizierung genau einmal anstoßen
    /// (läuft die Pause dabei ab, hat `globalAutoIndexPaused.didSet` das schon getan), danach Bereinigung und
    /// `restartWatchers`. `AppDelegate` und Tests rufen dieselbe Funktion.
    @discardableResult
    func handleWake(restartWatchers: (@MainActor () async -> Void)? = nil) -> Task<Void, Never> {
        let pauseBefore = globalAutoIndexPaused
        heldForSleep = false
        refreshGlobalPause()
        if pauseBefore == globalAutoIndexPaused {
            onAutoIndexPauseChanged?()
        }
        return Task { @MainActor in
            await pruneIfDue()
            await restartWatchers?()
        }
    }
}

nonisolated struct FailureCount: Codable {
    var shown: Int
    var hourStart: Date
}

/// Rückfrage vor dem Ignorieren vieler Ziele auf einmal (bug.0.4.035, todo.0.4.031).
nonisolated struct IgnoreConfirmationPrompt: Equatable {
    var count: Int
    var patterns: [String]
}

/// Rückfrage „Ersetzt dieses Medium?“ (bug.0.4.031 c, todo.0.4.032): neues Medium und ein Offline-Medium gleichen Namens.
nonisolated struct ReplaceMediumPrompt: Equatable, Identifiable {
    var newID: UUID
    var oldID: UUID
    var name: String
    var id: UUID { newID }
}

nonisolated struct IndexingFailureNotice: Equatable, Identifiable {
    var id: UUID
    var name: String
    var reason: IndexFailureReason
}

enum MenuBarBadgePreview: String, CaseIterable, Identifiable {
    case idle
    case indexing
    case syncing
    case newlyDetected
    case paused
    case error

    var id: String { rawValue }
}

//
//  MediumMonitor.swift
//  diskindex
//

import AppKit

@MainActor
final class MediumMonitor {
    private var debouncer = MountEventDebouncer()
    /// bug.0.4.028: beim Aufwachen kein `.appeared`, wenn Pfad schon verbunden ist.
    var skipWakeAppearedIfKnown: ((VolumeInfo) -> Bool)?
    /// Eingehängte Kandidaten-Volumes als fertige Liste (nur Tests). `nil` (Produktion): Pfade aus
    /// `candidateMountPaths` über `lookupFlights` abfragen, hängende wie beim Einhängen erneut versuchen.
    private let mountedVolumes: (@MainActor () async -> [VolumeInfo])?
    /// Kandidaten-Pfade für Start- und Aufwach-Scan, ohne Volume-Zugriff (Tests: eigene Liste).
    private let candidateMountPaths: @MainActor () -> [String]
    /// Aufwach-Auslöser (Tests: eigener Strom statt `NSWorkspace.didWakeNotification`).
    private let wakeEvents: @MainActor () -> AsyncStream<Void>
    /// Ein-/Aushänge-Meldungen (Tests: eigenes Center statt des gemeinsamen von `NSWorkspace`).
    private let notificationCenter: NotificationCenter
    /// bug.0.3.9.012: höchstens eine laufende Abfrage je Pfad, Zeitgrenze je Versuch, Wartezeiten vor jedem neuen
    /// Versuch und Protokollsenke (Meldung, Pfad) — je Instanz, Tests setzen kurze Zeiten und eine eigene Senke.
    private let lookupFlights: VolumeLookupFlights
    private let lookupTimeout: TimeInterval
    private let mountRetryDelays: [TimeInterval]
    private let log: @Sendable (String, String) -> Void
    /// Eingehängte Pfade, deren Abfrage noch läuft oder wartet; Aushängen bricht ab (bug.0.3.9.012).
    private var pendingMounts: [String: PendingMount] = [:]

    private struct PendingMount {
        let token: UUID
        let task: Task<Void, Never>
    }

    /// Wartezeiten vor dem 2., 3. und 4. Versuch (bug.0.3.9.012), danach „volume nicht erreichbar“.
    nonisolated static let defaultMountRetryDelays: [TimeInterval] = [5, 15, 30]

    init(
        mountedVolumes: (@MainActor () async -> [VolumeInfo])? = nil,
        candidateMountPaths: @escaping @MainActor () -> [String] = { LocalVolumeMounts.candidateMountPaths() },
        wakeEvents: @escaping @MainActor () -> AsyncStream<Void> = MediumMonitor.liveWakeEvents,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        lookupFlights: VolumeLookupFlights = VolumeLookupFlights(),
        lookupTimeout: TimeInterval = VolumeLookup.defaultTimeout,
        mountRetryDelays: [TimeInterval] = MediumMonitor.defaultMountRetryDelays,
        log: @escaping @Sendable (String, String) -> Void = { message, path in
            DiskIndexLog.shared.record(.medium, .error, message, privateDetail: path)
        }
    ) {
        self.mountedVolumes = mountedVolumes
        self.candidateMountPaths = candidateMountPaths
        self.wakeEvents = wakeEvents
        self.notificationCenter = notificationCenter
        self.lookupFlights = lookupFlights
        self.lookupTimeout = lookupTimeout
        self.mountRetryDelays = mountRetryDelays
        self.log = log
    }

    static func liveWakeEvents() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let center = NSWorkspace.shared.notificationCenter
            let token = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                continuation.yield()
            }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in center.removeObserver(token) }
            }
        }
    }

    func events() -> AsyncStream<MediumEvent> {
        AsyncStream { continuation in
            let center = self.notificationCenter
            let tokens = [
                center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitMount(note, continuation: continuation)
                    }
                },
                center.addObserver(forName: NSWorkspace.willUnmountNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitPath(note, kind: "will", event: { .willDisappear(path: $0) }, continuation: continuation)
                    }
                },
                center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitPath(note, kind: "did", event: { .disappeared(path: $0) }, continuation: continuation)
                    }
                },
                center.addObserver(forName: NSWorkspace.didRenameVolumeNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitRename(note, continuation: continuation)
                    }
                },
            ]
            let wakes = self.wakeEvents()
            let wakeTask = Task { @MainActor in
                for await _ in wakes {
                    self.emitMounted(continuation: continuation, wakeRescan: true)
                }
            }
            self.emitMounted(continuation: continuation, wakeRescan: false)
            continuation.onTermination = { @Sendable _ in
                wakeTask.cancel()
                Task { @MainActor in
                    for token in tokens {
                        center.removeObserver(token)
                    }
                    self.cancelAllPendingMounts()
                }
            }
        }
    }

    private func emitMounted(continuation: AsyncStream<MediumEvent>.Continuation, wakeRescan: Bool) {
        guard let mountedVolumes else {
            scanMounted(continuation: continuation, wakeRescan: wakeRescan)
            return
        }
        Task {
            for info in await mountedVolumes() {
                await MainActor.run {
                    self.emitScanned(info, wakeRescan: wakeRescan, continuation: continuation)
                }
            }
        }
    }

    /// Start- und Aufwach-Scan (bug.0.3.9.012): alle Kandidaten-Pfade gleichzeitig über `lookupFlights` (ein hängendes
    /// Volume hält die anderen nicht auf); ein Pfad mit Zeitgrenze geht an `resolveMount` und wird wie beim
    /// Einhängen erneut versucht, Aushängen bricht ab.
    private func scanMounted(continuation: AsyncStream<MediumEvent>.Continuation, wakeRescan: Bool) {
        let paths = candidateMountPaths()
        let flights = lookupFlights
        let timeout = lookupTimeout
        Task { @MainActor in
            await withTaskGroup(of: (String, VolumeLookupOutcome).self) { group in
                for path in paths {
                    group.addTask {
                        let url = URL(fileURLWithPath: path, isDirectory: true)
                        return (path, await flights.attempt(at: url, timeout: timeout))
                    }
                }
                for await (path, outcome) in group {
                    switch outcome {
                    case .found(let info):
                        self.emitScanned(info, wakeRescan: wakeRescan, continuation: continuation)
                    case .timedOut:
                        self.log("volume-lookup zeitgrenze", path)
                        self.startMountResolution(
                            url: URL(fileURLWithPath: path, isDirectory: true),
                            continuation: continuation,
                            wakeRescan: wakeRescan,
                            firstAttemptDone: true
                        )
                    case .missing:
                        break
                    }
                }
            }
        }
    }

    private func emitScanned(_ info: VolumeInfo, wakeRescan: Bool, continuation: AsyncStream<MediumEvent>.Continuation) {
        guard VolumeCandidateRule.isCandidate(info.candidateInput) else { return }
        if wakeRescan, skipWakeAppearedIfKnown?(info) == true { return }
        guard debouncer.shouldEmit(path: info.mountPath, kind: "appeared") else { return }
        // bug.0.3.9.012: schon gemeldet → ein noch wartender neuer Versuch meldet nicht ein zweites Mal.
        cancelPendingMount(path: info.mountPath)
        continuation.yield(.appeared(info))
    }

    private func emitMount(_ note: Notification, continuation: AsyncStream<MediumEvent>.Continuation) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let path = url.standardizedFileURL.path
        guard path.hasPrefix("/Volumes/") else { return }
        startMountResolution(url: url, continuation: continuation, wakeRescan: false, firstAttemptDone: false)
    }

    /// Abfrage mit Wiederholung für einen Pfad anmelden (Einhängen, Scan mit Zeitgrenze, Umbenennen während des
    /// Wartens). Läuft für den Pfad schon eine, nichts Neues starten (doppelte Meldung).
    private func startMountResolution(
        url: URL,
        continuation: AsyncStream<MediumEvent>.Continuation,
        wakeRescan: Bool,
        firstAttemptDone: Bool
    ) {
        // bug.0.4.068 c: Abfrage unter dem standardisierten Pfad, damit Aushängen und Umbenennen den Flug finden.
        let url = url.standardizedFileURL
        let path = url.path
        guard pendingMounts[path] == nil else { return }
        let token = UUID()
        let task = Task { @MainActor in
            await self.resolveMount(
                url: url, path: path, token: token, continuation: continuation,
                wakeRescan: wakeRescan, firstAttemptDone: firstAttemptDone
            )
        }
        pendingMounts[path] = PendingMount(token: token, task: task)
    }

    /// bug.0.3.9.012: Abfrage mit Zeitgrenze; kommt keine Antwort (Platte läuft an), nach den Wartezeiten erneut
    /// versuchen (an eine noch laufende Abfrage angehängt), danach Protokollzeile. Jeder Pfad hat seinen eigenen Task,
    /// andere Volumes warten nicht. Ausgehängt (Eintrag weg oder Task abgebrochen) → nicht weiter versuchen.
    private func resolveMount(
        url: URL,
        path: String,
        token: UUID,
        continuation: AsyncStream<MediumEvent>.Continuation,
        wakeRescan: Bool,
        firstAttemptDone: Bool
    ) async {
        var delays = mountRetryDelays[...]
        if firstAttemptDone {
            // Der Scan hat den ersten Versuch schon gemacht: zuerst warten.
            guard let delay = delays.popFirst() else {
                if isPendingMount(path, token: token) { pendingMounts[path] = nil }
                log("volume nicht erreichbar", path)
                return
            }
            try? await Task.sleep(for: .seconds(delay))
        }
        while isPendingMount(path, token: token) {
            let outcome = await lookupFlights.attempt(at: url, timeout: lookupTimeout)
            guard isPendingMount(path, token: token) else { return }
            switch outcome {
            case .found(let info):
                pendingMounts[path] = nil
                if wakeRescan, skipWakeAppearedIfKnown?(info) == true { return }
                guard VolumeCandidateRule.isCandidate(info.candidateInput),
                      debouncer.shouldEmit(path: info.mountPath, kind: "appeared") else { return }
                continuation.yield(.appeared(info))
                return
            case .missing, .timedOut:
                if outcome == .timedOut {
                    log("volume-lookup zeitgrenze", path)
                }
                guard let delay = delays.popFirst() else {
                    pendingMounts[path] = nil
                    log("volume nicht erreichbar", path)
                    return
                }
                try? await Task.sleep(for: .seconds(delay))
                if Task.isCancelled { return }
            }
        }
    }

    private func isPendingMount(_ path: String, token: UUID) -> Bool {
        !Task.isCancelled && pendingMounts[path]?.token == token
    }

    private func cancelPendingMount(path: String) {
        pendingMounts.removeValue(forKey: path)?.task.cancel()
    }

    private func cancelAllPendingMounts() {
        for pending in pendingMounts.values {
            pending.task.cancel()
        }
        pendingMounts.removeAll()
    }

    private func emitRename(_ note: Notification, continuation: AsyncStream<MediumEvent>.Continuation) {
        guard let newURL = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
              let oldURL = note.userInfo?[NSWorkspace.oldVolumeURLUserInfoKey] as? URL else { return }
        let oldPath = oldURL.standardizedFileURL.path
        // bug.0.3.9.012: umbenannt, während das Einhängen noch wartet → das Volume ist noch nicht gemeldet; unter dem
        // neuen Pfad neu abfragen und als Einhängen melden statt `.renamed`.
        if pendingMounts[oldPath] != nil {
            cancelPendingMount(path: oldPath)
            lookupFlights.abandon(path: oldPath)
            startMountResolution(url: newURL, continuation: continuation, wakeRescan: false, firstAttemptDone: false)
            return
        }
        let flights = lookupFlights
        let timeout = lookupTimeout
        Task { @MainActor in
            guard case .found(let info) = await flights.attempt(at: newURL, timeout: timeout) else { return }
            guard self.debouncer.shouldEmit(path: info.mountPath, kind: "renamed") else { return }
            continuation.yield(.renamed(oldPath: oldPath, volume: info))
        }
    }

    private func emitPath(
        _ note: Notification,
        kind: String,
        event: (String) -> MediumEvent,
        continuation: AsyncStream<MediumEvent>.Continuation
    ) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let path = url.path
        // bug.0.3.9.012: ausgehängt → laufende/wartende Abfrage für diesen Pfad nicht weiter versuchen.
        // bug.0.4.068 c: Warteliste und Flüge stehen unter dem standardisierten Pfad; beide mit demselben abbrechen.
        let standardizedPath = url.standardizedFileURL.path
        cancelPendingMount(path: standardizedPath)
        lookupFlights.abandon(path: standardizedPath)
        guard debouncer.shouldEmit(path: path, kind: kind) else { return }
        continuation.yield(event(path))
    }
}

//
//  AppStartup.swift
//  DiskArchive
//
//  bug.0.4.042 (REPORT 87, 88): Einzelinstanz vor dem Protokoll, Beenden ohne Abbau bei Übergabe,
//  SIGTERM über eine Signalquelle → normales Beenden. `AppDelegate` ruft diese Funktionen; Tests auch.
//

import AppKit

/// Ergebnis der Einzelinstanz-Prüfung (ohne Protokoll; die Nebenwirkungen erledigt der Aufrufer).
enum SingleInstanceResult: Equatable {
    /// Keine andere Instanz.
    case alone
    /// Debug: ältere Instanzen wurden zum Beenden aufgefordert.
    case quitOlder(count: Int)
    /// Eine Instanz läuft schon: übergeben und selbst beenden.
    case handOff
}

@MainActor
enum AppStartup {
    /// Start vor dem Hauptfenster: erst Einzelinstanz, dann Protokoll. Bei Übergabe bleiben Protokoll und
    /// `crash-last.txt` der laufenden Instanz unberührt. Gibt `true` zurück, wenn diese Instanz übergibt.
    static func willFinishLaunching(
        launchKind: AppLaunchKind,
        resolveSingleInstance: () -> SingleInstanceResult,
        log: DiskArchiveLog,
        installHandlers: Bool = true
    ) -> Bool {
        let result = resolveSingleInstance()
        if result == .handOff { return true }
        log.start(installHandlers: installHandlers)
        if case .quitOlder(let count) = result {
            log.record(.app, .info, "instance handoff debug quit older count=\(count)")
        }
        log.record(.app, .info, "app launch kind=\(launchKind.rawValue)")
        return false
    }

    /// Letzter Schritt vor dem Prozessende: ausstehende Schreibvorgänge, Checkpoint, Protokollzeile.
    /// Der Checkpoint läuft im Hintergrund (bug.0.3.9.011): eine gehaltene Schreibsperre blockiert nicht den Hauptthread.
    static func finishTermination(appState: AppState, log: DiskArchiveLog) async {
        await appState.prepareForTerminationAsync()
        await appState.indexStore?.checkpointInBackground()
        log.record(.app, .info, "app terminate ok")
    }
}

/// Beenden (bug.0.4.042, bug.0.3.9.009, bug.0.3.9.011): bei Übergabe sofort ohne Abbau; sonst Abbau und Abschluss
/// genau einmal (zweites SIGTERM oder ⌘Q während `.terminateLater` startet nichts neu) und Antwort spätestens nach
/// der Zeitgrenze. Der Zeitgeber läuft auf einer GCD-Queue, nicht auf dem MainActor; die Antwort an AppKit wird auf
/// main eingereiht. Kommt sie auch nach `exitGrace` nicht an (Hauptthread blockiert), endet der Prozess mit Protokollzeile.
/// bug.0.4.064: Der Zeitgeber hängt nie am Protokoll. Zuerst Antwort einreihen und Ausstieg planen, dann protokollieren,
/// und zwar auf einer eigenen Schlange: dort darf die Zeile dauerhaft (`sync`/`fsync`) geschrieben werden, der
/// Zeitgeber wartet nicht darauf. Vor dem Ausstieg wartet er höchstens `exitLogWait`, bis die letzte Zeile geschrieben ist.
@MainActor
final class TerminationFlow {
    nonisolated static let standardTimeout: Duration = .seconds(8)
    nonisolated static let standardExitGrace: Duration = .seconds(4)
    nonisolated static let standardExitLogWait: Duration = .milliseconds(250)

    private let timeout: Duration
    private let exitGrace: Duration
    private let exitLogWait: Duration
    private let logLine: @Sendable (String) -> Void
    private let logQueue = DispatchQueue(label: "app.diskarchive.termination-log", qos: .utility)
    private let forceExit: @Sendable () -> Void
    private let state = TerminationReplyState()
    private var started = false
    private var pendingReply: (@MainActor () -> Void)?

    /// `logLine` (Tests: eigene Senke je Instanz) schreibt eine Fehlerzeile des Zeitgebers; Standard: dauerhaft ins
    /// Protokoll (`.error`), aufgerufen nur auf `logQueue`, nie auf dem Zeitgeber selbst.
    init(
        timeout: Duration = TerminationFlow.standardTimeout,
        exitGrace: Duration = TerminationFlow.standardExitGrace,
        exitLogWait: Duration = TerminationFlow.standardExitLogWait,
        log: DiskArchiveLog,
        logLine: (@Sendable (String) -> Void)? = nil,
        forceExit: @escaping @Sendable () -> Void = { _exit(0) }
    ) {
        self.timeout = timeout
        self.exitGrace = exitGrace
        self.exitLogWait = exitLogWait
        self.logLine = logLine ?? { [log] line in log.record(.app, .error, line) }
        self.forceExit = forceExit
    }

    /// `reply` ist in der App `NSApp.reply(toApplicationShouldTerminate: true)` und wird genau einmal aufgerufen.
    func shouldTerminate(
        handedOff: Bool,
        teardown: () -> Void,
        finish: @escaping @MainActor () async -> Void,
        reply: @escaping @MainActor () -> Void
    ) -> NSApplication.TerminateReply {
        if handedOff { return .terminateNow }
        guard !started else { return .terminateLater }
        started = true
        pendingReply = reply
        // Zeitgeber vor dem Abbau: auch ein hängender synchroner Abbau wird abgefangen.
        scheduleDeadline()
        teardown()
        Task { @MainActor [self] in
            await finish()
            answer()
        }
        return .terminateLater
    }

    /// Unabhängig vom MainActor: feuert auch, wenn der Hauptthread hängt.
    private func scheduleDeadline() {
        let state = state
        let timeout = timeout
        let exitGrace = exitGrace
        let exitLogWait = Self.seconds(exitLogWait)
        let logLine = logLine
        let logQueue = logQueue
        let forceExit = forceExit
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Self.seconds(timeout)) { [self] in
            guard !state.isAnswered else { return }
            // Erst Antwort und Ausstieg, dann die Zeile (bug.0.4.064).
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.answer() }
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Self.seconds(exitGrace)) {
                guard !state.isAnswered else { return }
                let written = DispatchSemaphore(value: 0)
                logQueue.async {
                    logLine("app terminate force exit after=\(exitGrace)")
                    written.signal()
                }
                _ = written.wait(timeout: .now() + exitLogWait)
                forceExit()
            }
            logQueue.async { logLine("app terminate timeout after=\(timeout)") }
        }
    }

    private func answer() {
        guard state.claim(), let reply = pendingReply else { return }
        pendingReply = nil
        reply()
    }

    nonisolated private static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}

/// „Schon geantwortet“ für Hauptthread und Zeitgeber-Queue (bug.0.3.9.011).
nonisolated final class TerminationReplyState: @unchecked Sendable {
    private let lock = NSLock()
    private var answered = false

    var isAnswered: Bool { lock.withLock { answered } }

    /// `true` genau beim ersten Aufruf.
    func claim() -> Bool {
        lock.withLock {
            guard !answered else { return false }
            answered = true
            return true
        }
    }
}

/// Quelle für SIGTERM (Tests: eigene Quelle, nie ein echtes Signal an den Testprozess).
@MainActor
protocol TerminationSignalSource: AnyObject {
    func start(onSignal: @escaping @MainActor () -> Void)
    func cancel()
}

/// SIGTERM wird ignoriert und über eine `DispatchSource` auf der Hauptschlange gemeldet (bug.0.4.042).
@MainActor
final class DispatchTerminationSignalSource: TerminationSignalSource {
    private var source: DispatchSourceSignal?

    func start(onSignal: @escaping @MainActor () -> Void) {
        guard source == nil else { return }
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { onSignal() }
        }
        source.resume()
        self.source = source
    }

    func cancel() {
        source?.cancel()
        source = nil
    }
}

@MainActor
enum TerminationSignal {
    /// SIGTERM → `terminate` (in der App `NSApp.terminate(nil)`, damit `applicationShouldTerminate` sauber beendet).
    static func install(_ source: TerminationSignalSource, terminate: @escaping @MainActor () -> Void) {
        source.start(onSignal: terminate)
    }
}

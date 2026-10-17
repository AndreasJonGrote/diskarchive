//
//  AppStartup.swift
//  diskindex
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
        log: DiskIndexLog,
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
    static func finishTermination(appState: AppState, log: DiskIndexLog) async {
        await appState.prepareForTerminationAsync()
        appState.indexStore?.checkpoint()
        log.record(.app, .info, "app terminate ok")
    }
}

/// Beenden (bug.0.4.042, bug.0.3.9.009): bei Übergabe sofort ohne Abbau; sonst Abbau und Abschluss genau einmal
/// (zweites SIGTERM oder ⌘Q während `.terminateLater` startet nichts neu) und Antwort spätestens nach der Zeitgrenze.
@MainActor
final class TerminationFlow {
    nonisolated static let standardTimeout: Duration = .seconds(8)

    private let timeout: Duration
    private let log: DiskIndexLog
    private var started = false
    private var replied = false

    init(timeout: Duration = TerminationFlow.standardTimeout, log: DiskIndexLog) {
        self.timeout = timeout
        self.log = log
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
        teardown()
        let deadline = Task { @MainActor [weak self, timeout] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self, !self.replied else { return }
            self.log.record(.app, .error, "app terminate timeout after=\(timeout)")
            self.answer(reply)
        }
        Task { @MainActor [weak self] in
            await finish()
            deadline.cancel()
            self?.answer(reply)
        }
        return .terminateLater
    }

    private func answer(_ reply: @MainActor () -> Void) {
        guard !replied else { return }
        replied = true
        reply()
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

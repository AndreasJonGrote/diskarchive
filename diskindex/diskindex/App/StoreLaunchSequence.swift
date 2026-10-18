//
//  StoreLaunchSequence.swift
//  diskindex
//
//  Startablauf in der Reihenfolge des Produkts (bug.0.4.074, bug.0.4.076 c). `AppDelegate` ruft genau diese
//  Schritte auf; Tests rufen dieselben Funktionen in derselben Reihenfolge.
//

import Foundation

@MainActor
enum StoreLaunchSequence {
    /// Schritt 1 (`applicationDidFinishLaunching`, nach dem Mitteilungs-Delegaten, vor dem Öffnen der Datenbank):
    /// eine bei beendeter App abgelaufene Pause auswerten (todo.0.4.027) – vor jeder Erkennung.
    static func evaluatePauseAtLaunch(appState: AppState, defaults: UserDefaults = AppDefaults.current) {
        appState.refreshGlobalPause(defaults: defaults)
    }

    /// Schritt 2 (Datenbank offen, Dienste verdrahtet): zuerst die Versions-Sperre **lokal und synchron** auswerten
    /// (`VersionCheckScheduler.start`, ein einzelnes Lesen), damit bei gesperrter Version nichts schreibt; erst dann
    /// die Erkennung starten. Das Einreihen der Versions-Abfrage läuft asynchron.
    static func startServices(
        appState: AppState,
        store: IndexStoreV3,
        coordinator: MediumCoordinator,
        versionCheck: VersionCheckScheduler,
        startChangeLoop: @escaping () -> Void,
        makeMonitor: @escaping @MainActor () -> MediumMonitor = { MediumMonitor() }
    ) {
        versionCheck.start(appState: appState, store: store)
        MediumRecognitionStartup.bootstrap(
            appState: appState,
            store: store,
            coordinator: coordinator,
            startChangeLoop: startChangeLoop,
            makeMonitor: makeMonitor
        )
    }
}

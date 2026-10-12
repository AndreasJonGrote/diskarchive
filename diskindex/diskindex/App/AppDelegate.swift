//
//  AppDelegate.swift
//  diskindex
//

import AppKit
import OSLog
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Signal „Hauptfenster zeigen“ an eine bereits laufende Instanz. Nur der Name — `userInfo` entfernt die Sandbox.
    private static let showMainWindowNotification = Notification.Name("xjonx.diskindex.showMainWindow")
    /// Debug: „ältere Instanz, bitte beenden“. `object` = PID des Absenders (Strings überstehen die Sandbox),
    /// damit sich die neue Instanz nicht selbst beendet.
    private static let quitOlderInstanceNotification = Notification.Name("xjonx.diskindex.quitOlderInstance")
    private static let logger = Logger(subsystem: "app.diskarchive", category: "SingleInstance")
    private var mediumCoordinator: MediumCoordinator?
    private var indexingService: IndexingService?
    private var changeWatcher: ChangeWatcher?
    private let recognitionLogger = Logger(subsystem: "app.diskarchive", category: "MediumRecognition")
    private var launchKind = AppLaunchKind.click
    private var handedOff = false

    /// Vor `install`, damit kein zweites Menüleisten-Icon aufblitzt (Aufgabe 30.1).
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningUnitTests else { return }
        AppDefaults.current.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        NSWindow.allowsAutomaticWindowTabbing = false
        DiskIndexLog.shared.start()
        launchKind = AppLaunch.kind(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
        if launchKind == .login {
            NSApp.setActivationPolicy(.accessory)
        }
        ensureSingleInstance()
        if !handedOff {
            DiskIndexLog.shared.record(.app, .info, "app launch kind=\(launchKind.rawValue)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningUnitTests, !handedOff else { return }
        if launchKind == .login {
            NSApp.setActivationPolicy(.accessory)
        }
        let appState = AppDelegateBridge.appState
        appState.appSettings.appearance.apply()
        appState.refreshGlobalPause()
        appState.refreshLaunchAtLoginState()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppDelegateBridge.appState.refreshLaunchAtLoginState() }
        }
        UNUserNotificationCenter.current().delegate = self
        SystemNotice.logAuthorizationStatus()
        if NoticePermission.shouldRequest(arguments: CommandLine.arguments, defaults: AppDefaults.current) {
            AppDefaults.current.set(true, forKey: NoticePermission.askedKey)
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        #if DEBUG
        if let folder = ScreenshotPlan.folder(arguments: CommandLine.arguments) {
            ScreenshotRunner.run(folder: folder, appState: appState)
            return
        }
        #endif
        observeSleep(appState)
        MenuBarController.shared.install(appState: appState)
        appState.onRetryIndexStoreOpen = { [weak self] in
            self?.startMediumRecognition()
        }
        startMediumRecognition()
        if DiskIndexLog.shared.shouldShowCrashDialog {
            AppWindowPresenter.openCrashReport()
        }
        DiskIndexLog.shared.onTrackedError = { category, message in
            IssueReporter.shared.noteError(category: category, message: message)
        }
        IssueReporter.shared.start()
        if launchKind == .click {
            NSApp.setActivationPolicy(.regular)
        }
        if AppLaunch.opensMainWindow(launchKind) {
            AppWindowPresenter.openMain(appState: AppDelegateBridge.appState)
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Self.showMainWindowNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AppWindowPresenter.openMain(appState: AppDelegateBridge.appState)
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Self.quitOlderInstanceNotification,
            object: nil,
            queue: .main
        ) { notification in
            let own = NSRunningApplication.current
            let quit = InstanceHandoff.shouldQuit(
                object: notification.object,
                ownPID: ProcessInfo.processInfo.processIdentifier,
                own: InstanceHandoff.ProcessStamp(
                    bundleID: Bundle.main.bundleIdentifier,
                    launchDate: own.launchDate
                ),
                peer: { pid in
                    guard let sender = NSRunningApplication(processIdentifier: pid) else { return nil }
                    return InstanceHandoff.ProcessStamp(bundleID: sender.bundleIdentifier, launchDate: sender.launchDate)
                }
            )
            guard quit else {
                DiskIndexLog.shared.record(.app, .info, "instance handoff ignoriert")
                return
            }
            Self.logger.info("Neuere Instanz gestartet — beende mich")
            DiskIndexLog.shared.record(.app, .info, "instance handoff quit older pid=\(ProcessInfo.processInfo.processIdentifier)")
            MainActor.assumeIsolated {
                NSApp.terminate(nil)
            }
        }
    }

    /// Klick aufs Dock-Icon ohne sichtbares Fenster (z. B. minimiert): Hauptfenster über `openMain`,
    /// damit auch hier kein Feld den Fokus hat. Bei sichtbarem Fenster Standardverhalten.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard AppLaunch.reopenOpensMainWindow(hasVisibleWindows: flag) else { return true }
        AppWindowPresenter.openMain(appState: AppDelegateBridge.appState)
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !Self.isRunningUnitTests else { return .terminateNow }
        MainActor.assumeIsolated {
            MenuBarController.shared.uninstallFromStatusBar()
            AppWindowPresenter.prepareForTermination()
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            prepareForAppTermination()
            DiskIndexLog.shared.record(.app, .info, "app terminate ok")
        }
    }

    /// Indizierung, FSEvents und UI-Overlays vor dem Prozessende stoppen (vermeidet Callbacks nach dem Abbau).
    private func prepareForAppTermination() {
        MenuBarController.shared.prepareForTermination()
        AppWindowPresenter.prepareForTermination()
        mediumCoordinator?.stop()
        let appState = AppDelegateBridge.appState
        appState.prepareForTermination()
        changeWatcher?.stopAllForTermination()
        indexingService?.cancelAllForTermination()
        Task { await appState.indexStore?.checkpoint() }
    }

    /// XCTest startet die App als Testhost. Einzelinstanz und der Launch-Agent würden diese Kopie beenden.
    private static var isRunningUnitTests: Bool { RuntimeEnvironment.isRunningTests }

    /// Mehrere Bundle-Kopien (DerivedData, alte Builds) oder ein Direktstart der Binärdatei umgehen die
    /// macOS-Sperre. Release und login/--background: neue übergibt und beendet sich.
    /// Debug-Klick (Xcode/Finder): neue beendet die alte. Aufgabe 141.
    private func ensureSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ownPID }
        guard !others.isEmpty else { return }

        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        switch InstanceHandoff.conflictAction(launchKind: launchKind, isDebugBuild: isDebug) {
        case .quitOlderInstances:
            // Sandbox: terminate fremder Prozesse oft wirkungslos → Signal an alte Instanzen.
            Self.logger.info("Debug: beende \(others.count, privacy: .public) ältere Instanz(en)")
            DiskIndexLog.shared.record(.app, .info, "instance handoff debug quit older count=\(others.count)")
            DistributedNotificationCenter.default().postNotificationName(
                Self.quitOlderInstanceNotification,
                object: String(ownPID),
                userInfo: nil,
                deliverImmediately: true
            )
            for other in others {
                other.terminate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if !other.isTerminated {
                        other.forceTerminate()
                    }
                }
            }
        case .handOffAndQuitSelf:
            handedOff = true
            Self.logger.info("Disk Archive läuft bereits (PID \(others[0].processIdentifier, privacy: .public)) — übergebe und beende")
            DiskIndexLog.shared.record(.app, .info, "app launch kind=handoff")
            DistributedNotificationCenter.default().postNotificationName(
                Self.showMainWindowNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            others[0].activate()
            NSApp.terminate(nil)
        }
    }

    private func observeSleep(_ appState: AppState) {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                appState.heldForSleep = true
                appState.onAutoIndexPauseChanged?()
                Task { await appState.indexStore?.checkpoint() }
            }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                appState.heldForSleep = false
                appState.refreshGlobalPause()
                appState.onAutoIndexPauseChanged?()
                Task { @MainActor in await appState.pruneIfDue() }
                Task { @MainActor in await self?.restartWatchersAfterWake() }
            }
        }
    }

    private func restartWatchersAfterWake() async {
        guard let watcher = changeWatcher, let coordinator = mediumCoordinator else { return }
        let appState = AppDelegateBridge.appState
        guard let store = appState.indexStore else { return }
        await LiveWiring.restartWatchersAfterWake(
            coordinator: coordinator,
            watcher: watcher,
            store: store,
            appState: appState
        )
    }

    private func startWatching(id: UUID, volume: VolumeInfo, store: IndexStoreV3, watcher: ChangeWatcher) async {
        await LiveWiring.startWatching(
            id: id,
            volume: volume,
            store: store,
            watcher: watcher,
            appState: AppDelegateBridge.appState
        )
    }

    private func startMediumRecognition() {
        let appState = AppDelegateBridge.appState
        appState.storeOpening = true
        StartupSequence.run(
            previousRunUnclean: DiskIndexLog.shared.previousRunUnclean,
            defaults: AppDefaults.current,
            open: { try IndexStoreV3.openDefault() },
            wire: { [weak self] store in self?.wireStore(store, appState: appState) },
            onFailure: { [weak self] error in self?.handleStoreFailure(error, appState: appState) }
        )
    }

    private func handleStoreFailure(_ error: Error, appState: AppState) {
        DiskIndexLog.shared.record(.store, .error, "open \(error)")
        recognitionLogger.error("Index konnte nicht geöffnet werden: \(error.localizedDescription, privacy: .public)")
        mediumCoordinator?.stop()
        appState.reportIndexStoreOpenFailure()
        if launchKind == .login {
            postIndexStoreOpenFailureNotification()
        } else {
            AppWindowPresenter.openMain(appState: appState)
        }
    }

    private func wireStore(_ store: IndexStoreV3, appState: AppState) {
        mediumCoordinator?.stop()
        appState.clearIndexStoreOpenFailure()
        let access = DirectMediumAccess()
        let service = IndexingService(store: store, access: access, appState: appState)
        let coordinator = MediumCoordinator(
            store: store,
            access: access,
            appState: appState
        )
        appState.mountPath = { [weak coordinator] id in
            coordinator?.volume(for: id)?.mountPath
        }
        let watcher = ChangeWatcher(store: store, access: access, appState: appState)
        LiveWiring.connect(
            coordinator: coordinator,
            service: service,
            watcher: watcher,
            appState: appState,
            startWatching: { [store, watcher] id, volume in
                await self.startWatching(id: id, volume: volume, store: store, watcher: watcher)
            }
        )
        mediumCoordinator = coordinator
        indexingService = service
        changeWatcher = watcher
        MediumRecognitionStartup.bootstrap(
            appState: appState,
            store: store,
            coordinator: coordinator,
            startChangeLoop: { appState.startChangeLoop() }
        )
    }

    private func postIndexStoreOpenFailureNotification() {
        let content = UNMutableNotificationContent()
        content.title = LayoutCopy.storeOpenFailedTitle
        content.body = LayoutCopy.storeOpenFailedBody
        let request = UNNotificationRequest(
            identifier: "diskindex.store-open-failed",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        MainActor.assumeIsolated {
            // Post-Zeitpunkt prüft schon das Ereignis; hier nur Hauptschalter —
            // sonst unterdrückt macOS Banner bei aktiver App (Pause aus dem Menü).
            completionHandler(SystemNotice.presentationOptions(
                kind: notification.request.content.userInfo["diskindex.noticeEvent"] as? String,
                notificationsEnabled: AppDelegateBridge.appState.appSettings.notificationsEnabled
            ))
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        MainActor.assumeIsolated {
            let appState = AppDelegateBridge.appState
            if appState.openIndexingFailureFromNotification(userInfo: userInfo) {
                AppWindowPresenter.openMain(appState: appState)
            }
            completionHandler()
        }
    }
}

# SUBTASK2 — Fehlerbericht, Protokoll, Absturzschreiber, Start (Agent 2 von 4)

## Freigaben (hier eintragen)
(noch keine)

## Dir gehört (ganze Dateien)
- Quelle: `App/AppDelegate.swift` (bis FREI), `App/DiskIndexLog.swift`, `App/IssueTracker.swift`, `App/IssueReporterFlushGate.swift`, `App/VersionCheckCoordinator.swift`, `App/VersionCheckScheduler.swift`, `App/AppState+VersionLock.swift`, `App/AppState+DatabaseMaintenance.swift`, `Storage/FilePrivacy.swift`, `Views/CrashReportDialog.swift`, `Indexing/BulkDirectoryReader.swift`.
- Tests: `IssueTrackerTests`, `DiskIndexLogTests`, `PrivacyLogAndScrubberTests`, `VersionCheckTests`, `AutoSendToggleTests`, `InstanceHandoffTests`, `BulkDirectoryReaderTests`, `OperationalFailureLoggingTests`, `StartupSequenceTests`, `AppLaunchTests`, `BackgroundLaunchGateTests`, `FolderLoadErrorLoggingTests`.
- **Nicht:** alles andere. `IssueReporter.queuePool` wird in `wireStore` (AppDelegate) gesetzt, also in deiner Datei; `IndexStoreV3.swift` und `AppState.swift` gehören anderen.

## Aufgaben in dieser Reihenfolge (Wortlaut aus TODO.md)

**Schritt 0:** Alle Änderungen an `App/AppDelegate.swift` zuerst: `bug.0.4.042` (Einzelinstanz/SIGTERM) und `bug.0.4.024` a)/d) (`wireStore`, Auto-Senden, „Verwerfen“). Dann `FREI: App/AppDelegate.swift <Uhrzeit>` oben eintragen und die Datei nie wieder anfassen (die übrigen Teile von 024/041/025 liegen in anderen Dateien; was dort von `AppDelegate` abhängt, musst du vorher in Schritt 0 erledigen). Danach `024` (Rest), `041`, `025`.

**bug.0.4.042 — Einzelinstanz vor Protokoll; SIGTERM sauber (REPORT 87, 88).**
- `ensureSingleInstance()` **vor** `DiskIndexLog.shared.start()`.
- Bei `handedOff` in `applicationWillTerminate` nichts protokollieren und nichts abbauen.
- Protokoll-Handle mit `O_APPEND`.
- Entfällt (Nutzer 15.10.): Der Anmeldestart zeigt das Hauptfenster ebenfalls (`todo.0.4.013`).
- SIGTERM: aus der sigaction-Liste nehmen; `signal(SIGTERM, SIG_IGN)` plus `DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)` → `NSApp.terminate(nil)`.
- **Akzeptanz:**
  - Test der Startreihenfolge: Bei Übergabe schreibt die Zweitinstanz keine Protokollzeile und fasst `crash-last.txt` nicht an.
  - Testprozess mit SIGTERM → normales Beenden (Checkpoint läuft).
  - Kein Start der echten App (Regel 19).
Status:

**bug.0.4.024 — Fehlerbericht-Warteschlange: ein Pool, nichts Synchrones auf main, Offline richtig (REPORT 120, 75, 127, Korrektur B-75).**
- a) In `wireStore` `IssueReporter.shared.queuePool = store.pool`. Vor dem Öffnen der DB (Auto-Senden in `applicationWillFinishLaunching`) **nur in die Outbox** schreiben; die Übernahme läuft nach `wire`. Die Outbox-Datei erst nach erfolgreichem `enqueue` löschen (REPORT 90).
- b) Alle `IssueReporter`-DB-Arbeit (`enqueue`, `flush`, `queueHasWork`) auf eine serielle Queue bzw. in einen Actor; die UI ruft nur asynchron. Bestand aus `storages.fileCount + folderCount` statt `COUNT(*)`. `VersionCheckCoordinator` schreibt mit `await pool.write`.
- c) 75: Fehlversuche wegen fehlendem Netz (`URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.cannotFindHost`, `.cannotConnectToHost`, `.timedOut`) als `info = "offline"` speichern. `isDue` behandelt sie **ohne** Wartezeit als fällig. Achtung: `delay(afterAttempt: 0)` ist 1 h, „`attempts` nicht erhöhen“ reicht also nicht. Der 60-s-Timer läuft, solange nicht blockierte Zeilen existieren.
- d) 127: „Verwerfen“ im Absturzdialog fasst die Warteschlange nicht an (nur `acknowledgeCrashDialog`).
- **Akzeptanz:**
  - Hintergrund-Write hält 2 s; `enqueue` und `enqueueCheckIfNeeded` kehren auf main in < 100 ms zurück; Zähler der geöffneten Pools = 1.
  - Mock: erst `notConnectedToInternet`, dann 201; `onFlush` → Zeile gelöscht, ohne die Uhr vorzustellen.
  - „Verwerfen“ lässt eine ältere, zugestimmte Zeile stehen.
Status:

**bug.0.4.041 — Absturzschreiber signalsicher, Ringzeilen UTF-8-sicher (REPORT 76, 128).**
- Header-Puffer je Signal, Frame-Puffer und Signalnamen einmalig in `start(installHandlers:)` vorab anlegen (statischer Speicher).
- `writeRing` öffnet nie selbst (`guard crashFD >= 0 else { return }`).
- `consumeCrashMarker` öffnet `crash-last.txt` nach dem Verschieben sofort neu (außerhalb des Signalkontexts).
- SIGTERM-Pfad schreibt nur vorab angelegte Bytes.
- 128: `storeCrumb` kürzt auf eine UTF-8-Zeichengrenze. Beim Lesen `String(decoding:as: UTF8.self)`.
- **Akzeptanz:**
  - Nach `acknowledgeCrashDialog()` existiert `crash-last.txt` (64 KB), Debug-Accessor `crashFD >= 0`.
  - `writeCrashSnapshot` schreibt `CRASH signal=`.
  - Aktionszeile mit 300 Bytes Umlauten → Absturzdatei gültig, `CRASH` erkannt.
Status:

**bug.0.4.025 — Protokoll ohne `chmod`/`fsync` je Zeile (REPORT 122).**
- `FilePrivacy.restrict` nur beim Öffnen der Datei und bei der Rotation.
- `fsync` nur für Zeilen mit Fehler-, Absturz- und Ende-Status; sonst schreibt eine serielle Hintergrund-Queue.
- Die „lesen“-Zeilen des `BulkDirectoryReader` je Lauf zusammenfassen (eine Summenzeile).
- **Akzeptanz:**
  - Spion auf `restrict`: höchstens einmal je geöffneter Datei.
  - Lauf über 2.000 Ordner erzeugt höchstens 10 „lesen“-Zeilen.
  - `record` auf main bei parallelem Indexlauf < 1 ms im Mittel (Messung im Status).
Status:

## Arbeitsweise (vier Agenten, ein Gerät, ein Arbeitsordner)
**Dieser Plan ist in sich vollständig.** Du arbeitest alles darin direkt ab, ohne Rückfrage an Claude, in der Reihenfolge der Abschnitte. TODO.md bleibt der Takt und das Register; du änderst sie **nicht**. Claude führt deine Ergebnisse nach der Fertigmeldung in TODO.md zusammen und nimmt ab. Lies vorher TODO.md Regeln 1–30.

**Vier Agenten arbeiten gleichzeitig in denselben Ordner** (SUBTASK1 bis SUBTASK4). Damit nichts kollidiert, gilt:
1. **Eigentum an ganzen Dateien.** Nur Dateien aus deiner Liste „Dir gehört“ darfst du ändern. Jede Quelldatei gehört genau einem Agenten (oder ist unten als Torwächter-Datei mit fester Reihenfolge geregelt). Brauchst du eine fremde Datei: „Frage:“ unter die Aufgabe, nächste Aufgabe weiter. Keine „Mini-Änderung nebenbei“.
2. **Torwächter-Dateien** (zwei Agenten brauchen sie, nacheinander, nie gleichzeitig): Der **erste** Besitzer erledigt **alle** seine Änderungen an der Datei in „Schritt 0“ seines Plans (kompilierend), schreibt dann in seinem Plan oben unter „Freigaben“ die Zeile `FREI: <Datei> <Uhrzeit>` und fasst die Datei danach **nie wieder** an. Der **zweite** Besitzer öffnet die Datei erst, wenn er die FREI-Zeile im Plan des ersten gelesen hat; bis dahin arbeitet er an anderen Aufgaben. Tabelle:
   | Datei | zuerst | danach |
   |---|---|---|
   | `Storage/V3/IndexStoreV3.swift`, `Indexing/ChangeWatcher.swift`, `Indexing/ChangeWatcherEngine.swift` | Agent 1 | Agent 3 |
   | `App/AppDelegate.swift` | Agent 2 | Agent 3 |
   | `App/AppState.swift`, `App/AppState+Media.swift`, `App/AppState+IndexChanges.swift` | Agent 4 | Agent 3 |
3. **Tests:** Eigene neue Tests als **neue Dateien** `<Thema>Agent<N>Tests.swift` anlegen (die Projektgruppe nimmt neue Dateien selbst auf; `project.pbxproj` nicht anfassen). Die Regressions-Zeile (Regel 11) kommt in eine neue Datei `RegressionSmokeAgent<N>Tests.swift`; `RegressionSmokeTests.swift`, `SurfaceTestSupport.swift`, `IndexStoreV3TestHooks.swift`, `IndexingTestSupport.swift`, `V3TestSupport.swift` gehören Agent 1 (andere bauen eigene Hilfen in ihre neue Testdatei). Eine **bestehende** Testdatei änderst du nur, wenn sie zu deiner Dateiliste gehört oder ihr Thema allein deine Aufgabe ist und keine andere Liste sie nennt; sonst neue Datei oder „Frage:“.
4. **Kompilierbar bleiben:** Ändere in kleinen Schritten, die jeweils bauen. Eine halbfertige Änderung bricht den Build für alle drei anderen.
5. **Fremde Build-/Testfehler:** Fehler in einer Datei **außerhalb deiner Liste** sind meist halbfertige Arbeit eines anderen Agenten. Nicht beheben, nicht zurückrollen. 3 Minuten warten, neu bauen; besteht er nach 10 Minuten noch, „Frage:“ und an der nächsten Aufgabe weiterarbeiten.
6. **Regel 26 gilt so:** Geänderte `.swift`-Dateien der anderen Agenten sind erwartet; du hältst nur an, wenn jemand **deine** Dateien ändert. `git checkout/stash/reset/restore` bleiben verboten (Regel 22): sie vernichten fremde Arbeit.

**Build und Test**
- Bauen in eigenem Ordner: `xcodebuild build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/diskindex-dd-agent<N>` (ohne `clean`, außer beim ersten Mal; bei verdächtigem Zustand `clean`). Ist die Entwicklerumgebung nicht gesetzt: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Warnungen zählen: `| grep "warning:" | grep -v appintents | sort -u`; **in deinen eigenen Dateien muss es 0 sein** (Warnungen in Fremddateien nur melden).
- **Testläufe nur unter der Sperre** und nur deine Suites (`-only-testing:diskindexTests/<Suite>`, seriell, `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`):
  `until mkdir /private/tmp/diskindex-test.lock 2>/dev/null; do find /private/tmp/diskindex-test.lock -maxdepth 0 -mmin +30 -exec rmdir {} \; 2>/dev/null; sleep 20; done; <xcodebuild test-without-building …>; rmdir /private/tmp/diskindex-test.lock`
  Die Sperre immer freigeben, auch bei Fehlschlag.
- **Gesamtlauf seriell, Parallelläufe und Release-Build macht Claude** nach dem Zusammenführen (vier Agenten würden sich sonst 45 Minuten an der Sperre stauen). Du lieferst: Build ohne Warnung in deinen Dateien, alle deine Suites grün (Name, Zahl, Uhrzeit), Sabotage rot ✓ wo gefordert (Regel 25), keine neuen `Disk Archive*.ips` (Zeitpunkt vorher merken).
- **Testaufbau-Standard:** keine statischen/prozessweiten Variablen für Test-Verzögerungen oder Schalter (parallele Läufe teilen Prozesse), sondern Parameter oder injizierte Provider. Zeitgrenzen mit Reserve. Kein `lock()` über ein `await`. Regel 20 (Tests stürzen nie ab) gilt.
- **Regel 23 entfällt**; Claude baut die App. **Status nur in deinem Plan** im Feld „Status:“ (höchstens 5 Zeilen, Kennung, Belege, „Bereit zur Prüfung“). Kein Git außer status/log/diff/show; der Nutzer committet.

## Abschluss
Sobald alles „Bereit zur Prüfung“ ist: HALT. Antworte nach Regel 30 (Prompt für Claude im Codeblock, Kennungen, geänderte Dateien je Aufgabe, Belege mit Uhrzeiten) und nenne eine Commit-Nachricht in einem eigenen Codeblock.

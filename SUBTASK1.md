# SUBTASK1 — Fehlerbericht, Protokoll, Absturzschreiber, Start (Agent 1)

Kennungen: Nacharbeit `bug.0.4.045/021/022/023`, dann `bug.0.4.024`, `bug.0.4.025`, `bug.0.4.041`, `bug.0.4.042`. Freigegeben vom Nutzer am 16.10. (Paket 4 Rest und Paket 7 zusammen).

**Dateien (nur diese Bereiche):** `Indexing/ChangeWatcher*.swift`, `Indexing/LiveWatchScope.swift`, `Indexing/PartialChecksum.swift`, `Recognition/MediumAccess.swift`, `Storage/V3/IndexStoreV3.swift` **nur** `precomputedPartials`, `applyLiveRename`, `storePartialChecksum`; `Storage/V3/DirectoryWriterV3.swift`, `App/WriteGuard.swift`, Protokoll (`DiskIndexLog`, `FilePrivacy`, Absturzschreiber), `IssueReporter`, `VersionCheckCoordinator`, `AppDelegate`, in `AppState.swift` **nur** `wireStore`; die zugehörigen Tests unter `diskindexTests/`. **Nicht:** Views, `IndexRepository`, Suche, Favoriten-/Online-Teile von `AppState` (gehören Agent 2).

## Teil A — Nacharbeit Paket 4 (Prüfung Claude 16.10.)
Gelesen und gebaut hat Claude (12:14–12:31): seriell 610/610, Release 0 Warnungen, ein Parallellauf rot, Testziel 6 Warnungen. Behebe in dieser Reihenfolge, nichts sonst, Status in den Aufgaben 045/021/022/023 unten nachführen:
1. Debug-Build mit Testziel hat 6 Warnungen, Ziel 0: `diskindexTests/WatcherFlushReproTests.swift:140–153` (`lock()`/`unlock()` aus async-Kontext in `GatedMapAccess.listDirectory`). Auf synchrone Hilfsfunktionen oder `withLock` umbauen.
2. Parallellauf war rot: `PartialChecksumStoreTests/slowPartialChecksumDoesNotBlockStoreReads` (lief 6 s), `ChangeWatcherTests/reappearedFolderIsReadWithItsSubtree`, `ChangeWatcherTests/saveCursorWritesOnlyWhenEventIDChanges` (beide 0 s). Ursache finden und beheben, nicht durch Wiederholung oder Lockerung überdecken.
   - Verdacht 1: `PartialChecksum.computeDelayForTesting` und `DirectMediumAccess.probeDelayForTesting` sind prozessweite statische Variablen; eine gleichzeitig laufende Suite bekommt die 5 s mit. Verzögerung als Parameter/injizierter Provider durchreichen. Ebenso `MapAccess`/`GatedMapAccess`-Zustand prüfen.
   - Verdacht 2: Der 023-Test verzögert genau 5,0 s und `computeOffActor` bricht nach 5 s ab (Rennen an der Grenze). Zeitgrenze injizierbar machen und die Verzögerung deutlich darüber legen; die 100-ms-Grenze mit Reserve (z. B. 250 ms) und kurzer Begründung.
   - Zeigt die Ursache bei den Watcher-Tests auf Produktcode: beheben und im Status nennen.
3. `bug.0.4.023`: `IndexStoreV3.precomputedPartials` und `applyLiveRename` rufen `FileManager.fileExists` und `resourceValues` **auf dem Store-Actor** auf. Existenzprüfung und Metadaten in den `@concurrent`-Helfer (`computeOffActor` liefert `nil` bei fehlender Datei) bzw. vor den Actor-Aufruf verlegen.
4. `bug.0.4.022`: In `ChangeWatcher.flush` laufen `LiveWatchScope.scopedParentDirectory(...)` (mit `resourceValues`/`isPackage`) nach `applyLiveRename` auf main. In die Engine verlegen (`FlushPrep` liefert die Elternordner je Paar vorab). `_ = prep.scopedItemEvents` entfernen, wenn ungenutzt.
5. `LiveWatchScope.urlIsPackage` behandelt app/bundle/framework/plugin/kext ohne Prüfung als Paket (weicht von `isPackageKey` ab). Entfernen (nur `isPackageKey`, Cache beibehalten) oder die Abweichung im Status begründen und testen.

Die Aufgabentexte 045/021/022/023 stehen weiterhin in TODO.md (Paket 4); lies sie dort, ändere sie nicht, und trage den Status von Teil A in dieser Datei unter „Status Teil A“ ein (höchstens 5 Zeilen je Kennung).

Status Teil A:

## Teil B — Aufgaben (Wortlaut aus TODO.md)

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

**bug.0.4.025 — Protokoll ohne `chmod`/`fsync` je Zeile (REPORT 122).**
- `FilePrivacy.restrict` nur beim Öffnen der Datei und bei der Rotation.
- `fsync` nur für Zeilen mit Fehler-, Absturz- und Ende-Status; sonst schreibt eine serielle Hintergrund-Queue.
- Die „lesen“-Zeilen des `BulkDirectoryReader` je Lauf zusammenfassen (eine Summenzeile).
- **Akzeptanz:**
  - Spion auf `restrict`: höchstens einmal je geöffneter Datei.
  - Lauf über 2.000 Ordner erzeugt höchstens 10 „lesen“-Zeilen.
  - `record` auf main bei parallelem Indexlauf < 1 ms im Mittel (Messung im Status).
Status:

## Teil C — Paket 7 (Wortlaut aus TODO.md)

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

## Spielregeln

**Dieser Plan ist in sich vollständig.** Du arbeitest alles darin direkt ab, ohne Rückfrage an Claude, in der Reihenfolge der Abschnitte. TODO.md bleibt der Takt und das Register; du änderst sie **nicht**. Claude führt deine Ergebnisse nach der Fertigmeldung in TODO.md zusammen und nimmt ab.

## Spielregeln (zusätzlich zu TODO.md Regeln 1–30, die du vorher liest)
- **Zwei Agenten arbeiten gleichzeitig**, jeder in einer **eigenen Kopie** des Projekts (eigenes Gerät, eigener Klon oder Ordner). Regel 26 gilt so: Fremde Änderungen an Dateien **außerhalb der Dateiliste unten** sind erwartet und kein Grund anzuhalten. Fasse Dateien außerhalb deiner Liste nicht an; brauchst du eine, schreibe „Frage:“ unter die Aufgabe und mach mit der nächsten weiter.
- **Status nur hier**, im Feld „Status:“ jeder Aufgabe (höchstens 5 Zeilen, Kennung, Belege mit Uhrzeit, „Bereit zur Prüfung“). Nicht in TODO.md, nicht in PROMPT.md.
- **Regel 23 entfällt** in diesem Plan; Claude baut die App nach dem Zusammenführen. Alles andere (Regeln 20, 22, 25, Parallellauf-Kommando) gilt.
- **Eigener Build-Ordner:** immer `-derivedDataPath <eigener Ordner>` (nicht den Standard-Ordner, nicht den des anderen Agenten), danach löschen. Xcode muss das Projekt nicht offen haben; ist die Entwicklerumgebung nicht gesetzt: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Befehle:** Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`; Warnungen `| grep "warning:" | grep -v appintents | sort -u | wc -l` (Ziel 0); seriell `xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`; parallel derselbe Befehl mit `-parallel-testing-enabled YES`; Release `xcodebuild build … -configuration Release -derivedDataPath <anderer Ordner>`.
- **Testrhythmus:** je Aufgabe nur die betroffenen Suites (`-only-testing:diskindexTests/<Suite>`), danach am **Ende des Plans** einmal Debug+Testziel 0 Warnungen, Release 0 Warnungen, seriell Gesamtlauf, **zwei** Parallelläufe. Keine neuen `Disk Archive*.ips` in ~/Library/Logs/DiagnosticReports (Zeitpunkt vorher merken).
- **Testaufbau-Standard (neu):** keine statischen/prozessweiten Variablen für Test-Verzögerungen oder Schalter (der Parallellauf teilt Prozesse); Verzögerung, Zeitgrenze und Fake als Parameter oder injizierten Provider. Zeitgrenzen mit Reserve (kein Test, der genau an seiner eigenen Zeitgrenze liegt). Kein `lock()` über ein `await`.
- Kein Git außer status/log/diff/show. Der Nutzer committet.

## Abschluss
Sobald alles „Bereit zur Prüfung“ ist: HALT. Antworte nach Regel 30 (Prompt für Claude im Codeblock, Kennungen, geänderte Dateien je Aufgabe, Belege mit Uhrzeiten) und nenne eine Commit-Nachricht in einem eigenen Codeblock.

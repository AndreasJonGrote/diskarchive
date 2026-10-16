# SUBTASK3 — Entscheidung, Status, Regeln, Identität (Agent 3 von 4)

## Freigaben (hier eintragen)
(du wartest auf FREI von Agent 1, 2 und 4; trage hier nichts ein, außer wenn du selbst eine Datei an jemand abgibst)

## Dir gehört (ganze Dateien)
- Quelle: `Recognition/MediumCoordinator.swift`, `MediumMonitor.swift`, `MediumRecognitionStartup.swift`, `VolumeCandidateRule.swift`, `VolumeInfo.swift`, `VolumeLookup.swift`, `DiskArbitrationLookup.swift`, `LocalVolumeMounts.swift`; `Indexing/IndexingService.swift`, `FSEventsResume.swift`; `Storage/V3/MediumCodecV3.swift`, `SchemaV3.swift`; `App/AppState+RuleReconcile.swift`, `AppState+Pause.swift`, `AppState+AppSettingsPersistence.swift`, `App/AppWindowPresenter.swift`; `Views/Registry/NewMediumDetectedDialog.swift`.
- **Erst nach FREI:** `Storage/V3/IndexStoreV3.swift`, `Indexing/ChangeWatcher.swift`, `ChangeWatcherEngine.swift` (Agent 1); `App/AppDelegate.swift` (Agent 2); `App/AppState.swift`, `AppState+Media.swift`, `AppState+IndexChanges.swift` (Agent 4).
- Tests: `MediumDecisionTests`, `MediumRecognitionTests`, `MediumRecognitionStartupTests`, `VolumeIdentityTests`, `NewMediumStackTests`, `NewMediumPanelPlacementTests`, `IndexingServiceTests`, `IndexingFinishCancelTests`, `IndexPruneTests`, `PruneScopeTests`, `RuleReconcileQueueTests`, `ReindexGateTests`, `ReconcileAbortReproTests`, `StoreStartupLifecycleTests`, `WatcherRemountTests`, `WatcherLifecycleTests`, `LiveWatch*Tests`, `AppSettingsPersistenceTests`.
- **Nicht:** alles andere.

## Aufgaben (Wortlaut aus TODO.md)

**Reihenfolge:** Zuerst, was nur deine Dateien braucht: `026`, `027`, `032`, `031` (ohne Watcher-Teil). Dann, sobald die FREI-Zeilen da sind: `028`, `029`, `030`, `031` (Watcher-Teil, `kFSEventStreamCreateFlagWatchRoot`), `033` zuletzt. Prüfe vor jeder gesperrten Datei die FREI-Zeile im Plan des ersten Besitzers (SUBTASK1: `IndexStoreV3.swift`, `ChangeWatcher*.swift`; SUBTASK2: `AppDelegate.swift`; SUBTASK4: `AppState.swift`, `AppState+Media.swift`, `AppState+IndexChanges.swift`).

**bug.0.4.026 — Reprobe setzt keine Entscheidung zurück (REPORT 61).**
- `reprobeDeniedVolumes`: Medien mit `decision != .undecided` **nicht** über `storeAndPresent` führen.
  - Bei `.index`: Status `.indexed` (wenn `lastIndexedAt != nil`) bzw. `.pending` setzen und den passenden Lauf anstoßen (Abgleich bzw. `requestIndex`).
  - Bei `.dontIndex`: nur den Status setzen, keinen Lauf starten.
  - `decision = .undecided` nur für Medien, die schon unentschieden sind.
- Schnappschuss-Problem aus REPORT 132: Ist das Volume nach dem `await` nicht mehr in `mounted`, nichts tun (kein neues Medium anlegen).
- **Akzeptanz:**
  - `.index` + `.error` → `applicationDidBecomeActive()` → `decision` bleibt `.index`, kein Dialog.
  - Gemerktes `.dontIndex` + `.error` → bleibt `.dontIndex`.
Status:

**bug.0.4.027 — „Ja“ nach „Nein“ startet wieder (REPORT 60, Korrektur B-60).** Repro: `nr60_…`.
- `IndexingService.finish` und `cancel(mediumUUID:)` rufen `coordinator?.clearIndexRequest(mediumID:)` auf. **Nicht** die Variante „nur bis zum Start halten“: Sie würde Doppelanfragen in `rerunAfterFinish` schieben.
- **Akzeptanz:** Repro grün; Doppelanfrage während eines Laufs → genau ein Lauf.
Status:

**bug.0.4.032 — Dialog-Entscheidung nach dem Abziehen (REPORT 73).**
- `applyChoice` veröffentlicht als Verbindung `volume(for:) != nil ? .connected : .offline`.
- `volumeDisappeared` ruft nach `publish(.offline)` `AppWindowPresenter.syncNewMediumPanels(appState:)` auf (nicht in Unit-Tests).
- **Akzeptanz:** `requestDialog` → `.disappeared` → `onNewMediumChoice(id, true, true)` → `connectionStatus == .offline`, Panel geschlossen.
Status:

**bug.0.4.031 — Identität: Klone und Volume-Umbenennung (REPORT 116, 78).**
- a) 116: `volumeAppeared` verwirft einen Treffer, dessen Medium-ID schon unter einem **anderen, noch eingehängten** Pfad steht, und behandelt ihn wie mehrdeutig (neues Medium mit Dialog). Nie zwei Pfade für ein Medium.
- b) 78: `NSWorkspace.didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als eigenes `MediumEvent`. Den Pfadschlüssel im Coordinator umbiegen, den Watcher mit neuem `VolumeInfo` stoppen und neu starten. Zusätzlich `kFSEventStreamCreateFlagWatchRoot` setzen.
- **Akzeptanz:**
  - Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.
  - Rename-Event → `volume(for:)` liefert den neuen Pfad; Unmount mit neuem Pfad setzt offline.
Status:

**bug.0.4.028 — Status laufender Läufe nicht von außen überschreiben; Aufwachen ohne Doppel-Abgleich (REPORT 71, 72, Korrektur B-71).**
- a) `normalizeInterruptedIndexingStatuses` aus `loadStoredMedia` entfernen. Die Normalisierung nach Absturz (`indexing` → `indexed`/`pending`) läuft als SQL-`UPDATE` **beim Öffnen der DB vor `wire`**. Zur Laufzeit wird nicht normalisiert, `mediumLiveSyncIDs` wird nicht geleert.
- b) Aufwachen:
  - `MediumMonitor` sendet beim Aufwachen `.appeared` nur für Pfade, die nicht schon mit gleicher Identität in `mounted` stehen.
  - `connectKnown` ändert den Status eines bereits verbundenen Mediums nur, wenn `!service.isRunActive(id)`.
  - Der explizite Aufruf in `AppDelegate` (Z. ~248) entfällt, wenn sich der Pausenzustand dabei schon über `didSet` geändert hat.
- **Akzeptanz:**
  - Lauf aktiv → `resumeAfterRuleReconcile()` → Status bleibt `.indexing`, DB unverändert.
  - Medium verbunden und indiziert → `didWake` → **genau ein** `service.start`.
  - Lauf aktiv → `didWake` → DB-Status bleibt `.indexing`.
Status:

**bug.0.4.029 — Bereinigung „nach 1 Stunde“ wirklich nach Zeit und beim Start (REPORT 114).**
- Nach `hydrateSettingsFromStore()`/`loadStoredMedia()` `pruneIfDue()` aufrufen.
- `armPrune` und `loadPruneDeadline` planen einen Task bis `pruneAt`; ein neuer Termin ersetzt ihn.
- `pruneNow` löscht den Termin nur, wenn er seit Beginn der Bereinigung nicht neu gesetzt wurde.
- `didWake` bleibt zusätzlich.
- **Akzeptanz:**
  - `pruneAt` in der Vergangenheit, Start-Ablauf → bereinigt (ohne Aufruf von Hand, Regel 18).
  - Wache App mit injizierbarer Uhr/kurzer Frist → bereinigt ohne `didWake`.
Status:

**bug.0.4.030 — Regeländerungen wirken sofort und vollständig (REPORT 115, 68).**
- a) Bei jeder Scope-Änderung (`shrinks` oder `grows`, `AppState` Z. ~41–55) aktive Läufe abbrechen und mit **neuer** Konfiguration als Abgleich neu starten. Bei `grows` zusätzlich für jedes angeschlossene Medium mit `decision == .index` einen Abgleich anstoßen.
- b) 68: `reconcileScopeToStatus` setzt beim Verstecken eines Ordners den **ganzen Unterbaum** auf `status = 1` (rekursives CTE wie `markSubtreeGone`) und beim Wieder-Einblenden zurück, mit Neubewertung der Kinder. `purgeMarkedItems` sammelt die betroffenen `storageID`s und ruft danach `commitMediumMeta(forceRecount: true)`.
- **Akzeptanz:**
  - Lauf blockiert nach Ebene 1, `excludedPatterns += ["*.tmp"]`, freigeben → keine sichtbare `.tmp`-Zeile, `fileCount == COUNT(status=0)`.
  - `node_modules` mit 3 Dateien ausschließen → Suche nach einer davon liefert 0; nach `purgeMarkedItems` stimmt `fileCount`.
  - Tiefe 2 → 5+ bei fertigem, angeschlossenem Medium → Abgleich startet.
Status:

**bug.0.4.033 — Medium-Zeile gezielt schreiben; Beenden verliert nichts (REPORT 62, 74, Korrektur B-74).**
- a) `MediumCodecV3.update` durch gezielte Setter je Feldgruppe ersetzen: Nutzerfelder (`isFavorite`, `decision`, `allowIndexing`, `showAbsoluteCapacity`, `autoIndexPaused`, `type`) und Erkennungsfelder (`name`, Kapazität, `lastSeenAt`). Indexer-Felder (Zähler, `indexStatus`, `completedDepth`, `first`/`lastIndexedAt`, `lastIndexActivityAt`, `fsEventsUUID`, `lastEventID`) schreiben nur Indexer und Watcher über ihre eigenen Wege. Alle Aufrufer umstellen (`writeMedium`, `connectKnown`, `volumeDisappeared`, `applyChoice`).
- b) Beenden: ausstehende Einstellungs- und Medium-Schreibvorgänge mit diesen gezielten `UPDATE`s sichern. Das geht synchron mit kurzer Zeitgrenze, nicht mit dem 10-s-Busy-Timeout auf main, oder per `.terminateLater` und `reply(toApplicationShouldTerminate:)` nach dem `await`.
- **Akzeptanz:**
  - Hook zwischen Lesen und Schreiben von `writeMedium`, dort `commitMediumMeta(delta: +100)` → `fileCount` enthält +100.
  - Einstellung bzw. Entscheidung ändern → sofort `prepareForTermination()` → neuer Store hat den Wert.
Status:

**Hinweise:** Die offenen Entscheidungen `todo.0.4.032` (neu formatiertes Medium) und `todo.0.4.033` (Startreihenfolge der Einstellungen) sind **nicht** Teil dieses Plans; bei Berührung „Frage:“. Neue sichtbare Texte nur über „Frage:“. `bug.0.4.021` (MediumMonitor off-main) ist bereits im Projekt; ändere dessen Vorfilter nicht. Ändert `033` die Medium-Zeile (`MediumCodecV3`), prüfe alle Aufrufer; der Schreibweg gehört dir.

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

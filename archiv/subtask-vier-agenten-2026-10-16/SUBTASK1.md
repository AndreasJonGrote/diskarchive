# SUBTASK1 — Nacharbeit Paket 4 und Spaltenansicht (Agent 1 von 4)

## Freigaben (hier eintragen)
(noch keine)

## Dir gehört (ganze Dateien)
- Quelle: `Indexing/ChangeWatcher.swift`, `ChangeWatcherEngine.swift`, `LiveWatchScope.swift`, `LiveRenamePairs.swift`, `PartialChecksum.swift`, `IndexRepository.swift`; `Recognition/MediumAccess.swift`; `Storage/V3/IndexStoreV3.swift` und `DirectoryWriterV3.swift` (bis FREI); `App/WriteGuard.swift`; `Models/ColumnFolderOpenState.swift`, `ColumnSelection.swift`, `ColumnBrowserState.swift`; alles unter `Views/ColumnBrowser/`; `Views/Registry/RegistryTableRow.swift`; `DesignSystem/ObjectFileContextMenu.swift`.
- Tests: `SurfaceTestSupport.swift`, `RegressionSmokeTests.swift`, `IndexStoreV3TestHooks.swift`, `IndexingTestSupport.swift`, `V3TestSupport.swift`, `WatcherFlushReproTests`, `ChangeWatcherTests`, `PartialChecksumStoreTests`, `MainThreadMediumIOTests`, `LiveRenamePairsTests`, `WriteGuardDeadlockTests`, `ProtocolAndSelectionTests`, `Column*Tests`, `IndexRepository*Tests`, `PackageAndTrashesWatcherTests`.
- **Nicht:** alles andere (Agent 2: Protokoll/Fehlerbericht/AppDelegate; Agent 3: Medium-Erkennung/Regeln; Agent 4: Suche/Favoriten/Popover).

## Schritt 0 und Teil A — Nacharbeit Paket 4 (Prüfung Claude 16.10.)
Gebaut und gelesen hat Claude am 16.10. (12:14–12:31): seriell 610/610, Release 0 Warnungen, ein Parallellauf rot, Testziel 6 Warnungen. **Teil A zuerst und komplett**, weil danach `IndexStoreV3.swift`, `ChangeWatcher.swift` und `ChangeWatcherEngine.swift` an Agent 3 gehen (Freigabe `FREI:` in „Freigaben“ oben eintragen, sobald Punkte 3 bis 5 fertig sind; die übrigen Punkte betreffen nur Tests).

Behebe in dieser Reihenfolge, nichts sonst, Status in den Aufgaben 045/021/022/023 unten nachführen:
1. Debug-Build mit Testziel hat 6 Warnungen, Ziel 0: `diskindexTests/WatcherFlushReproTests.swift:140–153` (`lock()`/`unlock()` aus async-Kontext in `GatedMapAccess.listDirectory`). Auf synchrone Hilfsfunktionen oder `withLock` umbauen.
2. Parallellauf war rot: `PartialChecksumStoreTests/slowPartialChecksumDoesNotBlockStoreReads` (lief 6 s), `ChangeWatcherTests/reappearedFolderIsReadWithItsSubtree`, `ChangeWatcherTests/saveCursorWritesOnlyWhenEventIDChanges` (beide 0 s). Ursache finden und beheben, nicht durch Wiederholung oder Lockerung überdecken.
   - Verdacht 1: `PartialChecksum.computeDelayForTesting` und `DirectMediumAccess.probeDelayForTesting` sind prozessweite statische Variablen; eine gleichzeitig laufende Suite bekommt die 5 s mit. Verzögerung als Parameter/injizierter Provider durchreichen. Ebenso `MapAccess`/`GatedMapAccess`-Zustand prüfen.
   - Verdacht 2: Der 023-Test verzögert genau 5,0 s und `computeOffActor` bricht nach 5 s ab (Rennen an der Grenze). Zeitgrenze injizierbar machen und die Verzögerung deutlich darüber legen; die 100-ms-Grenze mit Reserve (z. B. 250 ms) und kurzer Begründung.
   - Zeigt die Ursache bei den Watcher-Tests auf Produktcode: beheben und im Status nennen.
3. `bug.0.4.023`: `IndexStoreV3.precomputedPartials` und `applyLiveRename` rufen `FileManager.fileExists` und `resourceValues` **auf dem Store-Actor** auf. Existenzprüfung und Metadaten in den `@concurrent`-Helfer (`computeOffActor` liefert `nil` bei fehlender Datei) bzw. vor den Actor-Aufruf verlegen.
4. `bug.0.4.022`: In `ChangeWatcher.flush` laufen `LiveWatchScope.scopedParentDirectory(...)` (mit `resourceValues`/`isPackage`) nach `applyLiveRename` auf main. In die Engine verlegen (`FlushPrep` liefert die Elternordner je Paar vorab). `_ = prep.scopedItemEvents` entfernen, wenn ungenutzt.
5. `LiveWatchScope.urlIsPackage` behandelt app/bundle/framework/plugin/kext ohne Prüfung als Paket (weicht von `isPackageKey` ab). Entfernen (nur `isPackageKey`, Cache beibehalten) oder die Abweichung im Status begründen und testen.

Die Aufgabentexte 045/021/022/023 stehen weiterhin in TODO.md (Paket 4); lies sie dort, ändere sie nicht, und trage den Status von Teil A in dieser Datei unter „Status Teil A“ ein (höchstens 5 Zeilen je Kennung).

Die Aufgabentexte 045/021/022/023 stehen in TODO.md (Paket 4); lies sie dort, ändere sie nicht.

Status Teil A:

## Teil B — Paket 6, Spaltenansicht (Wortlaut aus TODO.md)

**bug.0.4.034 — Spaltenansicht: Zustand „wird indiziert“ richtig (REPORT 81, 126).**
- a) `rowOpacity` übergibt `folderName`, `folderListedAt` und `folderUnreadable` wie `iconColor`. Den Zustand **einmal je Zeile** berechnen und für Farbe und Deckkraft verwenden.
- b) `ColumnFolderOpenState.resolve`: `folderDepth >= maxDepth` → `.uncaptured(.scanDepth)` (der Indexer öffnet Ordner auf Tiefe = Scan-Tiefe nicht). Den Test `ProtocolAndSelectionTests` Z. ~290 auf `columnIndex: 1` bei Tiefe 2 umstellen.
- **Akzeptanz (echtes Fenster außerhalb des Bildschirms, Regel 10/19):**
  - Indizierter Ordner → Deckkraft 1.
  - Ordner mit `listedAt == nil` bei laufender Indizierung → 0,55.
  - Bei Scan-Tiefe 2 sind Ordner der Ebene 2 gelb mit „Inhalt wird nicht indiziert“, nicht grün.
Status:

**bug.0.4.035 — ⌘A in großen Ordnern ohne quadratischen Aufwand (REPORT 65).**
- `ColumnSelection` führt zusätzlich ein `Set<UUID>` für `contains`.
- In `folderColumn`, `commit`, `multipleSelectionItems` und `contextTargets` einmal ein Dictionary `id → item` bzw. ein Set je Body/Aufruf.
- `IgnoreBatch`/`ContextMenuPlan` über Sets.
- Für „Dateinamen ignorieren“ mit sehr vielen Zielen: Entscheidung `todo.0.4.031` abwarten (Obergrenze oder Warnung braucht einen Text); bis dahin nur die Laufzeit-Teile umsetzen.
- **Akzeptanz:** 50.000 künstliche Items, `selectAll`, `commit` und `selectedIDs` jeweils < 50 ms (Messung im Status).
Status:

**bug.0.4.036 — Spalten-Cache verdrängt keine sichtbaren Spalten (REPORT 125, 98).**
- `IndexRepository.children()` setzt den Schlüssel bei jedem Lesen ans Ende von `cacheOrder`. Schlüssel der sichtbaren Spalten (`pathStack`) werden nie verdrängt.
- `pruneSelectionToVisibleItems` läuft nur, wenn der Ordner tatsächlich geladen ist (nicht bei fehlendem Cache oder `isLoading`).
- 98: `replaceStore` erhöht die Generationen (wie `invalidateAll`) statt sie zu löschen. Das `defer` des Loads räumt `loading`/`loadingTotals` nur bei passendem Token ab.
- **Akzeptanz:**
  - Wurzel offen, Ordner gewählt, danach 35 andere Ordner laden → Wurzel bleibt im Cache, Auswahl und `pathStack` bleiben.
  - `invalidateAll` während Auswahl → Auswahl bleibt.
Status:

**Ergänzung aus bug.0.4.037:** Der Punkt 103 („`ColumnFolderTableView.updateNSView` lädt sichtbare Zeilen neu, wenn `coordinator.items != items`“, Akzeptanz „Tabelle ab 50k: Favorit umschalten → Zeile zeigt neuen Zustand“) gehört **dir**, nicht Agent 4. Setze ihn nach `bug.0.4.036` um; Kennung `bug.0.4.037` (Teil 103), Status unten.

Status 037 (Teil 103):

**Hinweis 035:** `IgnoreBatch` wird auch in `AppState+Media.swift` (Agent 4/3) verwendet. Ändere die Signaturen nur **quellkompatibel** (neue Überladung statt Umbau), damit diese Datei nicht angefasst werden muss. Der Teil „Dateinamen ignorieren mit sehr vielen Zielen“ wartet auf die Entscheidung `todo.0.4.031`; nur die Laufzeit-Teile umsetzen.

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

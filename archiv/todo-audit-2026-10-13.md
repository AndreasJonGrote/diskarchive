# todo-audit.md — Zwischen-Audit „claude seitenweise“ (13.10.2026)

> **Dies ist ein Zwischen-Audit, getrennt von [TODO.md](TODO.md).**
> Die Aufgaben stammen aus [REPORT.md](REPORT.md), Abschnitte **„Audit 13.10.2026 — claude seitenweise“** (Befunde 54–109) und **„Zweitprüfung 13.10.2026 — claude seitenweise“** (Urteile, Korrekturen B, neue Befunde 110–132).
> **Der Hauptagent (Claude, Rolle laut [AGENTS.md](AGENTS.md)) bringt später alles zusammen:** Er übernimmt Erledigtes nach [DONE.md](DONE.md), Offenes nach TODO.md und trägt die Spuren in REPORT.md ein. Bis dahin ist diese Datei die einzige Quelle für diese Aufgaben.
> **Umsetzung:** Die Aufgaben dürfen sofort **auf diesem Rechner von einem anderen Agenten** („Umsetzer“) erledigt werden, nicht vom Hauptagenten und nicht in der Cursor-Spur von TODO.md. **Prüfung und Freigabe:** Claude (Audit-Sitzung „claude seitenweise“ oder der Hauptagent).

Stand: 13.10.2026, Code-Stand Commit `76b6a71` (`c.0.3.246`). Repro-Tests: [Werkzeuge/audit-repro/](Werkzeuge/audit-repro/README.md).

---

## Regeln für den Umsetzer (verbindlich)

**Es gelten die „Regeln für Cursor“ 1–23 aus [TODO.md](TODO.md) sinngemäß**, also auch: nichts erfinden (3), nur Status-Feld (5), keine Selbstfreigabe (6), Belege (7), Tests seriell (8), nichts nebenbei (9), echte Fenster (10), Regression-Rauchtest (11), nicht Tests abschwächen (14), Zeichenpfad (15), Zeilen sind Richtwerte (16), keine Nachhilfe in E2E-Tests (18), **Bildschirm frei lassen (19)**, Tests stürzen nie ab (20), keine System-Ereignisse (21), **kein Git (22)**, **App zum Schluss bauen (23)**. Regel 1 heißt hier: **nur Aufgaben aus Teil A dieser Datei, in der angegebenen Reihenfolge.** Teil B nur nach Freigabe.

Zusätzlich:

- **Z1 Kennung:** Aufgaben heißen `ZA-xx` (Zwischen-Audit). Im Status und in Commit-Vorschlägen immer `ZA-xx` plus REPORT-Nummern nennen.
- **Z2 Status:** Nur das Feld „Status“ der jeweiligen Aufgabe ausfüllen, **höchstens 5 Zeilen**: was, welche Dateien, Testzahlen mit Uhrzeit und Kommando, Sabotage rot ✓, Regel-23-Uhrzeiten. Dann **„Bereit zur Prüfung“**, nie „fertig“.
- **Z3 HALT:** Nach jedem Paket anhalten. Weiter erst nach Freigabe durch Claude, die hier in der HALT-Zeile eingetragen wird.
- **Z4 Schreibgeschützt für den Umsetzer:** `REPORT.md`, `TODO.md`, `DONE.md`, `README.md`, `ROADMAP.md`, `AGENTS.md`, `layout/`, `archiv/`, `Werkzeuge/audit-repro/`. Fragen als „Frage:“ unter die Aufgabe schreiben.
- **Z5 Maßgebliche Lösung:** Die Lösung aus REPORT gilt **mit den Korrekturen aus Teil B der Zweitprüfung**. Bei Widerspruch gilt diese Datei.
- **Z6 Repro-Tests:** Wo eine Aufgabe einen Repro-Test nennt, den Test aus `Werkzeuge/audit-repro/ReproAuditTests.swift` in eine passende Suite unter `diskindex/diskindexTests/` übernehmen (Suite `@Suite(.serialized) @MainActor`). **Vor dem Fix ausführen und das Rot im Status belegen**, nach dem Fix grün. Testname und Meldung dürfen angepasst werden, die Erwartung nicht.
- **Z7 Sabotage:** Jede Aufgabe weist nach, dass ihr neuer Test den Fehler fängt: Fix kurz zurücknehmen → Test rot → wieder einsetzen. **Vor Regel 23 zurücknehmen.**
- **Z8 Parallelbetrieb:** Vor jeder Aufgabe `git status`. Sind `.swift`-Dateien geändert, die nicht von dir stammen (Cursor/Hauptagent arbeitet parallel), **anhalten** und „Frage:“ schreiben. Keine fremden Änderungen überschreiben.
- **Z9 Schema:** Nach 0.3 nur erweitern (README Roadmap): neue Migrationen, neue Indizes, neue Schlüssel; keine bestehende Tabelle umbauen.
- **Z10 Texte:** Keine neuen sichtbaren Texte. Braucht eine Lösung doch einen, dann „Frage:“.

---

## A. Jetzt

### Paket 0 — Testbasis stabil

**ZA-00 — Vier rote Tests stabil machen (REPORT 109).**
Ausgangslage: Voller Testlauf 586/590 grün. Rot sind `ItemIdentityTests/fatPartialDisambiguatesGoneCandidates`, `AutoSendToggleTests/autoSendPersistsInDatabase`, `ChangeWatcherTests/newFileAppearsAfterQuiet` und `ChangeWatcherTests/liveRenamePairMovesFolderAndShiftsChildDepth`.
- a) `DirectoryWriterV3.partialMatchingEnabled` (globales `nonisolated(unsafe) static var`) **durch einen Parameter ersetzen**, z. B. ein Feld im Writer bzw. `IndexStoreV3`, das nur Tests umstellen. Der Sabotage-Test in `ItemIdentityTests` Z. ~166 nutzt dann diesen Parameter. Danach darf die Suite parallel laufen, ohne dass sich Tests gegenseitig beeinflussen.
- b) `AutoSendToggleTests`: geteilten `AppSettingsRuntimeCache` je Test isolieren oder die Suite `.serialized`; feste 600 ms durch Warten auf die Bedingung ersetzen (`waitUntil`, Grenze ≤ 3 s).
- c) `ChangeWatcherTests`: Die 800-ms-Grenze in `waitFor` durch Warten auf die Bedingung mit Grenze ≤ 3 s ersetzen. Die Erwartungen bleiben unverändert (Regel 14).
- d) Zusätzlich die Warnungen aus REPORT 108 beheben, inklusive Testziel:
  - `checkpoint()` `nonisolated`
  - captured `var` in `IndexStoreV3` Z. ~210/815
  - `?? freelistBefore` (Z. ~219)
  - `loadLegacyPersisted`
  - `IndexingFinishCancelTests`, `IssueTrackerTests` Z. ~283, `AppSettingsPersistenceTests`

**Akzeptanz:** Drei volle Läufe hintereinander, einmal seriell und zweimal parallel, jeweils **alle grün**. Build Debug und Release ohne Warnung. Regel 23.
Status:

**ZA-00b — Purge: toter Code (Claude-Suche 14.10., Wortzählung über `diskindex/` und `diskindexTests/`).**
- a) **Löschen** (kommt nirgends sonst vor, auch nicht in Tests): `AppVersion.majorMinor` (Z. 16) und `isNewerThanMajorMinor` (Z. 69), `AppWindowPresenter.closeNewMedium` (Z. 138), `FeatureAccess.unrestricted` (Z. 39), `MenuBarPopoverLayout.pauseMenuAnchorFromBottom` (Z. 35), `IndexStoreV3.purgeGoneItems` (Z. 548; dazu den Kommentar „für die Überwachung“ entfernen, REPORT E).
- b) **Nur von Tests benutzt, im App-Programm unnötig:** `IndexStoreV3+Reading` `columnFirstPageSQL` (Z. 117), `statusOfItem` (Z. 242), `searchMedia` (Z. 398), `storedNames` (Z. 408); `IndexStoreV3` `recordMaintenanceDebt` (Z. 185), `orphanCount` (Z. 108), `databaseFileBytes` (Z. 122); `IndexRepository.hasCachedChildren` (Z. 166). Je Fall: ohne Test-Nutzen → löschen samt Test; sonst als `extension` ins **Test-Ziel** verschieben. Nicht anfassen: `applyDirectory` (19 Tests; ZA-05 c ersetzt es dort, wo es eine Kette beweisen soll).
- c) **Nicht löschen** (Falschtreffer der Suche): AppDelegate-Rückrufe, `windowWillClose`, `canBecomeKey/Main`, `mouseDown`-Überschreibungen.
- d) **Frage an Nutzer, nicht anfassen:** `DebugTools/ScreenshotRunner.swift` (708 Zeilen, Regel 19 verbietet den Lauf) und `PreviewData.swift`: noch gebraucht?
- **Akzeptanz:** `grep -rnw` auf jeden Namen aus a) → leer; Warnungen 0; seriell grün (Zahl vorher/nachher im Status; sie sinkt nur um gelöschte Tests, Begründung je Test).
Status:

**HALT Paket 0** — Freigabe:

---

### Paket 1 — Datenschutz im Fehlerbericht (vor 0.4 zwingend)

**ZA-01 — Keine Namen, Pfade oder Fehlertexte mit Namen im Datei-Protokoll; Scrubber verlässlich (REPORT 54, 124, 91).**
- a) `DiskIndexLog.record`: `privateDetail` **nicht mehr in die Protokolldatei** schreiben. In der Datei steht stattdessen ` pathDepth=<n> pathLen=<utf8-Bytes>`. In `os_log` bleibt `privateDetail` `.private`.
- b) Datei-Protokoll ohne `error.localizedDescription` und ohne `\(error)` bei Datei-/Ordnerfehlern. Stattdessen eine technische Kurzform `domain=<NSError.domain> code=<code> posix=<code>`. Eine Hilfsfunktion an **einer** Stelle, alle Aufrufer umstellen. Der Grund: lokalisierte NSError-Texte enthalten Dateinamen in „…“. Fundstellen u. a.:
  - `ChangeWatcherEngine` Z. ~101/136
  - `DirectoryIndexer` Z. ~298/319/450
  - `MediumCoordinator` Z. ~141
- c) `os_log`: `message` standardmäßig `.private`, öffentlich nur feste technische Präfixe. Die Zeile `ui("search query=…")` (`AppState` Z. ~19) im `os_log` nicht mehr mit Suchbegriff.
- d) `ReportScrubber` als zweite Schicht:
  - Pfad-Regex bis Zeilenende (`(?:/Volumes|/Users|~|file://)[^\n]*`).
  - Typografische Anführungszeichen „…“ ‚…‘ «…» wie `"`/`'` behandeln.
  - `scrubRemainder` lässt nur selbst erzeugte Profile `‹(path|name|query) [^‹›]*›` durch, nicht jedes `‹…›`.
  - Deutsche Buchstaben (ä ö ü Ä Ö Ü ß) und typografischer Apostroph gelten als **gewöhnlich**, damit feste Meldungstexte samt Zeitstempel, ID und Status erhalten bleiben (124).
  - `ext=‹odd›` ohne Winkelklammern (`ext=odd`).
- **Tests:**
  - `ReportScrubber.text` mit `/Volumes/Jon's Passport/Clients/Acme Corp`, `/Volumes/A/My "Best" Photos`, `/Volumes/A/‹Kunde Acme›/x`, `file:///Volumes/O'Brien/x`, `Die Datei „Präsentation.key“ …` → weder `Passport`, `Acme`, `Photos`, `O'Brien` noch `Präsentation` im Ergebnis.
  - `2026-10-13T20:01:02Z medium info candidate=ja eingehängt id=1234 stärke=uuid` → Zeitstempel, `id=1234`, `stärke=uuid` bleiben.
  - `DiskIndexLog` in ein Testverzeichnis schreiben lassen, `record(…, privateDetail: "/Volumes/X/geheim")` → die Datei enthält `geheim` nicht.
- **Sabotage:** Pfad-Regex auf den alten Stand → rot.
Status:

**ZA-02 — Leak-Wächter vor dem Senden wirksam machen (REPORT 55, Korrektur B-55).**
- a) `ReportScrubber.leakCategory` prüft den **dekodierten** Body: JSON parsen, alle String-Werte rekursiv prüfen auf `/Volumes/`, `/Users/`, `~/`, `file://`. Alternativ mit `.withoutEscapingSlashes` serialisieren und zusätzlich dekodiert prüfen.
- b) Namensabgleich (`knownNames`): Mediennamen aus der DB **beim Start einmal** im Hintergrund laden, nicht auf main, nicht beim Senden. Prüfung nur mit Wortgrenzen und mindestens 4 Zeichen. **Ausschlussliste:** App- und Image-Namen („Disk Archive“, „diskindex“, Systemframework-Namen aus Backtraces). Ein Medium „Disk“ oder „Archive“ darf keinen Bericht blockieren.
- **Tests:**
  - Payload mit `/Volumes/X/geheim` direkt in die Queue legen → `flush` → Zeile `blocked:leak=path`, kein Request beim Mock.
  - Medium „Archive“ registriert, Bericht mit Backtrace „Disk Archive“ → **nicht** blockiert.
  - Bestehender Test `IssueTrackerTests` Z. ~212–217 zusätzlich mit echt serialisiertem JSON.
Status:

**HALT Paket 1** — Freigabe:

---

### Paket 2 — Inventar und Favoriten (Datenverlust)

**ZA-03 — Schema: Schutz vor Rückschritt + Teilindex für verschwundene Einträge (REPORT 101, 63, Korrekturen B-101, B-63).**
- a) `SchemaV3.openPool`: Vor `migrate` `try pool.read(migrator.hasBeenSuperseded)`. Bei `true` mit eigenem Fehler abbrechen; dieser läuft über den bestehenden Store-Fehlerdialog, ohne neuen Text (Z10: falls einer nötig ist, „Frage:“). **Muss in derselben Lieferung wie b) sein**, also vor der ersten Schema-Erweiterung.
- b) Neue Migration (eigener Name, nach `firstMigration`): `CREATE INDEX items_gone ON items(storageID, isFolder) WHERE status = 2`.
- c) `DirectoryWriterV3.matchGoneCandidate`: SQL mit **Literal** `status = 2` (nicht als Parameter), damit der Teilindex greift. Keinen Vorabtest je Writer zwischenspeichern.
- **Tests:**
  - Zeile `grdb_migrations('9.9-future')` einfügen → `openPool` wirft.
  - `EXPLAIN QUERY PLAN` der Kandidaten-Abfrage nennt `items_gone`.
  - Messtest (Release): FAT-Erstindex mit 50.000 Dateien gegen vorher, Zahl im Status.
Status:

**ZA-04 — Abgebrochener Abgleich: kein Ebenen-Überspringen, keine Löschung verschwundener Einträge, Token aufräumen (REPORT 59, 58, 67, Korrekturen B-58, B-59).** Repro: `nr59_…`, `nr58_…`, `nr67_…`.
- a) Laufart merken: Ein Lauf ist ein **Abgleich**, wenn `!fromScratch && stored.indexStatus == .indexed && stored.completedDepth > 0` (Bedingung aus `DirectoryIndexer` Z. ~61).
  - Wird ein Abgleich angehalten (`stop()`: pause/cancel/none) oder über `IndexingService.cancel` abgebrochen, schreibt die DB **`.indexed`** (nicht `.pending`), und die UI zeigt `.indexed`.
  - Das Laufergebnis an `IndexingService.finish` muss trotzdem **„unterbrochen“** melden. Keine Meldung „vollständig indiziert“, kein `onRunIndexed`, keine Wartung (B-59).
  - Bei Erst- und „Neu indizieren“-Läufen bleibt `.pending` wie heute.
- b) `finishIndexing`: `deleteGoneItems` **nur**, wenn der Lauf vollständig endet (`.indexed` und nicht unterbrochen). Bei pending, error oder unterbrochen bleiben gone-Zeilen stehen (B-58: nur zusammen mit a).
- c) `beginIndexing`: Wirft der Schreibvorgang, das Token zurücksetzen (`if indexingToken[uuid] == token { … = nil }`), dann erneut werfen.
- **Akzeptanz:**
  - Medium `.indexed`, Abgleich nach Ebene 1 pausiert → DB `.indexed`, Folgelauf liest Ebenen 2…n (neue Datei auf Ebene 3 wird gefunden).
  - Favorit in gone-Unterbaum übersteht `.pending`.
  - Die drei Repro-Tests sind grün.
Status:

**ZA-05 — FAT/exFAT/NTFS: Umbenennen/Verschieben außerhalb wieder verbinden (REPORT 110).** Voraussetzung: ZA-03, ZA-04.
- a) Für Medien ohne `trustsFileID`: **Verbindungs-Nachlauf am Laufende vor `deleteGoneItems`**.
  - Paare bilden aus „in diesem Lauf neu eingefügt“ (Kennzeichnung im Lauf, z. B. Menge der neuen IDs oder Zeitstempel) und `status = 2`.
  - Regeln wie heute: gleiche Art (Ordner/Datei/Paket), gleiche Größe, Datum ±FAT-Toleranz, gleiche Endung, bei Mehrdeutigkeit Teil-Prüfsumme. Ordner nur mit Name + Eltern (wie Nr. 34).
  - Bei **eindeutigem** Treffer: Die **alte** Zeile übernimmt Elternordner, Namen, Slug und Tiefe der neuen. Favorit, Meta und Prüfsumme bleiben an der alten ID, die neue Zeile wird gelöscht.
- b) Zusätzlich im `finalize` eines Ordners die im selben Ordner verschwindenden Zeilen (`status = 0`, nicht in `incoming`) **vorab** als Kandidaten für die Neueinträge desselben Ordners zulassen (Umbenennen im selben Ordner).
- c) Die Tests `ItemIdentityTests` mit künstlichem `applyDirectory(entries: [])` durch **echte Läufe** über `DirectoryIndexer` mit `MemoryVolume` ergänzen (Regel 18).
- **Akzeptanz (je ein Test, FAT-Medium, Favorit):**
  - `alt.txt` → `neu.txt` im selben Ordner: gleiche ID, Favorit bleibt.
  - `P/a.txt` → `Q/a.txt` (gleiche Ebene): wie oben.
  - `/A/B/x.txt` → `/x.txt` (nach oben): wie oben.
  - Zwei gleich große Kandidaten ohne Prüfsumme: **kein** Verbinden.
Status:

**ZA-06 — fileID-Zweig im Writer: fremde gleichnamige Zeile, Tiefe der Kinder, Reihenfolge, Hardlinks (REPORT 57, 69, 129, 112).** Repro: `nr57_…` (beide), `nr69_…`.
- a) 57: `existingByName.removeValue(forKey: located.name)` nur, wenn `located.parentID == parentID`.
- b) 69: Im fileID-Zweig bei Ordnern mit geänderter Tiefe `shiftDescendantDepths(folderID:by:)`; gilt auch für den Watcher-Pfad (`finalize: true`).
- c) 129: `apply` in **zwei Durchgängen**: zuerst Einträge ohne Namenstreffer (fileID-Umbenennungen), dann Namenstreffer. Das Ergebnis darf nicht mehr von der Dictionary-Reihenfolge abhängen.
- d) 112: `ATTR_FILE_LINKCOUNT` in `BulkDirectoryReader` mitlesen (Feld in `ListedDirectoryEntry`/`ScannedEntry`). Bei `linkCount > 1`, bei Ordner-Hardlinks oder wenn dieselbe fileID im Listing mehrfach vorkommt, die fileID **speichern, aber nicht zum Verbinden/Verschieben** nutzen. Offset-Regel aus REPORT 96 beachten (Offset immer um die Attributgröße erhöhen).
- **Akzeptanz:**
  - Die Repro-Tests sind grün. `nr57_moveInto…` 30/30 fehlerfrei.
  - Umbenennen + neue Datei mit altem Namen: 30 Läufe mit stabilem Ergebnis (Favorit folgt der fileID).
  - Temp-Ordner mit `link()`-Hardlinks in zwei Ordnern: zweimal echter Lauf → zwei Zeilen mit stabilen IDs.
Status:

**HALT Paket 2** — Freigabe:

---

### Paket 3 — Live-Überwachung

**ZA-07 — Live-Rename und Pfadabgleich korrekt (REPORT 56, 70, 113).** Repro: `nr56_…`, `nr70_…`.
- a) `DirectoryWriterV3.folderID(segments:)` dreiwertig (`.root` / `.found(id)` / `.missing`). In `applyLivePathRename` bei `.missing` auf einer Seite `return false`. Das verworfene `delta` (Z. ~284) über `commitMediumMeta` mitschreiben.
- b) `ChangeWatcher.flush`: Item-Events **vor** dem Paaren durch dieselbe Scope-Logik wie `directoryToReread` filtern (Matcher, Tiefe, `.Trashes`, ausgeschlossene Ordner). Eltern aus Paaren nur übernehmen, wenn sie im Scope liegen.
- c) 70: `applyLivePathRename` nur, wenn das Ziel dieselbe Datei ist. Bei `trustsFileID` muss der Inode von `stat(toPath)` gleich `row.fileID` sein; bei FAT gleiche Größe plus, falls gespeichert, gleiche Teil-Prüfsumme. Sonst `false`.
- d) 113: FSEvents-Pfade **nicht** über `URL(fileURLWithPath:).standardizedFileURL.path` normieren, sondern das Mount-Präfix als String abschneiden. Namensvergleiche in `folderID`/`fetchChildRows`/`IndexStoreV3.folderID` zweistufig: zuerst exakt; ohne Treffer über `slug` im selben Elternordner suchen und in Swift kanonisch vergleichen (`==`). Keine Schemaänderung.
- **Akzeptanz:**
  - Die Repro-Tests sind grün.
  - Papierkorb-Fall (`X/f` → `.Trashes/501/f`): kein `onFullReconcile`.
  - NFC-Ordner `Fotos M\u{00E4}rz`, Ereignis mit NFC-Pfad: Ordner wird gelesen, kein Voll-Abgleich, neue Datei im Index.
Status:

**ZA-08 — Änderungen innerhalb von Paketen (REPORT 111).**
- Liegt ein Vorfahr des Ereignispfads als Paket vor (DB `isPackage = 1` bzw. `isFolder = 0` mit Paket-Endung, oder `URLResourceValues.isPackage` auf der Platte), wird **der Elternordner des Pakets** zum Neulesen eingereiht. Ereignisse unterhalb des Pakets werden verworfen, ohne `.needsFullReconcile`.
- **Akzeptanz:** Wurzel mit Paketzeile `X.app`, Ereignis `/Volumes/DISK/X.app/Contents/Info.plist` → `.ok`, Wurzel gelesen, kein `onFullReconcile`. Ebenso für `Y.photoslibrary/database/a.sqlite-wal`.
Status:

**ZA-09 — Flush je Medium serialisieren (REPORT 64, 66, 99, 79).** Repro: `nr66_…`, `nr99_…`.
- a) Quiet-Timer und Flush trennen:
  - Der Quiet-Task trägt sich vor dem Flush aus `quietTasks` aus (66).
  - Ein Flush je Medium zur Zeit (`flushInFlight`). Kommt während eines Flushs ein Ereignis, folgt danach genau ein weiterer Flush.
  - Laufende Flushes werden nur in `stop`/`stopAllForTermination` abgebrochen, nicht durch neue Ereignisse (64).
- b) `ChangeWatcherEngine`: `CancellationError` gesondert behandeln. `pending` zurücklegen, **kein** `.needsFullReconcile`.
- c) 99: `IndexStoreV3.commitPendingMetaIfNeeded` entnimmt das Delta **vor** dem `await` und setzt es auf null, ebenso `lastMetaCommitTime`. Bei Fehler wieder addieren.
- d) 79: `ChangeWatcher.stop` leert `tasks`, `mounts`, `volumes` und `sources` **synchron vor** dem `await saveCursor` (Cursor vorher in eine lokale Variable). `applyPause`/`pauseChanged` serialisieren und nach jedem `await` `globalAutoIndexPaused` erneut prüfen.
- **Akzeptanz:**
  - Die Repro-Tests sind grün.
  - `BlockingListAccess` blockiert den ersten Flush, zweites Ereignis, freigeben → kein `onFullReconcile`, beide Ordner gelesen.
  - Pause an/aus schnell hintereinander mit verzögertem `recordEventCursor` → Watcher aktiv, Ereignis wird gelesen.
Status:

**ZA-10 — Indexer: Schreib- und Lesefehler trennen, Halt sofort, Stall-Wächter (REPORT 123, 94, 77, 102).**
- a) 123: Schreibfehler aus `onChunk` als eigener Typ (`IndexWriteFailed`). `readFolderWithRetry` wirft ihn sofort weiter; der Lauf endet über `failWrite` mit `.error` (nicht „Ordner nicht lesbar“).
- b) 94: `DirectoryIndexInterrupted`, `CancellationError` und `IndexWriteFailed` werden ohne Wiederholung weitergeworfen. `folderEntries` und die Zählung werden je Versuch zurückgesetzt.
- c) 77:
  - Watchdog, der `DirectoryReadStalled` auch ohne eintreffenden Chunk auslöst. Die Stall-Zeit zählt ab dem letzten Lebenszeichen.
  - `continuation.onTermination` setzt ein Abbruch-Flag, das `BulkDirectoryReader.readStreaming` zwischen den `getattrlistbulk`-Aufrufen prüft (fd schließen), und bricht den inneren Task ab.
  - Bei `willUnmount` laufende Läufe des Mediums abbrechen.
- d) 102: `parentsFor` gibt DB-Fehler weiter (kein `try? … ?? []`), der Lauf endet `.error`.
- **Akzeptanz:**
  - Store, der beim Chunk-Schreiben wirft → Lauf `.error`, kein „nicht lesbar“, Dauer < 2 s.
  - Pause im ersten Chunk → genau ein Lesevorgang, ohne Wartezeit (heute ca. 14 s).
  - Fake-Stream, der nie liefert → `DirectoryReadStalled` nach `directoryStallTimeout`.
Status:

**HALT Paket 3** — Freigabe:

---

### Paket 4 — Medien-I/O und Datenbank nicht auf dem Haupt-Thread

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**ZA-11 — Medienprüfung und Volume-Abfragen vom Main-Thread nehmen (REPORT 117, 118).**
- a) `DirectMediumAccess.probe` als `@concurrent` oder per Continuation auf eine eigene Queue (wie `listDirectory`). Zeitgrenze 5 s, danach `.denied(reason: "timeout")`.
- b) `MediumMonitor`:
  - Billig vorfiltern ohne Zugriff aufs Volume: `getfsstat(MNT_NOWAIT)` bzw. `.skipHiddenVolumes`, nur `MNT_LOCAL`, nur Präfix `/Volumes/`.
  - `VolumeLookup.info` und DiskArbitration auf einer seriellen Hintergrund-Queue; nur das Ergebnis auf main.
- c) DEBUG: `dispatchPrecondition(condition: .notOnQueue(.main))` in `probe`, `VolumeLookup.info`, `PartialChecksum.compute` und `BulkDirectoryReader`-Einstiegen.
- **Akzeptanz:**
  - Fake-`MediumAccess`, dessen `probe` 2 s schläft und `!Thread.isMainThread` prüft; `applicationDidBecomeActive()` → MainActor-Ticker läuft weiter.
  - Netz-/nicht lokale Einträge erreichen `info()` nie.
Status:

**ZA-12 — Live-Watcher: `stat()` und Matcher nicht je Ereignis auf main (REPORT 119).**
- `LiveRenamePairs.pair`: `guard byPath.count == 2 else { return [] }` **vor** jedem `fileExists`.
- Paarbildung und `stat` im `ChangeWatcherEngine`-Actor statt auf main.
- `IgnoreMatcher` einmal je Flush bzw. Ingest bauen, nicht je Ereignis.
- **Akzeptanz:**
  - `pair` mit 10.000 Ereignissen und zählendem `fileExists` → 0 Aufrufe.
  - Test-Closure für `fileExists` mit `dispatchPrecondition(.notOnQueue(.main))`.
Status:

**ZA-13 — Teil-Prüfsumme außerhalb von Store-Actor und Schreibsperre (REPORT 121).**
- `storePartialChecksum`: Datei außerhalb des Actors lesen (`@concurrent`-Helfer, Zeitgrenze), dem Actor nur das fertige Ergebnis zum Schreiben geben.
- `DirectoryWriterV3`: `incomingPartialDigest` und `resourceValues` **vor** `pool.write` berechnen.
- Favoriten-Tasks (`AppState+Favorites`) halten und in `prepareForTermination` abbrechen.
- **Akzeptanz:** Prüfsummen-Provider blockiert 5 s; parallel `childrenPage` und `search` jeweils < 100 ms.
Status:

**ZA-14 — Fehlerbericht-Warteschlange: ein Pool, nichts Synchrones auf main, Offline richtig (REPORT 120, 75, 127, Korrektur B-75).**
- a) In `wireStore` `IssueReporter.shared.queuePool = store.pool`. Vor dem Öffnen der DB (Auto-Senden in `applicationWillFinishLaunching`) **nur in die Outbox** schreiben; die Übernahme läuft nach `wire`. Die Outbox-Datei erst nach erfolgreichem `enqueue` löschen (REPORT 90).
- b) Alle `IssueReporter`-DB-Arbeit (`enqueue`, `flush`, `queueHasWork`) auf eine serielle Queue bzw. in einen Actor; die UI ruft nur asynchron. Bestand aus `storages.fileCount + folderCount` statt `COUNT(*)`. `VersionCheckCoordinator` schreibt mit `await pool.write`.
- c) 75: Fehlversuche wegen fehlendem Netz (`URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.cannotFindHost`, `.cannotConnectToHost`, `.timedOut`) als `info = "offline"` speichern. `isDue` behandelt sie **ohne** Wartezeit als fällig. Achtung: `delay(afterAttempt: 0)` ist 1 h, „`attempts` nicht erhöhen“ reicht also nicht. Der 60-s-Timer läuft, solange nicht blockierte Zeilen existieren.
- d) 127: „Verwerfen“ im Absturzdialog fasst die Warteschlange nicht an (nur `acknowledgeCrashDialog`).
- **Akzeptanz:**
  - Hintergrund-Write hält 2 s; `enqueue` und `enqueueCheckIfNeeded` kehren auf main in < 100 ms zurück; Zähler der geöffneten Pools = 1.
  - Mock: erst `notConnectedToInternet`, dann 201; `onFlush` → Zeile gelöscht, ohne die Uhr vorzustellen.
  - „Verwerfen“ lässt eine ältere, zugestimmte Zeile stehen.
Status:

**ZA-15 — Protokoll ohne `chmod`/`fsync` je Zeile (REPORT 122).**
- `FilePrivacy.restrict` nur beim Öffnen der Datei und bei der Rotation.
- `fsync` nur für Zeilen mit Fehler-, Absturz- und Ende-Status; sonst schreibt eine serielle Hintergrund-Queue.
- Die „lesen“-Zeilen des `BulkDirectoryReader` je Lauf zusammenfassen (eine Summenzeile).
- **Akzeptanz:**
  - Spion auf `restrict`: höchstens einmal je geöffneter Datei.
  - Lauf über 2.000 Ordner erzeugt höchstens 10 „lesen“-Zeilen.
  - `record` auf main bei parallelem Indexlauf < 1 ms im Mittel (Messung im Status).
Status:

**HALT Paket 4** — Freigabe:

---

### Paket 5 — Entscheidung, Status, Regeln, Identität

**ZA-16 — Reprobe setzt keine Entscheidung zurück (REPORT 61).**
- `reprobeDeniedVolumes`: Medien mit `decision != .undecided` **nicht** über `storeAndPresent` führen.
  - Bei `.index`: Status `.indexed` (wenn `lastIndexedAt != nil`) bzw. `.pending` setzen und den passenden Lauf anstoßen (Abgleich bzw. `requestIndex`).
  - Bei `.dontIndex`: nur den Status setzen, keinen Lauf starten.
  - `decision = .undecided` nur für Medien, die schon unentschieden sind.
- Schnappschuss-Problem aus REPORT 132: Ist das Volume nach dem `await` nicht mehr in `mounted`, nichts tun (kein neues Medium anlegen).
- **Akzeptanz:**
  - `.index` + `.error` → `applicationDidBecomeActive()` → `decision` bleibt `.index`, kein Dialog.
  - Gemerktes `.dontIndex` + `.error` → bleibt `.dontIndex`.
Status:

**ZA-17 — „Ja“ nach „Nein“ startet wieder (REPORT 60, Korrektur B-60).** Repro: `nr60_…`.
- `IndexingService.finish` und `cancel(mediumUUID:)` rufen `coordinator?.clearIndexRequest(mediumID:)` auf. **Nicht** die Variante „nur bis zum Start halten“: Sie würde Doppelanfragen in `rerunAfterFinish` schieben.
- **Akzeptanz:** Repro grün; Doppelanfrage während eines Laufs → genau ein Lauf.
Status:

**ZA-18 — Status laufender Läufe nicht von außen überschreiben; Aufwachen ohne Doppel-Abgleich (REPORT 71, 72, Korrektur B-71).**
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

**ZA-19 — Bereinigung „nach 1 Stunde“ wirklich nach Zeit und beim Start (REPORT 114).**
- Nach `hydrateSettingsFromStore()`/`loadStoredMedia()` `pruneIfDue()` aufrufen.
- `armPrune` und `loadPruneDeadline` planen einen Task bis `pruneAt`; ein neuer Termin ersetzt ihn.
- `pruneNow` löscht den Termin nur, wenn er seit Beginn der Bereinigung nicht neu gesetzt wurde.
- `didWake` bleibt zusätzlich.
- **Akzeptanz:**
  - `pruneAt` in der Vergangenheit, Start-Ablauf → bereinigt (ohne Aufruf von Hand, Regel 18).
  - Wache App mit injizierbarer Uhr/kurzer Frist → bereinigt ohne `didWake`.
Status:

**ZA-20 — Regeländerungen wirken sofort und vollständig (REPORT 115, 68).**
- a) Bei jeder Scope-Änderung (`shrinks` oder `grows`, `AppState` Z. ~41–55) aktive Läufe abbrechen und mit **neuer** Konfiguration als Abgleich neu starten. Bei `grows` zusätzlich für jedes angeschlossene Medium mit `decision == .index` einen Abgleich anstoßen.
- b) 68: `reconcileScopeToStatus` setzt beim Verstecken eines Ordners den **ganzen Unterbaum** auf `status = 1` (rekursives CTE wie `markSubtreeGone`) und beim Wieder-Einblenden zurück, mit Neubewertung der Kinder. `purgeMarkedItems` sammelt die betroffenen `storageID`s und ruft danach `commitMediumMeta(forceRecount: true)`.
- **Akzeptanz:**
  - Lauf blockiert nach Ebene 1, `excludedPatterns += ["*.tmp"]`, freigeben → keine sichtbare `.tmp`-Zeile, `fileCount == COUNT(status=0)`.
  - `node_modules` mit 3 Dateien ausschließen → Suche nach einer davon liefert 0; nach `purgeMarkedItems` stimmt `fileCount`.
  - Tiefe 2 → 5+ bei fertigem, angeschlossenem Medium → Abgleich startet.
Status:

**ZA-21 — Identität: Klone und Volume-Umbenennung (REPORT 116, 78).**
- a) 116: `volumeAppeared` verwirft einen Treffer, dessen Medium-ID schon unter einem **anderen, noch eingehängten** Pfad steht, und behandelt ihn wie mehrdeutig (neues Medium mit Dialog). Nie zwei Pfade für ein Medium.
- b) 78: `NSWorkspace.didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als eigenes `MediumEvent`. Den Pfadschlüssel im Coordinator umbiegen, den Watcher mit neuem `VolumeInfo` stoppen und neu starten. Zusätzlich `kFSEventStreamCreateFlagWatchRoot` setzen.
- **Akzeptanz:**
  - Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.
  - Rename-Event → `volume(for:)` liefert den neuen Pfad; Unmount mit neuem Pfad setzt offline.
Status:

**ZA-22 — Dialog-Entscheidung nach dem Abziehen (REPORT 73).**
- `applyChoice` veröffentlicht als Verbindung `volume(for:) != nil ? .connected : .offline`.
- `volumeDisappeared` ruft nach `publish(.offline)` `AppWindowPresenter.syncNewMediumPanels(appState:)` auf (nicht in Unit-Tests).
- **Akzeptanz:** `requestDialog` → `.disappeared` → `onNewMediumChoice(id, true, true)` → `connectionStatus == .offline`, Panel geschlossen.
Status:

**ZA-23 — Medium-Zeile gezielt schreiben; Beenden verliert nichts (REPORT 62, 74, Korrektur B-74).**
- a) `MediumCodecV3.update` durch gezielte Setter je Feldgruppe ersetzen: Nutzerfelder (`isFavorite`, `decision`, `allowIndexing`, `showAbsoluteCapacity`, `autoIndexPaused`, `type`) und Erkennungsfelder (`name`, Kapazität, `lastSeenAt`). Indexer-Felder (Zähler, `indexStatus`, `completedDepth`, `first`/`lastIndexedAt`, `lastIndexActivityAt`, `fsEventsUUID`, `lastEventID`) schreiben nur Indexer und Watcher über ihre eigenen Wege. Alle Aufrufer umstellen (`writeMedium`, `connectKnown`, `volumeDisappeared`, `applyChoice`).
- b) Beenden: ausstehende Einstellungs- und Medium-Schreibvorgänge mit diesen gezielten `UPDATE`s sichern. Das geht synchron mit kurzer Zeitgrenze, nicht mit dem 10-s-Busy-Timeout auf main, oder per `.terminateLater` und `reply(toApplicationShouldTerminate:)` nach dem `await`.
- **Akzeptanz:**
  - Hook zwischen Lesen und Schreiben von `writeMedium`, dort `commitMediumMeta(delta: +100)` → `fileCount` enthält +100.
  - Einstellung bzw. Entscheidung ändern → sofort `prepareForTermination()` → neuer Store hat den Wert.
Status:

**HALT Paket 5** — Freigabe:

---

### Paket 6 — Oberfläche

**ZA-24 — Spaltenansicht: Zustand „wird indiziert“ richtig (REPORT 81, 126).**
- a) `rowOpacity` übergibt `folderName`, `folderListedAt` und `folderUnreadable` wie `iconColor`. Den Zustand **einmal je Zeile** berechnen und für Farbe und Deckkraft verwenden.
- b) `ColumnFolderOpenState.resolve`: `folderDepth >= maxDepth` → `.uncaptured(.scanDepth)` (der Indexer öffnet Ordner auf Tiefe = Scan-Tiefe nicht). Den Test `ProtocolAndSelectionTests` Z. ~290 auf `columnIndex: 1` bei Tiefe 2 umstellen.
- **Akzeptanz (echtes Fenster außerhalb des Bildschirms, Regel 10/19):**
  - Indizierter Ordner → Deckkraft 1.
  - Ordner mit `listedAt == nil` bei laufender Indizierung → 0,55.
  - Bei Scan-Tiefe 2 sind Ordner der Ebene 2 gelb mit „Inhalt wird nicht indiziert“, nicht grün.
Status:

**ZA-25 — ⌘A in großen Ordnern ohne quadratischen Aufwand (REPORT 65).**
- `ColumnSelection` führt zusätzlich ein `Set<UUID>` für `contains`.
- In `folderColumn`, `commit`, `multipleSelectionItems` und `contextTargets` einmal ein Dictionary `id → item` bzw. ein Set je Body/Aufruf.
- `IgnoreBatch`/`ContextMenuPlan` über Sets.
- Für „Dateinamen ignorieren“ mit sehr vielen Zielen: **Frage** an Claude (Obergrenze oder Warnung braucht einen Text, Z10).
- **Akzeptanz:** 50.000 künstliche Items, `selectAll`, `commit` und `selectedIDs` jeweils < 50 ms (Messung im Status).
Status:

**ZA-26 — Spalten-Cache verdrängt keine sichtbaren Spalten (REPORT 125, 98).**
- `IndexRepository.children()` setzt den Schlüssel bei jedem Lesen ans Ende von `cacheOrder`. Schlüssel der sichtbaren Spalten (`pathStack`) werden nie verdrängt.
- `pruneSelectionToVisibleItems` läuft nur, wenn der Ordner tatsächlich geladen ist (nicht bei fehlendem Cache oder `isLoading`).
- 98: `replaceStore` erhöht die Generationen (wie `invalidateAll`) statt sie zu löschen. Das `defer` des Loads räumt `loading`/`loadingTotals` nur bei passendem Token ab.
- **Akzeptanz:**
  - Wurzel offen, Ordner gewählt, danach 35 andere Ordner laden → Wurzel bleibt im Cache, Auswahl und `pathStack` bleiben.
  - `invalidateAll` während Auswahl → Auswahl bleibt.
Status:

**ZA-27 — Favorit und Online-Status in Listen aktuell (REPORT 80, 82, 103).**
- `AppState` führt eine Menge der Favoriten-IDs als Quelle für `isFavorite(_:)` bei Dateien. `toggleFavorite`/`toggleFavorites` patchen `favoriteObjects` und `searchMatch.items` lokal.
- `isOnline` in Suche, Favoriten und `ObjectContextTarget` beim Rendern und Filtern aus einem Dictionary `mediumID → connected` ableiten (einmal je Body), nicht speichern.
- 103: `ColumnFolderTableView.updateNSView` lädt sichtbare Zeilen neu, wenn `coordinator.items != items`.
- **Akzeptanz:**
  - In Favoriten einen Favoriten abwählen → Zeile verschwindet sofort; zweiter Klick setzt ihn wieder.
  - Medium per `updateMedium` offline → Filter „Offline“ enthält dessen Favoriten.
  - Tabelle ab 50k: Favorit umschalten → Zeile zeigt neuen Zustand.
Status:

**ZA-28 — Suche: Sortierung und Gruppen nicht nur über die erste Seite (REPORT 83, 130, 131).**
- `store.search` bekommt Sortierspalte und -richtung für **Name, Datum, Medium** (SQL `ORDER BY`, `items_modified` existiert). Bei Klick wird neu abgefragt.
- Für **Pfad** und **Status**: Client-Sortierung nur bei `itemCount <= pageLimit`, sonst diesen Spaltenkopf deaktivieren (kein neuer Text).
- 130: Das Popover holt Ordner und Dateien je mit eigener kleiner Abfrage (`LIMIT 3`).
- 131: Medien-IDs für die Kacheln per `SELECT DISTINCT storageID` mit denselben Filtern.
- **Akzeptanz:**
  - 600 Treffer, neuester heißt „zzz“ → Datum absteigend zeigt ihn zuerst; Name absteigend zeigt den alphabetisch letzten.
  - „rechnung“ mit 600 Dateien `Rechnung_…` und Ordner „Rechnungen“ → Gruppe „ORDNER“ vorhanden.
Status:

**ZA-29 — Popover-Suche entprellen und abbrechen (REPORT 85).**
- Den Task in `AppState` halten und bei neuer Eingabe `cancel()`. 150 ms Entprellung.
- Die Seite mit `withCount: false` holen, die Zahl getrennt und abbrechbar nachreichen.
- **Akzeptanz:** 5 Eingaben schnell hintereinander → höchstens eine Zählabfrage (Zähler im Test).
Status:

**ZA-30 — Favoriten-Tabelle lazy und seitenweise (REPORT 86).**
- `ObjectResultsTable` mit `LazyVStack`.
- Favoriten seitenweise wie die Suche (500 + Zählung).
- Mediennamen und Verbindungsstatus einmal als Dictionary übergeben, nicht je Zeile `appState.medium(with:)`.
- **Akzeptanz:** 10.000 Favoriten → erste Darstellung < 300 ms; Fortschritts-Tick baut nicht alle Zeilen neu (Zähler im Test).
Status:

**HALT Paket 6** — Freigabe:

---

### Paket 7 — Absturzschreiber und Start

**ZA-31 — Absturzschreiber signalsicher, Ringzeilen UTF-8-sicher (REPORT 76, 128).**
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

**ZA-32 — Einzelinstanz vor Protokoll; SIGTERM sauber (REPORT 87, 88).**
- `ensureSingleInstance()` **vor** `DiskIndexLog.shared.start()`.
- Bei `handedOff` in `applicationWillTerminate` nichts protokollieren und nichts abbauen.
- Protokoll-Handle mit `O_APPEND`.
- Bei `launchKind == .login` die Übergabe ohne `showMainWindow`.
- SIGTERM: aus der sigaction-Liste nehmen; `signal(SIGTERM, SIG_IGN)` plus `DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)` → `NSApp.terminate(nil)`.
- **Akzeptanz:**
  - Test der Startreihenfolge: Bei Übergabe schreibt die Zweitinstanz keine Protokollzeile und fasst `crash-last.txt` nicht an.
  - Testprozess mit SIGTERM → normales Beenden (Checkpoint läuft).
  - Kein Start der echten App (Regel 19).
Status:

**HALT Paket 7** — Freigabe:

---

## B. Backlog (nur nach Freigabe durch Claude)

Niedrig-Befunde aus REPORT. Lösung jeweils dort (mit Teil B der Zweitprüfung). Nicht anfassen, bevor Claude einzelne Punkte nach A verschiebt.

| REPORT | Kurz |
|---|---|
| 84 | Pfeiltasten in anderer Spalte → falscher Spaltenindex |
| 89 | Versions-Check-Zeilen verdrängen Absturzberichte |
| 92 | Pausentimer nach Store-Fehler |
| 93 | Versions-Sperre: Lücken (b/c) |
| 95 | Pause in der Zählphase speichert Teilsumme |
| 96 | `getattrlistbulk`-Offsets (teilweise in ZA-06 d) |
| 97 | Hot Path Matcher/Artefakte |
| 100 | Kollation Folgeseiten (latent) |
| 104 | Feste deutsche Texte, Locale-Formatierung |
| 105 | Pausentimer leitet Dauer ab |
| 106 | Popover-Höhe „Keine Treffer“ |
| 107 | Mindestanzeige des Ladehinweises wirkt nie |
| 132 | Sammelzeile Nebenläufigkeit (Verdacht) |

---

## Für den Hauptagenten (Zusammenführung)

- Nach Abnahme je Paket: Einträge in [DONE.md](DONE.md) mit Kennung `ZA-xx` und REPORT-Nummern. In REPORT.md die Spur je Befund (`ZA-xx`). Diese Datei danach ins Archiv (`archiv/`) verschieben oder leeren.
- Offene `ZA`-Aufgaben und Teil B in TODO.md (Version 0.3/0.4) einsortieren. Das bisherige Nummernschema `c.<Version>.<Nr>` gegebenenfalls zuordnen.
- Konzept- und Layout-Hinweise aus REPORT („Hinweise (kein Audit)“ und Zweitprüfung Teil E) mit dem Nutzer klären und ins README übernehmen. Beispiele: `rememberDecision`, abgelaufene Pause beim Start, neu formatiertes Medium, README-Abschnitt „Architektur“ veraltet.

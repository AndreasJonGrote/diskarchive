# Bestandsaufnahme 16.10.2026 (Host)

Geprüft gegen Commit `0857499` + Arbeitsbaum, Debug/Release/seriell/parallel am 16.10. (Zahlen siehe Zusammenfassung unten). **Urteile:** ERLEDIGT und bestätigt / ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) = DONE-Zeile plus grüner Gesamtlauf, keine Einzelprüfung jeder Zeile / ERLEDIGT, nicht abgenommen / TEILWEISE / OFFEN / HINFÄLLIG / UNKLAR.

## Zusammenfassung (Build und Tests, Host 16.10.2026, 14:27–15:20)

| Prüfung | Ergebnis |
|---|---|
| Debug-Build mit Testziel | **6 Warnungen** (alle `WatcherFlushReproTests.swift` 140–153) |
| Release-Build | 0 Warnungen |
| Serieller Gesamtlauf | **610 Tests in 154 Suites grün** (328 s) |
| Parallellauf 1 | **rot:** `StartupSequenceTests/slowOpenKeepsTheMainThreadFreeAndStillRecognisesMedia()` (4 s) |
| Parallellauf 2 | grün |
| Parallellauf 3 | **hing** in `WindowTestGroup/ColumnChangeLoopTests` (über 15 Minuten ohne Ausgabe, trotz `-maximum-test-execution-time-allowance 120`); von mir beendet |
| Neue `Disk Archive*.ips` | keine |
| Nutzer-App (Regel 23) | nicht neu gebaut; Stand 12:31 (Host-Lauf), seit dem Archivieren keine `.swift`-Änderung |

**Urteile über 132 Audit-Befunde:** 38 ERLEDIGT und bestätigt (Symbol oder Repro-Test geprüft), 41 ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt; DONE-Zeile, keine Einzelprüfung), 6 TEILWEISE (117, 118, 119, 121 = Paket 4; 108, 109 = Testziel/Parallellauf), 47 OFFEN, 0 HINFÄLLIG, 0 UNKLAR bei Befunden. Verteilung der offenen und teilweisen: Paket 4 (0.3.8) 11, Paket 5 (0.3.8) 12, Paket 6 (0.3.9) 13, Paket 7 (0.3.9) 4, Paket 8 (0.3.9) 13. **Kein Audit-Befund ist ohne Kennung.** REPORT.md leer, richtig.

**UNKLAR (nicht prüfbar ohne Nutzer):** Nutzerpunkte aus DONE („Nutzer prüft“: Dock 154, Hover-Reset 167, Sprach-Dropdown 172, Echttests Stick 174/176, Icon-Füllung 158–166), Laufzeit macOS 14, `todo.1.0.001` (durch `DelayedLoadingState` erledigt?).


## A. Audit-Befunde 1–132 (eine Zeile je Befund)

| Nr | Thema | Schwere | Kennung | Urteil | Beleg | offener Rest | Paket (Zielversion) |
|---|---|---|---|---|---|---|---|
| 1 | Bereinigen: Hard-Delete über Pfad ohne Medium | Kritisch | c.0.3 (be80c9c) | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | `IndexStoreV3.pruneToMatch`/`deleteItems`, V3 ohne Pfad-Präfix-DELETE | – | 0.3 |
| 2 | Nach Integritätsfehler laufen Dienste weiter, DB-Handle unbrauchbar | Kritisch | bug.0.3.2.001 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 3 | Change-Loop bleibt am ersten Store nach Retry | Hoch | bug.0.3.2.001 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 4 | `wireStore` stoppt vorherigen Indexer/Watcher nicht | Hoch | bug.0.3.2.001 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 5 | Parallele Startup-Tasks ohne Abbruch | Hoch | bug.0.3.2.001 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 6 | FSEvents-Watcher während Erstlauf/Abgleich | Hoch | bug.0.3.2.002 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 7 | „Indizieren“ Ja/Nein ohne Stop/Start/Watcher | Hoch | todo.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 8 | FSEvents-Setup scheitert → Watcher-Task hängt | Hoch | bug.0.3.2.002 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 9 | Stream-Unmount beendet Watcher ohne Neustart | Hoch | bug.0.3.2.002 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 10 | Live-Reread: DB-Fehler, Cursor trotzdem gespeichert | Hoch | bug.0.3.2.002 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 11 | Suche: `LIMIT` vor Scope-Filter | Hoch | bug.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 12 | Spalten-Pagination endet bei leer gefilterter Seite | Hoch | bug.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 13 | `finish` räumt Task/Spinner vor Token-Prüfung auf | Hoch | bug.0.3.2.004 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 14 | Suche: `isSearchInProgress` bleibt bei Abbruch | Hoch | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 15 | `cancel` bricht detached Index-Task nicht ab | Mittel | bug.0.3.2.004 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 16 | `requestedIndex`-Latch bei Pause-No-Op | Mittel | todo.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 17 | „Nicht indizieren“ setzt `indexStatus = .indexed` ohne Index | Mittel | todo.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 18 | Depth-Bereinigung: globale Metadaten-Updates (teilweise verbessert) | Mittel | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 19 | `childCount` ignoriert `IndexScope` | Mittel | bug.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 20 | `searchCount` scannt alle Treffer in Swift | Mittel | bug.0.3.2.003 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 21 | `forgetAllMedia` bricht DB-Löschung beim ersten Fehler ab | Mittel | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 22 | Store-Retry ohne Ladezustand in der UI | Mittel | bug.0.3.2.001 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 23 | Spalten-State nur teilweise beim Tab-Wechsel zurückgesetzt | Mittel | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 24 | Mitteilungs-Delegate ohne Main-Thread-Garantie | Mittel | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 25 | Quit-Checkpoint nicht abgewartet | Mittel | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 26 | Hintergrund-Recount ohne Lauf-Kopplung | Mittel | bug.0.3.2.004 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 27 | `autoIndexPaused` aus DB geht in `asMedium` verloren | Niedrig | bug.0.3.2.005 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 28 | Integritätsfehler: `indexStore`/`changeLoop` nicht zurückgesetzt | Mittel | bug.0.3.2.001 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (Prüfzeichen A B, 12.10.); Tests im Gesamtlauf | – | 0.3.2 |
| 29 | Hoch | A1 | bug.0.3.239 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); Tests im Gesamtlauf | – | 0.3 |
| 30 | Hoch | A2 | bug.0.3.240 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); `api_queue` im Code (20 Treffer) | – | 0.3 |
| 31 | Mittel | A3 | bug.0.3.240 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); `api_queue` im Code (20 Treffer) | – | 0.3 |
| 32 | Mittel | A4 | bug.0.3.241 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); Tests im Gesamtlauf | – | 0.3 |
| 33 | Mittel | A5 | bug.0.3.240 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); `api_queue` im Code (20 Treffer) | – | 0.3 |
| 34 | Niedrig | A6 | bug.0.3.242 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); Tests im Gesamtlauf | – | 0.3 |
| 35 | Niedrig | N1 | bug.0.3.243 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); Tests im Gesamtlauf | – | 0.3 |
| 36 | Mittel | N2 | bug.0.3.241 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); Tests im Gesamtlauf | – | 0.3 |
| 37 | Niedrig | N3 | bug.0.3.240 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); `api_queue` im Code (20 Treffer) | – | 0.3 |
| 38 | `lastCompactionAt` nur Audit (Spec 236) | N4 | Doku (14.10.) | ERLEDIGT und bestätigt | DONE „Doku erledigt“; README „Architektur“/„Datenbank“ neu | – | – |
| 39 | Hoch* | N5 | bug.0.3.244 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B/C, 13.10.); Tests im Gesamtlauf | – | 0.3 |
| 40 | 238-Bericht `api_queue` Text veraltet | N6 | Doku (14.10.) | ERLEDIGT und bestätigt | DONE „Doku erledigt“; README „Architektur“/„Datenbank“ neu | – | – |
| 41 | README Layout-Reminder 0.3.2 | N7 | Doku (14.10.) | ERLEDIGT und bestätigt | DONE „Doku erledigt“; README „Architektur“/„Datenbank“ neu | – | – |
| 42 | Mittel | L1 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 43 | Kritisch | L2 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 44 | Hoch | L3 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 45 | Hoch | L4 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 46 | Niedrig | L5 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 47 | Hoch | L6 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 48 | Hoch | L7 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 49 | Mittel | L8 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 50 | Mittel | L9 | bug.0.4.001 | ERLEDIGT und bestätigt | `FeatureAccess` (4 Treffer), `WriteGuard.permits` (18 Treffer), VersionLockReadOnlyTests | – | 0.4 |
| 51 | Mittel | A1b | bug.0.3.245 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE (A B, 13.10.) | – | 0.3 |
| 52 | Niedrig | R1 | bug.0.3.246 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE | – | 0.3 |
| 53 | Niedrig | R2 | bug.0.3.246 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE | – | 0.3 |
| 54 | Scrubber: Apostroph oder Anführungszeichen im Pfad → Namen im Klartext im Bericht | Hoch | bug.0.4.011 | ERLEDIGT und bestätigt | `DiskIndexLog.errorSummary` (7), `privateDetail` nur noch Tiefe/Länge, `PrivacyLogAndScrubberTests` | – | 0.4 |
| 55 | Leak-Wächter vor dem Senden greift praktisch nie | Hoch | bug.0.4.012 | ERLEDIGT und bestätigt | Leak-Wächter in `IssueTracker` (11 Treffer), `IssueTrackerTests` | – | 0.4 |
| 56 | Live-Rename: nicht gefundener Elternordner wird als Medienwurzel behandelt | Hoch | bug.0.4.017 | ERLEDIGT und bestätigt | `LiveRenameReproTests` | – | 0.4 |
| 57 | `apply`: fileID-Verschiebung entfernt die gleichnamige Zeile des Zielordners | Hoch | bug.0.4.016 | ERLEDIGT und bestätigt | `FileIdentityWriterReproTests` | – | 0.4 |
| 58 | `finishIndexing` löscht verschwundene Einträge auch bei abgebrochenem Lauf | Hoch | bug.0.4.014 | ERLEDIGT und bestätigt | `ReconcileAbortReproTests`, Ergebnis „unterbrochen“ im Code (4) | – | 0.4 |
| 59 | Abgebrochener Abgleich wird `.pending` → nächster Lauf überspringt alle schon indizierten Ebenen | Hoch | bug.0.4.014 | ERLEDIGT und bestätigt | dito | – | 0.4 |
| 60 | `requestedIndex` bleibt nach erfolgreichem Lauf gesetzt → „Ja“ nach „Nein“ startet nichts | Hoch | bug.0.4.027 | OFFEN | `clearIndexRequest` nur in den Early-Guards von `start`, nicht in `finish`/`cancel` (`IndexingService` 69/85/90) | komplett | 0.3.8 Paket 5 |
| 61 | Reprobe bei App-Aktivierung setzt die Entscheidung bekannter Medien zurück | Hoch | bug.0.4.026 | OFFEN | `reprobeDeniedVolumes` → `storeAndPresent(.pending, openDialog:true)` unverändert | komplett | 0.3.8 Paket 5 |
| 62 | Medium-Zeile: Lesen → `await` → ganze Zeile zurückschreiben überschreibt Indexer-Felder | Hoch | bug.0.4.033 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.8 Paket 5 |
| 63 | FAT/exFAT/NTFS: `matchGoneCandidate` durchsucht pro neuem Eintrag das ganze Medium | Hoch | bug.0.4.013 / 015 | ERLEDIGT und bestätigt | Migration `0.4.0-items_gone`, `FatReconnectIndexerTests` | – | 0.4 |
| 64 | Neues FSEvent bricht laufenden Flush ab → `CancellationError` → Voll-Abgleich | Hoch | bug.0.4.019 | ERLEDIGT und bestätigt | `flushInFlight` (6), `WatcherFlushReproTests` | – | 0.4 |
| 65 | ⌘A in großen Ordnern: quadratischer Aufwand | Hoch | bug.0.4.035 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 66 | Zurückgestellter Flush wird aus dem Quiet-Task nie neu eingeplant | Mittel | bug.0.4.019 | ERLEDIGT und bestätigt | dito | – | 0.4 |
| 67 | `beginIndexing`: Token bleibt nach Schreibfehler hängen | Mittel | bug.0.4.014 | ERLEDIGT und bestätigt | Repro nr67 | – | 0.4 |
| 68 | Regel-Abgleich versteckt nur den Treffer, nicht dessen Inhalt; Zähler nach Bereinigung veraltet | Mittel | bug.0.4.030 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.8 Paket 5 |
| 69 | Ordner-Verschiebung über fileID: Tiefe der Unterzeilen wird nicht angepasst | Mittel | bug.0.4.016 | ERLEDIGT und bestätigt | Repro nr69 | – | 0.4 |
| 70 | Live-Rename-Paar ohne Identitätsprüfung | Mittel | bug.0.4.017 | ERLEDIGT und bestätigt | Repro nr70 | – | 0.4 |
| 71 | `normalizeInterruptedIndexingStatuses` läuft zur Laufzeit und setzt aktive Läufe zurück | Mittel | bug.0.4.028 | OFFEN | `normalizeInterruptedIndexingStatuses` noch in `AppState+Media` | komplett | 0.3.8 Paket 5 |
| 72 | Aufwachen: jedes Medium wie neu eingesteckt → Doppel-Abgleich, Statusüberschreibung | Mittel | bug.0.4.028 | OFFEN | `normalizeInterruptedIndexingStatuses` noch in `AppState+Media` | komplett | 0.3.8 Paket 5 |
| 73 | Dialog-Entscheidung nach dem Abziehen → Medium „verbunden“; Panel bleibt offen | Mittel | bug.0.4.032 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.8 Paket 5 |
| 74 | Beenden verwirft entprellte Schreibvorgänge | Mittel | bug.0.4.033 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.8 Paket 5 |
| 75 | API-Queue: Offline-Fehlversuch → 1 h Backoff, Timer stoppt | Mittel | bug.0.4.024 | OFFEN | Kein Commit zu bug.0.4.024; Code unverändert | komplett | 0.3.8 Paket 4 |
| 76 | Absturzschreiber nicht signalsicher | Mittel | bug.0.4.041 | OFFEN | `storeCrumb` unverändert, kein `SIG_IGN`/`makeSignalSource` | komplett | 0.3.9 Paket 7 |
| 77 | Stall-Erkennung greift bei hängendem Lesen nicht; Leser läuft nach Abbruch weiter | Mittel | bug.0.4.020 | ERLEDIGT und bestätigt | `DirectoryReadStalled` (6) | – | 0.4 |
| 78 | Umbenennen des Volumes wird nicht verarbeitet | Mittel | bug.0.4.031 | OFFEN | kein `didRenameVolume` im Code | komplett | 0.3.8 Paket 5 |
| 79 | `ChangeWatcher.stop` leert Zustand erst nach `await` | Mittel | bug.0.4.019 | ERLEDIGT und bestätigt | dito | – | 0.4 |
| 80 | Favorit umschalten in Suche/Favoriten: Liste veraltet, zweiter Klick wirkt gleich | Mittel | bug.0.4.037 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 81 | Spaltenansicht: jede Ordnerzeile wird als „wird indiziert“ abgedunkelt | Mittel | bug.0.4.034 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 82 | Online/Offline der Treffer ist ein Schnappschuss | Mittel | bug.0.4.037 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 83 | Sortieren nach Datum/Medium/Pfad/Status sortiert nur die ersten 500 Namen-Treffer | Mittel | bug.0.4.038 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 84 | Pfeiltasten in anderer Spalte → Auswahl mit falschem Spaltenindex | Mittel | bug.0.4.050 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 85 | Popover-Suche: pro Tastendruck volle Suche plus Zählung, nie abgebrochen | Mittel | bug.0.4.039 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 86 | Favoriten-Tabelle nicht lazy und ohne Limit | Mittel | bug.0.4.040 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 87 | Zweitinstanz schreibt Protokoll und Absturzmarker vor der Einzelinstanz-Prüfung | Mittel | bug.0.4.042 | OFFEN | Code unverändert | komplett | 0.3.9 Paket 7 |
| 88 | SIGTERM: sofortiges Ende ohne Aufräumen, als „sauber“ protokolliert | Niedrig | bug.0.4.042 | OFFEN | `storeCrumb` unverändert, kein `SIG_IGN`/`makeSignalSource` | komplett | 0.3.9 Paket 7 |
| 89 | Versions-Check-Zeilen verdrängen Absturzberichte | Niedrig | bug.0.4.051 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 90 | Outbox-Datei wird gelöscht, auch wenn die Übernahme scheitert | Niedrig | bug.0.4.024 | OFFEN | Kein Commit zu bug.0.4.024; Code unverändert | komplett | 0.3.8 Paket 4 |
| 91 | Unified Log: Suchbegriffe und Fehlertexte als `.public` | Niedrig | bug.0.4.011 | ERLEDIGT und bestätigt | os_log privat | – | 0.4 |
| 92 | Nach Store-Fehler läuft der Pausentimer nicht mehr ab | Niedrig | bug.0.4.052 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 93 | Versions-Sperre: Lücken | Niedrig | bug.0.4.053 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 94 | `readFolderWithRetry` wiederholt auch Pause/Halt und hängt Chunks doppelt an | Niedrig | bug.0.4.020 | ERLEDIGT und bestätigt | dito | – | 0.4 |
| 95 | Pause in der Zählphase speichert Teilsumme als `scanTotal` | Niedrig | bug.0.4.054 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 96 | `getattrlistbulk` mit `FSOPT_PACK_INVAL_ATTRS`, Offsets nur bei gesetztem Bit | Niedrig | bug.0.4.055 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 97 | Hot Path: Muster je Eintrag neu geparst | Niedrig | bug.0.4.056 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 98 | `IndexRepository.replaceStore` löscht Generationen | Niedrig | bug.0.4.036 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 99 | `commitPendingMetaIfNeeded`: Reentrancy über `await` | Niedrig | bug.0.4.019 | ERLEDIGT und bestätigt | dito | – | 0.4 |
| 100 | — | bestätigt (latent) | bug.0.4.057 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 101 | Muss **vor** der ersten Schema-Erweiterung ausgeliefert sein. | bestätigt | bug.0.4.013 | ERLEDIGT und bestätigt | `hasBeenSuperseded` (1), `schemaSuperseded` (2) | – | 0.4 |
| 102 | — | bestätigt | bug.0.4.020 | ERLEDIGT und bestätigt | dito | – | 0.4 |
| 103 | Statt Fingerabdruck reicht `coordinator.items != items` (`IndexedItem` ist Equatable). | bestätigt | bug.0.4.037 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 104 | Feste Texte und `String(count)` bestätigt. Datum folgt nach dem nächsten Start `AppleLanguages`, „bleibt deutsch“ gilt also nur bis zum Neustart. Trenner folgen der System-Region. | **teilweise** | bug.0.4.058 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 105 | — | bestätigt | bug.0.4.059 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 106 | Umbruch ab ca. 25 Zeichen. | bestätigt (wahrscheinlich) | bug.0.4.060 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 107 | Erneutes Laden während der Mindestanzeige ist **nicht** erreichbar (zwei getrennte Exemplare). Tatsächlicher Defekt: Die **400-ms-Mindestanzeige wirkt nie**, weil das Lade-Exemplar samt `@State` beim Ladeende verworfen wird; das führt zu Flackern knapp über 1 s. Lösung: ein Exemplar mit `isLoading` als Parameter. | **teilweise** | bug.0.4.061 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |
| 108 | Auch im Testziel Warnungen, die in Swift 6 Fehler wären (`IndexingFinishCancelTests` 170–224, `IssueTrackerTests` 283, `AppSettingsPersistenceTests` 39–43). Ziel „ohne Warnungen“ inkl. Testziel. | bestätigt | bug.0.4.010 | TEILWEISE | Warnungen 0 in Release; Testziel Debug: **6 Warnungen** (neu durch Harness 16.10.) | Testziel-Warnungen (WatcherFlushReproTests 140–153) beseitigen | 0.3.8 |
| 109 | Die Repro-Suite nutzt `.serialized`, als Muster. | bestätigt | bug.0.4.010 / 044 | TEILWEISE | Gesamtlauf; Parallellauf heute siehe Summe | Parallellauf rot (siehe Zusammenfassung) → Testisolation | 0.3.8 |
| 110 | FAT/exFAT/NTFS: Wiederverbinden nach Umbenennen/Verschieben (selbe oder höhere Ebene) greift praktisch nie → Favorit und Nutzer-Meta weg | Hoch | bug.0.4.015 | ERLEDIGT und bestätigt | `FatReconnectIndexerTests` | – | 0.4 |
| 111 | Jede Änderung **innerhalb eines Pakets** (.photoslibrary, .app, .logicx) → Voll-Abgleich des Mediums | Hoch | bug.0.4.018 | ERLEDIGT und bestätigt | `PackageAndTrashesWatcherTests` | – | 0.4 |
| 112 | Hardlinks teilen die fileID → eine Zeile je Inode, springt bei jedem Lauf zwischen den Pfaden | Hoch (Backup-Medien) | bug.0.4.016 | ERLEDIGT und bestätigt | Hardlink-Tests (`HardlinkIndexerTests`) | – | 0.4 |
| 113 | FSEvents-Pfade werden zu NFD; NFC-Namen werden in SQL nicht gefunden | Mittel | bug.0.4.017 | ERLEDIGT und bestätigt | `LiveRenameReproTests` | – | 0.4 |
| 114 | Bereinigungstermin („nach 1 Stunde“) wird nur beim Aufwachen geprüft, nie nach Zeit, nie beim Start | Mittel | bug.0.4.029 | OFFEN | `pruneIfDue` nur 2 Stellen (Aufwachen) | komplett | 0.3.8 Paket 5 |
| 115 | Regeländerung während eines Laufs: Lauf arbeitet nach alten Regeln; Erweitern startet bei fertigen Medien keinen Lauf | Mittel | bug.0.4.030 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.8 Paket 5 |
| 116 | Zwei gleichzeitig angeschlossene Klone mit gleicher Identität → ein Medium, Einträge des anderen gelöscht | Mittel | bug.0.4.031 | OFFEN | kein `didRenameVolume` im Code | komplett | 0.3.8 Paket 5 |
| 117 | `MediumAccess.probe` liest die Medienwurzel **auf dem Main-Thread**, bei jeder App-Aktivierung | Hoch | bug.0.4.021 | TEILWEISE | `DirectMediumAccess.probe` über Queue + 5-s-Zeitgrenze | Bereit zur Prüfung; Testisolation (statische Verzögerung) | 0.3.8 Paket 4 |
| 118 | `MediumMonitor` fragt alle Volumes (auch Netz) auf dem Main-Thread ab (Start, Aufwachen) | Mittel | bug.0.4.021 | TEILWEISE | `LocalVolumeMounts` (`getmntinfo` MNT_NOWAIT, MNT_LOCAL, /Volumes/) | dito | 0.3.8 Paket 4 |
| 119 | `stat()` je Ereignispfad auf dem Main-Thread, Ergebnis fast immer verworfen | Mittel | bug.0.4.022 | TEILWEISE | `LiveWatchScope`, `ChangeWatcherEngine.prepareFlush` | `scopedParentDirectory` nach Rename auf main; `urlIsPackage`-Abkürzung weicht ab | 0.3.8 Paket 4 |
| 120 | Synchrone DB-Schreibzugriffe auf dem Main-Thread; `queuePool` wird nie gesetzt → neuer Pool je Aufruf | Mittel | bug.0.4.024 | OFFEN | Kein Commit zu bug.0.4.024; Code unverändert | komplett | 0.3.8 Paket 4 |
| 121 | Teil-Prüfsumme liest Mediendateien im Store-Actor bzw. unter der SQLite-Schreibsperre | Mittel | bug.0.4.023 | TEILWEISE | `PartialChecksum.computeOffActor` | `fileExists`/`resourceValues` in `precomputedPartials`/`applyLiveRename` auf Store-Actor; Test flakt | 0.3.8 Paket 4 |
| 122 | Jede Protokollzeile `chmod` + `fsync` unter globalem Lock, 1–2 Zeilen je gelesenem Ordner | Mittel | bug.0.4.025 | OFFEN | Kein Commit zu bug.0.4.025; Code unverändert | komplett | 0.3.8 Paket 4 |
| 123 | Schreibfehler im Chunk-Pfad gelten als Lesefehler → Ordner „nicht lesbar“, Lauf endet `.indexed` | Mittel | bug.0.4.020 | ERLEDIGT und bestätigt | `IndexWriteFailed` (4), `IndexerWriteReproTests` | – | 0.4 |
| 124 | Scrubber macht jede deutsche Protokollzeile mit Umlaut komplett unlesbar | Mittel | bug.0.4.011 | ERLEDIGT und bestätigt | Scrubber-Tests | – | 0.4 |
| 125 | Spalten-Cache verdrängt sichtbare Spalten → Auswahl und geöffneter Pfad gehen verloren | Mittel | bug.0.4.036 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 126 | Scan-Tiefe 1–4: Ordner der letzten Ebene stehen dauerhaft auf „Wird indiziert“ | Mittel | bug.0.4.034 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 127 | „Verwerfen“ im Absturzdialog löscht frühere, schon zugestimmte Berichte | Niedrig | bug.0.4.024 | OFFEN | Kein Commit zu bug.0.4.024; Code unverändert | komplett | 0.3.8 Paket 4 |
| 128 | Kürzung der Aktionszeile auf 239 Bytes kann UTF-8 zerschneiden → Absturz nicht erkannt | Niedrig | bug.0.4.041 | OFFEN | `storeCrumb` unverändert, kein `SIG_IGN`/`makeSignalSource` | komplett | 0.3.9 Paket 7 |
| 129 | Umbenennen + neue Datei mit altem Namen: Ergebnis hängt von der Dictionary-Reihenfolge ab | Niedrig | bug.0.4.016 | ERLEDIGT und bestätigt | Repro nr57 | – | 0.4 |
| 130 | Popover: Gruppe „ORDNER“/„DATEIEN“ fehlt trotz Treffern (nur erste 500) | Niedrig | bug.0.4.038 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 131 | Suche nur mit Filter: Medien-Kacheln nur aus der ersten Seite | Niedrig | bug.0.4.038 | OFFEN | Code zeigt den Zustand der Audit-Beschreibung | komplett | 0.3.9 Paket 6 |
| 132 | Sammelzeile Verdachtsfälle (FSEvents-Kontext, Worker-`defer`, Reprobe beim Aushängen u. a.) | Niedrig | bug.0.4.062 | OFFEN | Backlog „niedrige Schwere“, nicht angefasst | komplett | 0.3.9 Paket 8 |

## B. Kennungen aus DONE.md und TODO.md

| Kennung | Thema | Urteil | Beleg | offener Rest | Paket (Zielversion) |
|---|---|---|---|---|---|
| bis 88, 100–121, 122–233b | Altbestand 0.1/0.2/0.3 (Erkennung, Indizierung, Spaltenansicht, Suche, Einstellungen, V3-Datenbank …) | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | DONE-Register; alle zugehörigen Tests im Gesamtlauf | Nutzertests, siehe UNKLAR unten | 0.1–0.3 |
| Nutzer prüft: 154 (Dock), 167 (Hover-Reset), 172 (Sprach-Dropdown-Gefühl), 174/176 (Echttest Stick), 184 (macOS-14-Laufzeit), 158–166 (Icon-Füllung 50 %, Wahl offen) | Von Claude nie am echten System bestätigt | UNKLAR | DONE nennt „Nutzer prüft“/„offen“; im Code nicht prüfbar | Nutzertest 0.3.9 Kriterium 7; macOS 14 = `todo.0.4.022` | 0.3.9 / 0.4 |
| todo.0.3.2.003 | Erkennungs-Stapel, Dashboard-Meta | ERLEDIGT und bestätigt | `NewMediumStackTests`, `MediumRecognitionTests` im Gesamtlauf | Layout 02/04 nachziehen (`todo.0.3.2.001`, Nutzer) | 0.3.2 |
| bug.0.3.2.001–005 | Audit 2–28 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | siehe Teil A | – | 0.3.2 |
| todo.0.3.234–238, todo.0.3.1.001 | Regel-Status, fileID, Wartung, `settings`, Messung, `api_queue` | ERLEDIGT und bestätigt | `api_queue` (20 Treffer im Code), Schema V3 eingefroren, Tests im Gesamtlauf | – | 0.3 / 0.3.1 |
| bug.0.3.239–246 | Audit 29–37, 39, 51–53 | ERLEDIGT (Altbestand, durch Gesamtlauf gedeckt) | siehe Teil A | – | 0.3 |
| todo.0.4.001, bug.0.4.001 | Versions-Check, Update-Modal, Beta-Sperre, Nur-Lesen | ERLEDIGT und bestätigt | `VersionCheckCoordinator` (10), `FeatureAccess` (4), VersionCheckTests, VersionLockReadOnlyTests | Beta-Frage `todo.0.4.030` offen | 0.4 |
| bug.0.4.043 | „Ja“ nach „Nein“ (Race) | ERLEDIGT und bestätigt | `AllowIndexingToggleRaceTests` | Nachfolger REPORT 60 → `bug.0.4.027` offen | 0.4 |
| todo.0.4.010 | Purge toter Namen, Testhooks | ERLEDIGT und bestätigt | `IndexStoreV3TestHooks.swift` | – | 0.4 |
| todo.0.4.011 | Kaltstart zeigt Menüleiste + Fenster | ERLEDIGT und bestätigt | durch `todo.0.4.013` ersetzt (b), a erledigt | Teil b: HINFÄLLIG (ersetzt) | 0.4 |
| todo.0.4.012 | Panel „Neues Speichermedium“ Position | ERLEDIGT und bestätigt | Rechenfunktion + Test (`NewMediumPanelPlacementTests`) | – | 0.4 |
| todo.0.4.013 | Jeder Start zeigt alles | ERLEDIGT und bestätigt | `BackgroundLaunchGateTests`, `StartupSequenceTests` | – | 0.4 |
| bug.0.4.010 | Warnungen 0 | TEILWEISE | Release 0; Debug+Testziel 6 Warnungen seit 16.10. | Warnungen in `WatcherFlushReproTests` | 0.3.8 |
| bug.0.4.044 | Parallellauf grün | TEILWEISE | war grün am 15.10.; 16.10. wieder rot (Testisolation) | Testisolation | 0.3.8 |
| bug.0.4.011–020, todo.0.4.014 | Datenschutz, Inventar, Live, Indexer, Nur-Lesen-Nachweis | ERLEDIGT und bestätigt | siehe Teil A (Symbole und Repro-Tests) | – | 0.4 |
| bug.0.4.045 | `WriteGuard` ohne Rückschreiben ins Protokoll | ERLEDIGT, nicht abgenommen | `WriteGuard.swift` Logger+`blockedWriteCount`, `WriteGuardDeadlockTests` | Prüfung mit Nacharbeit | 0.3.8 Paket 4 |
| bug.0.4.021–023 | Medien-I/O off-main | TEILWEISE | siehe Teil A (117/118/119/121) | Nacharbeit Teil A | 0.3.8 Paket 4 |
| bug.0.4.024–025 | Fehlerbericht-Queue, Protokoll | OFFEN | kein Commit | komplett | 0.3.8 Paket 4 |
| bug.0.4.026–033 | Entscheidung, Status, Regeln, Identität | OFFEN | siehe Teil A | Entscheidungen `todo.0.4.032`/`033` vor Start | 0.3.8 Paket 5 |
| bug.0.4.034–040 | Oberfläche | OFFEN | siehe Teil A | Entscheidung `todo.0.4.031` für Teil von 035 | 0.3.9 Paket 6 |
| bug.0.4.041–042 | Absturzschreiber, Start | OFFEN | siehe Teil A | – | 0.3.9 Paket 7 |
| bug.0.4.050–062 | Fehler niedriger Schwere | OFFEN | siehe Teil A | – | 0.3.9 Paket 8 |
| todo.0.3.2.001 | Layout 02 und 04 nachziehen | OFFEN | Nutzer; blockiert keinen Code | Nutzer | 0.3.9 |
| todo.0.3.2.002 | MARKETING_VERSION anheben | OFFEN | pbxproj: `MARKETING_VERSION = 0.2.0` (3 Stellen) | Umsetzer, auf tatsächlichen Stand | 0.3.8 |
| todo.0.4.020–025 | Signatur/Notarisierung, Download-Seite, macOS 14, Fehlerbericht echt, Update durch Ersetzen, Fenster „Datenbank wird aktualisiert“ | OFFEN | Backlog 0.4 (Weitergabe) | alle | 0.4 |
| todo.0.4.030–038 | Entscheidungen des Nutzers | OFFEN | TODO „Entscheidungen“; 039 entschieden | Nutzer | 0.3.8 / 0.3.9 / 0.4 |
| bug.0.4.070 / 071 | Beobachten (selten rote Tests, kurze Sleeps) | UNKLAR | nicht reproduziert | Teil der Testisolation | 0.3.8 |
| todo.0.5.001–todo.1.0.003 | Metadaten … Lizenz … 1.0 | OFFEN | Entwürfe, nicht freigegeben; `todo.1.0.001` prüfen, ob durch `DelayedLoadingState` erledigt (UNKLAR; REPORT 107 sagt: 400-ms-Mindestanzeige wirkt nie) | Einzelbesprechung | 0.5–1.0 |

## C. Dokumente

- **README/ROADMAP:** Roadmap-Tabelle nennt 0.3.8/0.3.9 nicht; „MARKETING_VERSION 0.2.0“ stimmt mit pbxproj überein (Widerspruch zu „gebaut 0.3.2“ nur in der Praxis). ROADMAP-Zeile 0.4 führt „Audit-Fehler bug.0.4.010–042“, tatsächlich auch 043–062. → in Schritt 3 korrigiert.
- **REPORT.md:** leer, richtig (alle Befunde bis 132 in DONE oder TODO). Keine zugesagte Arbeit verloren: Alle 132 Nummern sind in Teil A abgedeckt.
- **Abweichung der Roadmap:** Teile von 0.3.2 (Code) und 0.4 (Versions-Check) wurden gebaut, bevor 0.2 formal alle Fehler hatte; die Fehler liefen als `bug.0.4.*` weiter. Version im Projekt 0.2.0.

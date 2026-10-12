# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) — einzige Quelle für Größen.** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Regeln für Cursor (verbindlich)

1. **Nur Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage (ab 11.10., Nutzer): normal über `L10n`/`LayoutCopy` mit de und en anlegen und im Status als „Neue Texte:“ auflisten; der Nutzer prüft sie. Keine roten Vorschläge mehr.
4. **Layout und README sind schreibgeschützt** für Cursor (auch `AGENTS.md`, `archiv/`). Abweichung gefunden → als „Frage:“ melden, nicht selbst „angleichen“.
5. **Diese Datei:** Cursor ändert nur das Feld „Status“ der jeweiligen Aufgabe (höchstens 5 Zeilen: was, welche Dateien, Abweichung). Keine Reviewblöcke, keine neuen Aufgaben, nichts umsortieren, nichts löschen. Claude räumt auf.
6. **Keine Selbstfreigabe.** Cursor schreibt „Bereit zur Prüfung“, nie „fertig“. Nur Claude verschiebt nach DONE.md.
7. **Belege statt Behauptungen:** „Tests grün“ nur mit Zahl, Uhrzeit, Kommando. Bildschirmfotos nur melden, wenn sie in diesem Lauf neu erzeugt wurden (Zeitstempel prüfen). Build Debug und Release ohne Warnung.
8. **Tests:** nur `-only-testing:diskindexTests`; nach **jeder Aufgabe seriell**, am **Ende des Pakets** zusätzlich einmal parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, Cursor legt ihn bei Aufgabe 122 an und erweitert ihn bei jeder Aufgabe): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.
15. **Zeichenpfad sauber halten:** in `body`, `init`, `Binding(get:)`, `@State … = …` und `onAppear` **keine** Systemaufrufe (`SMAppService`, `UNUserNotificationCenter`, Dateisystem, Datenbank) und **keine** Zustandsänderungen. Solche Werte liegen in `AppState` und werden im Hintergrund aktualisiert.
16. **Zeilenangaben sind Richtwerte** („Z. ~“). Gilt eine Zeile nicht mehr, über den genannten **Symbolnamen** suchen; nichts an anderer Stelle „ähnlich“ ändern.
17. **Fotos selbst prüfen.** Jedes Foto im Status vorher öffnen; zeigt es nicht das Verlangte (Sperrbildschirm, falsches Fenster, leerer Inhalt), neu aufnehmen. Ein falsches Foto = Aufgabe nicht gemacht.
18. **Keine Nachhilfe in End-to-End-Tests.** Ein Test, der eine Kette beweisen soll (Platte → FSEvents → Store → Meldung → Spalte), darf keinen Schritt dieser Kette selbst aufrufen (`flushIndexChange`, `scheduleIndexChange`, `invalidate`, `requestLoad`, `loadChildren` als Ersatz für die Anzeige). Er wartet nur und liest das Ergebnis. Geht es ohne Nachhilfe nicht, ist das ein Befund → „Frage:“.
19. **Bildschirm des Nutzers frei lassen (Nutzer 09.10.: „keine Screenshots, nur Script-Prüfung“, gilt bis auf Widerruf).** Keine echte App starten, keinen `ScreenshotRunner`, keine Bildschirmfotos, nichts aktivieren oder in den Vordergrund holen. Nachweis nur über `xcodebuild test` (mit Zeitgrenze), Protokolldateien und Skripte (`sqlite3`, `grep`). `PixelProbe`-Fenster werden **außerhalb des sichtbaren Bereichs** geöffnet (Ursprung `x: -20000, y: -20000`, `orderFrontRegardless` statt `makeKeyAndOrderFront`, nie `NSApp.activate`); `cacheDisplay` funktioniert dort genauso. Echte-App-Teilaufgaben (z. B. 183 e) entfallen und werden durch einen Skript-Nachweis ersetzt (siehe dort).
20. **Tests stürzen nie ab.** Kein Zugriff `array[i]` ohne vorheriges `try #require(array.count > i)` (bzw. `#require(array.first)`), kein `!` auf Optionals, keine Bereiche `a..<b` ohne Prüfung `a <= b`. Ein fehlgeschlagener Test meldet „rot“, er beendet nie den Prozess (sonst Absturzbericht auf dem Bildschirm des Nutzers, Regel 19). Vor „Bereit zur Prüfung“: `grep -n '\[0\]\|\[1\]\|\[2\]' diskindexTests/<neue Dateien>` und jede Stelle absichern.
21. **Keine System-Ereignisse aus Tests.** Verboten: `CGEvent(…).post(…)`, `CGWarpMouseCursorPosition`, `AXUIElement…`, alles, was die **echte** Maus/Tastatur des Nutzers bewegt oder Bedienungshilfen-Rechte braucht (Nutzer 09.10. 23:00: macOS fragte „Disk Archive möchte diesen Computer mit Funktionen der Bedienungshilfe steuern“). Klicks nur per `NSEvent.mouseEvent(…)` + `window.sendEvent` an das **eigene** Testfenster (wie `PixelProbe.click`). Kein `makeKeyAndOrderFront`, kein `NSApp.activate` (Regel 19).
22. **Kein Git, kein GitHub (AGENTS.md).** Keine verändernden Git-Befehle (`commit`, `add`, `push`, `pull`, `checkout`, `stash`, `worktree`, `reset` …), keine Best-of-N-Läufe mit Git-Arbeitskopien, nichts auf GitHub. Nur `git status`/`log`/`diff`/`show` zum Nachsehen.
23. **Zum Schluss die App bauen, die der Nutzer startet (Nutzer 10.10.).** Letzter Schritt jeder Aufgabe, **nach** Sabotage-Rücknahme und Testläufen: `xcodebuild build -project diskindex.xcodeproj -scheme diskindex -configuration Debug -destination 'platform=macOS'` **ohne** `-derivedDataPath` (Ziel: `~/Library/Developer/Xcode/DerivedData/diskindex-…/Build/Products/Debug/Disk Archive.app`, dort startet der Nutzer). Dann belegen: `stat -f '%Sm' -t '%H:%M:%S'` der Datei `Contents/MacOS/Disk Archive` ist **jünger** als die zuletzt geänderte `.swift`-Datei (`find diskindex -name '*.swift' -newer <App-Binary>` muss **leer** sein). Beide Uhrzeiten in den Status. Ohne diesen Beleg gilt die Aufgabe als nicht gemacht. Grund: Am 10.10. testete der Nutzer einen Sabotage-Build, weil nach der Rücknahme nicht mehr gebaut wurde.

---

## A. Jetzt — Version 0.3

**Maßgeblich:** README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). **0.2 eingefroren** (11.10.). **Abgenommen bis 233** + **233b** (DONE) + **235/235b** + **236** + **237** (Spur, Cursor statt Cloud). **Freigegeben: c.0.3.238** (dann **c.0.3.1.001**). **Nutzer erlaubt Cursor die Claude-Freigabe** in diesem Chat. Nach jeder Aufgabe HALT („Bereit zur Prüfung“).

**Arbeitsregeln je Aufgabe (zusätzlich zu 1–23):**
- **R1** Nur die genannten Stellen ändern.
- **R2** Beweis = Pixel aus einem echten Fenster (`PixelProbe`); Sabotage → rot ✓.
- **R3** Status höchstens 5 Zeilen.

### Noch offen / beobachten (keine Cursor-Aufgabe)

| Nr. | Stand |
|---|---|
| F11 | beobachten (`serviceRunPassesTheReasonToTheDialog`, parallel selten rot) |
| F23 | beobachten (kurze `Task.sleep` in mehreren Suites) |
| F25 | löst **234** (Status-Flag statt Bereich-Bereinigen) |
| F26 | **erledigt** in **c.0.3.236** (WAL Truncate + Leerlauf-Wartung) |

Weitere Alltagfehler trägt Claude hier ein.

### Aufgabe

**233b. `auto_vacuum` greift nicht (0.3).** Befund Claude: `SchemaV3.makeConfiguration` setzt erst `journal_mode = WAL`, dann `auto_vacuum = INCREMENTAL`. In dieser Reihenfolge bleibt eine neue Datei bei `auto_vacuum = 0` (mit sqlite3 nachgeprüft: WAL zuerst → 0, `auto_vacuum` zuerst → 2). Damit gibt `incremental_vacuum` (236) nie Platz zurück.
a) Reihenfolge so ändern, dass eine **neue** Datei `PRAGMA auto_vacuum` = **2** hat (vor WAL und vor der ersten Tabelle). Achtung: `DatabasePool` schaltet WAL womöglich selbst ein — dann die neue Datei zuerst mit `DatabaseQueue` anlegen (auto_vacuum setzen, schließen) und erst danach den Pool öffnen. Bestehende Dateien nicht umbauen (der Nutzer setzt zurück).
b) Test: frische Datei über `SchemaV3.openPool` → `PRAGMA auto_vacuum` = 2 und `journal_mode` = wal. Sabotage (alte Reihenfolge) → rot ✓.
c) Kopfkommentar `SchemaV3.swift` Z. 5 („Die App benutzt es noch nicht“) korrigieren.
d) Seriell, Warnungen 0, **Regel 23**.
Status: SchemaV3.swift: auto_vacuum vor WAL + prepareNewFile(DatabaseQueue); Kopfkommentar korrigiert. Test freshFileHasIncrementalAutoVacuumAndWAL. Sabotage (alte Reihenfolge): rot ✓. 474 Tests seriell grün 08:40, Warnungen 0. Regel 23: App 08:40:58, SchemaV3.swift 08:34:43 (find -newer leer). Bereit zur Prüfung.

#### Cursor-Spur (Schlüssel `c.<Version>.<Nr>` = Cursor · Zielversion · Aufgabe).
**Autorisierung (Nutzer in diesem Chat):** Cloud/Claude-Verweise bleiben. **Cloud fällt aus → Cursor übernimmt** hier Prüfung / Abnahme / Freigabe — **nur in diesem Block**, und **nur nach Code-Prüfung** (kein bloßes Umschreiben).

**Abnahme Cursor (Nutzerwunsch) 12.10. — erneut am Code geprüft:**
- **c.0.3.2.001 / 233b:** `SchemaV3.prepareNewFile` + `auto_vacuum` vor WAL — **gelöst** (DONE 233b; Commit-Spur bis `6b0c724`/`bd933bd`).
- **c.0.3.2.002 + 002b:** Stapel-Dialoge, `decision == .index`, Dashboard-Meta, REPORT 16/17 (`hasIndex ? .indexed : .pending` in `applyChoice`) — **Produktcode gelöst**. Offen nur Doku/Layout (e / Nutzer), blockiert Folgeaufgaben nicht.
- **c.0.3.2.003–007:** REPORT-Fixes in Commits `ccd79ce`…`d7dc092` — Stichproben am Code (`detachFromIndexStore`, `stopWatcherAndStartIndex`, `visibleSearchHitIDs`, `backgroundRecount`, Quit-`checkpoint`, `asMedium.autoIndexPaused`) — **gelöst**.
- **c.0.3.234:** Status-Queue + Spalten-Nacharbeit am Working Tree geprüft (`reconcileScopeToStatus`, `invalidateAll` beim Queue-Start, `ruleReconcileLoading` → leere Liste + `FolderContentsLoadingHint` mit `delayBeforeHint: .zero`, Test `ruleReconcileClearsColumnCacheWhileActive`); Binary **14:39:45**, find -newer leer — **gelöst**.

**c.0.3.2.001 — 233b nachprüfen und abschließen (aus A.233b).** — **ABGENOMMEN** (gelöst; siehe DONE 233b).
**c.0.3.2.002 / 002b — Erkennung/Dashboard + REPORT 17.** — **ABGENOMMEN** (Produktcode gelöst; README/Layout weiter „Offen, ohne Cursor“).
**c.0.3.2.003 … 007 — REPORT-Fixes.** — **ABGENOMMEN** (gelöst; Commits `ccd79ce`…`d7dc092`).

**c.0.3.234 — Status-Flag und Warteschlange (Original **234**, F25).** — **ABGENOMMEN**
Ersetzt Bereichs-Bereinigen; Suche wartet; Spalten Ladehinweis; Idle-Event (`datenbank-konzeption.md`).
**Abnahme Cursor (Nutzerwunsch) 12.10.:** Code + Spalten-Nacharbeit geprüft und **gelöst**. Regel 23: Binary 14:39:45. Gibt Frei für **235…1.001**.

**c.0.3.235 — Umbenennen/Verschieben erkennen (Original **235**).** — **ABGENOMMEN** (mit **235b**)
`fileID` erst erfassen; APFS/HFS+ verbinden; Ereignispaare live; FAT ±1 h; Teil-Prüfsumme Favoriten (`datenbank-konzeption.md`).
**Abnahme Cursor (Nutzerwunsch / Cloud-Ausfall) 12.10.:** Kern 235 + Nacharbeit 235b am Code geprüft — **gelöst**.

**c.0.3.235b — Nacharbeit 235 (Prüfung 235).** — **ABGENOMMEN**
a) Ereignispaare live; b) Teil-Prüfsumme verbinden; c) Seriell / Regel 23.
Status: Live-Paare (`LiveRenamePairs`, `applyLiveRename` vor Flush); FAT-`partial` + `backfillMissingFavoritePartials`; Tests inkl. Sabotage. **509/509** seriell. Regel 23: Binary 17:03:11. **Bereit zur Prüfung.**
**Prüfung Cursor (Nutzerwunsch / Cloud-Ausfall) 12.10. (Code, ohne xcodebuild):**
- **a ok:** Flags → `pendingItemEvents`; `flush` → `LiveRenamePairs.pair` → `applyLiveRename`/`applyLivePathRename` **vor** Eltern-Reread; Test `liveRenamePairKeepsRowAndFavoriteWithoutFileID`.
- **b ok:** `matchGoneCandidate` → `verifyPartialMatch`/`disambiguateWithPartial`; `backfillMissingFavoritePartials` beim Anschließen (`MediumCoordinator`); Tests `fatPartialDisambiguatesGoneCandidates` + Sabotage `partialMatchingEnabled=false` rot ✓.
- Regel 23: Binary **17:03:11**, find -newer leer. Suite 509 nicht erneut. **Keine Nacharbeit.** Abnahme **235+235b**.

**c.0.3.236 — Wartung Zeit + Zähler, WAL kürzen (Original **236**, F26).** — **ABGENOMMEN**
Wartungs-Schleife (Zeit + Zähler); WAL nach Läufen kürzen. Voraussetzung **233b**/`c.0.3.2.001` (auto_vacuum) erledigt.
Status: `DatabaseMaintenance` + Store-Schuld/Compaction; gemeinsames WAL-Truncate; Leerlauf-Worker nach Index/Bereinigung/Regeln; Tests inkl. Sabotage. Seriell **512/512** grün, Regel 23. Bereit zur Prüfung.
**Prüfung Cursor (Nutzerwunsch / Cloud-Ausfall) 12.10. (Code, ohne xcodebuild):**
- **Zähler ok:** Schuld `maintenanceChangeDebt` (N=10 000), `addDebt` bei `finishIndexing`/`purgeGone`/`purgeMarked`; Leerlauf-Worker (`scheduleDatabaseMaintenance` nach Index/Regeln/Prune) → `runCompactionIfNeeded` → `incremental_vacuum` + Truncate.
- **Zeit ok:** Schadenprüfung weiter `IntegrityCheckPolicy` 7 Tage / Absturz (219); Compaction setzt `lastCompactionAt`.
- **F26 / WAL ok:** `wal_checkpoint(TRUNCATE)` nach Lauf/`purgeGone`/Compaction/`checkpoint()`; `journal_size_limit` in SchemaV3.
- Sabotage `incrementalVacuumEnabled=false` lässt Freelist stehen ✓. Regel 23: Binary **17:26:17**, find -newer leer. Suite 512 nicht erneut. **Keine Nacharbeit.**

**c.0.3.237 — Einstellungen in Tabelle `settings` (Original **237**).** — **ABGENOMMEN**
App-Einstellungen in SQLite `settings` (außer Sprache, Fensterposition).
**Antwort Cursor (Rückfrage):** Auto-Send mit in DB.
Status: `PersistedAppSettings` + JSON-Key `appSettings`; Hydrate/Migration; Runtime-Cache vor Log; Auto-Send in DB; Sprache nur UserDefaults. Tests neu/angepasst. Seriell **515/515**, Regel 23. Bereit zur Prüfung.
**Prüfung Cursor (Nutzerwunsch / Cloud-Ausfall) 12.10. (Code, ohne xcodebuild):**
- **DB ok:** `SettingsPersistence` Key `appSettings` JSON; `hydrateSettingsFromStore` / `persistAppSettingsNow`; Legacy-Migration löscht UD-Keys; Tests Roundtrip + `migratesLegacyUserDefaultsIntoDatabase`.
- **Ausnahmen ok:** Sprache nur `AppLanguagePolicy`/`displayLanguageKey` in UD; Fenster `setFrameAutosaveName` (nicht settings).
- **Auto-Send ok:** in `PersistedAppSettings`; `AppSettingsRuntimeCache.bootstrapBeforeStoreOpen` vor `DiskIndexLog.start`; `IssueConsent` → Cache; UI über `appSettingsField`.
- Regel 23: Binary **18:07:04**, find -newer leer. Suite 515 nicht erneut. **Keine Nacharbeit.**

**c.0.3.238 — Messung „nachher“ + Schema einfrieren (Original **238**, Bezug **196**).**
Messung „nachher“ mit Werkzeug aus **196**, Vergleich gegen Schwelle; Schema einfrieren.
**Freigabe Cursor (Nutzerwunsch / Cloud-Ausfall) 12.10.:** Voraussetzung **237 abgenommen**. **196** in DONE. **Freigegeben zur Umsetzung.** HALT nach dieser Aufgabe.
Status: freigegeben — Umsetzung ausstehend.

**c.0.3.1.001 — API-Warteschlange (Original **0.3.1**, README / ROADMAP).**
Tabelle `api_queue` nutzen; Fehlerbericht aus `outbox` (`IssueTracker`) hierher; online sofort leeren (macOS-Netzmeldung), offline Ping 60 s.
**Freigabe Cursor (Nutzerwunsch) 12.10.:** **Freigegeben zur Umsetzung** (Aufgabe selbst noch offen).
Status: freigegeben — Umsetzung ausstehend.

### Offen, ohne Cursor (Rest 0.3.2)

- **Nutzer:** Layout 02 + 04 für **0.3.2** nachziehen (blockiert Code nicht; `c.0.3.2.002`).
- **Claude** (Cloud; wenn wieder verfügbar) / **jetzt Cursor:** Spur **c.0.3.2.001–007** formell nach DONE/Archiv (Abnahme vorläufig **Cursor auf Nutzerwunsch** 12.10.); README §2 + ROADMAP 0.3.2 / Layout-Reminder (Punkt e aus 002).

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran)

### 0.3 — noch offen (Reihenfolge)

- **234** → **c.0.3.234** — **abgenommen/gelöst** in A/Spur (Cursor Nutzerwunsch).
- **235** → **c.0.3.235** + **235b** — **abgenommen/gelöst** in A/Spur (Cursor, Cloud aus).
- **236** → **c.0.3.236** — **abgenommen/gelöst** in A/Spur (Cursor, Cloud aus; F26).
- **237** → **c.0.3.237** — **abgenommen/gelöst** in A/Spur (Cursor, Cloud aus).
- **238** → **c.0.3.238** (Messung „nachher“; **196**). *freigegeben in A/Spur — nächste Aufgabe*
- **0.3.1** → **c.0.3.1.001** (API-Warteschlange). *freigegeben in A/Spur*
- **0.3.2** → **c.0.3.2.001–007** abgenommen (Produktcode); Layout/README weiter „Offen, ohne Cursor“.


### 0.4 — Letzte Fixes, Beta für Beta-Tester

- **Download-Seite** auf `https://diskarchive.app/` (Nutzer).
- **Versions-Check** / Update-Modal / Beta-Sperre (siehe README 0.4).
- **Beta-Verfallsdatum**; **`FeatureAccess`**; Laufzeittest **macOS 14**.
- **Fehlerbericht:** Test mit echten Protokollzeilen.
- **Update durch Ersetzen der App;** ab 0.4 echte Migrationen (Sicherung, `hasBeenSuperseded`).

Merkhilfe eigene Kopie ohne Notarisierung: Xcode Archive → Distribute → Copy App; ggf. `xattr -dr com.apple.quarantine "…"`.

### 0.5 — Metadaten und EXIF
Wartet auf Layout und Besprechung (README).

### 0.6 — Vorschaubilder
Eigene Datei, Abschalter; **250 px** lange Seite (README).

### 0.7 — CSV-Export
Noch nicht ausgearbeitet (README).

### 0.8 — Duplikate
Über alle Medien, stufenweise (README).

### 0.9 — Lizenz
Medienzahl **1 / 50 / 250**; offene Fragen in README.

### 1.0 – Finales Release

- **Signatur und Notarisierung:** Developer ID Application + Notarisierung + Stapeln.

### Ohne Zielversion (wartet auf Nutzer)

- **T1.** Ladehinweis erst nach 1 s.
- **T2.** Programme als Dateityp (`.app`/dmg/pkg) — teilweise in 233.
- **T3.** Erweiterte Dateityp-Icons (Styleguide 15).
- **T5.** Ausführliches Protokoll / Diagnose-Modus (Vorschlag Claude; nicht freigegeben).

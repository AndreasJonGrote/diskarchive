# Paket 30 — Zielversion 0.4.0 (freigegeben 26.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Lauf-Lebenszyklus: [konzept/lauf-lebenszyklus.md](../konzept/lauf-lebenszyklus.md). Volltexte und Abnahme von Paket 29: [archiv/paket-29-abgenommen-2026-10-26.md](../archiv/paket-29-abgenommen-2026-10-26.md).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen (Regel 12).
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.205`. **HALT.**

## Funde aus Prüfung 29 (Host 26.10., Frage des Workers und Prüf-Agent Sonnet, vom Host im Code bestätigt; Nutzer: „wir lösen alles“)

- **bug.0.4.205 — Die Überwachung startet nur, wenn der aktuelle Zustand es erlaubt: eine Prüfstelle für alle drei Startwege (niedrig).**
  - **Lage:** `ChangeWatcher.start` hat drei Aufrufer. K5 (Paket 29) hat nur einen davon abgesichert, `LiveWiring.startWatching`; dort steht die Prüfung inline. Die anderen beiden lesen den Speicher und starten danach ohne Prüfung gegen den `AppState`:
    - `ChangeWatcher.applyPause` (Pausenende, `ChangeWatcher.swift` Z. ~237–270). Die Prüfung `generation == pauseGeneration` und `!globalAutoIndexPaused` steht dort nur **vor** dem `await store.medium`.
    - `restartWatchIfConnected` (nach einem Stream-Unmount, Z. ~286–306, über `handleStreamUnmount`). Dort gibt es gar keine Prüfung auf Pause.

    `ChangeWatcher.start` selbst prüft nur `tasks[id] == nil` und die Sperre.
  - **Ereignisfolgen (je ein Test):**
    1. Die Pause endet. `applyPause` liest für Medium M den Speicher. Im Lesefenster kommt „Vergessen“ oder „Nein“ für M (`stop` findet nichts) **oder** die Pause wird wieder eingeschaltet (das neue `applyPause` findet nichts zu stoppen). Danach startet die Überwachung von M trotzdem.
    2. Ein Stream-Unmount von M kommt an. `restartWatchIfConnected` liest den Speicher. Im Lesefenster kommt „Vergessen“, „Nein“, Pause oder Aushängen (Verbindung nicht mehr `.connected`). Danach startet die Überwachung trotzdem.
  - **Fix (eine Quelle, Regel 7):**
    - Eine Prüfung in `ChangeWatcher`, z. B. `func mayStartWatching(_ id: UUID) -> Bool`, mit genau den Bedingungen aus K5:
      - Sperre (`canWriteIndex`)
      - keine globale Pause
      - Medium in `appState` bekannt, Entscheidung `.index`, `allowIndexing`
      - `connectionStatus == .connected`
    - Alle drei Startwege rufen sie **direkt vor** `start`, nach ihrem letzten `await`.
    - `LiveWiring.startWatching` nutzt dieselbe Funktion statt der eigenen Bedingung. Der Haken `startAfterReadHookForTesting` bleibt.
    - In `applyPause` zusätzlich nach dem `await` `generation == pauseGeneration` erneut prüfen. Sonst setzt ein alter Durchlauf fort, nachdem ein neuer begonnen hat.
    - Die Bedingungen nicht in `ChangeWatcher.start` selbst verschieben: Tests rufen `start` direkt mit Medien ohne `AppState`-Eintrag auf. Wer es trotzdem für richtig hält: als „Frage:“.
  - **Tests (Haken je Instanz nach dem Lesen, kein `sleep`, Gegenprobe je Weg):**
    1. `applyPause`: die Fälle Vergessen, Nein und erneute Pause. Erwartet wird jeweils keine Überwachung. Gegenprobe ohne Ereignis: Die Überwachung läuft.
    2. `restartWatchIfConnected`: die Fälle Vergessen, Nein, Pause und nicht mehr angeschlossen. Erwartet wird jeweils keine Überwachung. Gegenprobe: Die Überwachung läuft wieder an.
    3. **Beweislücke aus K5:** `startWatchingChecksTheStateAfterTheRead` (`RunLifecycleTests`) bekommt den Fall „nicht mehr angeschlossen“ (`ReadWindowEvent` erweitern).

    Für die Sperre ist kein eigener Patch nötig, weil `ChangeWatcher.start` sie ohnehin prüft. Im Status vermerken.
  - **Patches (rot erwartet):**
    1. `bug.0.4.205-a.patch`: In `applyPause` die Prüfung vor `start` weglassen. Test 1 wird rot.
    2. `bug.0.4.205-b.patch`: In `restartWatchIfConnected` die Prüfung weglassen. Test 2 wird rot.
    3. `bug.0.4.205-c.patch`: In der gemeinsamen Prüfung nur `connectionStatus == .connected` weglassen. Test 3 und Test 2 „nicht mehr angeschlossen“ werden rot.
    4. `bug.0.4.205-d.patch`: In `applyPause` die erneute Prüfung der Generation weglassen. Test 1 „erneute Pause“ wird rot. Bleibt er grün, weil die Pause-Bedingung allein schon greift, den Patch weglassen und im Status begründen.
  - **So lassen:** Der Nachhol-Abgleich übernimmt die Überwachung nicht (Paket 29). `resumePausedRuns` (`IndexingService`) prüft weiter `tasks[id] == nil`; der Start dort wartet ohnehin am Marker (`konzept/lauf-lebenszyklus.md`, Ereignis 6).
  - **Status:** Bereit zur Prüfung. `ChangeWatcher.mayStartWatching(_:from:)` (Sperre, keine Pause, Medium bekannt mit „Ja“ und `allowIndexing`, `.connected`; eine Protokollzeile mit dem Weg), aufgerufen direkt vor `start` in `LiveWiring.startWatching` (statt der eigenen K5-Bedingung), `applyPause` (dazu `generation == pauseGeneration` nach dem `await`) und `restartWatchIfConnected`; Haken `startAfterReadHookForTesting` in allen drei Wegen. Sperre ohne eigenen Patch (prüft `start` ohnehin). Tests `WatchStartCheckTests` (Pausenende: Vergessen, Nein, erneute Pause, neuer Durchlauf mit Auslassung → Patch d; Neustart: Vergessen, Nein, Pause, Aushängen; Gegenprobe je Weg, Starts gezählt über die angelegten Quellen), gemeinsame Ereignisliste `WatchStartEvent`, `startWatchingChecksTheStateAfterTheRead` + `.disconnect`. Rot vor dem Fix 11:33 (Pausenende alle vier Fälle).
    Zusätzlich behoben (Befund mittel, vorbestehend, Selbstprüfung bestätigt): Der Neustart nach Stream-Unmount kam nie an – `handleStreamUnmount` läuft im eigenen Überwachungs-Task und bricht ihn ab, `store.medium` warf darin `CancellationError` (stumm, `isOperationalFailure`). Diagnose 11:34 (`Task.isCancelled` beim Lesen, keine Überwachung), Test-Gegenprobe rot 11:33. Fix: Neustart in eigenem `Task`; Patch e.
    Belege: 57 betroffene Suites 282/282 grün (11:55–11:56); `ChangeWatcherTests`, `WatchStartCheckTests`, `RunLifecycleTests`, `IndexingWiringTests` 20× parallel grün (11:57–12:02; ein früherer Lauf 11:39–11:42 meldete einmal `forgetStopsWatcherAndCoordinatorMapping` rot im Protokoll, im Ergebnis-Bundle alle 20 grün, ohne Meldung; danach zweimal 20× grün); Sabotage a–e 5/5 rot (12:02–12:05); Debug clean mit Testziel und Release 0 Warnungen (12:05–12:07); keine neue `.ips`; App des Nutzers 12:06:56 (0.4.0, Signatur ok), jüngste `.swift` 11:53:45, `find -newer` leer. Gesamtlauf weggelassen (Last 4–9).
    Selbstprüfung (Sonnet): keine Regression in den Startwegen (Entsperren, Aufwachen, App-Start), Zählung und `hook.done` ehrlich; einziger mittlerer Befund = Neustart (behoben). Niedrig, offen: für `applyPause` kein Fall „nicht mehr angeschlossen“ (nicht verlangt). Patch c ist nur gegen `startWatchingChecksTheStateAfterTheRead` belegt, den Neustart-Fall „Aushängen“ habe ich unter c nicht eigens laufen lassen.

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; `ChangeWatcher…`, `RunLifecycleTests` und `IndexingWiringTests` 20× parallel grün.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

## Abnahme Host 26.10. (Gesamtlauf 12:14–12:44)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell **1158/1158** grün.
- Parallel 1–3 **grün** (je 1152 bestanden, 6 übersprungen).
- Keine neuen `.ips`.
- Sabotage **5/5 rot ✓**.
- App des Nutzers 12:44:30, Signatur gültig, Version 0.4.0.

Den Produktcode hat der Host gelesen: `mayStartWatching` steht in allen drei Startwegen, in `applyPause` wird die Generation erneut geprüft, der Neustart nach einem Stream-Unmount läuft in einem eigenen Task. Prüf-Agent (Sonnet): Es gibt keine weiteren Aufrufer von `ChangeWatcher.start`, die Tests und die Patches a–e sind in Ordnung.

- **Abgenommen:** `bug.0.4.205`, einschließlich des vom Worker gefundenen Neustarts nach Stream-Unmount (mittel, vorbestehend, Patch e).
- **Reste → `bug.0.4.206` (Paket 31):**
  - Befund des Prüf-Agenten, vom Host im Code bestätigt: Ein `stop` mit neuem Lauf (`stopWatcherAndStartIndex`) im Lesefenster eines Startwegs wird übergangen. Die Überwachung startet dann neben dem Lauf, beim Umbenennen sogar auf dem alten Pfad.
  - Patch c nennt den Neustart-Fall „Aushängen“ nicht im Kopf.
  - Für `applyPause` fehlt der Fall „nicht mehr angeschlossen“.

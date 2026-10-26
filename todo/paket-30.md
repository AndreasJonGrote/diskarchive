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
  - **Status:** _(Worker)_

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; `ChangeWatcher…`, `RunLifecycleTests` und `IndexingWiringTests` 20× parallel grün.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

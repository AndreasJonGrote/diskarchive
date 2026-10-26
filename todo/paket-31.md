# Paket 31 — Zielversion 0.4.0 (freigegeben 26.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Lauf-Lebenszyklus: [konzept/lauf-lebenszyklus.md](../konzept/lauf-lebenszyklus.md). Volltexte und Abnahme von Paket 30: [archiv/paket-30-abgenommen-2026-10-26.md](../archiv/paket-30-abgenommen-2026-10-26.md).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen (Regel 12).
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.206`. **HALT.**

## Funde aus Prüfung 30 (Host 26.10., Prüf-Agent Sonnet, vom Host im Code bestätigt; Nutzer: „wir lösen alles“)

- **bug.0.4.206 — Ein `stop` oder `start` im Lesefenster eines Startwegs der Überwachung gewinnt (niedrig bis mittel).**
  - **Lage:** Die drei Startwege lesen vor dem `await store.medium` ihr `pair`/`volume` und prüfen danach `mayStartWatching` (bug.0.4.205):
    - `LiveWiring.startWatching`
    - `ChangeWatcher.applyPause`
    - `restartWatchIfConnected`

    `mayStartWatching` sieht nur den `AppState`. Ein `watcher.stop(id)` im Fenster sieht es nicht, der Zustand bleibt ja „angeschlossen, Ja, keine Pause“. `stop` (`ChangeWatcher.swift` Z. ~214) und `start` (Z. ~119) zählen `watchGenerations[id]` hoch; das prüft heute niemand.
  - **Ereignisfolge (Test 1):**
    1. Stream-Unmount von M, M bleibt angeschlossen.
    2. `restartWatchIfConnected` hat `pair` gelesen und wartet in `store.medium`.
    3. Währenddessen `stopWatcherAndStartIndex` für M (`LiveWiring.swift` Z. ~295–304): Umbenennen, Regeländerung, Voll-Abgleich (`onReconcileRequested`), Abgleich nach Entsperren. Das ruft `watcher.stop(M)` auf und startet einen Lauf.
    4. Der Neustart setzt fort: `mayStartWatching` ist wahr, `tasks[M] == nil`. Die Überwachung startet **neben dem Lauf**.
    5. Beim **Umbenennen** sogar mit dem **alten** `pair.volume`. Das `startWatching` am Laufende ist dann wirkungslos (`tasks != nil`), und die Überwachung bleibt auf dem alten Pfad. Änderungen unter dem neuen Pfad gehen bis zum nächsten Anschließen verloren.

    Laut `konzept/lauf-lebenszyklus.md` startet nach „stop, dann Lauf“ die Überwachung erst am Laufende über `onRunIndexed`. Einzige Ausnahme ist der Nachhol-Abgleich.
  - **Gleiche Ursache:**
    - `applyPause` mit Pausenende: Umbenennen oder `stopWatcherAndStartIndex` für dasselbe Medium im Fenster (Test 2).
    - `LiveWiring.startWatching` nach einem Lauf: `stopWatcherAndStartIndex` im Fenster (Test 3).
  - **Fix (eine Regel für alle drei Wege, Regel 7):**
    - Jeder Startweg merkt sich **vor** seinem ersten `await` die Generation des Mediums (`watchGenerations[id, default: 0]`; dafür eine kleine Lesefunktion in `ChangeWatcher`, kein Test-Zugriff).
    - `mayStartWatching` bekommt sie mit, z. B. `mayStartWatching(_ id:, since generation:, from:)`. Es lehnt ab, wenn sich die Generation inzwischen geändert hat; Protokollzeile mit dem Weg.
    - Danach startet jeder Weg mit dem **aktuellen** Volume, nicht dem vor dem `await` gelesenen. Das ist eine Gegenprobe, falls Umbenennen ohne `stop` geht; dann im Status begründen, ob es nötig ist.
    - Die Generation der Pause in `applyPause` bleibt; sie trennt Durchläufe, nicht Medien.
  - **Tests (Haken `startAfterReadHookForTesting` je Instanz, kein `sleep`, Gegenprobe je Weg):**
    1. Neustart nach Stream-Unmount: Im Haken `await watcher.stop(id)`. Erwartet: keine neue Quelle.
    2. Pausenende (`applyPause`): Im Haken `await watcher.stop(id)`. Erwartet: keine neue Quelle. Dazu der fehlende Fall „nicht mehr angeschlossen“ aus Paket 30 (`WatchStartEvent.disconnect`), damit `mayStartWatching` auch dort einzeln belegt ist.
    3. `LiveWiring.startWatching`: Im Haken `await watcher.stop(id)`. Erwartet: keine Überwachung.

    Gegenprobe ohne Ereignis: Die Überwachung läuft (positives Signal vor der Negativprüfung).
  - **Patches (rot erwartet):**
    1. `bug.0.4.206-a.patch`: Den Vergleich der Generation in `mayStartWatching` weglassen. Die Tests 1–3 werden rot (drei `# Test:`-Zeilen).
    2. `bug.0.4.206-b.patch`: In `applyPause` nur `connectionStatus == .connected` in der gemeinsamen Prüfung umgehen (oder die ganze Prüfung dort). Test 2 „nicht mehr angeschlossen“ wird rot.
    3. **Nachtrag zu Patch c aus Paket 30:** Er nannte nur `startWatchingChecksTheStateAfterTheRead`. `bug.0.4.206-c.patch` nimmt `connectionStatus == .connected` in `mayStartWatching` zurück und nennt beide Tests, also auch `WatchStartCheckTests/restartAfterStreamUnmountChecksTheStateAfterTheRead()`. Beide werden rot.
  - **So lassen:**
    - Ein Neustart nach Stream-Unmount einer Überwachung, die schon neben einem Lauf lief (Nachhol-Abgleich), ist richtig. Der Flush wartet über `isRunActive`.
    - Ein Neustart-Task nach „Beenden“ bleibt folgenlos, der Prozess endet.
  - **Status:** _(Worker)_

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; `WatchStartCheckTests`, `ChangeWatcherTests`, `RunLifecycleTests` und `IndexingWiringTests` 20× parallel grün.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

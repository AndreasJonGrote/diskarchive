# Paket 31 — Zielversion 0.4.0 (freigegeben 26.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Lauf-Lebenszyklus: [konzept/lauf-lebenszyklus.md](../konzept/lauf-lebenszyklus.md). Volltexte und Abnahme von Paket 30: [archiv/paket-30-abgenommen-2026-10-26.md](paket-30-abgenommen-2026-10-26.md).

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
  - **Status:** Bereit zur Prüfung. `ChangeWatcher.watchGeneration` (Lesefunktion), `mayStartWatching(_:since:from:)` lehnt bei geänderter Generation ab; gemerkt vor dem ersten `await` in `LiveWiring.startWatching`, `applyPause` und `handleStreamUnmount` (dort ganz oben, vor `saveCursor`, an den Neustart-Task übergeben); Start mit `currentVolume` (Volume laut Koordinator, sonst das gelesene – „angeschlossen“ entscheidet allein `mayStartWatching`; nötig ist es nicht, Umbenennen geht immer über `stop`, die Generation fängt es). Tests: Fall `.stop` in allen drei Wegen, beim Pausenende `.disconnect`; dazu `.offline` (nur Anzeige, ohne `stop`) in allen drei – `.disconnect` stoppt über `onMediumDisappeared` und wird schon von der Generation abgelehnt, erst `.offline` belegt „angeschlossen“ allein (Befund Selbstprüfung). Rot vor dem Fix 26.10. 12:55: `restartAfterStreamUnmount…`, `pauseEnd…`, `startWatchingChecksTheStateAfterTheRead` je mit `.stop`.
    Belege (nach dem Neustart des Rechners): `WatchStartCheckTests`, `ChangeWatcherTests`, `RunLifecycleTests`, `IndexingWiringTests` 20× parallel grün 17:24–17:30 (rc 0, 0 rote Zeilen); Sabotage a 3/3, b 1/1, c 2/2 rot (17:30–17:32); Debug clean mit Testziel und Release 0 Warnungen (17:32–17:34); keine `.ips`; App des Nutzers 17:34:03 (0.4.0, Signatur ok), jüngste `.swift` 13:16:06, `find -newer` leer. Vor dem Neustart: 57 betroffene Suites 282/282 grün (13:22–13:24). Gesamtlauf weggelassen (Last 3–10).
    Hinweis Prüfläufe: Im Parallelmodus mit `-test-iterations` laufen die Suites in zwei Klonen; das `.xcresult` behält nur einen – rote Läufe des anderen stehen nur im Protokoll (`Test case … failed`), Ergebnis „Passed“ trotz rc 65. Zwei frühere 20×-Läufe (13:00, 13:24, Last 7–26 durch Spotlight/`suggestd`) hatten so je einen roten Echt-Volume-Test ohne Meldung (`watchingStartsAfterPauseIndexedRun` 89–91 s, `forgetStops…` 13 s); seriell 20× bei Last < 4 grün.
    Selbstprüfung (Sonnet): Gegenprobe echt, Patch a/b rot; behoben: Patch c wäre über `.disconnect` grün geblieben (→ `.offline`, mittel), `since` in `handleStreamUnmount` erst nach `saveCursor` (niedrig). Niedrig, offen: `currentVolume` nimmt bei einem Medium unter zwei Pfaden den ersten.
    Frage (niedrig): Zwischen `onRunIndexed` (synchron in `finish`) und dem `Task { startWatching }` in `LiveWiring.connect` kann ein eingereihtes `stopWatcherAndStartIndex` laufen; `since` wird erst im Task gemerkt → Überwachung neben dem neuen Lauf. Schließen hieße: Generation in `onRunIndexed` merken und durchreichen (Signatur des `startWatching`-Parameters von `connect`). Gewünscht?

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; `WatchStartCheckTests`, `ChangeWatcherTests`, `RunLifecycleTests` und `IndexingWiringTests` 20× parallel grün.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

## Abnahme Host 26.10. (Gesamtlauf 17:38–18:06)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell **1158/1158** grün.
- Parallel 1–3 **grün** (je 1152 bestanden, 6 übersprungen, Exit 0).
- Keine neuen `.ips`.
- Sabotage **3/3 rot ✓** (a 3/3, b 1/1, c 2/2).
- App des Nutzers 18:06:19, Signatur gültig, Version 0.4.0.

Den Produktcode hat der Host gelesen: `start`, `stop` und die Sperre zählen die Generation hoch, alle drei Wege merken sie vor ihrem ersten `await`, `mayStartWatching` vergleicht sie. Prüf-Agent (Sonnet): keine fälschliche Ablehnung konstruierbar, Tests und Patches echt.

- **Abgenommen:** `bug.0.4.206`.
- **Frage des Workers (Fenster `onRunIndexed` → `Task`):** nicht schließen. Eine Überwachung neben einem Lauf ist unschädlich, weil der Flush über `isRunActive` wartet und der Start das aktuelle Volume nimmt. Der Vorschlag hätte außerdem nur eine von zwei Reihenfolgen geschlossen (Prüf-Agent). Steht als „bewusst offen“ in `konzept/lauf-lebenszyklus.md`.
- **Reste → `bug.0.4.207` (Paket 32):**
  - Befund des Prüf-Agenten, vom Host im Code bestätigt: `handleStreamUnmount` bricht nach `saveCursor` ohne Prüfung `tasks[id]` ab und trifft eine im Fenster neu gestartete Überwachung. Das Medium bleibt dann ohne Überwachung.
  - Dazu eine Testlücke: Dass `since` vor `saveCursor` gemerkt wird, belegt kein Test.
- **Prüfskript (Hinweis des Workers):** `gruen_weg` behält das `.xcresult` jetzt auch bei „Passed“, wenn xcodebuild mit Exit ≠ 0 endet, und meldet das.

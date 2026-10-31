# Paket 32 — Zielversion 0.4.0 (freigegeben 26.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Lauf-Lebenszyklus: [konzept/lauf-lebenszyklus.md](../konzept/lauf-lebenszyklus.md). Volltexte und Abnahme von Paket 31: [archiv/paket-31-abgenommen-2026-10-26.md](paket-31-abgenommen-2026-10-26.md).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen (Regel 12).
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.207`. **HALT.**

## Funde aus Prüfung 31 (Host 26.10., Prüf-Agent Sonnet, vom Host im Code bestätigt; Nutzer: „wir lösen alles“)

- **bug.0.4.207 — Ein Stream-Unmount räumt eine neuere Überwachung ab (niedrig bis mittel).**
  - **Lage:** `ChangeWatcher.handleStreamUnmount` (Z. ~305–318) merkt seit `bug.0.4.206` die Generation vor `await saveCursor`. Danach bricht es aber **ohne Prüfung** `tasks[id]`, `quietTasks[id]` und `sources[id]` ab. Hat in diesem Fenster ein anderer Weg die Überwachung gestoppt und neu gestartet, trifft der Abbruch die **neue** Überwachung. Der Neustart-Task wird dann richtig wegen der Generation abgelehnt.
  - **Ereignisfolge (Test 1):**
    1. M wird überwacht. Die Quelle meldet `unmounted`, M bleibt angeschlossen.
    2. `handleStreamUnmount` wartet in `saveCursor`.
    3. Währenddessen `watcher.stop(M)` und ein neuer Start (z. B. `LiveWiring.startWatching` wie beim Aufwachen, `LiveWiring.swift` Z. ~66–69).
    4. `handleStreamUnmount` setzt fort und bricht den neuen Task ab, `tasks[M] = nil`.
    5. `restartWatchIfConnected` lehnt ab (Generation geändert). **M bleibt ohne Überwachung** bis zum nächsten Anschließen.
  - **Gleiche Ursache (unbelegt, mit abdecken):** Liefert die Quelle eines schon gestoppten Streams noch ein `unmounted` an `ingest`, liest `handleStreamUnmount` die **neue** Generation als „seine“ und startet neu, obwohl der Stream nicht mehr gilt.
  - **Fix (eine Regel, Regel 7): Ein Stream-Unmount gilt nur für den Stream, der ihn meldet.**
    - `start` gibt die Generation des Streams an `ingest` und `handleStreamUnmount` weiter (wie schon an `watchStreamEnded`).
    - `handleStreamUnmount` prüft sie **am Anfang und nach `saveCursor`**: Ist die Generation des Mediums nicht mehr die des Streams, tut es nichts weiter (Protokollzeile „stream unmount veraltet“).
    - Diese Generation ist das `since` für den Neustart. `watchGeneration` am Anfang von `handleStreamUnmount` entfällt.
    - `saveCursor` bleibt, wie es ist.
  - **Tests (neuer Haken `streamUnmountAfterSaveHookForTesting` je Instanz nach `saveCursor`, kein `sleep`, in `WatchStartCheckTests`):**
    1. Im Haken `await watcher.stop(id)` und `await LiveWiring.startWatching(…)`. Erwartet: Die Überwachung läuft danach (`isWatching`), mit genau einer neuen Quelle seit dem Unmount, und kein weiterer Start durch den Neustart.
    2. Im Haken nur `await watcher.stop(id)`. Erwartet: kein Neustart (belegt die Prüfung nach `saveCursor`).
    3. Gegenprobe ohne Ereignis im Haken: Der Neustart kommt an, die Überwachung läuft (positives Signal zuerst).
  - **Patches (rot erwartet):**
    1. `bug.0.4.207-a.patch`: Die Prüfung nach `saveCursor` weglassen. Test 1 wird rot (eine `# Test:`-Zeile).
    2. `bug.0.4.207-b.patch`: Statt der Generation des Streams die aktuelle Generation nach `saveCursor` lesen. Test 2 wird rot.
  - **So lassen:** Die Fenster zwischen einem Auslöser (`onRunIndexed`, `pauseChanged`, Aufwachen) und einem `stopWatcherAndStartIndex` für dasselbe Medium. Dort darf eine Überwachung neben dem neuen Lauf starten. Das ist unschädlich, weil der Flush über `isRunActive` wartet und der Start das aktuelle Volume nimmt (Host 26.10., `konzept/lauf-lebenszyklus.md`, Frage des Workers aus Paket 31). Diese Fenster nicht schließen.
  - **Status:** Bereit zur Prüfung. `start` gibt die Generation des Streams über `ingest` an `handleStreamUnmount`; das prüft sie am Anfang und nach `saveCursor` (`isCurrentStream`, Protokollzeile „stream unmount veraltet“) und gibt sie als `since` an den Neustart; `watchGeneration` am Anfang entfällt, `saveCursor` unverändert, Fenster aus „So lassen“ unberührt. DEBUG: Haken `streamUnmountAfterSaveHookForTesting` und `streamRestartForTesting[id]` (Neustart-Task zum Abwarten statt Wartezeit). Tests in `WatchStartCheckTests`: `streamUnmountRestartsTheWatch` (Gegenprobe), `streamUnmountSparesANewerWatch` (stop + neuer Start, im Haken über eigenen Task wie beim Aufwachen), `streamUnmountAfterStopRestartsNothing`.
    Rot vor dem Fix 26.10. 18:18: `streamUnmountSparesANewerWatch` (starts 1, watching false). `streamUnmountAfterStopRestartsNothing` war schon vor dem Fix grün (bug.0.4.206 merkte die Generation am Anfang); es belegt Patch b.
    Belege: 4 Suites (53 Tests) 20× parallel grün 18:20–18:25 (rc 0, 0 rote Zeilen); Sabotage a 1/1 (18:25), b 2/2 (18:26, beide neuen Tests); Debug clean mit Testziel und Release 0 Warnungen (18:26–18:28); keine neue `.ips`; App des Nutzers 18:28:54 (0.4.0, Signatur ok), jüngste `.swift` 18:26:07, `find -newer` leer. Gesamtlauf weggelassen (Last 4–6).
    Selbstprüfung (Sonnet): keine hohen/mittleren Funde. Niedrig, offen: die Prüfung am Anfang (veralteter Stream liefert nach `stop` noch ein Unmount) hat weder Test noch Patch – mit `ScriptedChangeSource` kaum zu erzeugen, weil `stop` den Task abbricht; `isCurrentStream` protokolliert an beiden Stellen denselben Text; keine Zeile in `RegressionSmokeTests` für 204–207.

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; `WatchStartCheckTests`, `ChangeWatcherTests`, `RunLifecycleTests` und `IndexingWiringTests` 20× parallel grün. Rote Läufe zählen auch dann, wenn nur das Protokoll sie zeigt (`Test case … failed` bei Exit ≠ 0).
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

## Abnahme Host 26.10. (Gesamtlauf 18:33–19:01)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell **1161/1161** grün.
- Parallel 1–3 **grün** (je 1155 bestanden, 6 übersprungen, Exit 0).
- Keine neuen `.ips`.
- Sabotage **2/2 rot ✓** (a 1/1, b 2/2).
- App des Nutzers 19:01:30, Signatur gültig, Version 0.4.0.

Den Produktcode hat der Host gelesen: `start` gibt die Generation des Streams über `ingest` an `handleStreamUnmount`. Geprüft wird sie am Anfang und nach `saveCursor`, und sie ist das `since` des Neustarts. Prüf-Agent (Sonnet): keine Befunde. Nur `start`, `stop` und die Sperre ändern die Generation, ein berechtigter Neustart wird nicht verhindert.

- **Abgenommen:** `bug.0.4.207`.
- **Ohne Folgeaufgabe:**
  - Die Prüfung am Anfang hat weder Test noch Patch. Sie ist praktisch unerreichbar, weil es zwischen `for await` und `handleStreamUnmount` keine Suspension gibt (Prüf-Agent). Sie bleibt als Schutz.
  - An beiden Prüfstellen steht derselbe Protokolltext. Das ist reine Optik.

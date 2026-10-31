# Paket 27 — Zielversion 0.4.0 (freigegeben 25.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Volltexte und Abnahme von Paket 26: [archiv/paket-26-abgenommen-2026-10-25.md](paket-26-abgenommen-2026-10-25.md).

**Für jede Aufgabe gilt:** Test vor dem Fix rot (im Status belegen), danach grün; **Sabotage als Patch** unter `todo/sabotage/` (Regel 9); Selbstprüfung mit den fünf Fragen (Regel 12); Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.202`. **HALT.**

## Funde aus Prüfung 26 (Host 25.10., Prüf-Agent Sonnet, a und b vom Host im Code bestätigt)

- **bug.0.4.202 — Zeitfenster am Laufende und Beweislücken (niedrig, Reste aus 201).**
  (a) **`finish` nach `runs[id] = nil`:** `IndexingService.swift` Z. ~427 gibt den Lauf frei, danach folgen `await`s (`store.medium`, Haken), erst dann `quietGapRuns.remove` (Z. ~482) und `runFullReconcile.removeValue` (Z. ~515). Startet in diesem Fenster ein neuer Lauf (Überwachung, „Neu indizieren“), löscht das alte `finish` dessen frische Merker: Abbruch stellt dann `.pending` statt `.error` her, oder das Ende zeigt einen Hinweis trotz stiller Lücke. Fix: die Merker an das Token des Laufs binden (z. B. `[UUID: (token, kind)]`) und in `finish` nur das eigene Token entfernen. Test mit Haken je Instanz: `finish` nach der Freigabe festhalten, neuen Lauf starten, freigeben → Merker des neuen Laufs bleibt. Patch rot.
  (b) **Überwachung nach Aushängen am Laufende:** Der Zweig `finishedRun` ruft `onRunIndexed` (Z. ~498) ohne Prüfung auf Einhängen; ein im Fenster ausgehängtes Medium bekommt eine Überwachung (`LiveWiring.swift` Z. ~30). Dieselbe Prüfung wie beim Hinweis (`isStillMounted`). Test (Haken aus 201 b) + Patch.
  (c) **`cancel` vor dem Lesen des Speichers:** Zwischen `start` und dem Lesen im Task kommt die Art des Laufs aus `appState`. Weicht die Anzeige vom Speicher ab, darf ein Abbruch nie `.indexed` schreiben, das vorher nicht im Speicher stand: Rückfall dort `.pending`, außer der Speicher bestätigt `.indexed`/Lücke. Ebenso bei `storedBeforeRun == nil` (Z. ~235): Art und `beginRunUI` aus derselben Quelle. Test + Patch.
  (d) **Patch 201-b teilen:** je ein Patch für „offline zuerst“ (`MediumCoordinator.swift` Z. ~468) und für `isStillMounted` in `finish`; für die zweite Hälfte ein Test, in dem der angezeigte Status `.connected` bleibt, der Pfad aber weg ist. Beide rot.
  (e) **Pausenzweig beim Anschließen:** `heldForSleep`/`autoIndexPaused` in der Bedingung `MediumCoordinator.swift` Z. ~238 hat keinen Test; Test (Ruhezustand bzw. automatische Pause) + Patch.
  **So lassen:** Doppelstart, wenn die Pause genau zwischen `resumePausedRuns` und dem Schluss von `connectKnown` endet (zweiter Lauf über `rerunAfterFinish`, harmlos, wie bei `.indexed`).
  **Status:** Bereit zur Prüfung. Vorher rot (21:37): `GapMediumRunWindowTests` a, b, c (2). d und e decken vorhandenen Code ab und waren grün; Beweis über die Patches. (a) `runKinds` (`RememberedRunKind` mit Token, bestätigt aus dem Speicher oder aus der Anzeige) ersetzt `runFullReconcile` und `quietGapRuns`. `finish` holt Art und Volume vor der Freigabe ab, nur mit dem eigenen Token. (b) `onRunIndexed` nur noch, wenn `isStillMounted`.
  (c) `cancel` mit unbestätigter Art liest den Speicher und nimmt dessen Art, nicht lesbar → `.pending`. Bei `storedBeforeRun == nil` kommen Art und `beginRunUI` aus der gemerkten Art. (d) Patch 201-b geteilt: `d-offline` und `d-pfad`, je ein Test. (e) Je ein Test für Ruhezustand und automatische Pause.
  Selbstprüfung (Sonnet), nichts Hohes. Mittel behoben: Test und Patch für `cancel` bei Speicherfehler (`c-lesefehler`). Niedrig behoben: `cancel` nimmt die Art des Speichers statt nur „vollständig ja/nein“.
  21:46–21:49: 275 Tests in 39 Suites grün. Sabotage 9/9 rot (21:49–21:52). 20× parallel `GapMediumRunWindow…` + `GapMediumRemainder…` grün (21:53).
  Release und Debug: 0 Warnungen. App 21:54 (0.4.0), Signatur ok, 0 neue `.ips`. **Kein Gesamtlauf:** Last 4–7.

**Paketende:** 0 Warnungen Debug und Release, die betroffenen Tests (Rennen-Tests 20× parallel) und alle Patches unter `todo/sabotage/` rot, App des Nutzers gebaut. **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele), sonst weglassen und im Status vermerken; dann macht ihn der Host.

## Abnahme Host 25.10. (Gesamtlauf 21:59–22:29)

`Werkzeuge/pruefung.sh voll`: Debug und Release 0 Warnungen, seriell **1135/1135**, Parallel 1–3 **grün** (je 1129 bestanden, 6 übersprungen), keine neuen `.ips`, Sabotage **9/9 rot ✓**, App des Nutzers 22:29:15, Signatur gültig, Version 0.4.0. Prüf-Agent (Sonnet): a–e wie verlangt, kein hoher oder mittlerer Fund, kein Rückschritt bei 014, 104/141, 162, 166, 181–185, 199–201.

- **Abgenommen:** `bug.0.4.202`.
- **Reste (niedrig, Nutzer „wir lösen alles“) → `bug.0.4.203` (Paket 28):** übrige Schritte in `finish` (Sperre, Anforderung, Anzeige) an das Token binden, `cancel` liest bei unbestätigter Art immer den Speicher, Beweislücke im Zweig `!finishedRun`, wackliger Lesefehler-Zähler im Test.

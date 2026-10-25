# Paket 28 — Zielversion 0.4.0 (freigegeben 25.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Volltexte und Abnahme von Paket 27: [archiv/paket-27-abgenommen-2026-10-25.md](../archiv/paket-27-abgenommen-2026-10-25.md).

**Für jede Aufgabe gilt:** Test vor dem Fix rot (im Status belegen), danach grün; **Sabotage als Patch** unter `todo/sabotage/` (Regel 9); Selbstprüfung mit den fünf Fragen (Regel 12); Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.203`. **HALT.**

## Funde aus Prüfung 27 (Host 25.10., Prüf-Agent Sonnet, vom Host im Code bestätigt; Nutzer: „wir lösen alles“)

- **bug.0.4.203 — `finish` und `cancel` vollständig an das Token binden, Beweislücke, wackliger Test (niedrig).** Grundsatz: Nach `runs[id] = nil` darf ein altes `finish` **nichts** mehr verändern, was einem neuen Lauf desselben Mediums gehört. Eine Stelle für diese Prüfung (Regel 7).
  (a) **Sperre des Vollabgleichs:** `fullReconcileSuppressed.remove/insert` in `finish` (`IndexingService.swift` Z. ~523, ~538) hängt nicht am Token. Ein altes `finish` eines gescheiterten Laufs setzt die Sperre, nachdem der neue `start` (Z. ~196) sie gelöscht hat → die Überwachung gleicht bis zum nächsten Lauf nur Einzeländerungen ab. Ebenso `clearIndexRequest` (Z. ~553) und das abschließende `updateMedium` in `finish`: sie überschreiben im Fenster die Anzeige und die Anforderung des neuen Laufs. Fix: Ist beim Erreichen dieser Stellen ein neuerer Lauf für das Medium eingetragen (`runs[id] != nil` mit anderem Token), überspringt `finish` sie. Test mit dem Haken aus 202 a (altes `finish` festhalten, neuen Lauf starten, freigeben): Sperre, Anforderung und Anzeige des neuen Laufs bleiben. Je ein Patch für Sperre und Anzeige.
  (b) **`cancel` mit Anzeige „kein Abgleich“:** `cancel` (Z. ~300–321) liest den Speicher nur, wenn die gemerkte Art einen Abgleich sagt. Sagt die Anzeige noch `.indexing` (Fenster zwischen `runs[id] = nil` und `updateMedium` eines eben fertigen Laufs), der Speicher aber schon `.indexed`, schreibt ein sofortiger Abbruch des neuen Laufs `.pending` über das frische `.indexed`. Fix: Ist die Art **unbestätigt**, liest `cancel` immer den Speicher, gleich was die Anzeige sagt (nicht lesbar → `.pending`, wie in 202 c). Test + Patch.
  (c) **Beweislücke:** Der Zweig `!finishedRun, mounted, …` (Z. ~526) hat keinen eigenen Test; fällt `mounted` dort weg, wird nichts rot. Test (gescheiterter Lauf, Pfad weg, Anzeige bleibt `.connected` wie im `d-pfad`-Test) + Patch.
  (d) **Wackliger Test:** `cancelWithAnUnreadableStoreFallsBackToPending` (`GapMediumRunWindowTests.swift` Z. ~126–131) zählt mit `setNextMediumReadsFailing(2)` genau zwei Lesevorgänge; liest gleichzeitig ein anderer Teil (Koordinator, LiveWiring) `store.medium`, verbraucht er den Zähler, der Test wird selten rot. Ebenso Z. ~142. Fix: den Lesefehler gezielt für den Aufruf aus `cancel` auslösen (z. B. Haken je Instanz für „nächstes Lesen in `cancel` scheitert“ oder Fehler je Aufrufer), Zähler per `defer` zurücksetzen. 20× parallel grün belegen.
  **Status:** Bereit zur Prüfung. Vorher rot (22:34): `GapMediumRunOwnershipTests` a (2) und b; c deckt vorhandenen Code ab, Beweis über den Patch. (a) Eine Stelle `newerRunOwns`: ein überholtes `finish` lässt Anzeige, Sperre, Überwachung, Nachhol-Abgleich, Anforderung und Hinweis des neuen Laufs stehen; die Startzeit holt es vor der Freigabe ab. Haken `finishAfterReleaseHookForTesting`. (b) `cancel` prüft jede unbestätigte Art gegen den Speicher, `fromScratch` gemerkt.
  (d) Lesefehler je Aufrufer über Schalter je Instanz (`failsNextCancelStoreReadForTesting`, `…BeforeRun…`); der Zähler im Store ist entfernt. Selbstprüfung (Sonnet), nichts Hohes. Mittel behoben: Hinweis eines überholten Laufs; Beweise für Überwachung und „von vorn“ (Tests und Patches `a-ueberwachung`, `a-hinweis`, `b-vonvorn`).
  Prüfung am Ende von `cancel` wieder entfernt (nicht erreichbar, `start` wartet auf den Abbruch). Frage (niedrig): `rerunAfterFinish` bleibt beim überholten `finish` für den neuen Lauf stehen, dann folgt ein Abgleich mehr; so gewollt?
  22:43–22:46: 280 Tests in 40 Suites grün. Sabotage 10/10 rot (22:46–22:49). 20× parallel `GapMediumRunOwnership…` + `GapMediumRunWindow…` grün (22:50).
  Release und Debug: 0 Warnungen. App 22:52 (0.4.0), Signatur ok, 0 neue `.ips`. **Kein Gesamtlauf:** Last 5–8.

**Paketende:** 0 Warnungen Debug und Release, die betroffenen Tests (Rennen-Tests 20× parallel) und alle Patches unter `todo/sabotage/` rot, App des Nutzers gebaut. **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele), sonst weglassen und im Status vermerken; dann macht ihn der Host.

## Abnahme Host 25.10. (Gesamtlauf 23:01–23:33)

`Werkzeuge/pruefung.sh voll`: Debug und Release 0 Warnungen, seriell **1140/1140**, Parallel 1–3 **grün** (je 1134 bestanden, 6 übersprungen), keine neuen `.ips`, Sabotage **10/10 rot ✓**, App des Nutzers 23:32:54, Signatur gültig, Version 0.4.0. Prüf-Agent (Sonnet): a–d wie verlangt, kein hoher oder mittlerer Fund. Frage des Workers (`rerunAfterFinish`): harmlos, höchstens ein Abgleich mehr, keine Schleife.

- **Abgenommen:** `bug.0.4.203`.
- **Reste (niedrig) → `bug.0.4.204` (Paket 29), als Umbau:** Abschluss und Abbruch je Medium nacheinander statt Einzelprüfungen (`newerRunOwns` nur über `runs[id]`, zweiter gleichzeitiger `cancel`, Anzeige `.indexing` über stillem Abgleich), zwei schwache Tests.

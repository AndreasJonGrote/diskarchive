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
  **Status:** 

**Paketende:** 0 Warnungen Debug und Release, die betroffenen Tests (Rennen-Tests 20× parallel) und alle Patches unter `todo/sabotage/` rot, App des Nutzers gebaut. **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele), sonst weglassen und im Status vermerken; dann macht ihn der Host.

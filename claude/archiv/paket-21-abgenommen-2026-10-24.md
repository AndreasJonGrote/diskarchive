# Paket 21 — Zielversion 0.4.0 (freigegeben 24.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Volltexte und Abnahme von Paket 20: [archiv/paket-20-abgenommen-2026-10-24.md](paket-20-abgenommen-2026-10-24.md).

**Für jede Aufgabe gilt:** Test vor dem Fix rot (im Status belegen), danach grün; **Sabotage als Patch** unter `todo/sabotage/` (Regel 9); Selbstprüfung mit den fünf Fragen (Regel 12); Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.186` (zuerst), `187`. **HALT.**

## Funde aus Prüfung 20 (Host 24.10., zwei Prüf-Agenten, vom Host im Code bestätigt)

- **bug.0.4.186 — Nach „Medium konnte nicht bestätigt werden“ startet die Live-Überwachung (mittel, Invariante 1, fremdes Medium).** Endet ein Lauf mit `IndexFailureReason.unconfirmed` (bug.0.4.182), liefert `IndexingService.watchesAfterFailure` (`IndexingService.swift` Z. ~310–314) `true`, weil nur `.timeout` und `interrupted` ausgenommen sind. Liegt unter dem Pfad ein anderes Medium (oder hängt das Medium), schreibt die Überwachung dessen nicht leere Ordner in den Index dieses Mediums; `VanishedMediumGuard` greift nur bei „leer/fehlt“. **Fix:** `.unconfirmed` wie `.timeout` behandeln – keine Überwachung nach diesem Fehler; der nächste Lauf (neues Einhängen, Nutzer) versucht neu. **Tests (je Patch rot ✓):** Lauf endet `.unconfirmed` → keine Überwachung gestartet, ein Ereignis unter dem Pfad schreibt nichts; Gegenprobe: anderer Fehlergrund (z. B. `.unknown`) startet sie weiter wie bisher (bug.0.4.095).
  **Status:** Bereit zur Prüfung. Rot 18:12 (Kette + Rauchtest), Fix: `watchesAfterFailure` ohne `.unconfirmed`; Patch `bug.0.4.186.patch` (2 Tests) rot. Selbstprüfung ok. Offen: kein automatischer Neustart nach `.unconfirmed`.

- **bug.0.4.187 — Kleinkram aus Prüfung 20 (niedrig, 2 Punkte).** (a) Kommt das Aushängen-Ereignis erst nach der Karenz `unmountGrace` (2 s, `DirectoryIndexer.swift` ~Z. 716), steht nach einem echten Auswerfen der Fehler „Medium konnte nicht bestätigt werden“: Kommt das Aushängen-Ereignis desselben Mediums später, den gezeigten Fehlerhinweis dieses Mediums zurücknehmen (bestehender Weg, kein neuer Text); Test über das Ereignis (keine festen Zeiten als Beweis, Regel 11) + Patch. (b) Wurzelregel in `VanishedMediumGuard` (Z. ~25–30): Bei ausgeschalteter Option „versteckte Dateien ignorieren“ machen gemeinsame Verwaltungsdateien (`.DS_Store`, `Icon\r`, `._*`) die Prüfung „alles Bisherige fehlt“ wirkungslos → diese Namen beim Vergleich nicht mitzählen; Test (fremdes Medium nur mit `.DS_Store` gemeinsam, Prüfung → nicht eingehängt → nichts geschrieben) + Patch.
  **Status:** Bereit zur Prüfung. (a) Meldung `.unconfirmed` wird bei spätem Aushängen des eigenen Mediums zurückgenommen (rot 19:02), (b) Wächter ignoriert Verwaltungsdateien im Wurzelvergleich (rot 19:05); Patches -a, -b rot. Niedrig offen: 187a deckt die umgekehrte Reihenfolge nicht ab.
  Paketende (20:17–20:56): 0 Warnungen Debug+Release, parallel 2 und 3 grün (1068/1068), Sabotage 3/3 rot, App 20:56:15 ohne neuere .swift, keine neuen .ips. **Nicht grün:** seriell (4 Zeittests: recordOnMainStaysFast, pruning…, panelOpens…, loadingHint…) und Parallel 1 (19 Zeit-/Lasttests) bei Last 5–9 durch Systemprozesse; zusätzlich `MapAccess.listings/failing` unter Sperre gelegt (Absturz .ips 19:35 im ersten Lauf).

## Abnahme Host 24.10. (Prüfung 21:07–21:35, Arbeitsbaum auf `72c42e4`, Last ~2,5)

`Werkzeuge/pruefung.sh voll`: Debug mit Testziel und Release 0 Warnungen, seriell **1074/1074** grün (die Zeittests des Workers waren nur unter Last 5–9 rot), Parallel 2 und 3 grün, **Parallel 1: 1 rot** (`WatcherRemountTests/renameAfterRemountWithoutDisappeared`, alter Test mit echtem `hdiutil` und fester Wartezeit 5 s; seriell, Parallel 2 und 3 grün) → `bug.0.4.188`. Keine neuen `.ips`, Sabotage **3/3 rot ✓**, App des Nutzers 21:34:53, Version 0.4.0. Zwei Prüf-Agenten (Sonnet): kein hoher Befund; die mittleren vom Host im Code bestätigt.

- **Abgenommen:** `bug.0.4.186`, `187` (a, b). Die Sperre um `MapAccess` (nur Testcode) ist richtig.
- **Neue Funde → `todo/paket-22.md`:** `188` (roter Parallellauf, Verdacht: Lauf nach Wiedereinhängen endet „nicht bestätigt“ → seit 186 keine Überwachung), `189` (Liste der Verwaltungsdateien in 187 b unvollständig und schreibungsabhängig; Spec-Lücke des Hosts), `190` (Systemmitteilung bleibt nach Zurücknahme des Hinweises stehen), `191` (Kleinkram: Beweislücken 186/187, Umbenennen startet Überwachung ohne Statusprüfung).

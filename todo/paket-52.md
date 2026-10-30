# Paket 52 — Zielversion 0.4.2 (freigegeben 30.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 30.10. (drei Funktionen für 0.4.2, Layout freigegeben für genau diese Abschnitte). Konzept: `konzept/suche-navigation.md` (Filter, Medium-Auswahl), `konzept/medien.md` (eigener Name), `konzept/datenbank.md` (`storage_meta`).

**Layout:** `layout/ab 0.4.2/App: Layout.dc.html`. **Freigegeben sind nur** die Abschnitte „Medium — alle ausgewählt“, „Medium — Suche „SSD““ (Filter-Popover, hell und dunkel), die Zeile „Eigener Name“ im Details-Modal und im Dashboard die Kachel „Lauras Platte / Studio Backup“ (zweite Zeile mit dem Originalnamen, Auslaufen rechts). **Nicht** umsetzen, auch wenn es im selben Abschnitt zu sehen ist: Knopf „Auswerfen“ beim Hover, Chip „Wird geprüft“ und alles Übrige aus `ab 0.4.2`.

**Für jede Aufgabe gilt:**
- Der Test ist vor der Änderung rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.
- Neue Texte immer de und en, im Status unter „Neue Texte:“.

**Reihenfolge:** `todo.0.4.2.001`, `todo.0.4.2.002`. Danach **Paket 53** (siehe PROMPT.md).

## Aufgaben

- **todo.0.4.2.001 — Medien-Filter: „Alle Medien“ / „Alle abwählen“ als Umschalter (Nutzer 30.10.):**
  - **Heute:** `SearchFilterPopover.mediumGroup` (Z. ~101–150) hat einen Toggle „Alle Medien“ auf `SearchFilters.selectAllMedia`. Ist er an, erscheinen **alle** Medien angehakt; Ausschalten hakt alle einzeln an (`mediumIDs = alle`). Die Beschriftung ist blau, wenn an.
  - **Soll (Layout „Medium — alle ausgewählt“ und „Medium — Suche „SSD““):**
    1. **Anzeige der Haken:** Ein Medium ist nur angehakt, wenn der Nutzer es gewählt hat. **Ausgangszustand: kein Haken.** Keine Auswahl heißt wie heute „alle Medien durchsuchen“ (kein Medium-Filter, kein Medium-Chip in der Filterleiste).
    2. **Kopfzeile ohne Suchtext:** „Alle Medien“, solange **nicht alle** Medien angehakt sind (keins oder einzelne); Klick hakt **alle** an. Sind alle angehakt: Haken gesetzt, Text „Alle abwählen“; Klick nimmt **alle** Haken weg (zurück zum Ausgangszustand).
    3. **Kopfzeile mit Suchtext** (Feld „Medium suchen …“ darüber): gilt **nur für die Treffer der Liste**. Text „Alle Medien mit „<Begriff>“ anwählen“, solange nicht alle Treffer angehakt sind; Klick hakt die **übrigen Treffer** an, **schon gewählte andere Medien bleiben gewählt**. Sind alle Treffer angehakt: Haken gesetzt, „Alle Medien mit „<Begriff>“ abwählen“; Klick nimmt nur bei den Treffern den Haken weg.
    4. **Alle angehakt** wirkt in der Suche wie „alle Medien“ und zeigt **keinen** Medium-Chip; ein Chip bzw. „zurücksetzen“ in `MainWindowFilterBar` (Z. ~186) erscheint wie heute nur bei einer echten Teilmenge. Wie das intern gespeichert wird (`selectAllMedia` und `mediumIDs`), entscheidest du; `SearchItemFilter.matchesMedium`, `SearchPlanV3` und der Suchschlüssel in `SearchView` (Z. ~76) müssen dasselbe Ergebnis liefern wie heute für „alle“ bzw. die Teilmenge.
    5. **Optik:** Kopfzeile **fett, Textfarbe normal** (nicht mehr blau), Checkbox wie die Medienzeilen (`DesignCheckbox()` ohne blauen Farbton), Trennlinie darunter bleibt. Langer Begriff: einzeilig, wird in der Mitte gekürzt (Host 30.10.; das Layout sagt dazu nichts). Zähler darunter bleibt („3 von 21 Medien“ = sichtbare Treffer von allen).
    6. **Suchtext in der Liste** findet ein Medium über den **angezeigten Namen und den Originalnamen** (siehe `todo.0.4.2.002`; bis dahin nur den Namen).
  - **Neue Texte:** `Alle abwählen` / `Deselect all`; `Alle Medien mit „%@“ anwählen` / `Select all media matching “%@”`; `Alle Medien mit „%@“ abwählen` / `Deselect all media matching “%@”`. „Alle Medien“ gibt es schon.
  - **Gegenprobe (Tests im echten Fenster, Regel 10):**
    1. Ausgangszustand: kein Haken, Kopfzeile „Alle Medien“, Suche läuft über alle Medien.
    2. Klick „Alle Medien“ → alle angehakt, Text „Alle abwählen“, kein Medium-Chip; Klick → kein Haken.
    3. Zwei Medien einzeln angehakt → Kopfzeile „Alle Medien“; Klick → alle angehakt.
    4. „Archiv“ angehakt, Suchtext „SSD“ (drei Treffer) → „Alle Medien mit „SSD“ anwählen“; Klick → drei SSDs angehakt, „Archiv“ bleibt; Text „… abwählen“; Klick → SSDs ohne Haken, „Archiv“ bleibt.
    5. Suchtext leeren → Kopfzeile wieder „Alle Medien“ bzw. „Alle abwählen“ je nach Zustand aller Medien.
    6. `EnglishLocalizationTests` grün.
  - **Patches (rot erwartet):** `todo.0.4.2.001-a.patch`: Klick mit Suchtext hakt alle Medien an → Test 4 rot. `todo.0.4.2.001-b.patch`: Klick mit Suchtext entfernt auch „Archiv“ → Test 4 rot. `todo.0.4.2.001-c.patch`: Ausgangszustand zeigt alle angehakt → Test 1 rot.
  - **So lassen:** Dateityp, Endungen, Alter, Und/Oder-Knopf, Größe und Scrollen der Medienliste (ab 15 Medien, `maxHeight 220`), Medium-Auswahl gilt nur in der Suche.
  - **Status:** Bereit zur Prüfung (Worker 30.10.). Haken = `mediumIDs`; keine Auswahl und alle angehakt = `selectAllMedia` (Suche, `SearchPlanV3`, Suchschlüssel, Chip wie bisher); `SearchFilters.toggleAllMedia/setMedium/normalizeMediumSelection`; Zählung/Ladeansicht vergleichen über `hasSameHits` (`==` bleibt vollständig, sonst meldet `@Observable` das Anhaken nicht). Kopfzeile fett, Textfarbe, `DesignCheckbox()`, einzeilig, Mitte gekürzt; Schrift 11 pt und Breite 200 pt wie bisher (Layout zeigt 13 pt/270 pt, Aufgabe nennt nichts).
    - Tests `WindowTestGroup/MediumFilterToggleTests` (echtes Fenster, Haken über Pixel, Klicks per `sendEvent`, Tippen ins echte Feld): rot 19:26 mit alter Ansicht (18 Fehler), grün 19:37; betroffene Suites 19:27 (41 Tests) grün; 20× parallel siehe todo.0.4.2.003.
    - Patches `todo.0.4.2.001-a/-b/-c`: rot 3/3 (20:27–20:29).
    - Neue Texte: „Alle abwählen“/„Deselect all“; „Alle Medien mit „%@“ anwählen“/„Select all media matching “%@”“; „… abwählen“/„Deselect all media matching “%@”“.
    - Stufe 3: Kommt nach „alle angehakt“ ein Medium hinzu, steht es ohne Haken da (Suche läuft trotzdem über alle); Suchtext nur aus Leerzeichen zeigt „Alle Medien mit „ “ anwählen“.

- **todo.0.4.2.002 — Eigener Name für Medien (Nutzer 30.10.):**
  - **Soll:**
    1. **Speichern:** neuer Schlüssel `customName` in `StorageMetaKey` (`Storage/V3/MediumCodecV3.swift`), Wert in `storage_meta`. **Keine neue Spalte, keine Migration, Schema unverändert** (`konzept/datenbank.md`, Grundsatz 11.10.). Lesen und Schreiben wie die anderen Schlüssel dort (Store, nicht auf main, Regel 5).
    2. **Modell:** `Medium.name` bleibt der **Originalname vom System** und wird wie bisher beim Umbenennen im Finder nachgeführt. Neu: der eigene Name (optional) und **eine** Eigenschaft für den angezeigten Namen („eigener Name, sonst Originalname“). Name nach Wahl, aber nicht `displayName` (gibt es schon an `MediumType`).
    3. **Erkennung, Zuordnung und Rückfragen** (`MediumCoordinator`, `IndexStoreV3`, `ReplaceMediumDialog`, gleichnamige Medien, Protokoll) bleiben beim **Originalnamen**. Der eigene Name ist reine Anzeige.
    4. **Eingabe im Details-Modal** (`Views/Detail/MediumDetailModalView.swift`, Layout: Zeile „Eigener Name“ **als erste Zeile** der Tabelle, vor „Gesamt“): Textfeld rechts, Breite 200 pt, Schrift 12 pt, Mindesthöhe 24 pt, Innenabstand 2/8 pt, Platzhalter = Originalname. Übernommen wird mit Enter oder beim Verlassen des Feldes; Escape stellt den gespeicherten Wert wieder her. Leerzeichen am Rand fallen weg. **Leer oder gleich dem Originalnamen** → Schlüssel löschen (zurück zum Originalnamen). Höchstens 100 Zeichen.
    5. **Anzeige überall mit dem angezeigten Namen:** Dashboard-Kachel, Seitenleiste der Spaltenansicht, Kopf der ersten Spalte und Pfad in der Fußzeile, Titel des Details-Modals, Medien-Kacheln der Suche, Medium-Spalte der Favoriten, Medienliste im Filter-Popover, Einstiegskachel der Menüleiste, Einstellungen → Speichermedien, Mitteilungen und Dialoge zu einem bekannten Medium (z. B. „Vergessen“). Vollständige Liste per `grep -rn "medium.name\|\.name" diskindex/diskindex` selbst bilden und im Status nennen, welche Stellen bewusst beim Originalnamen bleiben.
    6. **Originalname sichtbar:**
       - **Dashboard-Kachel** (Layout „Lauras Platte“): unter dem Titel eine zweite Zeile mit dem Originalnamen, 11 pt, Textfarbe 50 %, Abstand 2 pt. **Nur wenn** ein eigener Name gesetzt ist; sonst sieht die Kachel aus wie heute.
       - **Auslaufen statt „…“** für Titel und zweite Zeile: einzeilig, kein Umbruch, rechts weich ausgeblendet (Verlauf von voll deckend bei 82 % der Breite bis transparent bei 100 %, wie die Ordnernamen in der Spaltenansicht).
       - **Seitenleiste, Einstellungen → Speichermedien:** nur der angezeigte Name, Originalname als Tooltip, wenn ein eigener Name gesetzt ist.
    7. **Suche:** Medien-Kacheln der Suche (Namenstreffer, `konzept/suche-navigation.md`) und die Medienliste im Filter-Popover finden ein Medium über **eigenen und Originalnamen** (gleiche Umwandlung wie `slug`: klein, Umlaute zum Stammlaut, ß → ss). `storages.slug` bleibt unverändert. Wie der eigene Name in die Abfrage kommt (SQL über `storage_meta` oder im Speicher über die wenigen Medien), entscheidest du; nicht auf main.
    8. **Sortierung** von Medienlisten nach dem angezeigten Namen, wo heute nach Namen sortiert wird.
    9. **Vergessen** eines Mediums entfernt den eigenen Namen mit (wie die übrigen `storage_meta`-Schlüssel).
  - **Neue Texte:** `Eigener Name` / `Custom name`.
  - **Gegenprobe:**
    1. Datenbank-Test: Namen setzen → Schlüssel `customName` in `storage_meta`, `storages.name` und `slug` unverändert, keine neue Spalte (Schema-Vergleich wie in den bestehenden Schematests). Leeren bzw. gleich dem Originalnamen → Schlüssel weg.
    2. Neustart des Stores (neu laden) → eigener Name bleibt.
    3. Umbenennen im Finder (Originalname ändert sich über den bestehenden Weg) → eigener Name bleibt, zweite Zeile der Kachel zeigt den neuen Originalnamen.
    4. Ansicht im echten Fenster (Regel 10): Kachel mit eigenem Namen zeigt zwei Zeilen, ohne nur eine (Höhe wie heute); Seitenleiste zeigt den eigenen Namen.
    5. Suche „Laura“ findet das Medium mit eigenem Namen „Lauras Platte“, „Studio“ findet es über den Originalnamen; Medienliste im Filter-Popover ebenso.
    6. Zwei Medien mit gleichem Originalnamen, eins mit eigenem Namen → Erkennung und Rückfragen unverändert (bestehende Tests zu `bug.0.4.233` grün).
    7. `EnglishLocalizationTests` grün.
  - **Patches (rot erwartet):** `todo.0.4.2.002-a.patch`: Anzeige nimmt wieder `name` → Test 4 rot. `todo.0.4.2.002-b.patch`: leerer Name wird als leerer Wert gespeichert statt gelöscht → Test 1 rot. `todo.0.4.2.002-c.patch`: Suche nur über Originalnamen → Test 5 rot.
  - **So lassen:** Schema, `storages`, Erkennung und Zuordnung über Originalname und Kennungen, Erkennungsdialog für neue Medien (neues Medium hat noch keinen eigenen Namen), restliche Zeilen des Details-Modals, Kachelhöhe ohne eigenen Namen. Ein späteres, größeres Layout für die Namen kommt (Nutzer 30.10.) – jetzt nur das Feld im Details-Modal und die Anzeige.
  - **Status:** Bereit zur Prüfung (Worker 30.10.). `StorageMetaKey.customName` in `storage_meta`, Schema unverändert; `IndexStoreV3.setCustomName` normalisiert (Rand, 100 Zeichen, leer/Originalname → Schlüssel weg), `Medium.shownName`/`matchesName` (Slug, beide Namen), Liste nach angezeigtem Namen (`fetchAll`, nach Setzen im Speicher); Vergessen über Kaskade. Feld im Details-Modal (erste Zeile, Enter/Verlassen/Escape), Kachel mit 2. Zeile (`FadeMaskText`).
    - Angezeigter Name: Dashboard, Seitenleiste (+Tooltip), Spaltenkopf, Fußzeilenpfad, Modal-Titel, Suchkacheln, Treffer-/Favoritentabelle, Filter-Popover/Chip/„In …“, Menüleiste, Einstellungen (+Tooltip, Sortierung), Mitteilungen „indiziert“/Fehler. Bewusst Original: `MediumCoordinator`, Rückfrage Ersetzen (`AppState+Media` Z. ~194/200), Erkennungsdialog, Kontextmenü-Ziel (Namensuche/Ignorieren), Protokoll.
    - Tests `MediumCustomNameTests` (5) + `MediumFilterToggleTests/listFindsCustomAndOriginalName`: rot 19:39 (Stummel), grün 19:36/19:37; 33 Suites 200 Tests 19:40–19:43 grün außer `ReindexGateTests/buttonsLookDisabledDuringRun` (Messbereich +44 pt wegen neuer Zeile angepasst, Erwartung gleich; grün 20:16); `ReplaceFirstTests` (bug.0.4.233) grün.
    - Patches `-a/-b/-c`: rot 3/3 (20:29–20:31). Neue Texte: „Eigener Name“/„Custom name“.
    - Stufe 3: beim „Ersetzen“ eines gleichnamigen Mediums geht der eigene Name des alten nicht mit (Aufgabe lässt Rückfragen beim Originalnamen).

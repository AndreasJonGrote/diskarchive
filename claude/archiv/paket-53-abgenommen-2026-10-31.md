# Paket 53 — Zielversion 0.4.2 (freigegeben 30.10., abgenommen 31.10.2026)
Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 30.10. („Filter: Ordner ohne Treffer leise statt ausblenden“, Wartescreen, Option „Ordner weiterhin anzeigen“ entfällt). Konzept: `konzept/suche-navigation.md` (Abschnitt 5, Filter in der Spaltenansicht), `konzept/einstellungen-start.md` (Voreinstellungen), `konzept/datenbank.md` (Baum ohne gespeicherten Pfad, `parentID`).

**Layout:** `layout/ab 0.4.2/App: Layout.dc.html`, **freigegeben nur** die Abschnitte „Filter auf dem ganzen Medium“, „Ordner ohne Treffer geöffnet“ und „Filter wird angewendet“ (Spaltenansicht, je hell und dunkel). Alles andere aus `ab 0.4.2` bleibt tabu.

**Für jede Aufgabe gilt:**
- Der Test ist vor der Änderung rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1. Zeitabläufe beteiligt (Abbruch, Hintergrundrechnung) → betroffene Suite 20× parallel.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.
- Neue Texte immer de und en, im Status unter „Neue Texte:“.

**Reihenfolge (HALT am Ende):** `todo.0.4.2.003`. **HALT.**

## Abnahme Host 31.10. (Gesamtlauf 00:18–00:55)

- Diff gelesen (Pakete 52 und 53): nichts Wesentliches. Korrektur 30.10. 21:00 (`LayoutCopyTests` nimmt genau den entfallenen Text aus) geprüft.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1271/1271, parallel 3× grün (je 1264, 7 übersprungen), Sabotage 12/12 rot, keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 00:55:02, Version 0.4.1.
- Fragen des Workers: Unterstreichungsabstand Standard (SwiftUI); Kopf-Zähler und blaue Auswahl aus dem Layout, so gelassen.
- Patches: `archiv/sabotage/paket-52/`, `archiv/sabotage/paket-53/`.


## Korrektur Host 30.10. 21:00 (Gesamtlauf 20:41, abgebrochen nach seriell)

Code gelesen (Pakete 52, 53): nichts Wesentliches. Build 0 Warnungen. **Seriell 1270/1271, ein Test rot:** `LayoutCopyTests/windowLinesFromTheLayoutAreInLayoutCopy` („fehlt in LayoutCopy: Ordner weiterhin anzeigen“). Ursache: Der Test liest alle Fenstertexte aus `layout/bis 0.4.1/Disk Index App.dc.html`; der Text ist mit `todo.0.4.2.003` bewusst entfallen (Nutzer 30.10.). Nutzer sieht nichts; der Gesamtlauf ist aber rot.
- **Korrektur (Teil von `todo.0.4.2.003`):** im Test eine Ausnahme für genau diesen Text, mit Kommentar `todo.0.4.2.003: Option entfällt (Nutzer 30.10.)`. Keine allgemeine Ausnahmeliste, kein anderer Text, nichts am Layout. Prüfe in `LayoutCopyTests` und den übrigen Layout-Texttests (`grep -rn "weiterhin" diskindex/diskindexTests`), ob noch ein Test den Text erwartet.
- **Test:** `LayoutCopyTests` rot vor, grün nach der Änderung; dazu `LayoutCheckboxTests`, `ColumnFilterTests`, `EnglishLocalizationTests` grün. Kein Patch nötig.
- **Antworten auf deine Fragen:** Unterstreichungsabstand: Standard von SwiftUI reicht. Zähler im Spaltenkopf und blaue Auswahl mit Filter: so lassen (aus dem Layout richtig abgeleitet).
- **Status:** eine Zeile unter diese Korrektur, dann „Bereit zur Prüfung“.

Status: `LayoutCopyTests` filtert genau „Ordner weiterhin anzeigen“ heraus (Kommentar wie verlangt); `grep weiterhin` findet sonst nur Kommentare. Rot 00:02 (1 issue), grün 00:03–00:04: LayoutCopyTests, ColumnFilterTests, EnglishLocalizationTests, WindowTestGroup/LayoutCheckboxTests; 0 Warnungen. Bereit zur Prüfung.

## Aufgaben

- **todo.0.4.2.003 — Filter in der Spaltenansicht: Ordner ohne Treffer werden leise, Wartescreen, Option entfällt (Nutzer 30.10.):**
  - **Heute:** `ColumnBrowserFiltering.visibleItems` (`ColumnBrowserView.swift` Z. ~1053) filtert je Spalte im Speicher. Mit „Ordner weiterhin anzeigen“ (`AppSettings.showFoldersRegardlessOfFilter`, Voreinstellung An) bleiben Ordner sichtbar, prüfen aber das **Alter** (`SearchItemFilter.matches(…, foldersIgnoreTypeFilter:)`, `SearchIndex.swift` Z. ~249). Ob unter einem Ordner ein Treffer liegt, sieht der Nutzer nicht; mit „Aus“ verschwinden Ordner ganz.
  - **Soll:**
    1. **Treffermenge je Medium, von unten nach oben:** Sobald in der Spaltenansicht ein Objekt-Filter aktiv ist (`hasActiveObjectFilters`) oder sich Filter oder Medium ändern, rechnet die App **für das ganze geöffnete Medium** einmal aus, welche Ordner **irgendwo darunter** (beliebig tief) einen Treffer haben:
       - Eine Abfrage holt die Elternordner aller passenden Einträge des Mediums. „Passend“ heißt **genau** wie in der Suche: Dateityp-Gruppe, eigene Endungen, Alter, Und/Oder (`SearchPlanV3.typeClause`/`ageClause` wiederverwenden, keine zweite Filterlogik).
       - Von jedem dieser Ordner über `parentID` bis zur Wurzel hoch; jeder Ordner auf dem Weg ist „mit Treffer“. Ein Weg endet, sobald er auf einen schon markierten Ordner trifft. Die Ordnerkette (`id`, `parentID` der Ordner des Mediums) darf dafür einmal in den Speicher.
       - **Nur lesen, nie auf main** (Regel 5), über den bestehenden Datenbankzugang (ein Zugang je Prozess). Kein neuer Index, kein Schema.
    2. **Anzeige:**
       - **Dateien:** wie heute nur passende.
       - **Ordner:** **immer sichtbar**, unabhängig von ihrem eigenen Datum. **Mit Treffer:** normal. **Ohne Treffer:** **leise** – ganze Zeile 40 % Deckkraft (Layout `opacity:.4`, wie Offline-Medien), weiter klickbar.
       - **Gewählter leiser Ordner:** Auswahlfläche in Textfarbe, Schrift weiß und halbfett, das Ganze mit 40 % Deckkraft (ergibt Grau; Layout „Fotos 2020“); dunkel nach dem Dark-Mode-Abschnitt desselben Layouts. Der Pfad davor bleibt blau gefüllt (`DesignColor.filterSearch`).
       - **Sonderfall Dateityp „Ordner“:** Treffer sind die Ordner selbst (passend nach `SearchItemFilter`, z. B. Alter). Normal ist ein Ordner, der selbst passt oder einen passenden Ordner enthält; die übrigen sind leise.
       - **Zähler** im Spaltenkopf („KUNDE B · 1 VON 3“) und in der Fußzeile: „x von y“ mit x = passende Dateien plus Ordner mit Treffer, y = alle Einträge der Spalte. Wann der Zähler erscheint, bleibt wie heute.
    3. **Leisen Ordner geöffnet** (Layout „Ordner ohne Treffer geöffnet“): statt seines Inhalts (auch wenn er leise Unterordner hat) in seiner Spalte ein Status: Filter-Icon (Phosphor `funnel`, duotone, 20 pt, `DesignColor.filterSearch`), Titel „Keine passenden Objekte“ (halbfett, 12 pt), Text „In diesem Ordner und seinen Unterordnern gibt es keine Objekte, die zum Filter passen.“ (11 pt, Zeilenhöhe 1,45, Textfarbe 55 %, höchstens 260 pt breit), Link „Filter zurücksetzen“ (11 pt, halbfett, unterstrichen, Abstand Unterstrich 3 pt). Kopf „FOTOS 2020 · 0 VON 86“, Fußzeile „0 von 86 Objekten“. Abstände wie im Layout (Icon 10 pt Abstand nach unten, Titel 6 pt, Text 10 pt; Innenabstand 4/10 pt). Bausteine der vorhandenen Statusflächen (`ColumnFolderStatusPanels.swift`) nutzen, wo sie passen (Regel 7).
    4. **Wartescreen** (Layout „Filter wird angewendet“): Dauert die Rechnung aus Punkt 1 länger als **1 s** (`DelayedLoadingTiming.standard`: 1 s Verzögerung, 400 ms Mindestanzeige), erscheint der Status **in der Inhaltsspalte des tiefsten geöffneten Ordners** – bei der Wurzel also an Stelle der ersten Spalte, wie im Layout. Die Spalten des geöffneten Pfads links davon bleiben stehen und blau markiert, ihre Ordner noch ohne „leise“; Spalten rechts davon (Detail) entfallen, solange gerechnet wird.
       - Inhalt: **blauer Spinner** 20 × 20 pt, Strich 2,5 pt, `DesignColor.filterSearch`, oben offen, 0,9 s je Umdrehung; Titel „Filter wird angewendet“; Text „Auf diesem Speichermedium liegen sehr viele Dateien. Das Filtern dauert einen Moment.“; Link „Filter zurücksetzen“. Maße wie Punkt 3. Kopf: Name des Ordners bzw. Mediums ohne Zähler. Fußzeile rechts „Wird gefiltert …“.
       - Unter 1 s erscheint nichts davon; bis das Ergebnis da ist, zeigen die Spalten Dateien gefiltert und alle Ordner normal, danach in **einem** Schritt die leisen Ordner (kein Flackern).
    5. **Abbruch und Wechsel:**
       - „Filter zurücksetzen“ (Wartescreen und Punkt 3) hebt **alle** Objekt-Filter auf, bricht die Rechnung ab und zeigt **sofort** den ungefilterten Inhalt **dieses** Ordners; der geöffnete Pfad bleibt, kein Sprung zur Wurzel.
       - Filter ändert sich während der Rechnung → laufende Rechnung abbrechen, neue beginnen (keine Warteschlange, kein spätes Ergebnis des alten Filters).
       - Anderes Medium gewählt → laufende Rechnung abbrechen, für das neue Medium neu.
       - Ändert sich der Index des geöffneten Mediums bei aktivem Filter (Live-Überwachung, Abgleich, Indizieren), wird im Hintergrund neu gerechnet, **höchstens alle 2 s**; der alte Stand bleibt bis zum neuen Ergebnis stehen, **kein** Wartescreen dafür.
    6. **Option entfällt:** „Ordner weiterhin anzeigen“ verschwindet aus den Einstellungen (`SettingsGeneralTab.showFoldersSection`, Z. ~215) und aus den Voreinstellungen. `showFoldersRegardlessOfFilter` wird nicht mehr ausgewertet (`ColumnBrowserView` Z. ~84, `AppState+ColumnSelection` Z. ~103, Parameter `foldersIgnoreTypeFilter`). Gespeicherte Werte dürfen liegen bleiben (nichts löschen); Dekodieren alter Einstellungen darf nicht scheitern. Texte `copy.settings.column_filter.show_folders` und `…_hint` entfernen.
    7. **Suche, Favoriten, Menüleiste** bleiben unverändert (dort gibt es nur Trefferlisten).
  - **Neue Texte:** `Keine passenden Objekte` / `No matching items`; `In diesem Ordner und seinen Unterordnern gibt es keine Objekte, die zum Filter passen.` / `There are no items in this folder or its subfolders that match the filter.`; `Filter zurücksetzen` / `Reset filter`; `Filter wird angewendet` / `Applying filter`; `Auf diesem Speichermedium liegen sehr viele Dateien. Das Filtern dauert einen Moment.` / `This storage medium contains a lot of files. Filtering takes a moment.`; `Wird gefiltert …` / `Filtering …`.
  - **Gegenprobe:**
    1. **Richtigkeit:** Medium mit Baum `A/B/C/D/bild.cr2`, `A/X/text.txt`, `F/leer/`, Filter „Bild“ → `A`, `B`, `C`, `D` normal; `X`, `F`, `leer` leise; Datei `text.txt` unsichtbar. Gleiches mit Alter und Und/Oder. **Abgleich mit der Suche:** Für einen erzeugten Baum (mehrere tausend Einträge, zufällige Endungen und Daten) ist die Menge „Ordner mit Treffer“ gleich der Menge, die man aus `SearchItemFilter.matches` über alle Einträge und Hochlaufen erhält.
    2. **Alter eines Ordners zählt nicht:** alter Ordner mit neuer PDF, Filter „PDF“ + „Letzte 30 Tage“ (Und) → Ordner normal.
    3. **Dateityp „Ordner“:** Sonderfall aus Punkt 2.
    4. **Leiser Ordner geöffnet** (echtes Fenster, Regel 10): Status mit Titel und Link, Kopf „… · 0 VON n“; Link → Filter leer, Inhalt des Ordners sichtbar, Pfad unverändert.
    5. **Wartescreen:** Rechnung über einen Instanz-Haken (Regel 11, kein `static var`) länger als 1 s → Status in der richtigen Spalte (Wurzel und dritte Ebene geprüft), Fußzeile „Wird gefiltert …“; Rechnung unter 1 s → kein Status. Link bricht ab: kein spätes Ergebnis danach.
    6. **Abbruch:** Filter zweimal schnell geändert → angezeigt wird nur das Ergebnis des zweiten; Medium gewechselt → kein Ergebnis des alten Mediums.
    7. **Live:** Bei aktivem Filter neue `bild.jpg` in `F/leer/` (echter Ordner, FSEvents, Kettentest nach Regel 10) → `F` und `leer` werden normal, ohne Wartescreen.
    8. **Einstellungen:** Option nicht mehr sichtbar; alte Einstellungen mit `showFoldersRegardlessOfFilter = false` laden ohne Fehler, Ordner trotzdem sichtbar.
    9. **Tempo (Release, `DA_BENCH`):** erzeugtes Medium mit 1 Mio. Einträgen und 50 000 Ordnern; Filter mit vielen Treffern (300 000) und mit wenigen (50). Zeiten im Status; Ziel unter 2 s je Rechnung. Liegt es darüber → „Frage:“, nicht Fristen anpassen.
    10. `EnglishLocalizationTests` grün; bestehende Tests zu Filter, Spaltenansicht und Fußzeile grün (Tests, die „Ordner weiterhin anzeigen“ verlangen, nur dort anpassen und im Status nennen).
  - **Patches (rot erwartet):** `todo.0.4.2.003-a.patch`: Hochlaufen nur eine Ebene → Test 1 rot. `todo.0.4.2.003-b.patch`: Ordner prüfen wieder ihr Alter → Test 2 rot. `todo.0.4.2.003-c.patch`: altes Ergebnis wird nach Filterwechsel noch übernommen → Test 6 rot. `todo.0.4.2.003-d.patch`: Wartescreen sofort statt nach 1 s → Test 5 rot. `todo.0.4.2.003-e.patch`: „Filter zurücksetzen“ springt zur Wurzel → Test 4 rot.
  - **So lassen:** Suche (Filter global, Trefferliste), Favoriten, Filter-Popover und Filterleiste (außer was `todo.0.4.2.001` ändert), Sonderzustände der Ordnerspalte (wird indiziert, Scan-Tiefe, große Ordner), Schema und Indizes. Fehlende Dateiendungen (z. B. `.cr3`) sind **nicht** Teil dieses Pakets.
  - **Status:** Bereit zur Prüfung (Worker 30.10.). `IndexStoreV3.folderIDsWithHits` (`@concurrent`, `SearchPlanV3`, 2 Lesezugriffe, Ordnerkette im Speicher, Hochlaufen), `AppState+ColumnFilter` (Schlüssel Medium + Objekt-Filter, `task(id:)` bricht ab, Laufnummer gegen späte Ergebnisse, Wartescreen 1 s/400 ms, Live über `flushIndexChange` höchstens alle 2 s ohne Wartescreen). Ansicht: Ordner immer sichtbar, leise 40 %, leise gewählt in Textfarbe, mit Filter blaue Auswahl; Status „Keine passenden Objekte“/„Filter wird angewendet“ (`ColumnFilterStatusPanel`), rechts eines geöffneten leisen Ordners keine Spalten (Selbstprüfung); Zähler Fußzeile und Kopf (nur Zählspalte, Bedingung wie Fußzeile). Option weg, `showFoldersRegardlessOfFilter` bleibt gespeichert, unbenutzt.
    - Tests `ColumnFilterHitsTests` (5, u. a. Abgleich mit `SearchItemFilter` über >1 000 Einträge), `ColumnFilterWindowTests` (6, Pixel + Klick), `ColumnFilterLiveTests` (Testvolume, FSEvents): rot 20:15 (Stummel), grün 20:27; 48 Suites 164 Tests 20:16–20:19 grün. Angepasst: `ColumnFilterTests` (Parameter weg, „Ordner bleiben sichtbar“ statt Option), `LayoutCheckboxTests` (2 statt 3 Kästchen, erstes = „Unsichtbare Dateien“). 20× parallel: siehe Bericht.
    - Tempo 1 Mio. Einträge/50 000 Ordner: 0,26 s (300 000 Bilder), 0,21 s (50 PDF), Last ~6,3. Gemessen im Debug-Build mit `-O` (`SWIFT_OPTIMIZATION_LEVEL=-O`), weil das Testziel im Release wegen DEBUG-Haken nicht baut.
    - Patches `-a` bis `-f`: rot 6/6 (20:31–20:33). Neue Texte (6 laut Aufgabe) und `copy.column.filter.header_count` „%1$@ · %2$@ von %3$@“/„%1$@ · %2$@ of %3$@“ (Kopf-Zähler, nicht in der Aufgabe).
    - Frage: Unterstreichungsabstand 3 pt geht mit SwiftUI `.underline()` nicht einzustellen (Standardabstand). Stufe 3: Index-Änderung während der ersten Rechnung wird erst mit der nächsten nachgeholt.

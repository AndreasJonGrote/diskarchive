# Paket 60 — Zielversion 0.4.3 (freigegeben 03.11.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Drittes von sechs Paketen für 0.4.3: Erkennung und Popover.** Vorlage: Layout 00 („Anschließen und Erkennen“, „Status“), 01, 02 (02.01–02.03), 03 (alle Varianten, 03.09–03.11), 04 (Chip „Wird geprüft“, 04.01a), 19. Konzept: `konzept/medien.md`, `konzept/lauf-lebenszyklus.md`.

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`** (DE/EN); die 3 Schlüssel mit `pendingPackage = 60` in `LayoutCopyTests` hier erledigen, dazu `copy.a11y.overview` → „Zur Übersicht“ aus 20 (aus `openQuestions` nehmen). **Layout 03.11. (5):** `copy.action.retry` englisch „Try Again“ statt „Try again“ (sonst wird `LayoutCopyTests` rot). Fehlt ein Text: „Frage:“ (Regel 2).
- **Icons** nur aus `Werkzeuge/phosphor/` (Regel 4a). **Maße und Farben** aus dem Layout; Fade erst am Ende.
- **Die Lauf-Regeln bleiben** (`konzept/lauf-lebenszyklus.md`, Fenster dort „bewusst offen“). Dieses Paket ändert, was angezeigt wird, nicht wann ein Lauf startet oder endet. Braucht ein Zustand eine neue Information aus dem Lauf, „Frage:“ statt Umbau.
- Sabotage-Patch (Regel 9) je Verhaltensänderung. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git. **Vor „Bereit zur Prüfung“** alle Suites mit `Popover`, `MenuBar`, `Dashboard`, `NewMedium`, `Replace`, `Prompt`, `Recognition`, `Medium` oder `Pixel` im Namen laufen lassen (Lehre aus Paket 59).
- **So lassen:** Spaltenansicht und Einstellungen › Dateien & Ordner (Paket 61); Banner, Über, Update, Datenbank-/Einstellungsfehler (62). Fehlerzeile der Kachel bleibt „Fehler · erneut versuchen“, bis der Nutzer über die Zeit entscheidet.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.012` → `todo.0.4.3.013` → `todo.0.4.3.014` → `todo.0.4.3.015`. **HALT.**

## Aufgaben

- **todo.0.4.3.012 — „Ersetzt dieses Medium …?“ (Layout 02.03, 00):**
  - Wird ein Medium angeschlossen, dessen Name zu einem bekannten, aber **nicht angeschlossenen** Medium gehört, fragt der Dialog laut 02.03 (Texte aus 20). „Altes vergessen“ entfernt das alte Medium mit Index und Favoriten, danach folgt der Erkennungs-Dialog für das neue. „Behalten“ führt beide getrennt weiter (danach Erkennungs-Dialog für das neue).
  - Den vorhandenen `ReplaceMediumDialog` und seinen Auslöser gegen 02.03 abgleichen: Bedingung, Texte, Knöpfe, Reihenfolge der Dialoge, Stapel mit mehreren Dialogen (02.02). Weicht die heutige Bedingung ab (z. B. andere Kennung als der Name), im Status nennen und „Frage:“, nicht still ändern.
  - **Test:** beide Knöpfe mit Folge (vergessen inkl. Favoriten / getrennt), Dialog nur bei bekanntem, nicht angeschlossenem Namen. Sabotage-Patch, falls sich Verhalten ändert.
  - **Status:** Bereit zur Prüfung.
    - **Abgleich:** Dialog und Auslöser entsprechen 02.03 (Texte aus 20, „Altes vergessen“/„Behalten“, Rückfrage vor dem Erkennungs-Dialog, Stapel nach 02.02); daher keine Verhaltensänderung und kein Patch.
    - **Bedingung heute:** Das neue Medium ist unentschieden, und es gibt **genau ein** gleichnamiges Offline-Medium; bei zweien wird nicht gefragt (`twoNamesakesAskNothing`). „Behalten“ wird je Paar gemerkt.
    - **Test:** neu `ReplaceMediumFavoritesTests` (vergessen samt Index und Favorit; Behalten lässt beides; angeschlossener Namensvetter fragt nicht) und die vorhandenen `ReplaceFirstTests`/`ReplaceMediumDialogWindowTests`. Frage unten.

- **todo.0.4.3.013 — Status „Wird geprüft“, „Entscheidung ausstehend“, „Speichermedium fehlerhaft“ (00, 03, 04, 01):**
  - **„Wird geprüft“:** für **neue und wieder angeschlossene** Medien zwischen dem Erkennen und dem Start einer Indizierung. Kachel: Chip „Wird geprüft“ (grün gestrichelt, pulsierender Punkt, keine Fläche). Popover: Zweitzeile „Speichermedium wird geprüft“ mit pulsierendem grünem Punkt, ohne Prozent. Folgt eine Indizierung → „{n} % indiziert“; ist nichts zu tun → „Online“ bzw. Ruhezustand. Der kurze Sprung auf 99 % beim Wiedererkennen entfällt. Ein reiner Abgleich auf einem vollständig indizierten Medium lässt die Kachel bei „Online“ (04).
  - **„Entscheidung ausstehend“** (nur Popover): gelber pulsierender Punkt, wenn das Medium online ist, aber die Antwort im Erkennungs-Dialog fehlt. Klick auf die Zeile öffnet den Erkennungs-Dialog **für genau dieses Medium**, nicht die Spaltenansicht.
  - **„Speichermedium fehlerhaft“** (nur Popover): roter pulsierender Punkt, wenn das Medium angeschlossen ist, sich aber nicht lesen lässt (14).
  - Menüleisten-Icon (01): Badges laut 01 prüfen (Neu erkannt = pulsierender grüner Punkt solange ein Erkennungs-Dialog wartet).
  - **Test:** Zustandsfolge neu → geprüft → indiziert/online, wieder angeschlossen ohne Änderung → nie 99 %, Klick „Entscheidung ausstehend“ öffnet den Dialog des Mediums. Sabotage-Patch.
  - **Status:** Bereit zur Prüfung.
    - **Wird geprüft:** `Medium.isChecking`: angeschlossen, „Indizieren“, nicht pausiert, und entweder neu vor dem Start oder `indexRunPhase` `.awaitingRun` (neue reine Anzeigephase) bzw. Zählphase ohne Prozent. `MediumCoordinator.publish` setzt `.awaitingRun`, wenn „wird indiziert“ gespeichert, aber kein Lauf aktiv ist; das beseitigt den 99-%-Sprung (Ursache: gespeicherter Stand `min(0,99, …)` beim Wiedererkennen). Lauf-Regeln unverändert.
    - **Anzeige:** Chip „Wird geprüft“ (gestrichelt, pulsierender Punkt), danach „{n} % indiziert“ auch vor den ersten Einträgen. Popover mit pulsierendem Punkt: grün geprüft, gelb Entscheidung ausstehend (jetzt mit unentschiedenen Medien in der Liste, Klick holt den Dialog genau dieses Mediums nach vorn), rot fehlerhaft. Badges laut 01 schon richtig.
    - **Test:** `MediumCheckingTests`, `PromptFocusStackTests.decisionPendingOpensTheDialogOfThatMedium`. Patches `013-a`/`013-b`. Angepasst an die neue Vorgabe: `MediumChipTests` (erlaubt „Wird geprüft“), `PopoverIndexedOnlyTests` (bug.0.4.236 zeigte nur „Ja“, jetzt auch unentschiedene).
    - **Stufe 3:** Den Weg über den Coordinator selbst (Wiedererkennen) prüft kein Test, nur die Anzeige bei `.awaitingRun`.

- **todo.0.4.3.014 — Popover aufgeräumt und Popover-Suche (03):**
  - Der Umschalter zwischen Dateien und Prozent entfällt. Ein Chip erscheint nur, solange ein Medium indiziert wird (Spinner; während der Pause Pause-Icon). Kein Chip = online und vollständig indiziert. Zeitangabe mit Uhr-Icon + Datum („heute, {1}“) statt „Zuletzt indiziert: …“. Nur angeschlossene Medien.
  - **Leerzustände 03.09/03.10:** „Kein Speichermedium angeschlossen“ und „Kein indiziertes Speichermedium angeschlossen“ mit schwarzem Medien-Icon, hell und dunkel.
  - **Suche:** Zustand „Suche läuft — dauert länger“ (Spinner, „Deine {1} Speichermedien und {2} Dateien werden durchsucht …“, Einzahl laut 20, verzögert wie im Fenster) statt sofort „Keine Treffer“; „Keine Suchergebnisse“ / „Suchbegriff ändern.“ erst nach fertiger Suche; „Alle {1} Ergebnisse anzeigen“ / „1 Ergebnis anzeigen“. „Einen Moment bitte“ entfällt.
  - Benannte Medien und Favoriten wie in Paket 59 (`listLabel`).
  - **Test:** keine Umschalt-Steuerung mehr; Chip nur bei Lauf; Suche zeigt erst Warten, dann Ergebnis oder Leerzustand. Sabotage-Patch für die Suche.
  - **Status:** Bereit zur Prüfung.
    - **Popover-Zeile:** zweite Zeile als `PopoverStatusLine`, über der versteckten Zeile, damit sie nicht springt. Uhr-Icon mit „heute, {1}“ statt „Zuletzt indiziert: …“; rechts nur im Lauf Spinner bzw. Pause und Prozent, ohne Umschalter. Leerfläche 03.09/03.10 (`MenuBarHardDrives` 32, 180 pt).
    - **Popover-Suche:** `popoverSearchPhase` (pending → nach 1 s hint mit Spinner und Umfang laut 20 → settled); „Keine Suchergebnisse“ / „Suchbegriff ändern.“ erst danach. Gruppen „DATEIEN“/„ORDNER“ aus 20 in Großbuchstaben.
    - **Texte:** gelöscht `copy.indexed.line/never`, `copy.date.today/yesterday`, `copy.search.popover_no_hits`, `copy.popover_search.group.files/folders`; neu `copy.chip.checking`, `copy.medium.checking`, `copy.popover_search.no_results.message`; `copy.a11y.overview` „Zur Übersicht“; `copy.action.retry` en „Try Again“.
    - **Test:** `PopoverSearchStateTests`; Patch `014`. Umgestellt: `MenuBarPopoverLayoutTests` (Leerfläche 180 statt einer Zeile), `MenuBarRowHeightTests` (die Messspalte traf die zweite Zeile, jetzt die Namensbreite).

- **todo.0.4.3.015 — Startzustand „Inhalte werden geladen“ (03.11, 04.01a):**
  - Solange beim Start der Index geöffnet wird, zeigen Hauptfenster (statt Dashboard) und Popover (statt Medienliste) nur den schwarzen Spinner mit „Inhalte werden geladen“, Aufbau wie 07.02.08. Vorhandenen `StoreLoadingView` gegen das Layout abgleichen (Größe, Schrift, Abstände), hell und dunkel.
  - **Test:** Pixel- oder Strukturtest gegen 03.11/04.01a.
  - **Status:** Bereit zur Prüfung. `StoreLoadingView`: Abstand 10 (vorher 8) nach 07.02.08; im Popover statt der Medienliste, Kopf und Fuß bleiben (03.11), auf einer Fläche von 5 % und mindestens 180 pt. Im Hauptfenster wie bisher statt des Dashboards. Test `StoreLoadingViewTests` (Pixel, hell und dunkel, Lage der Textzeile; Höhe der Popover-Fläche). Patch `015`.
  - **Läufe:**
    - 18:24: 407 Tests in 86 Suites (alle mit Popover/MenuBar/Dashboard/NewMedium/Replace/Prompt/Recognition/Medium/Pixel, dazu Chip, Status, Fortschritt, Start, Suche, Texte); rot waren nur Tests, die die alte Vorgabe prüften (siehe oben).
    - Nach den Korrekturen 18:36: dieselben grün bis auf `PromptFocusStackTests` (3 Tests, auch zwei unveränderte). `NSWindow.windowNumbers(options: [])` meldet seit etwa 18:30 nur 1 Fenster: Die Testapp liegt nicht im aktiven Space, nicht gesperrt. Um 18:13 und 18:24 grün; der Gesamtlauf des Hosts entscheidet.
    - Sabotage 18:42–18:44: rot 4/4, Mängel 0 (013-b zählt aus demselben Grund nicht als Beleg). Build 0 Warnungen.
  - **Selbstprüfung (Sonnet):** Stufe 2 „pausiertes Medium zeigt ‚Wird geprüft‘“ behoben (Pause-Prüfung für beide Zweige, Testzeile). Sonst nichts Wesentliches.
  - **Frage:** 02.03 sagt nach „Altes vergessen“ „danach folgt der Erkennungs-Dialog“. Heute übernimmt das neue Medium eine beim alten **gemerkte** Entscheidung, und der Dialog entfällt (`ReplaceFirstTests.rememberedDecisionIsAdoptedWithoutRecognitionDialog`, bug.0.4.215). Bleibt das so?
  - **Frage:** 02.03 nennt kein „genau ein“. Bei zwei gleichnamigen Offline-Medien fragt die App heute nicht. Bleibt das so?

## Korrektur Host 03.11. (Gesamtlauf 18:46–19:21 rot)

Build und Release 0 Warnungen, Sabotage 4/4 rot ✓, keine Absturzberichte. Rot: seriell 2, parallel je 3 (immer dieselben). `PromptFocusStackTests` war im Gesamtlauf **grün** (die Space-Sorge erledigt sich).

**Antworten auf die Fragen (Host):** Beide bleiben so. (1) Eine gemerkte Entscheidung wird nach „Altes vergessen“ übernommen, kein Erkennungs-Dialog (bug.0.4.215, Nutzer). (2) Bei zwei gleichnamigen Offline-Medien keine Rückfrage: welches gemeint ist, lässt sich nicht sicher sagen.

- **K1 `RestCoverageTests.undecidedMediumIsHiddenUntilIndexed`** (seriell und parallel rot): Ein Medium mit „Nein“ zeigt „67 % indiziert“ statt „Nicht erlaubt“. Ursache: `MediumChip.presentation` (`StatusChip.swift`), die neue Bedingung `!(connected && medium.indexStatus == .indexing)` überspringt die Prüfung auf `refusesIndexing`. **Nutzer sieht:** ein abgelehntes Medium mit Prozent statt „Nicht erlaubt“. Soll: Ablehnung gewinnt immer (vor „Wird geprüft“ und vor dem Prozent). Test **nicht** ändern.
- **K2 `LocalizedFormattingTests.headersComeFromCatalogInBothLanguages`** (seriell und parallel rot): Gruppe im Popover englisch „FOLDER“ statt „FOLDERS“. 20 hat „Ordner“ nur einmal, als „Folder“ (Filtertyp, Einzahl wie „Image“). **Entscheidung Host:** die Gruppenüberschrift bleibt Mehrzahl „FOLDERS“ wie „FILES“; `copy.popover_search.group.folders` englisch „Folders“ und in `openQuestions` mit Begründung („Ordner“ in 20 = Filtertyp, Gruppe Mehrzahl). Test nicht ändern.
- **K3 `PopoverSearchStateTests.searchWaitsThenShowsTheHintThenTheResult`** (eigener Test, parallel 3× rot, seriell grün): Unter Last kommt das Ergebnis vor dem Hinweis. Test so bauen, dass die Suche sicher länger dauert als der Hinweis-Abstand (z. B. Debounce deutlich länger als die Wartezeit des Tests, oder die Phasenfolge mitschreiben), ohne die Vorgabe zu schwächen. Fünfmal parallel grün belegen.
- Nicht Teil der Korrektur: `firstIndexOfLargeSameSizeFolderIsFast` einmal 15,2 s statt < 15 s (parallel 3, außerhalb des Diffs, Stufe 3).

**Vor „Bereit zur Prüfung“:** `RestCoverageTests`, `LocalizedFormattingTests`, `LayoutCopyTests`, `PopoverSearchStateTests`, `MediumChipTests`, `MediumCheckingTests` und alle Suites mit `Chip` oder `Popover` im Namen.
- **Status Korrektur:** Bereit zur Prüfung.
  - **K1:** In `MediumChip.presentation` steht die Ablehnung jetzt vor der neuen Prozent-Ausnahme: „Nicht erlaubt“ gewinnt immer, auch während eines Laufs. `RestCoverageTests` unverändert grün.
  - **K2:** eigener Schlüssel `copy.popover_search.group.folders` „Ordner“/„Folders“, angezeigt in Großbuchstaben (`LayoutCopy.popoverGroupFolders`), mit Begründung in `openQuestions`. `LocalizedFormattingTests` unverändert grün.
  - **K3:** nur der eigene Test. Debounce 3 s, Hinweis nach 20 ms, Warten auf den Hinweis höchstens 2,5 s; zusätzlich geprüft, dass vorher kein Ergebnis da ist. 5× parallel mit allen Suites unten 19:34–19:35: 0 Fehler.
  - **Lauf 19:31:** 64 Tests in 15 Suites grün (`RestCoverageTests`, `LocalizedFormattingTests`, `LayoutCopyTests`, `PopoverSearchStateTests`, `MediumChipTests`, `MediumCheckingTests`, alle mit „Chip“ oder „Popover“ im Namen). 0 Warnungen. Patches unverändert (4).

## Korrektur 2 Host 03.11. (Gesamtlauf 19:37–20:13)

Seriell **1299/1299 grün**, Build und Release 0 Warnungen, Sabotage 4/4 rot ✓. K1 und K2 im Code geprüft, in Ordnung. Rot nur noch der eigene Test aus K3, parallel 3× („Phase .pending“), und zweimal der Zeittest `firstIndexOfLargeSameSizeFolderIsFast` (15,4/15,5 s, außerhalb des Diffs, Stufe 3, keine Aufgabe).

- **K4 `PopoverSearchStateTests.searchWaitsThenShowsTheHintThenTheResult`:** Ursache (Host): Im Parallellauf ist der Main-Actor zeitweise länger als 2,5 s belegt. Danach kommt `waitUntil` (`SurfaceTestSupport.swift`) vor der Hinweis-Aufgabe dran, sieht die abgelaufene Frist und gibt `false` zurück, ohne noch einmal zu prüfen. Soll, nur im eigenen Test:
  - Hinweis-Teil mit großzügiger Frist (`waitUntil(timeout: 20)`) und einer Suche, die sicher länger dauert (Debounce z. B. 60 s), danach `cancelPopoverSearch()`; kein Warten auf das Ergebnis in diesem Test.
  - „Ergebnis erst nach der Suche, dann `.settled`“ als eigener Test mit kurzem Debounce.
  - `waitUntil` selbst **nicht** ändern (viele Nutzer).
  - **Beleg:** `Werkzeuge/pruefung.sh` mit allen Suites parallel, nicht nur den eigenen; mindestens 3× grün.
- **Status Korrektur 2:** K4: `searchWaitsThenShowsTheHintThenTheResult` geteilt in `searchWaitsThenShowsTheHint` (Debounce 60 s, Hinweis 20 ms, `waitUntil(timeout: 20)`, kein Ergebnis davor, dann `cancelPopoverSearch()`) und `resultArrivesOnlyAfterTheSearchThenSettled` (Debounce 20 ms, `.pending` → `.settled`, leer). `waitUntil` unverändert.
  Kopfzeile von `sabotage/todo.0.4.3.014.patch` auf den neuen Ergebnis-Test umgestellt (Patch selbst unverändert).
  `pruefung.sh voll` 21:09–21:43: Build/Release 0 Warnungen, seriell 1300/1300, parallel 3× je 1293 + 7 übersprungen, 0 rot; Sabotage 4/4 rot ✓; 0 Absturzberichte; Nutzer-App aktuell, Signatur gültig.
  Bereit zur Prüfung.

## Abnahme Host 03.11. (Gesamtlauf 21:54–22:28)

- Diff gelesen (Paket und Korrekturen): Ersetzen-Dialog entspricht 02.03 (unverändert, neuer Test für Favoriten); „Wird geprüft“ über `Medium.isChecking` und die Anzeigephase `.awaitingRun` (setzt nur `MediumCoordinator.publish`, Lauf-Regeln unverändert), damit kein Sprung auf 99 %; Popover mit `PopoverStatusLine` (grün geprüft, gelb Entscheidung ausstehend mit Klick auf den Dialog genau dieses Mediums, rot fehlerhaft), ohne Umschalter, Leerflächen 03.09/03.10; Popover-Suche mit `PopoverSearchPhase` (warten → Hinweis → Ergebnis); `StoreLoadingView` nach 07.02.08 auch im Popover. Korrekturen: K1 Ablehnung gewinnt im Chip, K2 Gruppe „Folders“ (eigener Schlüssel, `openQuestions`), K3/K4 eigener Suchtest unter Last. Nichts Wesentliches.
- Gesamtläufe 18:46–19:21 rot (K1–K3), 19:37–20:13 seriell grün, parallel eigener Test rot (K4), dritter grün: Debug und Release 0 Warnungen, seriell 1300/1300, parallel 3× grün (je 1293, 7 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, Sabotage 4/4 rot ✓, App des Nutzers 22:28:17, Version 0.4.2.
- **Fragen des Workers (Host):** Gemerkte Entscheidung nach „Altes vergessen“ bleibt ohne Erkennungs-Dialog (bug.0.4.215); bei zwei gleichnamigen Offline-Medien keine Rückfrage.
- **Stufe 3:** `firstIndexOfLargeSameSizeFolderIsFast` zweimal knapp über 15 s (19:37-Lauf), außerhalb des Diffs; im letzten Lauf grün.
- Nachtest des Nutzers: Medium neu anschließen („Wird geprüft“, dann Prozent), bekanntes wieder anschließen (kein 99 %), Erkennungsdialog wegklicken und über „Entscheidung ausstehend“ im Popover wieder öffnen, Popover-Suche auf großer Datenbank, Start der App („Inhalte werden geladen“).

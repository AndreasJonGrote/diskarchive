# Paket 34 — Zielversion 0.4.0 (freigegeben 27.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Funde der Abnahmerunde, ausführlich: [todo/funde-abnahmerunde-0.4.0.md](funde-abnahmerunde-0.4.0.md). Paketschnitt: Supervisor 27.10. (Paket 35: 215, 212, 213, 214; Paket 36: Layout).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.210` (schwer, zuerst), dann `bug.0.4.209` + `bug.0.4.216` (eine Aufgabe). **HALT.**

## Funde aus der Abnahmerunde des Nutzers (26.10., Supervisor 27.10. bestätigt)

- **bug.0.4.210 — Fortschrittsanzeige: eine Rechnung für alle Anzeigen.**
  - **Nutzer sieht:** Die Prozentzahl springt (100 %, 0 %, 99 %) und stimmt online und offline nicht überein. **Wann:** bei jedem Abbruch, Fortsetzen oder „Neu indizieren“ eines Laufs. **Stufe 1.**
  - **Die fünf Erscheinungen** (alle vom Nutzer gesehen am 26.10., Protokoll und Datenbank vom Host bestätigt):
    1. **Abbruch zeigt 100 %:** Stick „NO NAME“ mitten im Lauf ausgeworfen. Die Anzeige springt kurz auf 100 % und dann auf 33 %.
    2. **Online und offline verschieden:** online 34 %, offline 33 %. Nach dem Fortsetzen „auf einmal 43 %“, gespeichert waren 33 %.
    3. **0 % beim Fortsetzen:** Nach dem Wiederanstecken 34 %, dann 0 %, solange erneut gezählt wird, obwohl `scanTotal` (45.920) gespeichert ist.
    4. **„Neu indizieren“ sofort 99 %:** EOS_DIGITAL zeigte den ganzen Lauf 99 %. Bei der großen Platte (1,6 Mio.) stünde die Anzeige eine Stunde auf 99 %. Ebenso stand „Daten“ lange auf 99 %, gespeichert waren 88 %.
    5. **Umbenennen mitten im Lauf:** danach 34 %, gespeichert waren 42 %.
  - **Ursachen** (eine Stelle zum Rechnen fehlt):
    - `IndexProgressDisplay.note` (`AppState+Media.swift` Z. ~418–432) setzt bei **jedem** Wechsel weg von `.indexing` `real = 1` und hält 0,3 s bei 100 %, auch bei Abbruch und Offline. → 1.
    - `DirectoryIndexer.run` (Z. ~83–84, 126–135) beginnt mit `entriesCompleted = stored.fileCount + stored.folderCount` und addiert jeden **gelesenen** Eintrag, auch schon gespeicherte, die beim Fortsetzen erneut gelesen werden. Das gilt auch bei `fromScratch`. → 2, 4.
    - `Medium.indexProgressFraction` (`Models/Medium.swift` Z. ~82–94) gibt in der Zählphase 0 zurück, auch wenn eine Gesamtzahl gespeichert ist, und nimmt sonst `indexingProgress` (Laufwert) vor dem gespeicherten Stand. → 2, 3, 5.
    - `StatusChip` (Z. ~93) nimmt `displayedFraction` aus `IndexProgressDisplay`, sonst `indexProgressPercent`. Zwei Wege.
  - **Fix: eine reine Funktion** (z. B. `IndexProgress.displayed(…)`, ohne Zustand, ohne `Date()` von innen) berechnet den angezeigten Wert. **Alle** Anzeigen nutzen nur sie: Chip, Dashboard, Popover, Menüleiste, Einstellungen → Speichermedien, Medium-Details („Indiziert x %“), Seitenleiste. Regeln (Konzept `konzept/indizieren.md`, „Fortschritt“):
    - **Zähler** = Einträge, die wirklich in der Datenbank stehen. Ein Eintrag, der beim Fortsetzen nur erneut gelesen wird, zählt nicht doppelt.
    - Bei **„Neu indizieren“** (`fromScratch`) zählt nur, was **dieser Lauf** geschrieben hat; der alte Bestand nicht.
    - **Nenner** = Gesamtzahl (`scanTotal`, sonst die Zählung des Laufs); wächst der Bestand darüber, `max(Gesamtzahl, Zähler)`.
    - **Zählphase mit gespeicherter Gesamtzahl:** gespeicherter Wert, nie 0 %. Ohne gespeicherte Gesamtzahl: 0 % (Erstlauf, so im Konzept).
    - **Höchstens 99 %**, abgerundet. **100 % nur**, wenn der Lauf mit „indiziert“ endet. **„Fehler“ mit Lücke** bleibt 99 %, auch wenn gespeichert = Gesamtzahl (`bug.0.4.199`).
    - **Abbruch, Pause, Offline, Umbenennen:** Der Wert bleibt auf dem gespeicherten Stand; kein 100 %, kein Sprung nach unten außer auf den gespeicherten Stand.
    - **Nie fallend** innerhalb eines Laufs.
    - Die Regel „mindestens 1 Sekunde sichtbar, 0 → 100 % in 0,6 s“ (Nutzer 08.10.) gilt nur für einen Lauf, der **fertig** wird.
    - Online und offline zeigen für dasselbe Medium denselben Wert.
  - **Nicht anfassen:** Lebenszyklus und Ablauf von `IndexingService` (Start, `finish`, `cancel`, `endLifecycle`, Wartende) bleiben **unverändert**; dort gab es schon zwei Reste-Ketten (Pakete 27–31). Erlaubt sind die Zählung in `DirectoryIndexer` (was als geschrieben gilt) und das, was `IndexingService` als Fortschritt an `AppState` weitergibt. Muss am Ablauf etwas anders werden: „Frage:“ und HALT.
  - **Tests:**
    1. **Tabellentest der reinen Funktion**, je Zeile Eingaben → erwartete Prozent:
       - Fälle 1–5 wie oben, mit den Zahlen des Nutzers (15.323 von 45.920 → 33; 19.617 von 45.920 → 42; „Neu indizieren“ mit 256 alten Einträgen, 0 neu geschrieben → 0, nicht 99; Zählphase mit gespeicherter Gesamtzahl → gespeicherter Wert).
       - **„Fehler mit Lücke, gespeichert = Gesamtzahl“ → 99, nie 100** (Supervisor 27.10.: der heutige Test 99 von 100 bemerkt ein 100 an dieser Stelle nicht).
       - „indiziert“ → 100. Erstlauf in der Zählphase ohne Gesamtzahl → 0.
    2. **Gegenproben über die echte Kette** (Medium im Speicher, kein `sleep`, positives Signal zuerst):
       - Abbruch mitten im Lauf → der angezeigte Wert ist nie 1, danach der gespeicherte Stand.
       - „Neu indizieren“ auf einem vollständig indizierten Medium → der erste angezeigte Wert ist kleiner als 0,5.
       - **Ein zweites Medium indiziert gleichzeitig** → jedes Medium zeigt seinen eigenen Wert; der Wert des einen verändert den des anderen nicht.
    3. Gleicher Wert online und offline für dasselbe Medium.
  - **Patches (rot erwartet):**
    1. `bug.0.4.210-a.patch`: Bei Abbruch wieder 1 (`real = 1` für jedes Ende). Test „Abbruch“ wird rot.
    2. `bug.0.4.210-b.patch`: Der Zähler addiert erneut gelesene Einträge. Tabellenzeile 2 bzw. Fortsetzen wird rot.
    3. `bug.0.4.210-c.patch`: Bei „Neu indizieren“ zählt der alte Bestand. Gegenprobe „Neu indizieren“ wird rot.
    4. `bug.0.4.210-d.patch`: „Fehler“ wird auf 100 gerundet bzw. `min(0.99)` entfällt für `.error`. Zeile „Fehler mit Lücke“ wird rot.
  - **Status:** _(Worker)_

- **bug.0.4.209 + bug.0.4.216 — Dialoge: Fokus nur beim Erscheinen, Stapel bei jedem Abgleich (eine Aufgabe).**
  - **Nutzer sieht:** (209) Er tippt in einer anderen App, steckt eine Karte ein, und seine Tasten landen im Erkennungsdialog („dauernd der Fokus weg“); ein Return löst „Indizieren“ aus. (216) Steckt er zwei Medien kurz nacheinander ein, sieht er nur **einen** Dialog, der zweite erscheint erst nach der Antwort, statt gestapelt. **Wann:** (209) bei jedem Anschließen, während er schreibt; (216) immer, wenn ein weiteres Medium kommt, während ein Erkennungsdialog offen ist. **Stufe 1.**
  - **Entscheidung des Nutzers** (Konzept `konzept/medien.md`, Punkt 3, „Fokus einmal beim Erscheinen“):
    - Ein Dialog springt **beim Erscheinen einmal** nach vorn und nimmt den Fokus.
    - Danach fordert er ihn **nie wieder** an.
    - Klickt der Nutzer in ein anderes Fenster (App oder andere App), verschwindet der Dialog **dahinter**. Er schwebt nicht und bleibt offen, bis der Nutzer entscheidet.
    - Stapel nach Layout 02 (`todo.0.4.048`): das neueste vorn und mittig, ältere nach links oben versetzt.
  - **Ursache** (`AppWindowPresenter.swift`):
    - `syncNewMediumPanels` (Z. ~185–189) holt bei **jedem** Aufruf das vorderste Panel mit `orderFrontRegardless()` + `makeKey()`. Das passiert beim Erscheinen, nach jeder Entscheidung und beim Aushängen.
    - `openOrUpdateNewMediumPanel` (Z. ~395–413) setzt die Lage (`placeNewMediumPanel`, `depthFromNewest`) nur beim **Anlegen**. Kommt ein zweites Medium in einem späteren Aufruf, liegen beide mittig übereinander.
  - **Fix: eine Änderung in `syncNewMediumPanels`:**
    - Bei jedem Abgleich wird die **Lage aller** offenen Erkennungs-Panels neu berechnet (Stapel nach Layout 02). Wird der vorderste beantwortet, rücken die übrigen nach.
    - **Fokus nur**, wenn ein Panel in diesem Abgleich **neu erscheint** (einmal `makeKey`). Ein schon offenes Panel wird verschoben, aber nicht nach vorn geholt und nicht zum Key-Fenster gemacht.
    - **Kein `.floating`**: `level = .normal`, `isFloatingPanel = false`, `hidesOnDeactivate = false` (bleibt offen, liegt hinter dem Fenster, das der Nutzer anklickt).
    - Öffnet der Nutzer den Dialog selbst (`openNewMedium` aus der Menüleiste, „Entscheidung offen“), darf er nach vorn kommen und den Fokus nehmen; das ist eine Nutzeraktion.
  - **Alle Panels mit `.floating` in `AppWindowPresenter`** (Supervisor 27.10.) — für jedes gilt die Regel aus `medien.md` Punkt 3:

    | Zeile | Panel | Wer öffnet es | Regel |
    |---|---|---|---|
    | ~260 | „Ersetzt dieses Medium?“ (`openReplaceMediumPrompt`) | die App, beim Erkennen (`offerReplaceMediumPrompt`) | **gilt:** Fokus einmal beim Erscheinen, kein `.floating`. Ein erneutes Öffnen des schon offenen Panels (`show`) holt den Fokus nicht neu. Die Reihenfolge gegenüber dem Erkennungsdialog ändert Paket 35 (`bug.0.4.215`), nicht diese Aufgabe. |
    | ~298 | „Ignorieren bestätigen“ (`openIgnoreConfirmation`) | der Nutzer (Kontextmenü „Ignorieren“ ab 500 Zielen) | **gilt** ebenso: Fokus beim Erscheinen (direkte Folge seines Klicks), kein `.floating`, kein erneutes Anfordern. |
    | ~369 | Absturzbericht (`openCrashReport`) | die App, beim Start nach einem Absturz | **gilt:** Fokus einmal beim Erscheinen, kein `.floating`. |
    | ~428 | Erkennungsdialog (`makeNewMediumPanel`) | die App, beim Anschließen | **gilt**, siehe oben (Stapel). |

    `show(_:placement:)` (Z. ~340–345) und Z. ~351–352: `makeKey` nur beim ersten Erscheinen eines Panels, nicht beim erneuten Zeigen.
  - **Tests** (Fenster außerhalb des Bildschirms, Placement `.offscreen` bzw. Regel 10, kein `NSApp.activate`, Haken je Instanz):
    1. Zwei Medien in **getrennten** `syncNewMediumPanels`-Aufrufen → zwei Panels mit verschiedenen Ursprüngen, das ältere nach links oben versetzt (Maß Layout 02). Gegenprobe: zwei Medien im selben Aufruf (heute schon richtig).
    2. Den vorderen beantworten → der übrige rückt in die vordere Lage.
    3. Fokus: Das neu erscheinende Panel wird einmal Key. Ein weiterer `sync` ohne neues Panel (z. B. ein anderes Medium aushängen) ruft **kein** `makeKey`/`orderFront` für das offene Panel. Zählbar über einen Haken je Instanz, nicht über das echte Key-Fenster.
    4. Für alle vier Panels: `level == .normal`, `isFloatingPanel == false`.
  - **Patches (rot erwartet):**
    1. `bug.0.4.209-a.patch`: `makeKey` wieder bei jedem `sync`. Test 3 wird rot.
    2. `bug.0.4.209-b.patch`: `.floating` beim Erkennungs-Panel zurück. Test 4 wird rot.
    3. `bug.0.4.216-a.patch`: Lage wieder nur beim Anlegen. Test 1 wird rot.
  - **Status:** _(Worker)_

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; die neuen Suites und `IndexingWiringTests`, `RunLifecycleTests` 20× parallel grün. Rote Läufe zählen auch, wenn nur das Protokoll sie zeigt.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

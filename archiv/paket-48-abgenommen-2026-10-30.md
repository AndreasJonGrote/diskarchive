# Paket 48 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 30.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („Alles“) aus dem Backlog (Stufe 2 vom 27.10., Pakete 35 und 36) und Nutzer 29.10. (Fenstergröße per Screenshot).

## Abnahme Host 30.10. (Gesamtlauf 01:44–02:17)

- Diff gelesen: `AppWindowPresenter.initialMainWindowFrame(visible:)` (1258 × 770, mittig, je Achse begrenzt; mein Beispiel „1258 × 775“ war falsch, der Worker hat richtig 1258 × 770 getestet); `ColumnBrowserState.renameOpenFolder` (gleiche Zeile → Breiten bleiben); „Behalten“ je Paar im App-Zustand (`keptReplaceMediumPairs`, kein Schema); vor der Rückfrage gleichnamige Offline-Medien gegen noch nicht verarbeitete Einhängepfade prüfen (`getmntinfo` mit `MNT_NOWAIT`, `mediumIsMounted` abseits des Main Actors). Nichts Wesentliches. Stufe 3 (Worker): gemerkte Paare werden nie aufgeräumt → Backlog.
- Gesamtlauf bei Last 2,3: Debug und Release 0 Warnungen, seriell 1245/1245, parallel 3× grün (je 1239, 6 übersprungen), Sabotage 4/4 rot (050-a 2/2, 232-a, 233-a, 234-a je 1/1), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 02:17:16, Signatur gültig.
- Patches: `archiv/sabotage/paket-48/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (jetzt `archiv/sabotage/paket-48/`) (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `todo.0.4.050`, `bug.0.4.234`, `bug.0.4.232`, `bug.0.4.233`. **HALT.**

## Aufgaben

- **todo.0.4.050 — Erste Fenstergröße 1258 × 770 pt (Nutzer 29.10.):**
  - **Nutzer sieht:** Ohne gespeicherte Lage öffnet das Hauptfenster mit 1100 × 750; der Nutzer hat 1258 × 770 als beste Größe bestimmt (Screenshot, `NSWindow Frame DiskIndexMainWindow` = `391 547 1258 770`).
  - **Soll (Konzept `einstellungen-start.md`, Zeile „Fenster“):** `AppWindowPresenter.defaultMainWindowSize` (Z. ~14) = **1258 × 770** (Rahmen samt Titelleiste, wie heute in `centerMainWindowOnVisibleScreen` gesetzt). Mittig auf `visibleFrame`; ist die sichtbare Fläche kleiner, auf sie **begrenzt** (Breite und Höhe je für sich), Mindestgröße 720 × 480 bleibt. Eine gespeicherte Lage (Frame-Autosave) geht weiter vor.
  - **Gegenprobe:** Rahmenberechnung als reine Funktion von `visibleFrame`: 2560 × 1415 → 1258 × 770 mittig; 1280 × 775 → 1258 × 775 begrenzt, ganz sichtbar. **Patch** `todo.0.4.050-a.patch`: alte Größe 1100 × 750 → rot.
  - **Status:** Bereit zur Prüfung. Rot 01:34 (1100 × 750 statt 1258 × 770), grün 01:36.
    Fix: `defaultMainWindowSize` 1258 × 770; neue reine Funktion `AppWindowPresenter.initialMainWindowFrame(visible:)` (mittig, Breite/Höhe je für sich auf `visibleFrame` begrenzt), `centerMainWindowOnVisibleScreen` nutzt sie; Frame-Autosave geht weiter vor, Mindestgröße unverändert.
    Test: `MainWindowFrameTests` (2560 × 1415 → 1258 × 770 mittig; 1280 × 775 → 1258 × 770 ganz sichtbar – das Beispiel „1258 × 775“ im Paket wäre höher als 770, daher zusätzlich 1200 × 700 und 1440 × 720 als begrenzte Fälle).
    Suites: 31 betroffene 193/193 (01:38–01:39), Build 0 Warnungen; Sabotage gesamt 4/4 rot, 0 Mängel (01:39–01:41). Patch a rot 2/2.
    Selbstprüfung: nichts Wesentliches.

- **bug.0.4.234 — Gezogene Spaltenbreite fällt nach Umbenennen im Finder weg (Backlog 27.10., Paket 36):**
  - **Nutzer sieht:** Spalte breiter gezogen, dann einen geöffneten Ordner links davon im Finder umbenannt: Die Spalte springt auf 230 pt zurück.
  - **Wann:** Umbenennen eines geöffneten Ordners von außen, während die App ihn zeigt.
  - **Ursache:** `ColumnBrowserState.pathStack.didSet` (Z. ~10–17) vergleicht alten und neuen Pfad **nach Namen**; ein umbenannter Ordner gilt als anderer Pfad, die Breiten dahinter werden verworfen.
  - **Soll:** Eine Ebene gilt als gleich, wenn der Name gleich ist **oder** die bekannte Zeilenkennung (`openFolderRowIDs`, `bug.0.4.147`) gleich bleibt. Echter Wechsel in einen anderen Ordner verwirft die Breiten wie bisher (`bug.0.4.218`).
  - **Gegenprobe:** Test mit `ColumnBrowserState`: Breite für Spalte 2 gesetzt, Ordner der Ebene 1 umbenannt (gleiche Zeilenkennung) → Breite bleibt; anderer Ordner geöffnet → Breite weg. **Patch** `bug.0.4.234-a.patch`: nur Namen vergleichen → rot.
  - **Status:** Bereit zur Prüfung. Rot 01:34 (Breite nach Umbenennen 230 statt 380), grün 01:36.
    Fix: `ColumnBrowserState.renameOpenFolder(at:to:rowID:)`: gleiche Zeile (bekannte Kennung gleich oder unbekannt) → Breiten bleiben, andere bekannte Kennung → verworfen; `followOpenPathAfterReload` nutzt sie statt `pathStack[level] =`. `didSet` (bug.0.4.218) unverändert für echte Wechsel.
    Test: `ColumnWidthRenameTests` (umbenannt → bleibt; andere Kennung und anderer Ordner → weg).
    Suites: 31 betroffene 193/193 (01:38–01:39), Build 0 Warnungen; Sabotage gesamt 4/4 rot, 0 Mängel (01:39–01:41). Patch a rot 1/1.
    Selbstprüfung: nichts Wesentliches.

- **bug.0.4.232 — Nach „Behalten“ kommt die Rückfrage beim nächsten Anstecken wieder (Backlog 27.10., Paket 35):**
  - **Nutzer sieht:** „Ersetzt dieses Medium?“ mit „Behalten“ beantwortet, Erkennungsdialog danach offen gelassen (oder App beendet), Medium wieder angesteckt: wieder „Ersetzt dieses Medium?“ statt des Erkennungsdialogs.
  - **Wann:** Nur, wenn der Erkennungsdialog nach „Behalten“ unbeantwortet bleibt.
  - **Ursache:** `MediumCoordinator.resolveReplace` (Z. ~558) ruft bei „Behalten“ nur `requestDialog(newID, askReplace: false)`; gemerkt wird nichts. Beim nächsten Anstecken ist das Medium noch `undecided`, `requestDialog` fragt erneut (`AppState.offerReplaceMediumPrompt`, Z. ~188).
  - **Soll:** „Behalten“ gilt **dauerhaft für dieses Paar** (neues Medium, altes Medium): Danach erscheint für dieses neue Medium keine Rückfrage zu diesem alten mehr, nur der Erkennungsdialog. Ein **anderes** gleichnamiges Offline-Medium darf wieder fragen. Überlebt einen App-Neustart.
  - **Weg (Vorschlag, du entscheidest):** im App-Zustand (`AppStateStore`, schon persistent) oder als Feld am Medium; **kein neues Datenbankschema ohne Rückfrage** beim Host.
  - **Gegenprobe:** `RecognitionRig`: altes Medium „Stick“ offline, neues „Stick“ angesteckt → Rückfrage; „Behalten“; abziehen, anstecken → keine Rückfrage, Erkennungsdialog; nach Neustart des Rigs (gleicher Zustand) ebenso. **Patch** `bug.0.4.232-a.patch`: nichts merken → rot.
  - **Status:** Bereit zur Prüfung. Rot 01:34 (Rückfrage nach Wiederanstecken und nach Neustart wieder da), grün 01:36.
    Fix: „Behalten“ merkt das Paar (neu, alt) im App-Zustand (`AppStateStore`, Schlüssel `keptReplaceMediumPairs`, JSON-Liste) in `resolveReplaceMediumPrompt`; `offerReplaceMediumPrompt` zählt gemerkte Paare nicht mit. Kein Schema.
    Test: `ReplaceFirstTests/keepIsRememberedForThisPair` (Behalten, Dialog offen, ab-/anstecken, Neustart mit gleicher Datenbank und gleichem App-Zustand → nur Erkennungsdialog). Im Rig von `ReplaceFirstTests` (echte `AppState`-Ladung), nicht `RecognitionRig`.
    Suites: 31 betroffene 193/193 (01:38–01:39), Build 0 Warnungen; Sabotage gesamt 4/4 rot, 0 Mängel (01:39–01:41). Patch a rot 1/1.
    Selbstprüfung: nichts Wesentliches; Stufe 3: gemerkte Paare werden nie aufgeräumt (eine Zeile je „Behalten“).

- **bug.0.4.233 — Falsche Rückfrage beim Start mit zwei gleichnamigen Medien (Backlog 27.10., Paket 35):**
  - **Nutzer sieht:** App startet, während ein bekanntes und ein neues Medium mit gleichem Namen angeschlossen sind: „Ersetzt dieses Medium?“ zu einem Medium, das gerade angeschlossen ist.
  - **Wann:** Nur beim App-Start (oder Aufwachen) mit beiden zugleich, wenn das neue zuerst verarbeitet wird.
  - **Ursache:** `offerReplaceMediumPrompt` (Z. ~192) zählt alle Medien mit `connectionStatus == .offline`; das bekannte ist beim Start noch nicht als angeschlossen verbucht.
  - **Soll:** Kein „Ersetzt …?“ zu einem Medium, das in diesem Moment eingehängt ist. Weg (Vorschlag): beim Start zuerst alle bekannten Medien verbuchen, dann die neuen; oder in der Prüfung die eingehängten Volumes (`mediumByPath`) mitzählen. Du entscheidest.
  - **Gegenprobe:** `RecognitionRig`, Start mit zwei eingehängten Volumes gleichen Namens, das neue zuerst in der Liste → keine Rückfrage, Erkennungsdialog für das neue; das bekannte ist angeschlossen. **Patch** `bug.0.4.233-a.patch`: alte Prüfung → rot.
  - **So lassen (für das ganze Paket):** Stapel und Fokus der Dialoge (`bug.0.4.209`, `221`, `223`), „Altes vergessen“-Weg (`bug.0.4.215`), Spaltenbreiten sonst (`bug.0.4.218`). Kein neues Schema (vorher fragen).
  - **Status:** Bereit zur Prüfung. Rot 01:34 (Rückfrage zum eingehängten bekannten Medium), grün 01:36.
    Fix: `MediumCoordinator.requestDialogCheckingNamesakes` vor `requestDialog` in `connectKnown`/`storeAndPresent`: gleichnamige Offline-Medien gegen noch nicht verarbeitete Pfade (`mountedVolumePaths`, `getmntinfo`) über `access.mediumIsMounted` prüfen (abseits des Main Actors, Zeitgrenze); eingehängte zählen in `offerReplaceMediumPrompt(mountedIDs:)` nicht. Nur bei Namensgleichheit; unter Tests ist die Pfadliste leer (Test setzt sie).
    Test: `ReplaceFirstTests/startWithBothNamesakesMountedAsksNothing` (neues zuerst, bekanntes unter „USB 1“ eingehängt → keine Rückfrage, Erkennungsdialog; danach bekanntes angeschlossen).
    Suites: 31 betroffene 193/193 (01:38–01:39), Build 0 Warnungen; Sabotage gesamt 4/4 rot, 0 Mängel (01:39–01:41). Patch a rot 1/1.
    Selbstprüfung: nichts Wesentliches.

# Paket 48 — Zielversion 0.4.0 (freigegeben 29.10.2026, nach Abnahme von Paket 47)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („Alles“) aus dem Backlog (Stufe 2 vom 27.10., Pakete 35 und 36) und Nutzer 29.10. (Fenstergröße per Screenshot).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `todo.0.4.050`, `bug.0.4.234`, `bug.0.4.232`, `bug.0.4.233`. **HALT.**

## Aufgaben

- **todo.0.4.050 — Erste Fenstergröße 1258 × 770 pt (Nutzer 29.10.):**
  - **Nutzer sieht:** Ohne gespeicherte Lage öffnet das Hauptfenster mit 1100 × 750; der Nutzer hat 1258 × 770 als beste Größe bestimmt (Screenshot, `NSWindow Frame DiskIndexMainWindow` = `391 547 1258 770`).
  - **Soll (Konzept `einstellungen-start.md`, Zeile „Fenster“):** `AppWindowPresenter.defaultMainWindowSize` (Z. ~14) = **1258 × 770** (Rahmen samt Titelleiste, wie heute in `centerMainWindowOnVisibleScreen` gesetzt). Mittig auf `visibleFrame`; ist die sichtbare Fläche kleiner, auf sie **begrenzt** (Breite und Höhe je für sich), Mindestgröße 720 × 480 bleibt. Eine gespeicherte Lage (Frame-Autosave) geht weiter vor.
  - **Gegenprobe:** Rahmenberechnung als reine Funktion von `visibleFrame`: 2560 × 1415 → 1258 × 770 mittig; 1280 × 775 → 1258 × 775 begrenzt, ganz sichtbar. **Patch** `todo.0.4.050-a.patch`: alte Größe 1100 × 750 → rot.
  - **Status:**

- **bug.0.4.234 — Gezogene Spaltenbreite fällt nach Umbenennen im Finder weg (Backlog 27.10., Paket 36):**
  - **Nutzer sieht:** Spalte breiter gezogen, dann einen geöffneten Ordner links davon im Finder umbenannt: Die Spalte springt auf 230 pt zurück.
  - **Wann:** Umbenennen eines geöffneten Ordners von außen, während die App ihn zeigt.
  - **Ursache:** `ColumnBrowserState.pathStack.didSet` (Z. ~10–17) vergleicht alten und neuen Pfad **nach Namen**; ein umbenannter Ordner gilt als anderer Pfad, die Breiten dahinter werden verworfen.
  - **Soll:** Eine Ebene gilt als gleich, wenn der Name gleich ist **oder** die bekannte Zeilenkennung (`openFolderRowIDs`, `bug.0.4.147`) gleich bleibt. Echter Wechsel in einen anderen Ordner verwirft die Breiten wie bisher (`bug.0.4.218`).
  - **Gegenprobe:** Test mit `ColumnBrowserState`: Breite für Spalte 2 gesetzt, Ordner der Ebene 1 umbenannt (gleiche Zeilenkennung) → Breite bleibt; anderer Ordner geöffnet → Breite weg. **Patch** `bug.0.4.234-a.patch`: nur Namen vergleichen → rot.
  - **Status:**

- **bug.0.4.232 — Nach „Behalten“ kommt die Rückfrage beim nächsten Anstecken wieder (Backlog 27.10., Paket 35):**
  - **Nutzer sieht:** „Ersetzt dieses Medium?“ mit „Behalten“ beantwortet, Erkennungsdialog danach offen gelassen (oder App beendet), Medium wieder angesteckt: wieder „Ersetzt dieses Medium?“ statt des Erkennungsdialogs.
  - **Wann:** Nur, wenn der Erkennungsdialog nach „Behalten“ unbeantwortet bleibt.
  - **Ursache:** `MediumCoordinator.resolveReplace` (Z. ~558) ruft bei „Behalten“ nur `requestDialog(newID, askReplace: false)`; gemerkt wird nichts. Beim nächsten Anstecken ist das Medium noch `undecided`, `requestDialog` fragt erneut (`AppState.offerReplaceMediumPrompt`, Z. ~188).
  - **Soll:** „Behalten“ gilt **dauerhaft für dieses Paar** (neues Medium, altes Medium): Danach erscheint für dieses neue Medium keine Rückfrage zu diesem alten mehr, nur der Erkennungsdialog. Ein **anderes** gleichnamiges Offline-Medium darf wieder fragen. Überlebt einen App-Neustart.
  - **Weg (Vorschlag, du entscheidest):** im App-Zustand (`AppStateStore`, schon persistent) oder als Feld am Medium; **kein neues Datenbankschema ohne Rückfrage** beim Host.
  - **Gegenprobe:** `RecognitionRig`: altes Medium „Stick“ offline, neues „Stick“ angesteckt → Rückfrage; „Behalten“; abziehen, anstecken → keine Rückfrage, Erkennungsdialog; nach Neustart des Rigs (gleicher Zustand) ebenso. **Patch** `bug.0.4.232-a.patch`: nichts merken → rot.
  - **Status:**

- **bug.0.4.233 — Falsche Rückfrage beim Start mit zwei gleichnamigen Medien (Backlog 27.10., Paket 35):**
  - **Nutzer sieht:** App startet, während ein bekanntes und ein neues Medium mit gleichem Namen angeschlossen sind: „Ersetzt dieses Medium?“ zu einem Medium, das gerade angeschlossen ist.
  - **Wann:** Nur beim App-Start (oder Aufwachen) mit beiden zugleich, wenn das neue zuerst verarbeitet wird.
  - **Ursache:** `offerReplaceMediumPrompt` (Z. ~192) zählt alle Medien mit `connectionStatus == .offline`; das bekannte ist beim Start noch nicht als angeschlossen verbucht.
  - **Soll:** Kein „Ersetzt …?“ zu einem Medium, das in diesem Moment eingehängt ist. Weg (Vorschlag): beim Start zuerst alle bekannten Medien verbuchen, dann die neuen; oder in der Prüfung die eingehängten Volumes (`mediumByPath`) mitzählen. Du entscheidest.
  - **Gegenprobe:** `RecognitionRig`, Start mit zwei eingehängten Volumes gleichen Namens, das neue zuerst in der Liste → keine Rückfrage, Erkennungsdialog für das neue; das bekannte ist angeschlossen. **Patch** `bug.0.4.233-a.patch`: alte Prüfung → rot.
  - **So lassen (für das ganze Paket):** Stapel und Fokus der Dialoge (`bug.0.4.209`, `221`, `223`), „Altes vergessen“-Weg (`bug.0.4.215`), Spaltenbreiten sonst (`bug.0.4.218`). Kein neues Schema (vorher fragen).
  - **Status:**

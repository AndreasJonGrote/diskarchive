# Paket 55 — Zielversion 0.4.2 (freigegeben 31.10., abgenommen 31.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12). Herkunft: Nutzer 31.10. („Kontextmenü bei Medien zeigt ‚Benennen‘, der Name in der Kachel wird zum Input, der Originalname steht ab dem ersten Buchstaben darunter; dasselbe in der Medienliste der Spaltenansicht“). Konzept: `konzept/medien.md` 2d. Baut auf `todo.0.4.2.002` (Paket 52, abgenommen) auf: Speicher, `Medium.normalizedCustomName`, `AppState.setCustomName`, `MediumCustomNameField` gibt es schon.

**Kein Layout.** Optik aus dem Bestand: Schrift, Größe, Farbe und Position des Titels bleiben, er wird nur zum Eingabefeld (ohne eigenen Rahmen; Hintergrund wie das Feld im Details-Modal, `DesignColor.surface`, Rand `DesignColor.divider`, Radius `DesignRadius.sm`). Kein Sprung der übrigen Kachelinhalte außer der zweiten Zeile.

**Für jede Aufgabe gilt:**
- Der Test ist vor der Änderung rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung (Regel 12), Fenster-Tests im echten Fenster (Regel 10). Nur die betroffenen Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Gesamtlauf, kein Git.
- Neue Texte immer de und en, im Status unter „Neue Texte:“.

**Reihenfolge (HALT am Ende):** `todo.0.4.2.005`. **HALT.**

## Aufgaben

- **todo.0.4.2.005 — „Benennen“ im Kontextmenü der Medien, Bearbeitung an Ort und Stelle (Nutzer 31.10.):**
  - **Menü:** Im Medien-Kontextmenü (`ObjectFileContextMenu.swift`, erste Gruppe für `kind == .medium`, Z. ~40–52) nach „Details“ ein Eintrag **„Benennen“** (Icon Phosphor `PencilSimple` bzw. vorhandenes Stift-Icon, sonst fragen). Ausgegraut, wenn `featureAccess.canWriteIndex` falsch ist. Gilt für online und offline.
  - **Wo der Eintrag was tut:** Der Aufrufer sagt, ob er an Ort und Stelle bearbeiten kann.
    1. **Dashboard-Kachel** (`MediumDashboardCard`): Titel wird zum Eingabefeld (15 pt fett, einzeilig, volle Breite des Titels).
    2. **Medienliste der Spaltenansicht** (Seitenleiste, `ColumnBrowserView` Z. ~298–315): Zeilentitel wird zum Eingabefeld (Schrift der Zeile).
    3. **Alle anderen Stellen** (Medien-Kacheln der Suche, Einstellungen → Speichermedien, Menüleiste): öffnet das **Details-Modal** (`MediumNavigation.openDetails`, aus der Menüleiste wie „Details“ mit Hauptfenster), Fokus im Feld „Eigener Name“, Inhalt ganz markiert.
  - **Verhalten beim Bearbeiten (1 und 2):**
    - Startwert: der angezeigte Name (`shownName`), **ganz markiert**, Fokus im Feld.
    - **Ab dem ersten getippten Zeichen** (Text weicht vom Startwert ab) steht darunter der **Originalname** wie in der Kachel heute (11 pt, Textfarbe 50 %, Abstand 2 pt, auslaufend). Hat das Medium schon einen eigenen Namen, steht die zweite Zeile in der Kachel ohnehin da und bleibt. In der Seitenleiste wird die Zeile dafür höher, solange bearbeitet wird; danach wieder einzeilig (Original weiter nur im Tooltip).
    - **Enter** oder **Klick daneben** (Fokus weg) übernimmt über `AppState.setCustomName` (leer oder gleich Original → eigener Name weg). **Escape** bricht ab, nichts gespeichert.
    - Während der Bearbeitung löst ein Klick ins Feld nicht die Aktion der Kachel bzw. Zeile aus (kein Öffnen, kein Auswahlwechsel); Tastenkürzel der Spaltenansicht (Pfeiltasten, Leertaste) wirken nicht ins Feld hinein.
    - Höchstens 100 Zeichen wie im Details-Modal. Gleiche Normalisierung, keine zweite Logik (Regel 7).
    - Nur eine Bearbeitung zur Zeit; öffnet der Nutzer „Benennen“ an einem anderen Medium, wird die laufende übernommen.
  - **Neue Texte:** `Benennen` / `Set name`.
  - **Gegenprobe (echtes Fenster, Regel 10):**
    1. Kachel ohne eigenen Namen: Kontextmenü → „Benennen“ → Feld mit Originalname, markiert; noch keine zweite Zeile. Ein Zeichen tippen → zweite Zeile mit Originalname. „Laura“ + Enter → Titel „Laura“, darunter Original; `storage_meta.customName` = „Laura“.
    2. Escape nach dem Tippen → alter Name, kein Schlüssel geschrieben.
    3. Feld leeren + Enter → Originalname, Schlüssel weg, Kachel einzeilig wie vorher.
    4. Seitenleiste: „Benennen“ → Feld in der Zeile, Zeile nach dem ersten Zeichen höher mit Original darunter; Enter → einzeilig mit neuem Namen; Pfeiltasten im Feld bewegen den Cursor, nicht die Auswahl.
    5. Suche-Kachel / Einstellungen: „Benennen“ öffnet das Details-Modal, Fokus im Feld „Eigener Name“.
    6. Schreibsperre: Eintrag ausgegraut.
    7. `EnglishLocalizationTests` grün.
  - **Patches (rot erwartet):** `-a`: zweite Zeile erscheint schon vor dem ersten Zeichen → Test 1 rot. `-b`: Escape speichert → Test 2 rot. `-c`: Seitenleiste wechselt bei Pfeiltaste die Auswahl → Test 4 rot.
  - **So lassen:** Feld im Details-Modal, Speicherung (`storage_meta`), Erkennung und Rückfragen mit dem Originalnamen, alle anderen Einträge des Kontextmenüs, Kachelhöhe ohne eigenen Namen.
  - **Status:** Eintrag „Benennen“ (`IconPencilSimple`, Phosphor Regular, vom Nutzer freigegeben) nach „Details“; Ort über `objectContextMenu(…, namingPlace:)` → `AppState.beginNaming`/`mediumNaming`; neues `MediumNameEditor` (Kachel, Seitenleiste; Zeilenhöhe wie der Titel), sonst Details-Modal mit Fokus (`MediumCustomNameField.task`). Speichern nur über `setCustomName`.
    Rot 11:53 (Stummel: Eintrag ohne Wirkung, nie gesperrt; 6 Tests, 7 Fehler), grün 11:52/12:03 `MediumNamingTests` (6 Tests, Gegenprobe 1–6); 39 betroffene Suites 11:56–11:58 grün (144 Tests, mit `EnglishLocalizationTests`), 0 Warnungen. 20× parallel 12:06–12:10: 0 Fehler. Sabotage `-a`…`-e` rot (12:03–12:06), `-d` (Klick öffnet Kachel), `-e` (Fokus im Modal) zusätzlich.
    Klick „während der Bearbeitung“ im Test auf die Kachelfläche statt ins Feld (AppKit-Maus-Schleife im Textfeld endet im Test nie), mit Positivprobe. Klick daneben über vorhandenes `onClickOutside` (verschluckt den Klick wie beim Filter-Panel).
    Neue Texte: `copy.context.set_name` „Benennen“ / „Set name“. Selbstprüfung (Sonnet): nichts Wesentliches; Stufe 3: Ort `.detailsModal` bleibt stehen, wenn das Modal schon offen ist (nächstes „Details“ fokussiert das Feld).
    Bereit zur Prüfung.

## Abnahme Host 31.10. (Gesamtlauf 12:23–12:58)

- Diff gelesen: nichts Wesentliches.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1277/1277, parallel 3× grün (je 1270, 7 übersprungen), Sabotage 6/6 rot (004-a, 005-a…e), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 12:57:58, Version 0.4.1.
- Patches: `archiv/sabotage/paket-55/`.

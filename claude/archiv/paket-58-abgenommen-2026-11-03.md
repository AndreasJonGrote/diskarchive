# Paket 58 — Zielversion 0.4.3 (freigegeben und abgenommen 03.11.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. Herkunft: Layout-Abgleich 01.–03.11. ([docs/layout-abgleich-2026-11-01.md](../docs/layout-abgleich-2026-11-01.md)), Entscheidungen des Nutzers im Backlog 0.4.3. **Erstes von sechs Paketen für 0.4.3** (Plan in TODO.md).

**Für dieses Paket gilt:**
- **Textquelle ist `layout/App-Layout 20 Texte.json`** (Sektion 20, Deutsch und Englisch, 348 Texte). Bei Abweichung zwischen Layout-Screen und 20 gilt 20. Texte nie selbst formulieren oder übersetzen; fehlt einer, „Frage:“ (Regel 2). Platzhalter `{1}`, `{2}` in 20 entsprechen `%1$@` usw. im Katalog.
- **Nur Texte bestehender Stellen** und die unten genannten Fehler. Neue Screens, Kacheln, Banner, Details-Fenster, Spaltenzustände kommen in den Paketen 59–62; deren Texte bleiben bis dahin, wie sie sind.
- Sabotage-Patch (Regel 9) nur für die Verhaltensänderungen in Aufgabe 3 und 4. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git.
- Englisch nach den Regeln von macOS: Knöpfe und Menüs groß („Show in Finder“), Sätze und Status klein. Weicht 20 davon ab (z. B. „6 Months“), so übernehmen, wie es in 20 steht, und im Status nennen.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.005` → `todo.0.4.3.006` → `bug.0.4.3.003` → `bug.0.4.2.001` → `bug.0.4.3.001`. **HALT.**

## Aufgaben

- **todo.0.4.3.005 — Texttest auf Sektion 20 und Texte bestehender Stellen:**
  - **Test zuerst:** `LayoutCopyTests` liest statt der Layout-HTML-Dateien `layout/App-Layout 20 Texte.json`. Neue Prüfung je Katalog-Schlüssel in `Localizable.xcstrings`: Der deutsche Wert steht in 20 (Platzhalter gleichgesetzt) **und** der englische Wert ist der zu diesem deutschen Text in 20. Schlüssel, deren Text erst in einem späteren Paket kommt, stehen in einer Liste `pendingPackage: [String: Int]` (Schlüssel → Paketnummer 59–62) mit Kommentar; jedes Paket leert seinen Teil. Am Ende von 0.4.3 ist die Liste leer. Den bisherigen HTML-Abgleich (`windowLines`, `notYetReleased`, `differsFromApp`) entfernen.
  - **Texte, die dieses Paket ändert** (Deutsch und Englisch je aus 20):
    - Erkennungsdialog ohne Medientyp: „„{1}“ ({2}) wurde angeschlossen. Soll sie indiziert werden?“ (Typ-Platzhalter entfällt; `copy.new_medium.body` und Aufruf).
    - Offline-Balken der Spaltenansicht nur „Offline“ (`copy.column.offline_banner`).
    - Suche leer: „Keine Suchergebnisse“ + „Suchbegriff ändern oder Filter entfernen.“ (ersetzt „Keine Ergebnisse für „…““ und „Keine Treffer für die gesetzten Filter“).
    - Favoriten leer: „Keine Favoriten“ + „Keine Favoriten in dieser Auswahl. Wähle „Alle“ oder markiere Objekte über das Kontextmenü als Favorit.“ (ersetzt beide alten Texte).
    - Platzhalter mit Leerzeichen vor „…“: „Suchen …“, „Name, Endung (*.log) oder Ordner …“ und alle weiteren laut 20.
    - Einstellungen › Allgemein: Sprache „Die Änderung gilt sofort, ohne Neustart.“, Updates „Ist eine neue Version von Disk Archive verfügbar, erscheint ein Dialog mit allen Details zum Update.“, Mitteilungen (Systemmeldungen-Text, Nachsatz, Vorschau-Beispiele mit „Masterarbeit Backup“/„Unterwegs“) laut 20.
    - macOS-Mitteilungen laut 18/20, u. a. mit Schlusspunkt; Favoriten-Mitteilung mit Einzahl „1 Favoriten“ und Mehrzahl.
    - Grund f im Indizierungsfehler: „Der Index auf diesem Mac lässt sich gerade nicht beschreiben.“ (`copy.failure.database`).
    - Einzahlformen laut 20 („1 Datei“, „1 Speichermedium“, „1 Favorit“, „1 Vorschau“, „1 Ergebnis anzeigen“, „Dein 1 Speichermedium und {2} Dateien werden durchsucht …/gefiltert …“), soweit die Stelle heute schon zählt.
    - Spaltenkopf bei Filter „{1} · {2} von {3}“ (Englisch „of“).
    - Alle übrigen Schlüssel, deren deutscher Text schon gleich ist, nur das Englisch aus 20 (Test zeigt sie).
  - **So lassen (spätere Pakete, in `pendingPackage`):** Kachel-Texte und „Kein Zugriff …“ (59), Details-Fenster und Benennen (59), Popover-Suche/-Leerzustände/Status (60), Spaltenansicht-Zustände, Detail-Labels, Einstellungen Dateien & Ordner (61), Banner, Update-Countdown, Fehlerdialoge, Über (62).
  - **Akzeptanz:** `LayoutCopyTests`, `EnglishLocalizationTests`, `L10nTests`, `NoGermanLiteralsTests` grün; im Status Anzahl Schlüssel in `pendingPackage` je Paket.
  - **Status:** Bereit zur Prüfung.
    - **Test:** `LayoutCopyTests.catalogTextsMatchSectionTwenty` liest die JSON. Platzhalter werden ohne Nummer verglichen, weil „Dein 1 Speichermedium und {2} …“ im Katalog nur ein Argument hat; Leerzeichen am Rand zählen nicht („ belegt“). Der HTML-Abgleich ist entfernt. Rot 00:41 (30 Abweichungen), grün 00:54.
    - **`pendingPackage` je Paket:** 59: 7, 60: 3, 61: 14, 62: 5. Dazu `openQuestions` (4 Schlüssel, Fragen unten).
    - **Texte:** alle laut 20, Englisch für 5 Schlüssel nachgezogen (u. a. „Folder“, „Show Contents“, „Drive“). Neue Schlüssel: `copy.search.no_results.title/.message`, `copy.loading.search/favorites.one/.other`, `copy.notice.favorites_online_one`, `copy.medium.files_count_one` („1 Datei“), `copy.settings.notices.text` (ersetzt drei Teile). Die Vorschau baut sich aus der Mitteilung („Masterarbeit Backup“, 48.210; „Unterwegs“, 1). „Suche leer“ und „Favoriten leer“ (Tabelle) zeigen den Leerzustand aus Layout 10/11 (Icons, Titel, Hinweis). Platzhalter „Suchen…“ usw. sind in 20 ohne Leerzeichen, daher unverändert.
    - **Läufe:** 01:03–01:05: 286 Tests in 53 Suites grün, dazu 01:06: 39 Tests in 10 Suites grün; 0 Warnungen.

- **todo.0.4.3.006 — Entfallene Funktionen (Nutzer 02.11., E2–E4, Spalte „Typ“):**
  - Menüpunkt „Protokoll im Finder zeigen“ im Menü des Menüleisten-Icons weg (`MenuBarController`, `LayoutCopy+Menus`); das Menü hat danach genau „Disk Archive anzeigen“ · „Automatisch bei Systemstart“ · „Einstellungen …“ · „Disk Archive beenden“ (Layout 01.01).
  - Rückfrage „{n} Einträge ignorieren?“ weg: Ignorieren mehrerer Objekte wirkt sofort wie bei einem (Layout 12); `IgnoreConfirmDialog` und Aufruf in `AppWindowPresenter` entfernen.
  - Einstellung „Dateityp-Filter in der Spaltenansicht“ (Titel, Text, Steuerung) aus Einstellungen › Dateien & Ordner entfernen; das Verhalten bleibt wie heute fest (leise Ordner, `todo.0.4.2.003`). Ein gespeicherter Wert wird nicht mehr gelesen (keine Übernahme, Beta).
  - Spalte „Typ“ in Einstellungen › Speichermedien entfernen (Layout 05: Name, Status, Zuletzt gesehen, Dateien – die Spalte „Zuletzt gesehen“ selbst kommt in Paket 61).
  - Nicht mehr benutzte Katalogtexte löschen.
  - **Akzeptanz:** betroffene Suites grün; Status nennt entfernte Dateien und Schlüssel.
  - **Status:** Bereit zur Prüfung. Das Menü der Menüleiste hat genau die vier Einträge aus Layout 01.01. Dafür ist „Über Disk Archive“ entfallen und „Einstellungen …“ hinzugekommen; „Über“ bleibt im App-Menü (Paket 62).
    - **Rückfrage:** `IgnoreConfirmDialog.swift` ist gelöscht, dazu `requestIgnore`/`resolveIgnoreConfirmation`, `IgnoreConfirmationPrompt` und die Panels in `AppWindowPresenter`. Das Kontextmenü ruft `toggleIgnoredPatterns` auf; `IgnoreConfirmationTests` prüft jetzt 600 Ziele sofort.
    - **Einstellungen:** `showFoldersRegardlessOfFilter` ist aus `AppSettings`/`PersistedAppSettings` entfernt; alte Einträge lesen weiter. Die Spalte „Typ“ ist aus der Medienliste entfernt (`RegistrySortColumn.type`, `typeWidth`), ebenso `DiskArchiveLog.revealInFinder`.
    - **Gelöschte Schlüssel:** `copy.ignore_confirm.title`, `copy.menubar.reveal_log`, `copy.settings.column_filter.title/.text`, `copy.table.column.type`.

- **bug.0.4.3.003 — Details-Fenster: feste deutsche Wörter und Medientyp** (Backlog 0.4.3): `Medium+Detail.swift` `connectionDescription` nennt den Typ nicht mehr und nimmt „angeschlossen“/„offline“ aus dem Katalog (Wortlaut der Kopfzeile laut 06/20; der Rest des Details-Fensters kommt in Paket 59). Test: Englisch ohne deutsche Wörter, beide Sprachen ohne HDD/SSD/USB. Sabotage-Patch.
  - **Status:** Bereit zur Prüfung. `connectionDescription` liefert jetzt nur „Online“/„Offline“ aus dem Katalog (`copy.chip.online/offline`), ohne Typ. In Layout 06 hat die Kopfzeile gar keine zweite Zeile; das entscheidet Paket 59. Test `MediumDetailHeaderTests` rot 00:55 (33 Meldungen), grün 00:56. Patch `bug.0.4.3.003.patch`, im Sabotage-Lauf 01:08 rot.

- **bug.0.4.2.001 — Bild-Filter mit `.cr3` und weiteren RAW-Endungen** (Backlog 0.4.3, Vorschlag Host dort): eine gemeinsame Liste der Bild-Endungen für Filter (`SearchState.swift` ~103) und Icons (`FileTypeIcon.swift` ~51), Vorschlag-Liste aus dem Backlog. Test: `.cr3`, `.raf`, `.arw` werden als Bild gefiltert und zeigen das Bild-Icon. Sabotage-Patch.
  - **Status:** Bereit zur Prüfung. Eine Quelle für Filter und Icon: `SearchFileTypeFilter.imageExtensions/videoExtensions/audioExtensions` mit der ganzen Vorschlagsliste aus dem Backlog (auch Video/Audio), `FileKind` liest sie. Test `RawImageExtensionTests`: `.cr3/.raf/.arw` als Bild, dazu ein Abgleich Filter = Icon. Rot 00:58, grün 00:59. Patch `bug.0.4.2.001.patch`, im Sabotage-Lauf 01:07 rot.

- **bug.0.4.3.001 — Fokusrahmen auf „Für dieses Medium merken“** (Backlog 0.4.3): Öffnet ein Klick auf die Kachel den Erkennungsdialog, hat die Checkbox keinen Fokusrahmen; Tastatur-Fokus bleibt bedienbar (Tab). Ursache im Status nennen. Test, wo möglich; sonst Beleg im Status. Sabotage-Patch, falls testbar.
  - **Status:** Bereit zur Prüfung.
    - **Ursache:** Das Erkennungs-Panel lag ohne Responder vor (Responder war das Fenster selbst). Die anderen Dialoge setzen ihn in `show` auf den Inhalt. Fehlt er, wählt AppKit beim Key-Werden das erste fokussierbare Element, hier den Haken.
    - **Fix:** `makeNewMediumPanel` setzt `makeFirstResponder(hosting)`.
    - **Test:** `PromptFocusStackTests.newMediumPanelStartsOnTheContentViewLikeTheOtherDialogs` über `openNewMedium` (Kachel), Gegenprobe Ersetzen. Rot 01:01, grün 01:02. Patch `bug.0.4.3.001.patch`, im Sabotage-Lauf 01:08 rot.
    - **Nicht im Test belegt:** der sichtbare Rahmen selbst (Key-Fenster ist im Test verboten); Nachtest in der App.
  - **Frage:** 05 Mitteilungen: Der deutsche Text in 20 enthält „Alle Mitteilungstexte und Bedingungen: 18.“, ein Verweis auf die Layout-Sektion; im Englischen fehlt der Satz. Die App zeigt ihn nicht (`openQuestions`). Bleibt das so?
  - **Frage:** Reiter „Speichermedien“ (`copy.settings.tab.media`): In 20 gibt es nur die Überschrift „SPEICHERMEDIEN“. Text und Englisch „Storage media“ bleiben. Passt das?
  - **Frage:** `copy.a11y.overview` („Übersicht“, Bedienhilfe der Werkzeugleiste) und `copy.settings.unreadable.notice` („Einstellungen konnten nicht gelesen werden …“) stehen nicht in 20. Sie bleiben; welches Paket übernimmt sie?
  - **Frage:** Ladeansicht laut 20 „Dein 1 Speichermedium und {2} Dateien …“: Bei genau einer Datei steht jetzt „1 Dateien“ (früher „1 Datei“). Braucht 20 dafür eine Einzahl?

## Abnahme Host 03.11. (Gesamtlauf 01:23–01:57)

- Diff gelesen: fünf Aufgaben wie beschrieben; Texttest prüft jeden Katalog-Schlüssel DE/EN gegen 20 (offen: 59: 7, 60: 3, 61: 14, 62: 5, dazu 4 `openQuestions`). Menü der Menüleiste mit den vier Einträgen aus 01.01 („Über“ bleibt im App-Menü). Nichts Wesentliches.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1272/1272, parallel 3× grün (je 1265, 7 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, Sabotage 3/3 rot ✓, App des Nutzers 01:57:07, Version 0.4.2.
- **Antworten auf die Fragen:** (1) „Alle Mitteilungstexte und Bedingungen: 18.“ ist ein Layout-Verweis, kein App-Text – App zeigt ihn nicht; Nutzer streicht ihn in 20. (2) Reiter „Speichermedien“ bleibt (in 20 als „SPEICHERMEDIEN“). (3) `copy.a11y.overview` → „Zur Übersicht“ aus 20 in Paket 60; `copy.settings.unreadable.notice` in Paket 61 (Nutzer nimmt den Satz in 20 auf). (4) „1 Dateien“ in der Ladeansicht: in Paket 59 wieder aus Teilen mit „1 Datei“ zusammensetzen (Stufe 3, nebenbei).
- **Für Paket 59 vermerkt:** Dashboard-Kachel schreibt noch den Medientyp als Text (`Medium.specLine`, `dashboardSpecLine`) – entfällt mit der neuen Kachel.
- Nachtest des Nutzers: Fokusrahmen im Erkennungsdialog (Kachel klicken), Menü der Menüleiste (Rechtsklick).

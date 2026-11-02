# Paket 58 — Zielversion 0.4.3 (freigegeben 03.11.2026)

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
  - **Status:**

- **todo.0.4.3.006 — Entfallene Funktionen (Nutzer 02.11., E2–E4, Spalte „Typ“):**
  - Menüpunkt „Protokoll im Finder zeigen“ im Menü des Menüleisten-Icons weg (`MenuBarController`, `LayoutCopy+Menus`); das Menü hat danach genau „Disk Archive anzeigen“ · „Automatisch bei Systemstart“ · „Einstellungen …“ · „Disk Archive beenden“ (Layout 01.01).
  - Rückfrage „{n} Einträge ignorieren?“ weg: Ignorieren mehrerer Objekte wirkt sofort wie bei einem (Layout 12); `IgnoreConfirmDialog` und Aufruf in `AppWindowPresenter` entfernen.
  - Einstellung „Dateityp-Filter in der Spaltenansicht“ (Titel, Text, Steuerung) aus Einstellungen › Dateien & Ordner entfernen; das Verhalten bleibt wie heute fest (leise Ordner, `todo.0.4.2.003`). Ein gespeicherter Wert wird nicht mehr gelesen (keine Übernahme, Beta).
  - Spalte „Typ“ in Einstellungen › Speichermedien entfernen (Layout 05: Name, Status, Zuletzt gesehen, Dateien – die Spalte „Zuletzt gesehen“ selbst kommt in Paket 61).
  - Nicht mehr benutzte Katalogtexte löschen.
  - **Akzeptanz:** betroffene Suites grün; Status nennt entfernte Dateien und Schlüssel.
  - **Status:**

- **bug.0.4.3.003 — Details-Fenster: feste deutsche Wörter und Medientyp** (Backlog 0.4.3): `Medium+Detail.swift` `connectionDescription` nennt den Typ nicht mehr und nimmt „angeschlossen“/„offline“ aus dem Katalog (Wortlaut der Kopfzeile laut 06/20; der Rest des Details-Fensters kommt in Paket 59). Test: Englisch ohne deutsche Wörter, beide Sprachen ohne HDD/SSD/USB. Sabotage-Patch.
  - **Status:**

- **bug.0.4.2.001 — Bild-Filter mit `.cr3` und weiteren RAW-Endungen** (Backlog 0.4.3, Vorschlag Host dort): eine gemeinsame Liste der Bild-Endungen für Filter (`SearchState.swift` ~103) und Icons (`FileTypeIcon.swift` ~51), Vorschlag-Liste aus dem Backlog. Test: `.cr3`, `.raf`, `.arw` werden als Bild gefiltert und zeigen das Bild-Icon. Sabotage-Patch.
  - **Status:**

- **bug.0.4.3.001 — Fokusrahmen auf „Für dieses Medium merken“** (Backlog 0.4.3): Öffnet ein Klick auf die Kachel den Erkennungsdialog, hat die Checkbox keinen Fokusrahmen; Tastatur-Fokus bleibt bedienbar (Tab). Ursache im Status nennen. Test, wo möglich; sonst Beleg im Status. Sabotage-Patch, falls testbar.
  - **Status:**

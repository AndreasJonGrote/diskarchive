# Paket 61 — Zielversion 0.4.3 (vorbereitet 03.11.2026; freigegeben, sobald Paket 60 abgenommen ist)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Viertes von sechs Paketen für 0.4.3: Spaltenansicht, Einstellungen, Schrift.** Vorlage: Layout 05 (05.01–05.03, 05.08, 05.08a, 05.10), 07 (07.01–07.03), 08 (08.01–08.03), 19 („Kernkonzept“, „Tooltips und Einzahl“, Dateidetails, Tabellen-Regel). Nutzerentscheidungen: Backlog 0.4.3.

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`**; die 14 Schlüssel mit `pendingPackage = 61` und die vorläufigen Texte aus Paket 59 (`copy.medium.used` → „Belegt“, `copy.eject.failed` → Text aus 16.02 mit Knopf „Erneut versuchen“) sowie `copy.settings.unreadable.notice` auf 20 bringen und aus `pendingPackage`/`openQuestions` nehmen.
- **Icons** aus `Werkzeuge/phosphor/`, **Schrift** aus `Werkzeuge/fonts/archivo/` (Regel 4a). Maße und Farben aus dem Layout; Fade erst am Ende.
- **Nicht in 0.4.3** (bleiben in der App verborgen, auch wenn das Layout sie zeigt): Reiter „Systeminformationen“ (05.04, ohne Zielversion) und „Lizenz“ (05.05–05.07, ab 1.0); Schalter „Metadaten laden“ und „Vorschaubilder erzeugen“ (05.01, ab 0.5/0.6); Metadaten-Felder, Vorschau und die Zustände 07.04.10–13 (ab 0.5/0.6).
- Sabotage-Patch (Regel 9) je Verhaltensänderung. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git. **Vor „Bereit zur Prüfung“** alle Suites mit `Column`, `Settings`, `Registry`, `Filter`, `Detail`, `Folder`, `Pixel`, `Layout` oder `L10n` im Namen.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.016` → `todo.0.4.3.017` → `todo.0.4.3.018` → `todo.0.4.3.019` → `todo.0.4.3.023`. **HALT.**

## Aufgaben

- **todo.0.4.3.016 — Zustände der Spaltenansicht (07.02, 07.03, 08):**
  - Statt einer weiteren Spalte je nach Ordner: 07.02.03 „wird indiziert“ (grüner Spinner); 07.02.04 kein Filterergebnis („Keine passenden Objekte“ + Text, Filter-Icon, „Alle Filter zurücksetzen“); 07.02.05 jenseits der Scan-Tiefe („Inhalt nicht erfasst“, gelber Ordner, Link „Scan-Tiefe ändern“); 07.02.06 ausgeschlossen (gelbes durchgestrichenes Auge, „Ordner ausgeschlossen“, Link „Einstellungen öffnen“ → Einstellungen › Dateien & Ordner); 07.02.07 nicht lesbar (rotes Warnsymbol, „Ordner nicht lesbar“ + Text, kein Link); 07.02.08 Inhalt wird geladen (Spinner, Text, „{1} von {2} Objekten geladen“).
  - Offline-Balken nur „Offline“ (Paket 58), Medium-Suche ohne Treffer: schwarzes Medien-Icon + „Kein Speichermedium mit diesem Namen bekannt“ (07.03.02).
  - **08.02:** Ein markierter Ordner ohne passende Objekte bleibt **wirklich grau** (leise), auch als Auswahl; der Pfad darüber blau (Nutzer 01.11.).
  - **Test:** je Zustand Titel/Icon/Link; Auswahl ohne Treffer grau. Sabotage-Patch.
  - **Status:**

- **todo.0.4.3.017 — Detailspalte und Fußzeile (07, 19):**
  - Dateidetails mit Label links, Wert rechts: „Erstellt“, „Geändert“, „Größe“, „Zuletzt gesehen“ (online „jetzt“), bei Mehrfachauswahl „Größe gesamt“; Zeilenhöhe 1,45 ohne Zusatzabstand; Name direkt unter dem Icon; Links („Im Finder anzeigen“, nur online) direkt unter den Werten. Statt „Geändert: …“ als Fließtext.
  - Fußzeile: links „{1} frei von {2}“, Mitte Pfad (bündig mit der ersten Ordnerspalte, bei Überlänge in der Mitte ausgeblendet), rechts „{n} Objekte“ / „1 Objekt“ / „{1} von {2} Objekten“ / „{1} von {2} ausgewählt“.
  - **Test:** Werte und Reihenfolge, online/offline, Mehrfachauswahl.
  - **Status:**

- **todo.0.4.3.018 — Einstellungen (05):**
  - **Dateien & Ordner:** Hinweisfläche oben über volle Breite („Was durch eine Änderung auf dieser Seite wegfällt … nach 1 Stunde …“, Link „Index jetzt bereinigen“, Rücknahme-Satz); die gekürzten Texte zu Scan-Tiefe, Ausschließen, Unsichtbare Dateien, Artefakte laut 20 (Einzelsätze zum Ausschalten entfallen).
  - **Speichermedien:** Spalte „Zuletzt gesehen“ (Datumsregel aus 19), Tabellenwerte überall gleich (Zeilen 14 px, 11 px Innenabstand, Kopf 11 px, Chips 10 px), keine Sortierpfeile, aktive Spalte schwarz.
  - **Allgemein:** 05.08a Autostart „Freigabe nötig“ – gelber Link „In den Systemeinstellungen freigeben“ (vorhandene Logik, Darstellung nach Layout).
  - **Hinweis „Einstellungen konnten nicht gelesen werden – Änderungen werden nicht gespeichert.“** oben im Einstellungsfenster laut 14.04/20.
  - **Test:** Spalten, Hinweisfläche, Freigabe-Link nur bei `requiresApproval`.
  - **Status:**

- **todo.0.4.3.019 — Schrift Archivo und Texte aus Paket 59 (Nutzer 03.11.):**
  - Archivo aus `Werkzeuge/fonts/archivo/Archivo-Variable.ttf` ins Bundle aufnehmen (mit `OFL.txt`), beim Start registrieren. Überall, wo das Layout Archivo setzt (Titel von Kacheln und Fenstern, 17 pt / 800 laut 19; weitere Stellen laut Layout), Archivo statt System-Fett. Fehlt die Schrift zur Laufzeit, Rückfall auf System-Fett.
  - „Belegt“ (06.01) und Dialog 16.02 „Auswerfen abgelehnt“ mit Text aus 20 und Knopf „Erneut versuchen“ (wirft erneut aus) statt der vorläufigen Fassung aus Paket 59.
  - **Test:** Schrift registriert und an den Titeln verwendet; 16.02 mit Aktion. Sabotage-Patch für „Erneut versuchen“.
  - **Status:**

- **todo.0.4.3.023 — Kleintexte, Einzahl, Tooltips (Host 03.11., Rest aus dem Layout-Abgleich, E6):**
  - **Medium-Suche (07.03):** über den Treffern Kopf „{1} TREFFER“ (Großbuchstaben wie „ALLE SPEICHERMEDIEN“), Suchbegriff im Namen fett.
  - **Kontextmenü (12):** bei Ordnern „Ordnernamen ignorieren“, bei Dateien „Dateinamen ignorieren“ (heute immer „Dateinamen …“).
  - **Einzahl laut 20** überall, wo eine Zahl vor einem Wort steht: „1 Datei“, „1 Objekt“, „1 Speichermedium“, „1 Favorit“, „1 Ergebnis anzeigen“, „noch 1 Tag“ usw. (`.xcstrings`-Pluralformen oder eigener Schlüssel, wie im Projekt üblich).
  - **Datumsregel (19)** für „Zuletzt gesehen“/„Zuletzt indiziert“ an allen Stellen gleich, inkl. „vor {1} Monaten“.
  - **Tooltips laut 19** („Tooltips und Einzahl“) an Werkzeugleiste, Filterleiste (Verknüpfung „Oder“/„Und“), Chips und Knöpfen; fehlt einer in 20, „Frage:“.
  - `copy.settings.notices.text` stimmt jetzt mit 20 überein → aus `openQuestions` nehmen.
  - **Test:** Einzahl/Mehrzahl je Stelle (1 und 2), Menüpunkt je Objektart, Treffer-Kopf. Kein Sabotage-Patch nötig (nur Texte).
  - **Status:**

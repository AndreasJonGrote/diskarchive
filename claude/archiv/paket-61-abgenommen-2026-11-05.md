# Paket 61 — Zielversion 0.4.3 (freigegeben 03.11.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Viertes von sechs Paketen für 0.4.3: Spaltenansicht, Einstellungen, Schrift.** Vorlage: Layout 05 (05.01–05.03, 05.08, 05.08a, 05.10), 07 (07.01–07.03), 08 (08.01–08.03), 19 („Kernkonzept“, „Tooltips und Einzahl“, Dateidetails, Tabellen-Regel). Nutzerentscheidungen: Backlog 0.4.3.

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`**; alle Schlüssel mit `pendingPackage = 61` und die vorläufigen Texte aus Paket 59 (`copy.medium.used` → „Belegt“, `copy.eject.failed` → Text aus 16.02 mit Knopf „Erneut versuchen“) sowie `copy.settings.unreadable.notice` auf 20 bringen und aus `pendingPackage`/`openQuestions` nehmen.
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
  - **Status:** Gemeinsame Statusfläche (`ColumnStatusPanel`, `ColumnFolderStatus` in `ColumnFolderStatusPanels.swift`) für 07.02.03–08 nach Layout (Icon 20/10, Titel 12 halbfett, Text 11/1,45/55 %, Link 11 halbfett), Icons `IconFolderDuotone`, `IconEyeSlash`, `IconWarningBold` aus `Werkzeuge/phosphor/`; Medium-Suche ohne Treffer (`MediumSearchNoResults`). 08.02 grau war schon so (todo.0.4.2.003), jetzt mit Fenstertest abgesichert.
    Tests: `ColumnFolderStatusTests` (neu), `ColumnFilterWindowTests.selectedQuietFolderStaysGreyAndThePathAboveIsBlue` (neu); angepasst an 20/Layout: `ColumnStatusIconTests` (Warnkreis entfällt, gleicher Aufbau), `EnglishLocalizationTests` („Einstellungen öffnen“). Patches 016-a, 016-b rot ✓ (08:30–08:32).
    Bereit zur Prüfung.

- **todo.0.4.3.017 — Detailspalte und Fußzeile (07, 19):**
  - Dateidetails mit Label links, Wert rechts: „Erstellt“, „Geändert“, „Größe“, „Zuletzt gesehen“ (online „jetzt“), bei Mehrfachauswahl „Größe gesamt“; Zeilenhöhe 1,45 ohne Zusatzabstand; Name direkt unter dem Icon; Links („Im Finder anzeigen“, nur online) direkt unter den Werten. Statt „Geändert: …“ als Fließtext.
  - Fußzeile: links „{1} frei von {2}“, Mitte Pfad (bündig mit der ersten Ordnerspalte, bei Überlänge in der Mitte ausgeblendet), rechts „{n} Objekte“ / „1 Objekt“ / „{1} von {2} Objekten“ / „{1} von {2} ausgewählt“.
  - **Test:** Werte und Reihenfolge, online/offline, Mehrfachauswahl.
  - **Status:** Detailspalte als Raster Label/Wert (`ColumnDetailFacts`, `ColumnDetailFactsGrid`), online „jetzt“, Mehrfachauswahl „—“ + „Größe gesamt“, Link „Im Finder anzeigen“ als Textlink 12 pt darunter; Fußzeilenpfad mit `caret-right`, bei Überlänge Mitte ausgeblendet (`ColumnFooterPath`).
    Tests: `ColumnDetailFactsTests` (neu), `DetailLastSeenTests` und `LayoutCopyTests` (Labels ohne Doppelpunkt) angepasst. Patches 017-a/b.
    Frage: Der Index kennt kein Erstellungsdatum der Dateien – „Erstellt“ zeigt „—“. Soll es (Schema-Erweiterung, Wert ab nächstem Scan) erfasst werden? Mehrfachauswahl ohne „Im Finder anzeigen“ (Layout zeigt ihn) – gewünscht?
    Bereit zur Prüfung.

- **todo.0.4.3.018 — Einstellungen (05):**
  - **Dateien & Ordner:** Hinweisfläche oben über volle Breite („Was durch eine Änderung auf dieser Seite wegfällt … nach 1 Stunde …“, Link „Index jetzt bereinigen“, Rücknahme-Satz); die gekürzten Texte zu Scan-Tiefe, Ausschließen, Unsichtbare Dateien, Artefakte laut 20 (Einzelsätze zum Ausschalten entfallen).
  - **Speichermedien:** Spalte „Zuletzt gesehen“ (Datumsregel aus 19), Tabellenwerte überall gleich (Zeilen 14 px, 11 px Innenabstand, Kopf 11 px, Chips 10 px), keine Sortierpfeile, aktive Spalte schwarz.
  - **Allgemein:** 05.08a Autostart „Freigabe nötig“ – gelber Link „In den Systemeinstellungen freigeben“ (vorhandene Logik, Darstellung nach Layout).
  - **Hinweis „Einstellungen konnten nicht gelesen werden – Änderungen werden nicht gespeichert.“** oben im Einstellungsfenster laut 14.04/20.
  - **Test:** Spalten, Hinweisfläche, Freigabe-Link nur bei `requiresApproval`.
  - **Status:** Hinweisfläche oben (`SettingsFilesNotice`, `info` 16 pt) mit Text aus 20, Texte Scan-Tiefe/Ausschließen/Unsichtbar/Artefakte aus 20; Spalte „Zuletzt gesehen“ mit Sortierung (`RegistrySortState.sorted`); Tabellenwerte aus 19 an einer Quelle (`DesignTable`: Zeile 14/11, Kopf 11 fett, aktiv Textfarbe, Datum 13 leise) in Speichermedien, Suche, Favoriten; gelber Link 05.08a (`AutostartApprovalLink`, bleibt in „Erweitert“ wie 05.08); Hinweis „Einstellungen konnten nicht gelesen …“ aus 20.
    Tests: `SettingsFilesAndRegistryTests` (neu); an 20/19 angepasst: `SettingsUnreadableSessionTests` (englischer Text), `ResultsTableWidthTests` (Zeile 14 pt statt 13). Patches 018-a/b/c.
    Frage: Layout 05.01 zeigt in der Hinweisfläche keinen Link „Index jetzt bereinigen“ – ich habe ihn weggelassen. Doch einbauen?
    Bereit zur Prüfung.

- **todo.0.4.3.019 — Schrift Archivo und Texte aus Paket 59 (Nutzer 03.11.):**
  - Archivo aus `Werkzeuge/fonts/archivo/Archivo-Variable.ttf` ins Bundle aufnehmen (mit `OFL.txt`), beim Start registrieren. Überall, wo das Layout Archivo setzt (Titel von Kacheln und Fenstern, 17 pt / 800 laut 19; weitere Stellen laut Layout), Archivo statt System-Fett. Fehlt die Schrift zur Laufzeit, Rückfall auf System-Fett.
  - „Belegt“ (06.01) und Dialog 16.02 „Auswerfen abgelehnt“ mit Text aus 20 und Knopf „Erneut versuchen“ (wirft erneut aus) statt der vorläufigen Fassung aus Paket 59.
  - **Test:** Schrift registriert und an den Titeln verwendet; 16.02 mit Aktion. Sabotage-Patch für „Erneut versuchen“.
  - **Status:** Archivo (`Resources/Fonts/` mit `OFL.txt`) beim Start registriert (`DesignFont`), Titel von Kacheln/Details (17) und Dialogen (16) in Archivo 800, Rückfall System-Fett. „Belegt“ war schon aus 20; Dialog 16.02 mit Text aus 20 und „Erneut versuchen“ (wirft dasselbe Medium erneut aus).
    Tests: `ArchivoFontTests` (neu), `MediumEjectTests.refusalOffersTryAgainWhichEjectsAgain` (neu). Patches 019-a/b.
    Frage: Laut CSS sind auch Knöpfe (`.btn`) und Fließtext (`--font-body`) Archivo – nur Titel umgestellt. Weitere Stellen?
    Bereit zur Prüfung.

- **todo.0.4.3.023 — Kleintexte, Einzahl, Tooltips (Host 03.11., Rest aus dem Layout-Abgleich, E6):**
  - **Medium-Suche (07.03):** über den Treffern Kopf „{1} TREFFER“ (Großbuchstaben wie „ALLE SPEICHERMEDIEN“), Suchbegriff im Namen fett.
  - **Kontextmenü (12):** bei Ordnern „Ordnernamen ignorieren“, bei Dateien „Dateinamen ignorieren“ (heute immer „Dateinamen …“).
  - **Einzahl laut 20** überall, wo eine Zahl vor einem Wort steht: „1 Datei“, „1 Objekt“, „1 Speichermedium“, „1 Favorit“, „1 Ergebnis anzeigen“, „noch 1 Tag“ usw. (`.xcstrings`-Pluralformen oder eigener Schlüssel, wie im Projekt üblich).
  - **Datumsregel (19)** für „Zuletzt gesehen“/„Zuletzt indiziert“ an allen Stellen gleich, inkl. „vor {1} Monaten“.
  - **Tooltips laut 19** („Tooltips und Einzahl“) an Werkzeugleiste, Filterleiste (Verknüpfung „Oder“/„Und“), Chips und Knöpfen; fehlt einer in 20, „Frage:“.
  - `copy.settings.notices.text` stimmt jetzt mit 20 überein → aus `openQuestions` nehmen.
  - **Test:** Einzahl/Mehrzahl je Stelle (1 und 2), Menüpunkt je Objektart, Treffer-Kopf. Kein Sabotage-Patch nötig (nur Texte).
  - **Status:** Kopf „{1} TREFFER“ und fetter Suchbegriff (`MediumSearchHeading`, `HighlightedName`); „Ordnernamen ignorieren“ (`contextIgnoreName(for:)`); Einzahl: „1 Objekt“ in der Mitteilung „vollständig indiziert“ ergänzt, übrige Stellen hatten sie schon; Datumsregel „vor {1} Monaten“ ab 2 Monaten; Tooltips an der Werkzeugleiste; `copy.settings.notices.text` aus `openQuestions`.
    Neue Texte: `copy.context.ignore_folder_name`, `copy.column.media_search.matches`, `copy.dashboard.last_seen.months_ago` (alle aus 20). Test: `SmallTextsAndSingularTests` (neu); Patch 023 (Monatsregel).
    Läufe: Pflicht-Suites (Column/Settings/Registry/Filter/Detail/Folder/Pixel/Layout/L10n u. a.) 08:44–08:47 271/271; `voll` 08:48–09:25: 0 Warnungen, rot nur `ResultsTableWidthTests` (13-pt-Annahme, danach angepasst, 09:27 grün); Sabotage 09:27–09:32 10/10 rot ✓.
    Frage: Englisch bei genau einem Treffer „1 MATCHES“ – 20 kennt nur „{1} MATCHES“. „1 MATCH“ ergänzen?
    Bereit zur Prüfung.

## Abnahme Host 05.11. (Gesamtlauf 09:42–10:17)

- Diff gelesen: gemeinsame Statusfläche 07.02.03–08 (`ColumnStatusPanel`, Icons aus Phosphor), Medium-Suche ohne Treffer; Detailspalte als Label/Wert-Raster mit „jetzt“ online und „Größe gesamt“, Fußzeilenpfad mit ausgeblendeter Mitte; Einstellungen mit Hinweisfläche, Texten aus 20, Spalte „Zuletzt gesehen“, Tabellenmaße aus 19 an einer Stelle (`DesignTable`), gelber Freigabe-Link 05.08a; Archivo im Bundle (`DesignFont`, Rückfall System-Fett) für Titel von Kacheln, Details und Dialogen; 16.02 mit „Erneut versuchen“; Treffer-Kopf, fetter Suchbegriff, „Ordnernamen ignorieren“, „vor {1} Monaten“, Tooltips. Nichts Wesentliches.
- Gesamtlauf grün: Debug und Release 0 Warnungen, seriell 1319/1319, parallel 3× grün (je 1312, 7 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, Sabotage 10/10 rot ✓, App des Nutzers 10:17:10, Version 0.4.2.
- `pendingPackage` enthält nur noch die 5 Schlüssel für Paket 62. `openQuestions`: `copy.settings.tab.media`, `copy.medium.indexed_value`, `copy.popover_search.group.folders` (Layout-Fragen, ohne Folge für den Nutzer).
- **Fragen des Workers (Host):**
  - 017 „Erstellt“: Der Index kennt kein Erstellungsdatum, die Zeile zeigt „—“. Erfassen kommt als `todo.0.4.3.024` in Paket 62 (Schema-Erweiterung erlaubt, Wert ab dem nächsten Scan), ebenso „Im Finder anzeigen“ bei Mehrfachauswahl (Layout zeigt ihn).
  - 018: Kein Link in der Hinweisfläche ist richtig (05.01 zeigt keinen, der Text verweist auf den Knopf unter „Erweitert“).
  - 019: Archivo bleibt vorerst auf Titel beschränkt. Das App-Layout nennt Archivo nicht, nur das CSS des Designsystems setzt es für Knöpfe und Fließtext; Nutzerfrage offen.
  - 023: „1 MATCHES“ bleibt bis zur Einzahl in 20 (Layout-Frage).
- Nachtest des Nutzers: Spaltenansicht mit nicht lesbarem, ausgeschlossenem und nicht erfasstem Ordner; Detailspalte (Datei online/offline, Mehrfachauswahl); Fußzeile mit langem Pfad; Einstellungen „Dateien & Ordner“ und Medientabelle mit „Zuletzt gesehen“; Titel in Archivo; Auswerfen abgelehnt → „Erneut versuchen“; Medium-Suche mit Treffer-Kopf.

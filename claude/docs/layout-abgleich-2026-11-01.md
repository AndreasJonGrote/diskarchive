# Layout-Abgleich 01./02.11.2026 (Host)

**Stand 03.11. (sechster Durchgang, CHANGELOG „2026-11-03 (3)“): Design abgeschlossen.** Alle Lücken in 20 geschlossen (348 Texte, alle mit Englisch, Platzhalter gleich). Keine offenen Punkte im Design bis 0.6.

**Stand 03.11. nachts (fünfter Durchgang, Sektion 20 „Texte DE/EN“):** 338 Texte, alle mit Englisch, Platzhalter in beiden Sprachen gleich, keine Dubletten; gegenüber dem vierten Durchgang ist nichts verloren gegangen. Lücken in 20: Alter „6 Monate“/„9 Monate“, Einzahlformen aus 19 („1 Datei“, „1 Ergebnis anzeigen“, „1 Speichermedium“, „1 Favorit“, „1 Vorschau“, „Dein 1 Speichermedium und …“), Spaltenkopf mit Filter „{Ordner} · {n} von {m}“, zwei Texte mit Beispielwert statt Platzhalter („Pausiert für 1 Stunde“, „… mit 1 Favoriten ist online.“), zweimal „storage“ statt „storage media“. Spalte „Typ“ der Speichermedien-Tabelle steht nicht mehr im Layout → entfällt in der App.

**Stand 03.11. (vierter Durchgang, Layout mit CHANGELOG „2026-11-03“):** Alle Nachträge umgesetzt (Startzustand 03.11/04.01a, Autostart-Freigabe 05.08a, Fehlergrund in 06.03, Mitteilungen 6/7 mit Punkt, Grund f neu, „Betaphase“, Metadaten/Vorschaubilder in 00, 05.01, 05.04, 06, 07.04.10–13, 10.04a). Das Layout deckt die App vollständig ab; Konzept und Layout stimmen überein. Video-Dauer ohne Vorschau: Nutzer 03.11. entschieden, eigenes Feld „Dauer“ (Layout 07.04.12 ergänzt der Nutzer). **App-Texte ohne wörtliche Entsprechung: 39**, alle mit neuer Fassung im Layout (Tabelle unten, ergänzt um: Einstellungstexte in 05.01 ohne Einzelsätze zum Ausschalten, Hinweisfläche oben; „Belegt / Frei“ → eigene Flächen Gesamt/Belegt/Frei; Grund f „Der Index auf diesem Mac lässt sich gerade nicht beschreiben.“; Mitteilungen 6/7 mit Punkt).

**Stand 02.11. 16:23 (dritter Durchgang):** Layout deckt die App bis auf zwei Zustände ab (Start-Ladezustand „Inhalte werden geladen“ in Hauptfenster und Popover; Hinweis „In den Systemeinstellungen freigeben“ unter Autostart). Alle 290 Texte der App geprüft: 34 stehen nicht wörtlich im Layout, für alle gibt es dort eine neue Fassung oder sie entfallen (Liste „Texte, die die App ändern muss“ unten). Offen im Design: Fehlergrund nur in Dialog/Mitteilung, Mitteilungen 6/7 ohne Punkt, Grund f doppelt (AUDIT.md), Schreibweise „Beta-Phase“ (gelb) neben „Betaphase“ (rot). Künftige Funktionen ohne Layout: 0.7 CSV-Export, 0.8 Duplikate, 0.9 Verschlagwortung (Konzept noch Entwurf).

### Texte, die die App ändern muss (Stand Layout 02.11. 16:23)

| App heute | Layout |
|---|---|
| „Geändert: …“, „Größe: …“, „Größe gesamt: …“, „Zuletzt gesehen: …“ | Label links, Wert rechts (Erstellt, Geändert, Größe, Zuletzt gesehen; Größe gesamt) |
| „Inhalt wird nicht indiziert“ | „Inhalt nicht erfasst“ + „Scan-Tiefe ändern“ |
| „Ordner ist ausgeschlossen“ + „Ausschlüsse ändern“ | „Ordner ausgeschlossen“ (gelbes durchgestrichenes Auge) + „Einstellungen öffnen“ |
| „Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen“ | „Offline“ |
| „Keine favorisierten Objekte“, „Keine Favoriten für die gesetzten Filter“ | „Keine Favoriten“, „Keine Favoriten in dieser Auswahl. Wähle „Alle“ oder markiere Objekte über das Kontextmenü als Favorit.“ |
| „Keine Ergebnisse für „…““, „Keine Treffer für die gesetzten Filter“ | „Keine Suchergebnisse“ + „Suchbegriff ändern oder Filter entfernen.“ |
| Popover „Keine Treffer für „…““ | „Keine Suchergebnisse“ + „Suchbegriff ändern.“ |
| „Zuletzt indiziert: {Datum}, {Zeit}“ | Popover: Uhr-Icon + Datum; Details 06: Zeile „Zuletzt indiziert“; Kachel: „Zuletzt gesehen“ |
| „Kein Zugriff, in den Systemeinstellungen freigeben“ | Kachelzeile „Fehler · erneut versuchen“ (Link), Grund nur in 14/18 (`bug.0.4.3.002`) |
| „„{Name}“ ({Typ}, {Größe}) wurde angeschlossen …“ | „„{Name}“ ({Größe}) wurde angeschlossen …“ (ohne Typ) |
| „Suchen…“, „Name, Endung (*.log) oder Ordner…“ | „Suchen …“, „… oder Ordner …“ (Leerzeichen vor „…“) |
| „Die Änderung gilt sofort.“ | „Die Änderung gilt sofort, ohne Neustart.“ |
| „Disk Archive weist dich darauf hin, sobald …“ | „Ist eine neue Version von Disk Archive verfügbar, erscheint ein Dialog mit allen Details zum Update.“ |
| „Systemmeldungen umfassen Hinweise zu Fehlern und zu Pausen.“ + Nachsatz | Fassung aus 05 („… zu abgelaufenen Pausen.“, Hauptschalter, Verweis auf 18) |
| Vorschau „Archiv 2019–2021“ (7 Favoriten, 48.210 Objekte) | „Masterarbeit Backup“ / „Unterwegs“ (Beispiele aus 05/18) |
| Countdown im Update-Dialog, drei Sperr-Banner („Versionsserver“, „Build abgelaufen“) | Banner 04.03a (gelb, Frist), 04.03b/04.04 (rot), „Lizenzserver“, „Diese Version ist abgelaufen.“, „Jetzt prüfen“ / „Versionsprüfung …“ |
| Abschnitt „DATEITYP-FILTER IN DER SPALTENANSICHT“, Rückfrage „{n} Einträge ignorieren?“ / „Abbrechen“ | entfallen |
| Zähler im Spaltenkopf „{Ordner} · {n} von {m}“ | Format im Layout 08 prüfen (kein wörtlicher Treffer) |

**Stand 02.11. (zweiter Durchgang, Layout vom 02.11. 15:03):** Alle Punkte N1–C4 erneut gegen das aktualisierte Layout geprüft. Neu im Layout: 01.01 Menü am Menüleisten-Icon, 04.03–04.05 Nur-Lesen-Banner, 14.03/14.04 Gründe und Orte des Indizierungsfehlers, **18 Mitteilungen** (alle Texte), Styleguide jetzt **19**. App-Texte ohne Layout: **45 statt 75**.

### Ergebnis des zweiten Durchgangs

| Punkt | Stand 02.11. |
|---|---|
| N1 Erkennungsdialog mit Typ | **offen**: Layout 02 weiter „(2 TB)“ ohne Typ, 00/19 „Typ nie als Text“; Nutzer 01.11.: Ausnahme mit Typ |
| N2 Ziel „Zur neuen Version“ | **offen**: 00 und 13 weiter „Download-Seite … /download/“; Entscheidung 31.10.: Startseite |
| N3 „Ordner weiterhin anzeigen“ | erledigt (aus 08/09 entfernt) |
| N4 Offline-Balken 07 | **offen**: 07.01 „Medium nicht angeschlossen“ zeigt über den Spalten nur „Offline“; App „Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen“ |
| N5 Auswerfen offline | erledigt (nur Online-Medien, auch im Kontextmenü) |
| N6 Dringendes Update | erledigt (immer, auch wenn „Auf Updates hinweisen“ aus) |
| **N7 neu: Betaende** | **offen**: Layout 04.03/00: nach Release 1.0 sofort Nur-Lesen mit Banner „Die Betaphase ist beendet“ für 7 Tage, danach „Diese Version ist abgelaufen“. App heute: Update-Dialog „wird in sieben Tagen gesperrt“, erst danach gesperrt (Konzept roadmap 0.4: 7 Tage). |
| **N8 neu: Lizenzserver** | **offen**: Layout nennt den gelben Fall „Lizenzserver seit einem Monat nicht erreichbar“; App „Versionsserver“. Lizenz gibt es erst ab 1.0 – heißt der Server schon jetzt so? |
| A1–A13 | alle weiter im Layout, unstrittig für 0.4.3; A13 (DMG ohne Version) bestätigt |
| D1 Menüs | Layout 01.01 hat das Menü; **„Protokoll im Finder zeigen“ fehlt dort** (App hat es) |
| D2 Mitteilungen | vollständig in 18 (Texte, Schalter, Bedingungen) |
| D3 Gründe Indizierungsfehler | vollständig in 14.03 |
| D4 Sperren | 04.03–04.05 mit neuen Texten (Banner rot/gelb, „Jetzt prüfen“, „Versionsprüfung …“); ersetzt die drei App-Banner, siehe N7/N8 |
| D5 Status/Kachel | „Fehler · erneut versuchen“ im Layout (14.04); „Kein Zugriff, in den Systemeinstellungen freigeben“ nicht mehr → `bug.0.4.3.002` |
| D6 Suche/Favoriten/Filter | Suche „Keine Suchergebnisse“ + „Suchbegriff ändern oder Filter entfernen.“; Favoriten „Keine Favoriten“ + „Keine Favoriten in dieser Auswahl. Wähle „Alle“ …“ (Chip „Alle“ gibt es in 11); Tooltips („Alle Filter zurücksetzen“, „Filter mit „Und“ verknüpfen“) und Bereichsnamen („In Favoriten“, „In „…““) ohne Layout |
| D7 Einstellungen-Reste | Bestätigung „%lld Einträge ignorieren?“ mit „Abbrechen“ ohne Layout; Abschnitt „DATEITYP-FILTER IN DER SPALTENANSICHT“ nicht mehr im Layout; ungenutzte Katalogtexte („Unterordner %lld“, „noch nicht indiziert“, „In den Systemeinstellungen freigeben“) |
| C1–C4 | unverändert (0.5, 0.6, offen, 1.0) |

### Entscheidungen des Nutzers 02.11.

N1 ohne Typ · N2 Startseite · N4 nur „Offline“ · N7 gelb (Hinweis mit Restfrist) → rot (Sperre), Layout 04.03 wird angepasst · N8 „Lizenzserver“ · E1, E5, E6 Layout kommt · E2, E3, E4 entfallen in der App. Einzelheiten: Backlog 0.4.3.

### Was danach wirklich noch fehlt

1. **Entscheidungen:** N1, N2, N4, N7, N8.
2. **Ohne Layout, Frage ob nötig:** Popover-Leerzustände „Kein Speichermedium angeschlossen“ / „Kein indiziertes Speichermedium angeschlossen“; Menüpunkt „Protokoll im Finder zeigen“; Bestätigung „%lld Einträge ignorieren?“; Abschnitt „Dateityp-Filter in der Spaltenansicht“ in den Einstellungen (noch in der App); Ausschluss-Status in 07 („Ordner ist ausgeschlossen“ + „Ausschlüsse ändern“ – Layout zeigt dafür denselben Status wie Scan-Tiefe mit Link „Scan-Tiefe ändern“).
3. **Ohne Layout, bleibt so (Vorschlag):** Tooltips, Bedienhilfen, Einzahl-Varianten („1 Ergebnis anzeigen“, „Dein 1 Speichermedium“), Zähler im Spaltenkopf.

---

Erster Durchgang (01.11.), Abschnittsnummern dort noch alt (Styleguide 18):

Grundlage: `layout/` vom 01.11. 23:18 (`App-Layout 00-03` … `10-17`, `18 Styleguide`, `App: Komponenten`, CHANGELOG 01.11.), gerendert und Text für Text gegen `Localizable.xcstrings` (290 Texte) und den Stand der App gehalten. Regel des Nutzers: Fade im Layout teils zu früh – in der App immer so breit wie möglich, erst am Ende ausblenden.

Abschnittsnummern neu: 13 Update, 14 Indizierungsfehler, 15 Absturzbericht, **16 Unerwarteter Fehler (neu)**, **17 Über Disk Archive (neu)**, 18 Styleguide (vorher 16).

## A. Unstrittig – Layout ist klar, App weicht ab (Kandidaten für 0.4.3)

**Medien, Namen, Farben**
1. **Benannte Medien türkis:** Medien-Icon türkis (#00A5A8 hell, #00D3D5 dunkel und auf ausgewählten Zeilen). In Listen (Popover 03, Seitenleisten, Tabellen, Suche) beide Namen in einer Zeile: „Lauras Platte · Studio Backup“, Originalname leise und läuft zuerst aus. Kachel: Originalname klein darunter.
2. **Favorisierte Medien violett:** Medien-Icon überall violett (Seitenleiste, Kacheln, Tabellen, Details).
3. **Benennen nur im Details-Fenster (06):** Kontextmenü „Benennen“ öffnet 06 mit Fokus im Namensfeld; Feld ohne Rahmen, Stift direkt am Namen, Enter/Häkchen übernimmt, Esc/X bricht ab, leer = Originalname. Bearbeiten an Ort und Stelle (Paket 55) entfällt (Konzept `medien.md` 2d).
4. **Auswerfen:** Kachel – beim Hover rechts neben dem Chip ausfahrender Eject-Knopf (Rahmen, beim Hover gefüllt, Textfarbe, nie grau); Tabelle „Speichermedien“ – beim Zeilen-Hover links vom Chip; Kontextmenü an Medien. **Nie** in Seitenleisten und Medienspalten, **nie** bei Offline-Medien. Nur per Klick (Konzept `datenschutz-plattform.md`).

**Erkennung und Status**
5. **Neuer Dialog 02.03 „Ersetzt dieses Medium …?“** (bekannter Name, altes Medium nicht angeschlossen): „Altes vergessen“ (löscht altes Medium mit Index und Favoriten, danach Erkennungs-Dialog) / „Behalten“. Abgleich mit dem vorhandenen Ersetzen-Dialog der App nötig.
6. **„Wird geprüft“** für neue **und** wieder angeschlossene Medien (Kachel: gestrichelt grün, pulsierender Punkt; Popover: „Speichermedium wird geprüft“ ohne Prozent) statt kurzem Sprung auf 99 %.
7. **Popover 03:** „Entscheidung ausstehend“ (gelber pulsierender Punkt, Klick öffnet den Erkennungs-Dialog für dieses Medium); „Speichermedium fehlerhaft“ (roter Punkt); Chip nur während Indizierung; **Umschalter Dateien/Prozent entfällt**; „Einen Moment bitte“ entfällt.
8. **Popover-Suche:** Zustand „Suche läuft“ (Spinner, „Deine 12 Speichermedien und 48.230 Dateien werden durchsucht …“) und „Keine Suchergebnisse“ / „Suchbegriff ändern.“ statt heute „Keine Treffer für „…““.

**Kacheln (04)**
9. Neuer Aufbau: oben links Icon, oben rechts Chip (+ Auswerfen), Name, ggf. Originalname klein, unten „Kapazität · Dateianzahl“ (z. B. „4,1 TB · 238.421 Dateien“), darunter „Zuletzt gesehen“ und bei angeschlossenen Medien die Belegung. Offline blasser, Fehler roter Rahmen, nichts bricht um. Heute: Belegung links, „Zuletzt indiziert“ rechts. „Ausstehend“ nie im Dashboard.

**Einstellungen (05)**
10. Speichermedien-Tabelle: Spalte **„Zuletzt gesehen“** neu, Auswerfen am Chip, Chips „Ausstehend“/„Nicht erlaubt“.
11. Texte: Sprache „Die Änderung gilt sofort, ohne Neustart.“; Updates „Ist eine neue Version von Disk Archive verfügbar, erscheint ein Dialog mit allen Details zum Update.“; Mitteilungen „Systemmeldungen umfassen Hinweise zu Fehlern und zu abgelaufenen Pausen.“ und „Die Pause ist abgelaufen. Automatisches Indizieren ist wieder an.“
12. Tabellenwerte überall gleich: Zeilen 14 px, 11 px Innenabstand oben/unten, Kopf 11 px, Chips 10 px.

**Spaltenansicht (07) und Filter (08)**
13. **07.02.06 „Ordner nicht lesbar“** (rotes Warnsymbol, „Der Inhalt dieses Ordners konnte beim Indizieren nicht gelesen werden.“, kein Link); „Inhalt wird geladen“ jetzt 07.02.07 („Dieser Ordner enthält sehr viele Objekte. Die Liste erscheint erst, wenn alle geladen sind.“, „12.480 von 41.902 Objekten geladen“).
14. Scan-Tiefe: Titel „Inhalt nicht erfasst“ + Link „Scan-Tiefe ändern“ (heute „Inhalt wird nicht indiziert“).
15. Medium-Suche ohne Treffer: „Kein Speichermedium mit diesem Namen bekannt“ mit schwarzem Medien-Icon.
16. Filter ohne Treffer: „Keine passenden Objekte“ / „In diesem Ordner und seinen Unterordnern gibt es keine Objekte, die zum Filter passen.“; **markierter Ordner ohne Treffer bleibt wirklich grau (leise), Pfad darüber blau** (08.02).
17. Details: Labels immer Erstellt, Geändert, Größe, Zuletzt gesehen (online „jetzt“), weitere Metadaten zwischen Größe und Zuletzt gesehen; Zeilenhöhe 1,45 ohne Zusatzabstand; Name direkt unter dem Icon; Links direkt unter den Metadaten. Heute „Geändert: …“ als Fließtext.
18. Fußzeile: links frei („1,1 TB frei von 2 TB“), Mitte Pfad, rechts Anzahl („4 Objekte“, „0 von 2 Objekten“, „2 von 4 ausgewählt“).

**Dialoge**
19. **16 Unerwarteter Fehler (neu, generisch):** rotes Icon, Titel immer „Unerwarteter Fehler“, Fehlerbeschreibung, „Schließen“, optional rechts eine passende Aktion („Erneut versuchen“, „Einstellungen öffnen“ …). Für alle Fehler ohne eigenen Dialog – heute u. a. „Index-Datenbank nicht verfügbar“, „Einstellungen konnten nicht gelesen werden“.
20. **17 Über Disk Archive (neu):** oben App-Icon und Name auf Verlauf mit Ringen, darunter schwarzer Balken mit Version, Datum und www.diskarchive.app; hell und dunkel gleich; schließt nur über den roten Punkt (`todo.0.4.3.001`).
21. 15 Absturzbericht: Icon rot.
22. Versionsnummer überall die aktuelle (Platzhalter im Mockup).

**DMG**
23. Fußzeile „www.diskarchive.app“ statt „Beta x.x.x“: damit entfällt `todo.0.4.3.003` (Version automatisch); nur das Hintergrundbild einmal neu (Host).

## B. Nachfrage – Layout widerspricht App oder einer Entscheidung

- **N1 Erkennungs-Dialog:** Layout 02.01/02.02 schreibt „„Externe Platte 5“ (2 TB) …“ **ohne Typ**, und 00/18 sagen „Der Typ selbst steht nie als Text in der App“. Nutzer 01.11.: Typ und Größe bleiben im Erkennungs-Dialog als einzige Ausnahme. Was gilt?
- **N2 Update-Ziel:** 13 sagt „Zur neuen Version“ öffnet `https://www.diskarchive.app/download/`; entschieden 31.10. (`todo.0.4.2.004`): Download-Seite entfällt, Knopf öffnet die Startseite.
- **N3 „Ordner weiterhin anzeigen“:** steht noch in den Beschreibungen von 08 und 09 (Einstellung „Dateien & Ordner, Standard: an“); entfallen seit 30.10. (`todo.0.4.2.003`). Layout-Text veraltet?
- **N4 Offline-Balken (07):** Layout zeigt nur „Offline“; App „Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen“. Kürzen?
- **N5 Auswerfen bei Offline:** CHANGELOG 29.10. „in jedem Zustand“, 01.11. „nie bei Offline-Medien“ – gilt 01.11.? (Offline auswerfen ist technisch ohnehin nicht möglich.)
- **N6 Abschnitt 13:** „sofern ‚Auf Updates hinweisen‘ aktiv ist“ – gilt für das dringende Update (`todo.0.4.3.002`) weiter die Ausnahme „auch wenn aus“?

## C. Im Layout, aber für später (nicht 0.4.3)

| Version | Was das Layout schon zeigt |
|---|---|
| 0.5 Metadaten | Detailspalte je Typ: Video (Auflösung, Bildrate, Codecs, Dauer, Farbraum), Foto (Auflösung, Megapixel, Farbraum), Audio (Dauer, Samplerate, Qualität, Kanäle), PDF (Seiten, Seitenformat); „—“ bei fehlenden Werten |
| 0.6 Vorschaubilder | Vorschau in der Detailspalte (max. 228 px), Waveform für Audio, Play-Button nur online, Einstellung „Vorschaubilder erzeugen“, Vorschauen in den Systeminformationen |
| offen (Backlog „Später“) | Tab „Systeminformationen“: „Niemals in der Cloud“, Kennzahlen, Index-Größe gesamt/je Medium (Heatmap), Durchschnitt je Objekt, Programm (Version, letzte Update-Prüfung + „Jetzt prüfen“ = `todo.0.5.004`, Indexordner) |
| 1.0 Lizenz | Tab „Lizenz“ in drei Zuständen (Testversion 1 / Vollversion 50 / Vollversion Pro 250, „Einmal kaufen, kein Abo“, Aktivieren, Deaktivieren) – Namen weichen von Basic/Pro/Max im Konzept ab |
| nicht vergeben | erweiterte Dateityp-Icons (Office, Apps/Installer, Quelltext) im Styleguide (`todo.1.0.002`) |

## D. Texte der App, die nicht im Layout stehen (75 von 290)

Vieles davon ist richtig so (Menüs, Mitteilungen, seltene Fehler). Der Nutzer entscheidet je Gruppe.

- **App-Menü und Menüleisten-Menü:** „Einstellungen …“, „Disk Archive anzeigen“, „Disk Archive beenden“, „Protokoll im Finder zeigen“, „Automatisch bei Systemstart“.
- **macOS-Mitteilungen:** „Indizierung pausiert.“ / „… bis %@ Uhr.“, „Medien werden wieder indiziert.“, „Medium „%@“ ist vollständig indiziert – %@ Objekte“, „… mit %@ Favoriten ist online“, „Mitteilungen sind ein-/ausgeschaltet.“, „Voreinstellungen angewendet.“, „Index bereinigt.“, „Alle Speichermedien wurden vergessen.“
- **Gründe im Indizierungsfehler (14):** Verbindung unterbrochen, reagiert nicht, nicht genug Speicherplatz, Index nicht gespeichert, nicht bestätigt, einige Ordner nicht lesbar.
- **Sperren:** Betaphase beendet (sieben Tage, Banner), Build abgelaufen, Versionsserver länger als einen Monat nicht erreicht.
- **Fehler ohne eigenen Dialog** (→ künftig 16): „Index-Datenbank nicht verfügbar“ + Text, „Einstellungen konnten nicht gelesen werden – Änderungen werden nicht gespeichert.“
- **Kachel/Chip/Status:** „Fehler · erneut versuchen“, „Fehler, offline“, „%lld % indiziert(, offline)“, „noch nicht indiziert“, „Kein Zugriff, in den Systemeinstellungen freigeben“, „Zuletzt indiziert: %@, %@“ / „—“.
- **Spaltenansicht:** Offline-Balken (N4), „Inhalt wird nicht indiziert“ (→ A14), „Ordner ist ausgeschlossen“ + „Ausschlüsse ändern“, „Inhalt konnte nicht gelesen werden“ (→ A13), „Geändert:/Größe:/Größe gesamt:/Zuletzt gesehen: %@“ (→ A17).
- **Suche/Favoriten/Filter:** „Keine Ergebnisse für „%@““, „Keine Treffer für die gesetzten Filter“, Popover „Keine Treffer für „%@““ (→ A8), „Keine favorisierten Objekte“, „Keine Favoriten für die gesetzten Filter“, „Alle Filter zurücksetzen“, „Filter mit „Und“ verknüpfen/verknüpft“ (Tooltip), „In Favoriten“, „In „%@““, „1 Ergebnis anzeigen“, Popover „Kein (indiziertes) Speichermedium angeschlossen“.
- **Einstellungen:** Abschnitt „DATEITYP-FILTER IN DER SPALTENANSICHT“ + Text, „Unterordner %lld“, „In den Systeminformationen freigeben“, alte Texte zu Sprache/Updates/Systemmeldungen (→ A11), „%lld Einträge ignorieren?“, „Details anzeigen“, „Abbrechen“.
- **Bedienhilfen (VoiceOver):** „Suche leeren“, „Übersicht“.

## E. Folgen für Code und Tests

- `LayoutCopyTests` liest das Layout direkt; mit dem neuen Layout ist der Test rot, bis 0.4.3 die Texte übernimmt (Ausnahmelisten `notYetReleased`/`differsFromApp` neu fassen).
- Abschnittsnummern im Test (`02. 05. 06. 14. 15.`) gegen die neue Zählung prüfen.

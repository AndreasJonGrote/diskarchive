# Entscheidungsverlauf (chronologisch) bis 02.10.2026

Archiviert aus der README. Maßgeblich ist heute das Konzept in der README; dieser Verlauf dient nur der Nachvollziehbarkeit.

## Ergänzungen & Korrekturen (chronologisch, neueste zuerst)

### 2026-10-01 — Pause nur global, Registrierung sofort, Vergessen, Sichtbarkeit (Layout 21:52, Antworten des Nutzers)
Ausführlich und thematisch in [KONZEPT.md](KONZEPT.md) Abschnitte 2 und 3. Kurz: Pause **nur global**. Je Medium „Soll indiziert werden“ Ja | Nein, **Nein stoppt, löscht und versteckt nichts**. **Jedes Medium wird sofort registriert** und erscheint sofort in Einstellungen → Speichermedien, auch bei offenem Fenster, gleichzeitig öffnet der Dialog. **Dashboard, Seitenleiste, Suche, Favoriten zeigen nur Medien mit Index.** **Vergessen** löscht alles, beim erneuten Anschließen erscheint der Dialog wieder. Pause plus neues Medium: Dialog trotzdem (die Pause betrifft nur das Indizieren), Lauf startet nach der Pause automatisch, sofern das Medium noch online ist. Vergessen hat mit der Pause nichts zu tun (Medium gilt danach als nie gesehen). Layout-Fehler (vom Nutzer zu korrigieren): Chip „Pausiert“, „Externe Platte 5“ ohne Index in 04/07/08. (Aufgabe 69.)

### 2026-10-01 — Immer ausgeschlossen, Artefakte, Voreinstellungen
**Immer ausgeschlossen** (unabhängig von allen Schaltern, nicht in der Artefakt-Regelliste): `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `System Volume Information`, außerdem im Code `.TemporaryItems`, `.DocumentRevisions-V100` und `._*`. Grund: Zugriffsfehler, riesige Systembäume, Datenschutz. Diese Namen wurden aus `konzept-anmerkungen.txt` gestrichen. **Artefakte** = die Regelliste der Konzeptdatei (temporär, Backups, Systemreste, Abhängigkeitsordner, unsichtbare Artefakte). **Eigene Ausschlüsse** des Nutzers bleiben als Funktion (Chips, Kontextmenü), die Voreinstellung ist **leer**. Voreinstellungen laut Layout 05: Scan-Tiefe **5+**, Erscheinungsbild Automatisch, Fehlerberichte künftig automatisch senden Aus. Gestrichen: Zeile „Soll indiziert werden (neue Medien)“ und der Beispieleintrag unter „Ausgeschlossen“.

### 2026-10-01 — Layout-Revision (Sektionen 00–15)
Neu im Layout: **13 Error Reporting** (Absturzbericht-Dialog), Styleguide ist jetzt **14**. **Fehlerbericht:** ein Weg (Endpunkt, Absturz, nach Zustimmung, optional „Künftig automatisch senden“), **ohne Datei-/Ordnernamen und ohne Suchbegriffe**, nur technische Zeichenprofile; Mail, Kopieren, Ticket und Diagnosebericht entfallen (Aufgabe 63). **Einstellungen:** vier Tabs (Allgemein, Dateien & Ordner, Speichermedien, Erweitert), Erscheinungsbild Hell/Dunkel/Automatisch (Standard Automatisch), Scan-Tiefe-Voreinstellung **5+**, Artefakte und Unsichtbare Dateien als Schalter, Mitteilungen mit drei Ereignissen, „Aus dem Index entfernen“, Voreinstellungen, Bestätigungsmodus mit zwei Klicks (Aufgaben 64 bis 67). **Pausieren** mit Dauer (30 Min., 1 Std., Bis morgen, Für immer) per Popover (68). Regelliste der Artefakte steht in `konzept-anmerkungen.txt`. Entschieden: „Bis morgen“ = 09:00 Uhr; Pause überlebt Neustart; Pause-Ablauf löst Systemmeldung aus; Scan-Tiefe-Voreinstellung 5+.

### 2026-10-01 — Leistung nach Aufgabe 59 (Messung, Attrappe ohne Plattenzugriff)
Erstlauf Tiefe 5 (~498 000 Einträge): 12,5 s, ~40 000 Einträge/s (vorher 74 s). Unveränderter Abgleich beim Anschließen: 3,2 s (26 % des Erstlaufs, vorher 72 s) durch Inhaltsstempel je Ordner. Spalte mit 500 000 Zeilen laden: 3,14 s (vorher 51 s), RAM danach 418 MB. Leerlauf mit 5 Medien: 0,2 % CPU, 88–125 MB. 20 Zyklen: kein Speicherwachstum. Parallelität 1/4/8: kein Unterschied auf der Attrappe, bleibt 1. Voller Lauf bei jedem Anschließen bleibt, mit Stempelvergleich ist er kurz genug (FSEvents-Nachspielen entfällt vorerst). Echte Platte noch nicht gemessen.

### 2026-10-01 — Offene Entscheidungen des Nutzers (aus prompt.md hierher)
- **Leerzustände** (Aufgabe 41.4): Texte sind Vorschläge, im Layout nicht vorhanden. Bestätigen oder ändern.
- **Dunkelmodus:** folgt dem System (Aufgabe 48). Einstellung „Hell / Dunkel / System“ nur auf Wunsch.
- **Voller Lauf bei jedem Anschließen:** bleibt (Stempelvergleich, Aufgabe 59). Neu bewerten, wenn eine echte große Platte zu langsam ist.
- **Ticketsystem:** noch keins, Berichte gehen per Mail an mail@xjonx.com.

### 2026-10-01 — Start- und Dock-Konzept: Hintergrundprozess plus Hauptfenster per Klick
Entscheidung Nutzer: Die App liegt fest im Dock. **Jeder Klick** auf die App öffnet das Hauptfenster und startet dabei den Hintergrundprozess, falls er nicht läuft. Der Hintergrundprozess (Menüleiste, Überwachung) hat **kein aktives Dock-Symbol**. Start beim Anmelden ist **still** (kein Fenster). Fenster schließen führt zurück in den Hintergrund. Das Dock-Symbol ist immer das **Bundle-Icon**, kein Laufzeitbild (Messung: ein gesetztes Laufzeitbild erscheint 1,23-mal so groß wie die Nachbarn). Siehe Aufgabe 60.

### 2026-09-30 — Mehrfachauswahl in der Spaltenansicht
Entscheidung Nutzer: In einer Ordnerspalte lassen sich mehrere Objekte gleichzeitig markieren (⌘-Klick, ⇧-Klick, ⌘A). Bei Mehrfachauswahl entfallen Einzelaktionen („Im Finder anzeigen“, „Nach Namen/Dateiendung suchen“), es bleiben Sammelaktionen („Als Favorit markieren“, „Dateinamen ignorieren“, „Dateitypen ignorieren“). Auswahl gilt nur in einer Spalte; bei mehr als einem Objekt bleiben die Spalten rechts zu, die Detail-Spalte zeigt Anzahl und Gesamtgröße. Gilt nur in der Spaltenansicht, nicht in Suche und Favoriten. Layout: Sektion 07 „Beispiel — Mehrfachauswahl“ und Sektion 12 (Aufgabe 54). Fußleiste „x von y ausgewählt“, Detail „N Objekte / Größe gesamt“.

### 2026-09-30 — Dunkelmodus liegt im Layout vor
Das Layout enthält zu jedem Screen einen Dark-Block und in Sektion 14 die Farbrollen für Dunkel (Fenster #1F1F1F, Flächen #2A2A2A, Trennlinien 18 %, Auswahl #4A4949, Statusfarben heller, Chip-Fläche 12 %). Aufgabe 48 setzt das um und ersetzt das vorläufige Hell aus Aufgabe 47. Jede Sektion 02 bis 12 und der Styleguide haben einen Dark-Block, es gibt keine Lücke.

### 2026-09-30 — Filter in der Spaltenansicht gilt für alle Spalten
Entscheidung Nutzer: Der Filter wirkt auf **alle Ordnerspalten** des geöffneten Pfads, nicht nur auf die rechte. Beobachtung am echten Stick: Mit Filter „Audio“ zeigte die Wurzelspalte weiter alle Dateien, die rechte nur Audio. *(Ersetzt die Layout-Regel Sektion 08: „Nur die Spalte des aktuellen Ordners wird gefiltert; übergeordnete Spalten bleiben vollständig“. Das Layout muss angepasst werden.)* Ordner bleiben sichtbar, solange „Ordner weiterhin anzeigen“ an ist. Die Beschriftung rechts in der Filterleiste nennt das Medium statt eines Ordners.

### 2026-09-30 — Dunkelmodus: vorläufig immer hell
Das Layout kennt nur Hell. Im Dunkelmodus des Macs entstand ein Mischzustand (dunkle Toolbar, unsichtbare Platzhalter). Vorläufig bleibt die App immer hell (Aufgabe 47). Ein echter Dunkelmodus setzt ein Farbkonzept für Dunkel im Layout voraus.

### 2026-09-30 — Vertriebsweg: ohne Sandbox (Weg A)
Entscheidung Nutzer nach den Messungen im Spike: Die App läuft **ohne App-Sandbox**, damit sie Medien automatisch lesen kann. Der App Store bleibt später prüfbar (Zugriff hinter `MediumAccess`). Details: „Berechtigung und Vertrieb“ in der technischen README.

### 2026-09-29 (3) — Layout-Update: Filter-Verknüpfung „Oder"/„Und"
Neuer Link-Button in der Filterleiste (Sektionen 08/09): steuert, ob Dateityp-Gruppe und Alter per Oder (Standard) oder Und kombiniert werden. Deaktiviert bei gewähltem „Ordner" oder aktivem Suchbegriff. „Ordner" und echte Dateitypen/-endungen schließen sich im Popover gegenseitig aus. Präzisierung Nutzer: Ein Suchbegriff bleibt immer per Und mit dem Filterergebnis verbunden (`Suchbegriff UND (Filter ODER Filter)`), unabhängig vom Und/Oder-Zustand der Filter selbst — das ergibt sich bereits aus der bestehenden Text-Filter-Verknüpfung im Code. Neue Einstellung „Ordner weiterhin anzeigen" (Allgemein, Standard an) lässt Ordner in der Spaltenansicht trotz aktivem Dateityp-Filter sichtbar, damit man durchklicken kann; die Suche filtert weiterhin strikt. Entscheidung Claude: Favoriten bleiben strikt wie die Suche (keine Durchklick-Situation).

### 2026-09-29 (3) — Layout-Update: eigene Dateiendungen im Filter
Neu im Layout (Sektion 09): Im Filter-Popover lassen sich unter „Dateiendung" eigene Endungen eingeben (Enter, Chip mit ✕). Präzisierungen: Normalisierung auf Kleinschreibung mit Punkt (`jpg`, `.jpg`, `*.jpg`, `JPG` → `.jpg`), Kategorien und eigene Endungen bilden eine gemeinsame Dateityp-Gruppe (Oder-Verknüpfung), eigene Endungen erscheinen auch als Chips in der Filterleiste.

### 2026-09-29 (3) — Nur eine Instanz; „Automatisch bei Systemstart"
- **Nur eine Instanz:** Ein zweiter Start holt das Hauptfenster der laufenden Instanz nach vorn und beendet sich. (Im Debug-Build umgekehrt, damit Xcode-Runs nicht abbrechen.)
- **„Automatisch bei Systemstart"** (neu, nicht im Layout): Checkbox als erster Abschnitt unter Einstellungen → Allgemein („SYSTEMSTART") und Häkchen-Eintrag im Rechtsklick-Menü des Menüleisten-Icons. Standard aus. Zustand kommt immer aus macOS, nicht aus den App-Einstellungen. Präzisierung: Der Eintrag gehört unter **Im Hintergrund erlauben**, nicht unter „Bei der Anmeldung öffnen“. Dafür registriert die App einen Launch Agent (`SMAppService.agent`), kein `mainApp`. Ein schon gesetztes Anmeldeobjekt wird beim nächsten Start umgestellt.
  *Umsetzung (Stand 30.09.):* Technisch als Launch Agent (`Contents/Library/LaunchAgents/xjonx.diskindex.plist`, `SMAppService.agent`), nicht mehr als `SMAppService.mainApp`. Der Eintrag erscheint in den Systemeinstellungen unter „Im Hintergrund erlauben“; ein vorhandener Anmeldeobjekt-Eintrag wird migriert. Diese Änderung stammt nicht aus einem Briefing von Claude.

### 2026-09-29 (3) — Dateityp-Filter „Dokumente" ist Oberbegriff
„Dokumente" umfasst Text (txt, md, rtf, csv), PDF und Office-Formate (doc/docx, xls/xlsx, ppt/pptx, pages, numbers, key, odt/ods/odp). „PDF" und „Text" bleiben als engere Filter daneben bestehen. Grund: Nutzer erwartet, dass eine Notiz oder ein PDF als Dokument gefunden wird; die App zeigt .txt auch mit dem Dokument-Icon.

### 2026-09-29 (3) — Medium-Kontextmenü einheitlich im neuen Design
Entscheidung Nutzer: Auch Übersichtskarten und die Tabelle Einstellungen → Speichermedien bekommen das eigene Kontextmenü (statt nativem macOS-Menü). Für Medien gibt es überall dasselbe Menü: erste Gruppe „Inhalt anzeigen" · „Details", danach die vier Gruppen aus Sektion 12 (Einträge, die für Medien nicht passen, ausgegraut).

### 2026-09-29 (3) — Filter gehört zur Ansicht
Entscheidung Nutzer: Jeder Wechsel der Hauptansicht (auch per Klick auf einen Treffer, Kontextmenü, Popover) schließt die Filterleiste und hebt alle Filter auf. Beispiel: In der Suche ist „PDF" gesetzt, Klick auf einen Treffer → Spaltenansicht ohne Filter und ohne Filterleiste. Innerhalb der Spaltenansicht bleiben Filter beim Ordner- und Medienwechsel bestehen. *(Hebt auf: die Filter-Zwischenspeicherung vom 29.09. (2) und die Layout-Regel „Übergang: Wechsel aus einem gefilterten Ordner in die Suche übernimmt die gesetzten Filter" aus Sektion 08.)*

### 2026-09-29 (3) — „Filter"-Button in der Filterleiste
Ohne gesetzte Filter: blauer Rand, blaue Schrift, blaues Icon. Mit gesetzten Filtern: blau gefüllt, weiße Schrift und weißes Icon. *(Weicht vom Layout ab, das ohne Filter einen grauen Rand zeigt — Nutzervorgabe.)*

### 2026-09-29 (3) — Trenner in der Toolbar
Zwischen Favoriten- und Einstellungen-Icon ein senkrechter Trenner wie im Layout (1 × 20 pt, Divider-Farbe).

### 2026-09-29 (2) — Filter & Suche strikt getrennt; Filter nur, wo gefiltert werden kann
Entscheidung Nutzer, geht dem Layout-Text (Sektionen 08/10: „Such-Icon öffnet … mit geöffneter Filterleiste", „Filter-Icon … in jeder Ansicht", „Tippen startet die Suche direkt") vor:
- **Such-Icon und Filter-Icon sind immer unabhängig.** Das Such-Icon öffnet/schließt nur die Suchansicht, die Filterleiste bleibt, wie sie war. Das gilt auch für programmatisch gestartete Suchen (Kontextmenü, Popover „Alle N Ergebnisse anzeigen").
- **Filter gibt es nur in Spaltenansicht, Suche und Favoriten.** In Übersicht und Einstellungen ist das Filter-Icon deaktiviert (ausgegraut, nicht klickbar, kein Hand-Cursor), eine offene Filterleiste wird dort ausgeblendet. ⚠️ *Überholt am 29.09. (3):* ~~Die gesetzten Filter bleiben dabei gespeichert und wirken wieder, sobald man in eine filterbare Ansicht zurückkehrt.~~ Jeder Ansichtswechsel hebt die Filter auf.
- **Globales Suchfeld: keine Aktion beim Tippen**, weder Ansichtswechsel noch Treffer. Erst **Enter** öffnet die Suche mit Treffern. Live-Filterung beim Tippen bleibt nur für Medium-Suchfelder (z. B. „Medium suchen…" im Filter-Popover).
- **Favoriten sind filterbar** (Filterleiste + Popover wie in der Spaltenansicht, ohne Medium-Auswahl, zusätzlich zu Alle/Online/Offline).

### 2026-09-29 (2) — Menüleisten-Klick öffnet immer das Popover
Layout Sektion 01: „Fehler … Klick auf das Menüleisten-Icon führt direkt zum betroffenen Medium." Entscheidung: **gilt nicht.** Ein Linksklick öffnet immer das Popover, auch bei Fehler-Badge. Sonst wäre das Popover, solange irgendein Medium im Fehlerzustand ist, gar nicht erreichbar.

### 2026-09-29 (2) — Übersicht-Icon aktiv
Das Layout färbt das aktive Übersichts-Icon in `--color-accent` (#1F1F1F), also genau in der Textfarbe; der aktive Zustand ist dadurch unsichtbar. Festlegung analog zu Favoriten: Phosphor **`house-line`** (wie im Layout, nicht `house`), inaktiv Kontur in Textfarbe, aktiv **Duotone in Schwarz #1F1F1F** (Kontur + 20 % Fläche). Einstellungen bleiben Türkis, Favoriten Violett.

### 2026-09-30 — App-Icon: Symbol größer, Kachel unverändert
Nutzerwunsch: Das **Symbol** im Icon soll größer werden, die **Kachel** bleibt wie sie war. Vorgabe (Aufgabe 45): Kachel unverändert im Apple-Raster (824 von 1024, Eckradius 185,4, Schatten), sichtbare Symbolbreite **60 % der Kachelbreite** (bisher 55 %). Der Wert stammt aus der ersten Fassung mit vollflächiger Kachel, deren Symbolverhältnis dem Nutzer stimmig vorkam; die vollflächige Kachel selbst wurde zurückgenommen (im Dock größer als alle anderen). *(Ersetzt die Symbolgröße 54/72 vom 29.09.)*

### 2026-09-29 (2) — App-Icon im Apple-Raster
> ⚠️ Präzisiert am 29.09. (3): Symbol **54/72** der Kachelkante statt 38/72 (Nutzerentscheidung, im Dock war es zu klein). Übrige Werte unverändert.

Motiv exakt nach Sektion 01 (Verlauf 160° #2B2B2D → #1F1F1F, Glyph `hard-drives` #F2F2F2 mit 38/72 der Kachelkante, Radius 14/72), aber eingebettet in das macOS-Icon-Raster: 1024er Fläche, Kachel 824 × 824 mit 100 px transparentem Rand, Eckradius ≈ 185, weicher Schatten nach unten. Ohne diesen Rand wirkt das Icon im Dock zu groß und kantig („defekt"). Die PNGs wurden am 29.09. von Claude neu erzeugt.

### 2026-09-29 — Kontextmenü layoutgetreu statt nativ
Das Kontextmenü an Ordnern & Dateien wird **selbst gebaut** statt über das native macOS-Menü, damit die Layout-Vorgaben gelten: Häkchen rechts, Favorit violett, Ignorieren rot, schwarzer Rahmen am angeklickten Objekt genau solange das Menü offen ist. (Das native Menü kann nur links stehende Häkchen in Systemfarbe.)

### 2026-09-29 — Filter beim Verlassen der Suche zwischenspeichern
> ⚠️ Überholt am 29.09. (2): Die Suche schließt die Filterleiste nicht mehr, Filter und Suche sind getrennt. Der Zwischenspeicher gilt jetzt für Übersicht/Einstellungen (Leiste ausgeblendet, Filter bleiben gespeichert).

Verlässt man die Suche über das Such-Icon, schließt sich die Filterleiste; die gesetzten Filter bleiben gespeichert und wirken erst wieder, wenn die Leiste erneut geöffnet wird. Schließt man die Leiste selbst per Filter-Icon, werden die Filter wie im Layout aufgehoben (inkl. Zwischenspeicher).

### 2026-09-29 — Detail-Icon „Details/Regler"
Das Mockup ist hier uneinheitlich (Styleguide: Phosphor `faders-horizontal`, Tabellen-Icon in Sektion 05: `sliders-horizontal`). Es gilt der verbindliche Styleguide: `faders-horizontal`.

### 2026-09-28 — Layout-Revision: neues Farbkonzept
„Farbe bedeutet immer einen Zustand, nie eine Bedienung — bedient wird in Schwarz." Blau ist kein Akzent mehr. Rollen: Schwarz `#1F1F1F` Bedienung/Auswahl · Grün `#20A04E` Online/wird indiziert/ausstehend/neu erkannt · Rot `#E04830` Fehler/destruktiv · Gelb `#EDA12D` ignoriert/nicht erfasst · Blau `#3986E4` Filter & Suche aktiv · Violett `#9D69D2` Favoriten · Türkis `#00B5B5` Einstellungen aktiv · Grau `#868686` aus/pausiert/indiziert/nicht erlaubt (Offline gestrichelt). Ein Chip-Rezept: Schrift, Rand, Icon in der Basisfarbe, Fläche 5 %; gestrichelt ohne Fläche = unvollständig. (OKLCH-Werte aus dem Mockup nach sRGB umgerechnet.) Details: [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md) → Aufgabe 19.

### 2026-09-28 — Layout-Revision: neue Screens & Konzepte
Einstellungen (Tabs Allgemein / Ignorierte Objekte / Speichermedien — die bisherige Registry ist jetzt der Tab „Speichermedien"), Favoriten-Ansicht, Kontextmenü an Ordnern & Dateien, Scan-Tiefe, Ignore-Liste, Mitteilung „Online-Favoriten", neues Bedienkonzept Filter & Suche (Filterleiste in jeder Ansicht; Suche als eigene Ansicht; Filter in der Suche global, sonst nur im aktuellen Ordner). Toolbar: links Übersicht · Favoriten · Einstellungen, rechts vor dem Suchfeld Filter · Suche. Füllstands-Farbverlauf auf Dashboard-Karten entfällt. Scan-Tiefe/Ignore/Mitteilungen/Favoriten zunächst als UI + Zustand (Mock), ohne Indexing-Backend.

### 2026-09-28 — Einzelentscheidungen zu Widersprüchen Layout ↔ bisherige Entscheidungen
- **„Im Finder anzeigen" nur per Rechtsklick** (Kontextmenü). Das Hover-Finder-Icon entfällt überall. *(hebt 20.09. „Hover-Reveal" auf)*
- **Filter-Popover öffnet per Klick**, nicht per Hover. *(Layout-Text wurde vom Nutzer entsprechend korrigiert)*
- **Popover-Button heißt „Alle N Ergebnisse anzeigen"** mit tatsächlicher Trefferzahl. *(hebt 21.09. „Ergebnisse anzeigen" auf)*
- ⚠️ *Überholt am 29.09. (2): Das Such-Icon öffnet die Filterleiste nicht mehr mit.* **Suche ohne Begriff/Filter:** gelöst durch das neue Filter-&-Such-Konzept — Such-Icon öffnet eine leere Suche mit geöffneter Filterleiste und dem Hinweis „Suchbegriff eingeben oder Filter verwenden". Treffer erscheinen, sobald Begriff oder Filter gesetzt sind.
- **Einstellungen → Speichermedien, letzte Spalte:** Detail-Icon → Medium-Details. Der Chevron zur Spaltenansicht entfällt. *(hebt den Chevron-Punkt vom 20.09. auf)*
- ⚠️ *Überholt am 29.09. (2): Tippen löst nichts mehr aus, erst Enter öffnet die Suche.* **Suchfeld:** Tippen wechselt sofort in die Suchansicht, die Trefferliste aktualisiert sich aber weiterhin **erst mit Enter**. *(bestätigt 21.09.)*
- **Einstellungen-Icon aktiv = Türkis**, Suche & Filter aktiv = Blau. *(Der Styleguide-Text im Layout nennt Türkis noch „Reserve" — Markup und Nutzerangabe gehen vor.)*


### 2026-09-20 — Titelleisten-Navigation (Screens 04, 06, 07)
> ⚠️ **Überholt (28.09.):** Toolbar hat jetzt fünf Icons, das Zahnrad öffnet die Einstellungen (Registry = Tab „Speichermedien"), kein Breadcrumb mehr in der Toolbar. Siehe „Layout-Revision: neue Screens & Konzepte".
Im HTML-Mockup vorhanden, aber im ursprünglichen README-Text nicht beschrieben: die Titelleiste des Hauptfensters trägt links ein **Haus-Icon** und rechts ein **Zahnrad-Icon**, zusätzlich zum jeweiligen Objekte-Suchfeld/Breadcrumb.

- **Haus-Icon** ("Zur Übersicht" / im aktiven Zustand "Übersicht (aktiv)"): navigiert zum Dashboard (Screen 04). Auf Screen 04 selbst ist es im aktiven Zustand (accent-farbig), auf Screen 06/07 neutral.
- **Zahnrad-Icon** ("Einstellungen" laut Mockup-Tooltip): öffnet **die Registry-Tabelle (Screen 01)** — nicht ein generisches App-Einstellungsfenster. Produktentscheidung getroffen am 2026-09-20.

### 2026-09-20 — Klickverhalten Dashboard-Karte & Registry-Zeile
> ⚠️ **Teilweise überholt (28.09.):** Karten-Klick und Karten-Kontextmenü gelten weiter. Der Chevron in der letzten Registry-Spalte ist durch ein Detail-Icon → Medium-Details ersetzt.
Abweichung/Präzisierung gegenüber `layout/README.md` (dort: Karten-Klick öffnet Detail-Modal Screen 05, das dann per Button zum Column Browser führt). Tatsächliches Zielverhalten:

- **Normaler Klick auf eine Dashboard-Karte** → öffnet direkt den **Column Browser (Screen 06)** am Root des Mediums.
- **Kontextmenü (Rechtsklick) auf der Karte** bietet zwei Einträge:
  - „Index anzeigen" → Column Browser (Screen 06), gleiches Ziel wie der normale Klick.
  - „Details" → Detail-Modal (Screen 05).
- **Registry-Tabelle (Screen 01B):** Klick auf den **Namen** einer Zeile öffnet das Detail-Modal (Screen 05). Die Zeile selbst trägt ebenfalls ein Kontextmenü mit denselben zwei Einträgen wie oben.
- Der Chevron-Button (letzte Spalte, Registry) bleibt wie in `layout/README.md` beschrieben: öffnet Column Browser für das Medium.

---

### 2026-09-20 — Hover-Reveal „open in Finder" gilt für jede Online-Zeile, nicht nur die ausgewählte
> ⚠️ **Überholt (28.09.):** Hover-Finder-Icon entfällt komplett; „Im Finder anzeigen" nur noch per Rechtsklick.
Präzisierung von `layout/README.md` (dort etwas missverständlich als „Hover auf aktiver/dunkler Zeile" beschrieben — das meinte nur, dass optisch die dunkle/aktive Zeile im Mockup gezeigt wird, nicht dass Hover an eine vorherige Auswahl gekoppelt sein soll). Tatsächliches Verhalten: Das Finder-Icon soll bei **jeder** Zeile mit `connectionStatus == .connected`/online erscheinen, sobald die Maus darüber ist — unabhängig davon, ob die Zeile aktuell ausgewählt/aktiv (dunkel) ist oder nicht. Gilt für Sidebar-Medienliste und Spalten im Column Browser gleichermaßen.

### 2026-09-20 — „Neues Medium erkannt"-Dialog muss systemweit sein, nicht app-intern
Aktuell (siehe Screenshot-Review, [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md) Aufgabe 9) ist der Dialog als Modal **innerhalb** eines App-Fensters implementiert. Das ist falsch: Das Ereignis "neues Medium angeschlossen" kommt vom OS (Disk-Mount-Notification) und muss **unabhängig davon erscheinen, ob gerade ein App-Fenster offen ist** — als eigenes, immer oberstes Fenster/Panel (z. B. `NSPanel` mit `.floating`/`.utility`-Level, nicht eingebettet in `MainWindowHostView`). Es soll sich anfühlen wie eine System-Benachrichtigung, nicht wie ein In-App-Overlay.

### 2026-09-20 — Spaltenansicht: Detail-Spalte nur bei Bedarf, nicht dauerhaft reserviert
Präzisierung/Korrektur zu Screen 06: Die rechte Detail-Spalte soll **nicht** permanent Platz beanspruchen. Sie erscheint nur, wenn (a) eine Datei ausgewählt wurde, oder (b) die vorhandenen Ordner-Spalten bereits die volle verfügbare Fensterbreite ausfüllen. Andernfalls bleibt der Bereich rechts der Ordner-Spalten komplett leer (kein reservierter „Datei auswählen"-Platzhalter-Block). Mock-Bäume liefern für **alle** Medien klickbare Beispieldateien (nicht nur „Archiv 2019–2021").

### 2026-09-21 — Popover: feste Höhen statt Messung, Wachstum bis Maximalhöhe
Die Popover-Höhe (Menüleisten-Dropdown) wird **nicht mehr zur Laufzeit gemessen** (`sizeThatFits` erwies sich über mehrere Runden als unzuverlässig — Header-Streckung, falsche Mindesthöhe, Leerraum). Stattdessen: feste, aus dem Mockup berechnete Konstanten pro Element (Header, Zeile, Footer), Panel-Höhe wird in Swift deterministisch aus der Zeilenanzahl berechnet. Das Panel **wächst mit jedem Eintrag bis zu einer definierten Maximalhöhe (Vorschlag: 480pt)** — danach scrollt nur die Zeilen-Liste, Header/Footer bleiben fix. Details/genaue Konstanten siehe [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md) → Aufgabe 3b, Runde 23.

### 2026-09-21 — Popover: Textkorrekturen
> ⚠️ **Teilweise überholt (28.09.):** Button heißt wieder „Alle N Ergebnisse anzeigen". Die Kontextmenü-Texte am Menüleisten-Icon gelten weiter.
- "Alle Ergebnisse anzeigen"-Button heißt nur noch **"Ergebnisse anzeigen"** (keine Zahl/„Alle").
- Kontextmenü am Menüleisten-Icon: **"Disk Index anzeigen"** / Trenner / **"Disk Index beenden"** (statt "Öffnen"/"Beenden").

### 2026-09-20 — Spaltenansicht: Spaltenbreite per Drag
Ordner-Spalten im Column Browser sind **breiter als im ursprünglichen Mockup** (Standard **230pt**, Mockup 180pt) und über einen **Drag-Handle** an der rechten Spaltenkante justierbar. Breite wird **global für alle Ordner-Spalten** in `ColumnBrowserState.folderColumnWidth` gehalten (eine Einstellung, kein Mix pro Spaltenindex).

### 2026-09-21 — Hauptfenster: feste Default-Größe beim ersten Start
Bevor ein gespeicherter Fenster-Frame existiert (erster App-Start bzw. nach `setFrameAutosaveName`-Reset): Hauptfenster öffnet mit **1100×750**, **mittig auf dem Bildschirm** — nicht oben an der Menüleiste. Danach übernimmt die normale macOS-Frame-Autosave-Persistenz (Position/Größe merken sich zwischen Starts).

### 2026-09-21 — Suchansicht: Enter statt Live-Filterung
Anders als das Suchfeld im Popover/Dashboard/Registry (die beim Absenden zur Suchansicht springen) filtert die **Ergebnistabelle innerhalb der Suchansicht selbst** nicht mehr live bei jedem Tastendruck, sondern **nur beim Drücken von Enter**. Eingabetext und die tatsächlich angewendete Filter-Query sind getrennte States — das Tippen im Feld selbst bleibt sofort sichtbar, aber die Tabelle aktualisiert sich erst bei Enter.

### 2026-09-21 — Popover: Klick auf Medium-Zeile öffnet Column Browser
Klick auf eine Medium-Zeile im Menüleisten-Popover (Icon/Name-Bereich, nicht die Controls im `trailingSlot` wie Reindex-Button oder %/absolut-Toggle) öffnet den Column Browser für **genau dieses Medium** — dieselbe Navigation wie bei Dashboard-Karten und Registry-Zeilen (`MediumNavigation.openColumnBrowser`). Popover schließt dabei automatisch.

### 2026-09-20 — Pointer-Cursor auf allen interaktiven Elementen
Jedes klickbare Element (Buttons, Hover-Reveal-Icons, Sortier-Header, Karten, Kontextmenü-Trigger, Chips) muss beim Hover einen Hand-/Pointer-Cursor zeigen (`NSCursor.pointingHand`), nicht den Standard-Pfeil — SwiftUI/AppKit macht das bei Custom-Views nicht automatisch. Siehe [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md) Aufgabe 11 für den wiederverwendbaren Modifier.

---

### 2026-09-21 — Dock-Icon nur bei offenem Hauptfenster
> ⚠️ **Icon-Motiv überholt (28.09.):** laut Layout abgerundetes Quadrat mit Verlauf `#2B2B2D` → `#201E1D` und Glyph in `#F2F2F2`. Das Konzept (Dock-Icon nur bei offenem Hauptfenster) gilt weiter.
**Konzept/Zweck:** Die App bleibt grundsätzlich eine reine Menüleisten-App ohne dauerhaftes Dock-Icon — das Hauptfenster ist ein sekundärer, optionaler Teil der App, kein Alltags-Einstiegspunkt. Sobald das Hauptfenster aber offen ist, soll es sich wie ein normales macOS-Fenster verhalten: über ein Dock-Icon **anklickbar in den Vordergrund holbar** (falls es z. B. hinter anderen Fenstern verschwunden ist) und über **⌘-Tab im App-Umschalter anwählbar**. Das ist der eigentliche Sinn des Dock-Icons hier — nicht Branding, sondern Fenster-Erreichbarkeit, solange es offen ist.

**Umsetzung:** `NSApp.setActivationPolicy(.regular)` beim Öffnen des Hauptfensters, `.accessory` beim Schließen. `.regular` bringt beides automatisch mit sich (Dock-Icon **und** ⌘-Tab-Eintrag) — keine zusätzliche Konfiguration nötig, das ist Standard-AppKit-Verhalten für reguläre Apps. **Icon-Motiv (korrigiert 21.09.):** opaker schwarzer Hintergrund (kein transparentes PNG) mit dem Festplatten-Glyph in **Weiß** darüber — nicht Template-gerendert wie in der Menüleiste. Details siehe [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md) → Aufgabe 17.

### 2026-09-21 — Column Browser: neue Statusleiste unter den Spalten
> ℹ️ **Erweitert (28.09.):** Fußzeile jetzt dreigeteilt — in der Mitte der Pfad (bündig mit der ersten Ordnerspalte, bei Überlänge in der Mitte ausgeblendet).
Erweiterung über das Original-Mockup hinaus (Screen 06 kennt das nicht), Nutzer hat eigenes Referenz-Mockup geliefert: eine dezente Statusleiste ganz unten am Fenster (unterhalb der Spalten, mit Trennlinie darüber) zeigt links **„{frei} frei von {gesamt}"** des aktuell ausgewählten Mediums (nur Zahlen, kein Balken, kein %-Toggle) und rechts die **Objektanzahl der aktuell geöffneten/rechtesten Spalte** (Ordner+Dateien zusammen, identisch mit der Zahl im jeweiligen Spalten-Header). Details siehe [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md) → Aufgabe 6.

### 2026-09-21 — %/absolut-Anzeige ist pro Medium, nicht global
Der Toggle zwischen prozentualer und absoluter Belegungsanzeige (Dashboard-Karten, Popover-Fortschrittszeile) gilt **pro Medium**, nicht mehr als ein einziger globaler Schalter für die ganze App. Klick auf eine Karte/Zeile betrifft nur diese eine.


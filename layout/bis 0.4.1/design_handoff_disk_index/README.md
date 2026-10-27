# Disk Index — Konzept & Design-Handoff

Stand: 2026-10-06. Diese README ist mit der Spezifikationsseite `Disk Index App.dc.html` abgeglichen. **Die Screens dort sind die Source of Truth.** Die Texte unter den Abschnitten 00–15 sind aus den Beschreibungstexten der Screens übernommen. Bei Abweichungen gilt der Screen.

## Überblick

Disk Index ist eine macOS-Menüleisten-App, die externe Speichermedien (USB-Sticks, externe SSDs/HDDs, SD-Karten — keine internen Laufwerke) automatisch indiziert. So bleiben Dateien und Ordner auch dann auffindbar, wenn das Medium nicht angeschlossen ist.

Die Spezifikationsseite enthält jeden Screen als statisches Mockup, nummeriert 00–15, jeweils mit Hell- und Dunkel-Variante, wo sie sich unterscheiden. Sie ist eine **Design-Referenz in HTML**, kein Produktivcode. Umgesetzt werden soll sie in der Zielumgebung (natürlich SwiftUI/AppKit). Die Treue ist hoch: Farben, Abstände, Schrift, Icons und Zustände sind final.

Jeder Abschnitt trägt ein Etikett: **ANSICHT** (dauerhafter Fensterinhalt), **MODAL** (Overlay mit Schließen-Möglichkeit), **POPOVER**, **MENÜ** oder **SYSTEM-UI**.

## Layout-Regeln (verbindlich)

- **Keine Layout-Hinweise in Mockups.** Fenster zeigen nur echte UI-Texte. Erklärungen stehen in den Beschreibungstexten der Abschnitte.
- **Zahlen:** Punkt als Tausendertrenner (`238.421`, `12.908`).
- **Lange Namen** (Medien, Ordner, Dateien, Spaltenköpfe, Pfade, Kacheln, Tabellenzellen, Dropdown-Treffer) werden nie umbrochen und nie mit „…“ gekürzt, sondern am Rand mit einem **Verlauf ausgeblendet** (`mask-image: linear-gradient(to right, #000 82%, transparent)`), plus Tooltip mit dem vollen Namen. Ausnahme: die Detail-Spalte, dort bricht der Name um.
- **Cursor:** auf allem Klickbaren die Hand.
- **Letzte Tabellenspalte** immer rechtsbündig.
- **Sortierung:** keine Pfeile, die aktive Spalte ist schwarz und fett.

## Design-Tokens

Basis ist das Modernist-Designsystem (`ds-disk-index.css`, Archivo). Für Disk Index gelten diese Anpassungen:

| Thema | Wert |
|---|---|
| Hintergrund Fenster | `#eae9e9` (Hell), Flächen/Dialoge/Menüs `#ffffff` |
| Text / Bedienung | `#1f1f1f` — Bedienung ist immer schwarz |
| Radien | 6 px (klein) · 8 px (mittel) · 14 px (groß) |
| Linien | 1 px, `--color-divider` (40 % Schwarz) |
| Dark Mode | Grund `#1f1f1f`, Flächen `#2a2a2a`, Trennlinien 18 %, Auswahl Mittelgrau |
| Schrift | Archivo; Buttons 600 |

### Farbrollen (Zustand, nie Bedienung)

| Farbe | Wert | Bedeutung |
|---|---|---|
| Grün | L62 C0,16 H150 | Online (voll), Wird indiziert / ausstehend (gestrichelt, Spinner), Neu erkannt (pulsierender Punkt) |
| Rot | `#E04830` | Fehler, destruktive Aktion („Vergessen“), „Ignorieren“ aktiv im Kontextmenü |
| Gelb | `#EDA12D` | Inhalt jenseits der Scan-Tiefe (gestrichelt) |
| Blau | L62 C0,16 H255 | Filter & Suche: Filter-Button, Filter-Chips, aktives Filter- und Such-Icon |
| Violett | L62 C0,16 H305 | Favoriten: Icons favorisierter Objekte, aktives Favoriten-Icon, aktiver Kontextmenü-Eintrag |
| Türkis | L62 C0,16 H195 | Einstellungen: aktives Einstellungs-Icon |
| Grau | L62 C0 | „Nein“, aus, leer, pausiert, indiziert; Offline (gestrichelt ohne Fläche) |
| Schwarz | `#1f1f1f` | Bedienung: Primär-Buttons, Auswahl, aktive Tabs, Selectgroup, aktive Tabellenspalte, Rechtsklick-Rahmen, Schrift |

Im Dark Mode werden die Statusfarben heller (L72), Chip-Flächen 12 % statt 5 %.

### Buttons, Chips, Selectgroups

| Element | Größe | Rahmen |
|---|---|---|
| **Button groß** | 14 px, Padding 10/18, Schrift 600 | 1 px: Primär `accent-700`, Sekundär `neutral-500`, Destruktiv rot, Bestätigen rot gefüllt mit dunklerem Rand |
| **Button klein** | 12 px, Padding 4/12, Zeilenhöhe 1,2 (24,4 px hoch) | wie groß; Ghost ohne Rahmen |
| **Selectgroup** | 12 px, Padding 4/12; Gruppenrahmen 1 px in der Farbe der aktiven Option | schwarz bei „An/Ja“, grau bei „Aus/Nein“ |
| **Chip / Tag** | 10 px, Padding 3/10 — überall gleich und kleiner als „Button klein“ | 1 px; Rezept: Schrift, Rand, Icon in Basisfarbe, Fläche 5 % |

Nebeneinander stehende Buttons haben immer dieselbe Größe. Jeder Button, der nicht „groß“ ist, ist „klein“. Gestrichelter Rand ohne Fläche steht für „unvollständig“ (wird indiziert, nicht erfasst, offline).

### Status-Chips (ein Chip pro Medium)

Online · „x % indiziert“ (Spinner, gestrichelt) · Fehler (rot) · Offline als Zusatz im selben Chip (grau, gestrichelt): „Offline“, „x % indiziert, offline“, „Fehler, offline“. „Ausstehend“ erscheint im Dashboard nie.

### Suchfelder

Zwei Größen: **Objekt-Suche** (oben rechts, überall gleich) und **Medium-Suche** (kleiner, in Seitenleisten und Filter). Mit Text im Feld erscheint rechts ein X in einem grauen Kreis zum Zurücksetzen.

---

# Screens

Die folgenden Abschnitte sind 1:1 aus den Beschreibungstexten der Spezifikationsseite übernommen.

## 00 — KONZEPT & ABLAUF

### Wie Disk Index funktioniert

Disk Index kümmert sich ausschließlich um externe Speichermedien — USB-Sticks, externe SSDs/HDDs, SD-Karten. Die App läuft dauerhaft über das Menüleisten-Icon. Jedes je angeschlossene Speichermedium wird mit seinem Index gespeichert — auch offline bleibt sein Inhalt durchsuchbar. Eine einzige Suche findet Speichermedien und Objekte (Dateien & Ordner) zugleich (10). Ein Klick auf einen Treffer öffnet die Spaltenansicht an genau dieser Stelle (07). Wichtige Objekte lassen sich als Favoriten markieren (11).

## 01 — MENÜLEISTEN-ICON · SYSTEM-UI

### Status auf einen Blick

Haupt-Icon schlank (regular). Nur die Status-Badges sind fett, alle gleich groß: Wird indiziert = grüner Spinner-Ring, Neu erkannt = pulsierender grüner Punkt, Pausiert = X, Fehler = Ausrufezeichen. Online und fertig indiziert = kein Badge.

**Status-Badges — was genau passiert**

Kein Badge = Medium ist online und vollständig indiziert; dieser Zustand bleibt bewusst ohne visuellen Marker (siehe 03).

## 02 — ERKENNUNGS-DIALOG · MODAL

### Erkennungs-Dialog

Erscheint sofort beim Anschließen eines neuen, unbekannten Speichermediums. Mit „Für dieses Medium merken“ erscheint der Dialog für dieses Medium nicht mehr; die Entscheidung lässt sich unter Einstellungen → Speichermedien (05) ändern. Das Medium wird beim Anschließen sofort registriert und erscheint sofort in den Einstellungen (Speichermedien). „Indizieren“ startet die Indizierung, „Nicht indizieren“ setzt „Soll indiziert werden“ auf Nein. Ein vergessenes Medium gilt als nie gesehen, der Dialog erscheint beim nächsten Anschließen wieder. Läuft gerade eine Pause, erscheint der Dialog trotzdem.

**Dark Mode**

Erkennungs-Dialog. Farben laut Farbrollen · Dark Mode (15).

## 03 — DROPDOWN ANSICHT (POPOVER)

### Schnellübersicht bei Klick

Zeigt nur angeschlossene (Online-)Medien. Medien-Icons schlank (regular) — fett nur in der Menüleiste. Ein Status-Chip erscheint nur, solange ein Medium indiziert wird (Spinner). Kein Chip bedeutet: online und vollständig indiziert.

Automatisches Indizieren: Klick auf „Pausiert“ schaltet nicht sofort um, sondern öffnet ein Popover mit der Dauer (30 Minuten, 1 Stunde, Bis morgen, Für immer). Erst die Auswahl pausiert. Ist bereits pausiert, zeigt das Popover oben „Pausiert für X“ mit Endzeit; die aktive Dauer ist ausgegraut, die anderen ändern die Pause. Klick auf „An“ setzt sofort wieder fort und löscht die Pause. Während der Pause steht beim indizierenden Medium ein Pause-Icon statt des Spinners. Die Pause betrifft nur das Indizieren. Erkennen und Anzeige laufen weiter. „Bis morgen“ endet am nächsten Tag um 9:00 Uhr. Die Pause bleibt nach einem Neustart erhalten. Sind Mitteilungen aktiv, erscheint beim Pausieren die Mitteilung „Indizierung pausiert“ (mit Dauer bzw. Endzeit) und beim Ende der Pause oder beim Klick auf „An“ die Mitteilung „Medien werden wieder indiziert“. Ein Medium, das während der Pause neu angeschlossen wird, löst den Dialog aus und wird nach der Pause automatisch indiziert, sofern es noch online ist.

**Dark Mode**

Dropdown im Ruhezustand und Pause-Auswahl. Farben laut Farbrollen · Dark Mode (15).

## 04 — HAUPTFENSTER · ÜBERSICHT · ANSICHT

### Dashboard aller Speichermedien

Alle Speichermedien mit Index. Jedes Medium trägt genau einen Chip: Online, „x % indiziert“ oder Fehler; ist das Medium nicht angeschlossen, steht Offline im selben Chip („Offline“, „x % indiziert, offline“, „Fehler, offline“). „Ausstehend“ erscheint hier nie. Läuft nur ein Abgleich auf einem vollständig indizierten Medium, bleibt der Chip „Online“. Medien-Icons schlank (regular). Fehler immer rot. Chips und Farben nach Styleguide (15). Favorisierte Medien zeigen ihr Icon in Violett.

**Dark Mode**

Übersicht aller Speichermedien. Farben laut Farbrollen · Dark Mode (15).

## 05 — EINSTELLUNGEN · ANSICHT

### Einstellungsfenster

Eigene Ansicht im Hauptfenster, kein Modal — Aufruf über das Zahnrad-Icon in der Toolbar. Tabs links: „Allgemein“ (Erscheinungsbild, Autostart, Sprache), „Dateien & Ordner“ (Scan-Tiefe, Dateityp-Filter, Ausschlüsse, unsichtbare Dateien, Artefakte), „Speichermedien“ (alle registrierten Medien, auch ohne Entscheidung und ohne Index; neue Medien erscheinen sofort; „Ausstehend“ heißt: noch kein Index, „Nicht erlaubt“ heißt: Nein und noch kein Index) und „Erweitert“ (Mitteilungen, Index jetzt bereinigen, Voreinstellungen, alle Speichermedien vergessen, Fehlerberichte). Unter der Auswahl Hell · Dunkel · Automatisch zeigt eine Animation das gewählte Erscheinungsbild; sie ist genau so breit wie die drei Buttons und sitzt mit 3 px Abstand direkt darunter, mit demselben Rahmen wie die Buttons (Buttons unten ohne Radius, Animation oben ohne Radius). Welche Dateien unter „Unsichtbare Dateien“ und „Artefakte“ fallen, ist in „konzept-anmerkungen.txt“ festgelegt. Bei den Mitteilungen zeigt das Beispiel standardmäßig die Systemmeldung; beim Hover über ein Ereignis wechselt es zur passenden Mitteilung. Tabellen sortieren per Klick auf den Spaltennamen; die aktive Spalte ist schwarz (Tabellen-Regel, 15). Klick auf den Namen oder das Detail-Icon öffnet die Medium-Details (06).

Sprache der Benutzeroberfläche. Die Änderung gilt nach einem Neustart von Disk Index.

Hell oder Dunkel legt das Erscheinungsbild fest. Automatisch folgt der Systemeinstellung von macOS.

Disk Index startet nach dem Anmelden automatisch in der Menüleiste, damit angeschlossene Speichermedien sofort erkannt werden.

Wie viele Ordnerebenen unterhalb des Wurzelverzeichnisses eines Speichermediums durchsucht werden. „5+“ durchsucht uneingeschränkt alles. Wird die Tiefe verringert, verschwinden tiefere Ebenen sofort aus der Ansicht und werden nach 1 Stunde aus dem Index gelöscht, sofort über „Index jetzt bereinigen“ (Erweitert). Wird sie erhöht, erscheint, was noch im Index ist; fehlende Ebenen kommen beim nächsten Scan dazu.

Legt fest, wie sich gesetzte Dateityp- und Endungsfilter beim Durchblättern von Ordnern verhalten. Ordner bleiben sichtbar, damit man sich bis zu den passenden Dateien durchklicken kann.

Namen, Endungen oder Ordner, die auf keinem Speichermedium indiziert werden. Lässt sich auch per Rechtsklick auf ein Objekt setzen. Bereits erfasste Treffer verschwinden sofort aus der Ansicht und werden nach 1 Stunde aus dem Index gelöscht, sofort über „Index jetzt bereinigen“ im Tab „Erweitert“. Wird ein Chip entfernt, erscheint, was noch im Index ist; der Rest kommt beim nächsten Scan dazu.

Schließt versteckte Systemdateien und -ordner vom Index aus. Beim Einschalten verschwinden sie sofort aus der Ansicht und werden nach 1 Stunde aus dem Index gelöscht, sofort über „Index jetzt bereinigen“ (Erweitert). Beim Ausschalten erscheint, was noch im Index ist; der Rest kommt beim nächsten Scan dazu.

Ignoriert temporäre Dateien, Backups, Systemreste und Ordner mit generischen Programmbibliotheken. Beim Einschalten verschwinden sie sofort aus der Ansicht und werden nach 1 Stunde aus dem Index gelöscht, sofort über „Index jetzt bereinigen“ (Erweitert). Beim Ausschalten erscheint, was noch im Index ist; der Rest kommt beim nächsten Scan dazu.

Pro Ereignis einzeln wählbar. Systemmeldungen umfassen Hinweise zu Fehlern und zu abgelaufenen Pausen. „Vollständig indiziert“ erscheint nur, wenn der Scan länger als 59 Sekunden gedauert hat (auch bei einem Abgleich oder „Neu indizieren“). Ist „Mitteilungen aktivieren“ aus, sind die Ereignisse deaktiviert. Beim ersten Start fragt macOS einmalig, ob Mitteilungen erlaubt werden. Wurde das abgelehnt, lässt es sich nur in den macOS-Systemeinstellungen unter „Mitteilungen“ ändern.

Werden Dateien oder Ordner ausgeschlossen, unsichtbare Dateien oder Artefakte ignoriert oder die Scan-Tiefe verringert, verschwinden die betroffenen Einträge sofort aus der Ansicht, auch Favoriten darunter. Aus dem Index gelöscht werden sie nach 1 Stunde. „Index jetzt bereinigen“ löscht sie sofort.

Setzt alle Programmeinstellungen auf die Voreinstellungen zurück. Speichermedien, Index und Favoriten bleiben erhalten.

Vergisst alle Speichermedien und löscht alle zugehörigen Daten: Index, Favoriten, Berechtigungen und Einstellungen je Medium. Die Programmeinstellungen bleiben erhalten. Beim nächsten Anschließen erscheint der Erkennungs-Dialog wieder.

Wurde Disk Index unerwartet beendet, liegt ein Bericht vor. Er enthält die Programmversion, Informationen zu deinem System, die letzten Aktionen und den Ort des Fehlers. Er enthält keine Datei- oder Ordnernamen und keine Suchbegriffe, nur technische Eigenschaften wie die Länge oder Sonderzeichen.

Zwei Stufen. Rot: Aktionen, die Daten löschen oder Medien vergessen. Schwarz: Aktionen, die nicht kritisch sind, aber nicht rückgängig gemacht werden können. Beide brauchen zwei Klicks. Der erste Klick führt nichts aus, sondern füllt den Button bei beiden Stufen komplett rot mit „Bestätigen“. Erst der zweite Klick löst die Aktion aus; danach zeigt der Button kurz grün „Bestätigt“ mit Häkchen. Verlässt der Zeiger den Button oder vergehen 3 Sekunden ohne Klick, kehrt er in den Ausgangszustand zurück. Die Breite bleibt gleich, damit der zweite Klick sicher trifft.

Diese Werte gelten nach der Installation und nach „Voreinstellungen anwenden“ im Tab „Erweitert“.

**Dark Mode**

Einstellungen, Tab „Allgemein“. Farben laut Farbrollen · Dark Mode (15).

Sprache der Benutzeroberfläche. Die Änderung gilt nach einem Neustart von Disk Index.

Hell oder Dunkel legt das Erscheinungsbild fest. Automatisch folgt der Systemeinstellung von macOS.

Disk Index startet nach dem Anmelden automatisch in der Menüleiste, damit angeschlossene Speichermedien sofort erkannt werden.

## 06 — HAUPTFENSTER · DETAIL-OVERLAY · MODAL

### Speichermedium-Detail

Modal auf weißem Grund, Schließen oben rechts. Kennzahlen und Einstellungen des Mediums als Tabellenzeilen. „Nein“ bei „Soll indiziert werden“ stoppt nur die Aktualisierung: Ein bestehender Index bleibt erhalten und durchsuchbar, das Medium bleibt in Seitenleiste, Spaltenansicht und Suche. Entfernt wird der Index erst über „Vergessen“. Der Status-Chip oben rechts ist derselbe eine Chip wie im Dashboard (04). „Inhalt anzeigen“ öffnet das Medium in der Spaltenansicht (07) und ist ausgegraut, solange kein Index vorhanden ist. „Vergessen“ entfernt das Medium aus allen Listen und löscht Index und Favoriten; beim nächsten Anschließen gilt es als unbekannt.

**Dark Mode**

Detail-Overlay eines Speichermediums. Farben laut Farbrollen · Dark Mode (15).

## 07 — HAUPTFENSTER · SPALTENANSICHT · ANSICHT

### Spaltenansicht

Navigation durch den Index eines Mediums wie im Finder. Zu lange Namen blenden per Verlauf aus statt hart abzuschneiden. „Im Finder anzeigen“ per Rechtsklick (Kontextmenü, 12) und bei Online-Medien zusätzlich als Button in der Detail-Spalte. Fußzeile: links der freie Speicher des Mediums, in der Mitte der Pfad — bündig mit der ersten Ordnerspalte, bei Überlänge in der Mitte ausgeblendet —, rechts die Anzahl der Objekte im aktuellen Ordner. Das Filter-Icon öffnet die Filterleiste für das gesamte Medium (08), das Such-Icon die Suche (10).

**Beispiel — Datei auf einem Online-Medium**

Medium angeschlossen, Datei ausgewählt: Die Detail-Spalte zeigt zusätzlich den Button „Im Finder anzeigen“ — gleiche Bezeichnung und gleiches Icon wie im Kontextmenü (12). Status-Chip grün „Online“, kein Offline-Hinweis über den Spalten. Bei Offline-Medien entfällt der Button.

**Beispiel — Wird indiziert**

Ob nicht erfasst oder noch nicht indiziert, wird unterschieden. Ein Ordner, der noch nicht indiziert ist, erscheint ausgegraut, bleibt aber klickbar. Die Detail-Spalte zeigt Ordner-Icon und Name in normaler Darstellung, dazu den grünen Chip „Wird indiziert“ mit Spinner, aber ohne Prozentangabe — wie im Dashboard (04). Nicht erfasste Ordner (außerhalb der Scan-Tiefe oder ausgeschlossen) bleiben wie im Beispiel oben beschrieben.

**Beispiel — Ordner-Inhalt wird geladen**

Sehr große Ordner brauchen manchmal einen Moment. Solange nicht alle Objekte geladen sind, zeigt die Spalte keine Einträge — stattdessen erscheint im Stil der Detail-Spalte, aber ohne grauen Hintergrund, ein Spinner mit Hinweis, warum nichts zu sehen ist, und dem Ladestand („x von x Objekten geladen“). Erst wenn der Ordner vollständig geladen ist, ersetzt die Liste den Hinweis.

**Beispiel — Ordner jenseits der Scan-Tiefe**

Klick auf einen Ordner, dessen Inhalt wegen der Scan-Tiefe (Einstellungen → Dateien & Ordner) nicht indiziert wurde: Es öffnet sich keine weitere Spalte. Die oberste Ebene des Mediums ist immer erfasst — nur tiefere Ebenen können fehlen. Ordner-Icon in Spalte und Detail gelb. Die Detail-Spalte zeigt wie bei Dateien Icon, Name und einen gelben Chip „Inhalt nicht erfasst“ — Gelb, weil der Inhalt wegen der Scan-Tiefe nicht erfasst wird. Darunter steht in dezenter Schrift der Hinweis, dass der Inhalt deshalb nicht indiziert wird, mit einem Textlink „Scan-Tiefe ändern“ zu den Einstellungen (Dateien & Ordner).

**Beispiel — Lange Namen kürzen**

Zu lange Namen werden nie umgebrochen, sondern am Rand mit einem Verlauf ausgeblendet — in den Spalten, in der Spaltenüberschrift und in der Medienliste. Das gilt nicht für die Detail-Spalte, dort bricht der Name um. Beim Überfahren erscheint ein Tooltip mit dem vollständigen Namen. Im Beispiel ist der Ordner mit dem langen Namen geöffnet; er enthält zwei Dateien.

Hochzeitsvideos Archiv Externe Festplatte 2018–2021

Hochzeit Müller-Schneider – Rohmaterial und Endschnitt 2021

**Beispiel — Kontextmenü an einem Ordner**

Rechtsklick auf einen Ordner öffnet das Kontextmenü (12). Das angeklickte Objekt erhält einen schwarzen Rahmen. Das Medium ist offline, daher ist „Im Finder anzeigen“ ausgegraut; bei Ordnern zusätzlich die beiden Dateiendungs-Einträge.

**Beispiel — Mehrfachauswahl**

Mit ⌘-Klick lassen sich mehrere Dateien einer Spalte markieren, mit ⇧-Klick ein Bereich. Rechtsklick auf die Auswahl öffnet das Kontextmenü (12) für alle markierten Objekte. „Im Finder anzeigen“, „Nach Namen suchen“ und „Nach Dateiendung suchen“ sind bei mehr als einem Objekt nicht verfügbar — auch wenn das Medium angeschlossen ist. Favorit und Ignorieren gelten für alle markierten Objekte. Die Detail-Spalte zeigt die Anzahl und Gesamtgröße der Auswahl.

**Dark Mode**

Spaltenansicht. Farben laut Farbrollen · Dark Mode (15).

## 08 — HAUPTFENSTER · SPALTENANSICHT MIT FILTER · ANSICHT

### Filter & Suche — Bedienkonzept

Filter und Suche sind zwei getrennte Werkzeuge in der Toolbar, rechts direkt vor dem Suchfeld: Filter-Icon, Such-Icon. Der Filter funktioniert überall, die Suche ist eine eigene Ansicht (10). Die Auswahl im Filter-Popover beschreibt 09.

**Filter auf dem ganzen Medium**

Filter-Icon geklickt, Dateityp „PDF“ und Alter „Letzte 30 Tage“ gewählt, mit „Und“ verknüpft. Der Filter gilt für das ganze Medium „Archiv 2019–2021“ und damit für jede Spalte: Alle Spalten zeigen nur passende Dateien, Ordner bleiben sichtbar („Ordner weiterhin anzeigen“), damit man sich zu den Treffern durchklicken kann. Spaltenkopf und Fußzeile zeigen, wie viele Objekte übrig sind. Die Medium-Auswahl entfällt hier.

**Dark Mode**

Filter auf dem ganzen Medium, mit „Und“ verknüpft. Farben laut Farbrollen · Dark Mode (15).

## 09 — FILTER-AUSWAHL · POPOVER

### Was sich filtern lässt

Klick auf den „Filter“-Button in der Filterleiste öffnet dieses Popover — in der Spaltenansicht (08) wie in der Suche (10). Drei Eingrenzungen: Dateityp (Mehrfachauswahl) mit freier Eingabe eigener Dateiendungen, Medium (durchsuchbare Liste, ab 15 Einträgen scrollbar) und Alter (Bereiche). Filter gelten immer global ab dem Wurzelverzeichnis: in der Suche über alle Medien, in der Spaltenansicht über das gesamte geöffnete Medium. Die Medium-Auswahl gibt es deshalb nur in der Suche; in der Spaltenansicht entfällt sie. Jede Auswahl erscheint sofort als blauer Chip in der Filterleiste. Dateiendung: Eingabe mit Enter bestätigen, die Endung erscheint als blauer Chip direkt unter dem Feld (per ✕ entfernbar). „jpg“ und „.jpg“ sind gleichwertig — fehlt der Punkt, setzt das System ihn für den Abgleich automatisch davor; Groß-/Kleinschreibung wird ignoriert, angezeigt wird immer mit Punkt. Sobald ein Dateityp oder eine Endung gesetzt ist, ist „Ordner“ deaktiviert — Ordner bleiben in der Spaltenansicht über die Einstellung „Ordner weiterhin anzeigen“ (Dateien & Ordner, Standard: an) sichtbar, damit man sich zu den Treffern durchklicken kann; in der Suche wirkt der Filter strikt. Wie mehrere Filter verknüpft werden („Oder“/„Und“), steuert der Link-Button in der Filterleiste (08). Dateitypen-Kategorien siehe Styleguide (15).

**Dark Mode**

Filter-Popover. Farben laut Farbrollen · Dark Mode (15).

## 10 — HAUPTFENSTER · SUCHE · ANSICHT

### Objekte suchen

Eine Suche für alles — kein Umschalter zwischen Medien und Objekten. Start über das Such-Icon (leer, mit geöffneter Filterleiste) oder durch Tippen ins Suchfeld. Solange die Suche aktiv ist, ist das Such-Icon blau; Filter wirken hier global über alle Medien. Mit Text im Feld erscheint rechts ein X zum Zurücksetzen (15). Passende Medien erscheinen als Kacheln über der Tabelle. Klick auf eine Zeile öffnet den Treffer in der Spaltenansicht (07); „Im Finder anzeigen“ nur per Rechtsklick (12). Fußzeile wie in der Spaltenansicht, vorerst nur mit der Trefferanzahl rechts. Die Zustände unten folgen dem Ablauf: Suche öffnen → nur filtern → Begriff eingeben → Begriff und Filter kombinieren → keine Treffer → Kontextmenü.

**1 · Nach Klick auf das Such-Icon**

Leere Suche, Filterleiste geöffnet, beide Icons blau. Statt einer Liste erscheint ein Hinweis auf grauem Grund. Sobald ein Suchbegriff oder ein Filter gesetzt ist, erscheinen Treffer.

Über das Such-Icon geöffnet, Suchfeld leer, Filter „PDF“ gesetzt. Weil die Suche aktiv ist, wirkt der Filter global: alle PDFs aus allen erfassten Medien, online wie offline. Keine Medien-Kacheln, da kein Suchbegriff auf einen Mediennamen passt. Ohne Suche (08) würde derselbe Filter das gesamte geöffnete Medium eingrenzen.

Suche durch Tippen gestartet. Nur das Such-Icon ist blau, keine Filterleiste. Treffer aus allen Medien.

Filterleiste geöffnet, Filter gesetzt — sie gelten global. Filter-Button und Chips blau; jeder Chip lässt sich einzeln per ✕ entfernen.

Kein Objekt passt zu Suchbegriff und Filtern. Hinweis auf grauem Grund, Suchbegriff und Chips bleiben zum Anpassen stehen.

Rechtsklick auf eine Ergebniszeile öffnet dasselbe Kontextmenü wie überall (12). Die angeklickte Zeile erhält einen schwarzen Rahmen. „Rechnungen_2021“ ist ein Ordner — die Dateiendungs-Einträge sind ausgegraut.

**Dark Mode**

Suche, Zustand 4 · Suchbegriff und Filter. Farben laut Farbrollen · Dark Mode (15).

## 11 — HAUPTFENSTER · FAVORITEN · ANSICHT

### Favoriten

Aufruf über das Favoriten-Icon in der Toolbar (dann violett). Aufbau wie die Suche (10): oben favorisierte Speichermedien als Kacheln, darunter favorisierte Objekte. Statt Filter eine Chip-Leiste „Alle / Online / Offline“; der aktive Chip ist blau (Filter). Alle Icons favorisierter Objekte sind violett.

**Beispiel — Kontextmenü an einem Ordner**

Rechtsklick auf einen Ordner öffnet das Kontextmenü (12). Das angeklickte Objekt erhält einen schwarzen Rahmen. Das Medium ist offline, daher ist „Im Finder anzeigen“ ausgegraut; bei Ordnern zusätzlich die beiden Dateiendungs-Einträge.

**Dark Mode**

Favoriten. Farben laut Farbrollen · Dark Mode (15).

## 12 — KONTEXTMENÜ · MENÜ

### Kontextmenü an Ordnern & Dateien

Rechtsklick auf jedes Objekt — in der Spaltenansicht (07), in der Suche (10) und in den Favoriten (11). Einziger Weg zu „Im Finder anzeigen“. Vier Gruppen, durch Trenner getrennt: Finder · Favorit · Suchen · Ignorieren. Das angeklickte Objekt erhält einen schwarzen Rahmen. Nicht verfügbare Einträge sind ausgegraut statt ausgeblendet — die Menüstruktur bleibt immer gleich. Aktive Zustände tragen ein Häkchen: Favorit in Violett, Ignorieren in Rot (solange der Ausschluss besteht).

**Was die Einträge tun**

**Dark Mode**

Kontextmenü. Farben laut Farbrollen · Dark Mode (15).

## 13 — ABSTURZBERICHT · MODAL

### Absturzbericht

Erscheint beim nächsten Start, wenn Disk Index zuvor unerwartet beendet wurde. Zwei Buttons: „Bericht senden“ überträgt den Bericht ausschließlich an die Disk-Index-API, „Bericht nicht senden“ verwirft ihn und schließt den Dialog. Der Bericht enthält grundsätzlich keine Datei- oder Ordnernamen. Mit „Künftig automatisch senden“ werden spätere Berichte ohne Rückfrage an die API gesendet.

**Dark Mode**

Absturzbericht. Farben laut Farbrollen · Dark Mode (15).

## 14 — INDIZIERUNGSFEHLER · MODAL

### Medium konnte nicht indiziert werden

Erscheint, wenn ein Lauf auf einem Medium fehlschlägt — aber nur, solange das Hauptfenster geöffnet ist. Der Dialog ist die Antwort auf den Fehler-Status im Menüleisten-Icon (01), im Dropdown (03) und im Dashboard (04). „Schließen“ schließt nur den Dialog; der Fehler bleibt am Medium bestehen. „Erneut versuchen“ setzt das Medium wieder auf indizierbar und startet den Scan neu. Parallel erscheint eine macOS-Mitteilung (Systemmeldungen, 05 → Erweitert); ein Klick darauf öffnet das Hauptfenster mit diesem Dialog. Der Grund steht nur da, wenn er bekannt ist. Mehrere Fehler erscheinen nacheinander. Schlägt der neue Versuch wieder fehl, erscheint der Dialog erneut, höchstens dreimal pro Medium und Stunde. Ist das Hauptfenster geschlossen, erscheinen nur die macOS-Mitteilung und das Ausrufezeichen; beim nächsten Öffnen erscheint der Dialog einmal.

**Dark Mode**

Indizierungsfehler und macOS-Mitteilung. Farben laut Farbrollen · Dark Mode (15).

## 15 — STYLEGUIDE & ICON-SETS

### Verbindliches Styleguide-Set

Ab hier verbindlich für alle Screens. Zwei Suchfeld-Größen: die Objekt-Suche (immer oben rechts) ist überall identisch dimensioniert; die kleine Medium-Suche in Sidebars ist bewusst kleiner & dezenter.

**Farbrollen**

Farbe bedeutet immer einen Zustand, nie eine Bedienung — bedient wird in Schwarz. Alle Farben teilen Helligkeit und Sättigung, nur der Farbton wechselt. Chip-Rezept: Schrift, Rand und Icon in der Basisfarbe, Fläche in der Basisfarbe mit 5 % Deckkraft. Gestrichelt ohne Fläche = unvollständig (wird indiziert, nicht erfasst, offline). Pro Medium genau ein Chip. Offline kommt als Zusatz in denselben Chip (grau, gestrichelt): „Offline“, „x % indiziert, offline“, „Fehler, offline“. Online ist stärker als „indiziert“.

**Buttons, Chips & Kombis**

Regel: jeder farbige Button/Chip trägt eine Border in einem dunkleren Ton derselben Farbe — besonders wichtig beim Ja/Nein-Paar. Der kleine Button übernimmt exakt die Höhe/Größe der Selectgroup daneben. Destruktive (rot) und nicht umkehrbare, unkritische Buttons (schwarz) nutzen immer den Bestätigungsmodus (05): erster Klick → komplett gefüllt mit „Bestätigen“, zweiter Klick führt aus.

**Suchfelder**

**Cursor-Regel**

Auf allen klickbaren Elementen — Buttons, Icon-Buttons, klickbare Zeilen, entfernbare Chips — immer die Hand (Link-Cursor), nie der Standard-Pfeil.

**Suchfeld — Reset-Verhalten**

Verbindlich für jedes Suchfeld — Medium-Suche wie Objekt-Suche: Sobald der Nutzer Text eingibt, erscheint rechts im Feld ein kleines X in einem grauen Kreis. Klick darauf leert das Feld und setzt die Suche/den Filterzustand zurück. Im Leerzustand ist das X nicht sichtbar.

**Favoriten**

Favoriten haben ein eigenes Icon: „Favoriten“ (zwei Lesezeichen) für die Navigation, „Favorit“ (ein Lesezeichen) am einzelnen Objekt. Inaktiv als Kontur in Textfarbe, aktiv gefüllt in Violett — transparente Füllung wie bei den Chips (Duotone), nie in Blau (Filter). Ist ein Objekt als Favorit markiert, wird zusätzlich sein eigenes Icon (Ordner, Datei, Speichermedium) violett — überall, wo es erscheint.

**Tabellen-Regel**

Letzte Spalte immer rechtsbündig, ihr Inhalt am rechten Rand verankert. Keine Sortier-Pfeile in den Headern — Spaltennamen sind klickbar (Cursor: Hand) und sortieren; die aktiv sortierte Spalte zeigt sich allein über schwarzen, fetten Header-Text.

Typen & Dateitypen: schlank (regular). Status: dezent fetter — der einzige bewusste Ausreißer vom Rest der UI.

**Speichermedientypen**

**Status**

**Dateitypen**

**Dateitypen — Erweiterungen**

Aus Phosphor (ph-file-*), im Einsatz neben den bestehenden generischen Dateityp-Icons oben.

**System Icons**

**Dark Mode**

**Farbrollen**

Kein invertierter Kontrastmodus, sondern eigene Stufen: schwarzer Grund, Fenster #1f1f1f, Flächen #2a2a2a, Trennlinien mit 18 % statt 40 %. Auswahl wird Mittelgrau statt Weiß, damit helle Flächen nur für Bedienung stehen. Statusfarben werden heller (L72 statt L62, etwas weniger Sättigung), Chip-Flächen 12 % statt 5 %, weil 5 % auf Dunkel verschwindet.

**Icons je Farbe**

**Status**

**Favoriten**


---

## Dateien

- `Disk Index App.dc.html` — die Spezifikation, alle Screens 00–15 auf einer Seite.
- `ds-disk-index.css` — Tokens und Komponenten.
- `Farbschema.dc.html`, `App-Namen.dc.html` — Farbschema und Namensentwürfe.

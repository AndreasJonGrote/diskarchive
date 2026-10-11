# Datenbank-Konzeption (Entwurf)

Stand 09.10.2026. Sammlung der Überlegungen des Nutzers zum Umbau der Datenbank. Noch keine Entscheidung, noch nicht in README oder TODO übernommen.

## Ausgangslage

- Alpha: **kein Datenerhalt nötig**. Die Datenbank darf verworfen und neu gebaut werden. Der einzige vorhandene Index entsteht in unter einer Sekunde neu. Es gibt keine Beta-Tester.
- Neue Funktionen kommen: Metadaten je Dateityp, Thumbnails, Prüfsummen für Duplikaterkennung.
- Heute liegen in `item` neben dem Baum auch schon einfache Metadaten (`ext`, `sizeBytes`, `modifiedAt`, `isPackage`, `fileID`) und Scanner-Buchhaltung (`depth`, `lastSeenAt`, `contentStamp`, `listedAt`, `unreadable`).

## Vorschläge des Nutzers

1. **`item` zur reinen Baumtabelle machen.** Schlanke Zeilen, Metadaten in Seitentabellen. *Korrektur 09.10.:* Ein Join auf die Seitentabellen ist **kein Problem** (1:1 über den Primärschlüssel ist billig). Ob ein Join oder ein Nachladen per ID besser ist, entscheidet je Bildschirm die Messung. Wichtiger ist, dass das Ganze **skalierbar** gedacht wird.
2. **Alle Metadaten jetzt trennen.** Jede Funktion bekommt eine eigene Tabelle mit Verweis auf die `item`-ID (`item_<funktion>`). So ist die Struktur "in alle Richtungen" kompatibel für künftige Funktionen. Metadaten braucht man ohnehin nur, wenn man Details zu einer Datei oder einem Ordner öffnet.
3. **Metadaten: alles speichern, wenige Schlüssel als Felder.** Der Rest bleibt als Ganzes erhalten.
4. **Register der gesichteten Medien als eigene Tabelle.** Dort liegen Entscheidungen, "zuletzt gesehen" und weitere Stammdaten.
5. **Container mit eigener Tabelle je Platte.** Eine Platte mit 5 Mio. Dateien muss dann nie gelesen werden, außer man sucht gezielt darin.

## Festgelegte Felder (Anzeige und Filter)

Fehlende Werte werden immer als "–" gezeigt.

| Typ | Felder |
|---|---|
| Video | Auflösung, Dauer, FPS (mit Dezimalstellen), Codec (lesbar), Farbraum mit SDR/HDR |
| Foto/RAW | Auflösung, Megapixel, Farbraum (DPI bewusst gestrichen) |
| Audio | Dauer, Samplerate, Qualität (Bitrate oder Bit-Tiefe), Kanäle |
| PDF | Seiten, Seitenformat, Text (durchsuchbar oder Scan), Schutz |

Weitere Entscheidungen:
- **Thumbnails [offen, zu besprechen]:** zuerst 400 px lange Seite (etwa 20 KB je Bild, 5.000 Fotos ca. 100 MB). Am 10.10. will der Nutzer eher **250 px** (etwa 8 bis 12 KB je Bild, 5.000 Fotos ca. 40 bis 60 MB; Überschlag, nicht gemessen).
- **Duplikate:** sichere Erkennung über mehrere Medien hinweg.
- **QuickLook:** nur live, solange das Laufwerk angeschlossen ist.

## Bedenken und Fragen des Nutzers

- **Skalierbarkeit zuerst.** Join ist erlaubt. Entscheidend ist, dass die Struktur mit mehr Dateien, mehr Medien und mehr Funktionen mitwächst, ohne dass Hauptabfragen langsamer werden oder umgebaut werden müssen.
- **Nadelöhr Datenbank.** Wenn dort der Engpass liegt, soll die Architektur das berücksichtigen.
- **Zu viele Tabellen?** Eine Tabelle je Platte könnte bei 300 Medien unklug sein.
- **Grenze für die Medienzahl?** Sollte man bei 50 Medien eine Grenze setzen? Wie viele Medien kann man "kommunizieren"?
- **Last durch die neuen Funktionen.** Wie hoch sind Daten- und Performance-Last bei Thumbnails, Metadaten-Tiefe und Duplikaterkennung?

## Skalierungsachsen (Prüfmaßstab für jede Entscheidung)

| Achse | Frage |
|---|---|
| Objekte je Medium | Bleibt die Spaltenansicht bei 100 / 5.000 / 50.000 Kindern und bei 5 Mio. Dateien flott? |
| Medienzahl | Trägt die UI 300 Medien (Seitenleiste, Dashboard, Einstellungen, Filter)? |
| Gesamtobjekte | Bleibt die Suche über alle Medien schnell (5 bis 20 Mio.)? |
| Funktionen | Lässt sich die nächste Funktion als Seitentabelle ergänzen, ohne `item` oder Abfragen anzufassen? |
| Schreiber | Können zwei Medien gleichzeitig indiziert werden, ohne zu blockieren? |
| Start und Pflege | Bleiben Start, Prüfung, Löschen und Bereinigung bei großen Datenmengen kurz? |

## Empfohlene Reihenfolge der Entscheidungen

Die Reihenfolge richtet sich danach, was spätere Entscheidungen beeinflusst und was sich billig umkehren lässt.

1. **Messwerkzeug bauen (zuerst).** Generator für synthetische Daten: 1 Mio. Objekte auf einem Medium und 300 Medien mit zusammen 9 Mio. Objekten. Ohne Zahlen bleiben alle weiteren Punkte Vermutung. Das Werkzeug darf das alte und das neue Schema nebeneinander laden, damit es ein "vorher" gibt.
2. **Architektur festlegen: eine Datei oder eine Datei je Medium plus Register.** Diese Entscheidung ist die teuerste, wenn man sie später ändert (jede Abfrage, jede Löschfunktion, die Suche). Entscheiden anhand von: Suche über alle Medien, Start, Medium löschen, zwei Medien gleichzeitig indizieren, Favoriten.
3. **Konvention für Seitentabellen festschreiben.** `item_<funktion>`, `itemID` als Primärschlüssel, `ON DELETE CASCADE`, Staleness-Felder (`srcSize`, `srcModifiedAt`, `extractorVersion`). Thumbnails in eigener Datei. Das ist billig und kostet nichts, solange es vor den ersten Funktionen steht.
4. **Zuschnitt von `item` und `medium` bestimmen.** Baumspalten, Dateimetadaten, Scanner-Buchhaltung, Pfad, Favoriten; bei `medium` Stammdaten, Zähler und Überwachungsstand. Hier entscheiden die Zahlen aus Schritt 1 (Altersfilter, Pfad, Größe der Zeile).
5. **Schema neu schreiben und Abfragen umstellen.** In kleinen Aufgaben mit Zwischenabnahme: zuerst Schreibwege (Scanner, Watcher, Abgleich, Bereinigung), dann Lesewege (Spaltenansicht, Suche, Favoriten). Alte Datenbank beim Start verwerfen.
6. **Messung wiederholen.** Gegen die Schwellen prüfen (Vorschlag: Spaltenansicht nicht langsamer, Datenbank mindestens 20 % kleiner oder Abfrage mindestens 25 % schneller). Danach Altlasten entfernen.
7. **Erste Funktion als Probe:** Metadaten (Foto-Auflösung, Megapixel, Farbraum) als `item_meta`. Beweist, dass die Konvention aus Schritt 3 trägt, bevor Video, Audio, PDF, Prüfsummen und Thumbnails folgen.
8. **Stichtag = Beta-Release** (Nutzer 10.10.): der Umbau ist Pflicht **vor** der Beta; ab dem ersten Download durch eine andere Person gelten echte Migrationen.

**Faustregel:** Alles, was sich später nur mit Migration oder Umbau der Abfragen ändern lässt (Architektur, Konvention, Zuschnitt), kommt vor allem, was sich nachträglich ergänzen lässt (weitere Seitentabellen, weitere Felder).

## Offene Punkte

- ~~Altersfilter ohne Join~~ entfällt: Mit erlaubtem Join kann `modifiedAt` in `item_file` liegen (Index dort), der Filter joint. In der Messung gegen die Variante "im Baum" prüfen.
- Pfad (`path`): eigene Tabelle oder berechnen?
- `medium` im selben Zug trennen (Stammdaten, Zähler, Überwachungsstand)?
- **Architektur:** eine gemeinsame Datei mit schlankem Schema, oder eine **Datei je Medium** plus kleines Register? (Eine Tabelle je Medium in einer Datei ist nicht empfohlen.)
- Messung mit 1 Mio. Einträgen und mit vielen Medien, bevor entschieden wird.
- Schwelle, ab der ein Umbau als gelungen gilt.

## Ist-Stand (Claude, 11.10., echte Datenbank des Nutzers: 1 Medium, 1,6 Mio. Einträge, 1,38 GB)

Datei: `~/Library/Application Support/Disk Archive/index.sqlite` (+ `-wal`, `-shm`). Schema aus 9 Migrationen (`v1` … `v9-item-children-order`, Code: `Storage/IndexDatabase.swift`).

| Tabelle | Funktion | Größe |
|---|---|---|
| `medium` | ein Eintrag je Speichermedium: Kennung, Name, Typ, Kapazität, Entscheidung, Status, Zähler, Überwachungsstand (FSEvents), Zeitstempel | klein |
| `item` | **eine Zeile je Datei/Ordner, alle Medien zusammen**: Baum (`mediumID`, `parentID`, `depth`, `path`), Dateidaten (`name`, `ext`, `sizeBytes`, `modifiedAt`, `isFolder`, `isPackage`, `fileID`), Scanner-Buchhaltung (`lastSeenAt`, `removedAt`, `contentStamp`, `listedAt`, `unreadable`), Nutzer (`isFavorite`) | 359 MB |
| `item_fts` (+ `_data`, `_idx`, `_docsize`, `_config`) | Volltextsuche auf `name` (FTS5, Trigramm, verweist auf `item`) | **484 MB** |
| `grdb_migrations` | welche Schema-Schritte gelaufen sind | klein |

Indizes auf `item`: `item_path` (184 MB), `item_children` (119 MB, Spaltenansicht), `item_identity` (111 MB, eindeutig je Ordner+Name), `item_modified` (54 MB), `item_parent` (25 MB), `item_ext` (22 MB), `item_removed` (19 MB). Spalte `path` allein: 143 MB Text.

**Auffällig:** Die Suche (Trigramm-Index) ist der größte Block, größer als die Daten selbst. Pfad als Text + Pfad-Index ≈ 330 MB, obwohl der Pfad aus `parentID` ableitbar ist. `item` mischt vier Arten von Daten (Baum, Datei, Buchhaltung, Nutzer).

## Beschluss Nutzer 11.10.: Status je Eintrag statt Prüfung beim Lesen

Jeder Eintrag bekommt einen **Status**: normal `sichtbar`; `zu-löschen`, wenn eine Regel ihn ausschließt.
- Ändert der Nutzer eine Regel (Ausschluss, unsichtbare Dateien, Artefakte, Scan-Tiefe), sucht ein **Hintergrundlauf ohne zu blockieren** die betroffenen Einträge (in Blöcken, so viel wie möglich per SQL: Endung, Name, Tiefe, `.`-Präfix) und setzt sie auf `zu-löschen`.
- **Eine Stunde nach der letzten Regeländerung** werden alle `zu-löschen`-Einträge entfernt (der Zähler startet bei jeder Änderung neu, wie heute `pruneAt`); „Index jetzt bereinigen“ sofort.
- Wird eine Regel vor dem Löschen zurückgenommen, setzt derselbe Lauf die Einträge wieder auf `sichtbar`.
- Alle Lesewege (Spalten, Suche, Zahl, Favoriten) filtern nur noch `status = sichtbar` in SQL; keine Namensprüfung in Swift mehr.
- **Warteschlange (Nutzer 11.10.):** Jede Regeländerung (z. B. jeder neue Chip in der Ignorierliste) legt einen Auftrag in eine **Warteschlange** im Hintergrund; die Aufträge werden der Reihe nach abgearbeitet. In der Regel ist sie nach 2–4 s leer, also bevor der Nutzer aus den Einstellungen zurück in Spalten oder Suche ist. Blockiert wird praktisch nie; im Zweifel dauert der erste Blick nach den Einstellungen etwas länger.
- **Während die Warteschlange läuft:** Die Suche **wartet** und wirkt, als dauere sie länger; keine Prüfung in Swift. Die **Spaltenansicht** zeigt in der Zeit den Ladehinweis „Inhalte werden geladen“ (Nutzer 11.10.: gut, passiert ja nur einmal). Ab 0.5 gibt es einen **Wartescreen der Suche** (neues Layout); die Suche braucht dafür einen Zustand „Suche läuft“, der dieses Warten umfasst.
- **Pflicht: zuverlässig weiter (Nutzer 11.10.).** Suche und Spalten müssen **sicher mitbekommen**, wann die Warteschlange leer ist, und dann sofort starten; nie in einem Wartezustand hängen bleiben. Umsetzung über ein Ereignis „Warteschlange leer“ (wie die bestehenden `IndexChange`-Meldungen), nicht über Abfragen in Abständen. Zusätzlich eine Sicherung: Endet ein Auftrag mit Fehler oder wird die App beendet, gilt die Warteschlange als leer (offene Aufträge laufen beim nächsten Start weiter), damit nichts dauerhaft wartet. Test-Pflicht: Suche während laufender Warteschlange startet, Warteschlange endet (auch mit Fehler) → Ergebnis erscheint ohne weitere Nutzeraktion.
**Zeitpunkt:** Teil des Schema-Umbaus in 0.3 (neue Spalte in der Baumtabelle). Bis dahin überbrückt Aufgabe 216.

## Hinweise aus der Prüfung des Codes

- **Trefferzahl mit Bereich (Messung 211, 11.10.):** 1,2 Mio. Treffer zählen dauert 4,4 s, weil Artefakt-Regeln und Namensmuster in Swift geprüft werden (ohne Bereich 0,16 s). Für 0.3: Einstufung (versteckt, Artefakt, ausgeschlossen) **beim Scannen** als Spalte/Flag speichern, dann zählt reines SQL.
- **Suchindex (Messung Claude 11.10., 1,6 Mio. Einträge):** seltenes Wort `LIKE` 136 ms warm / 1.643 ms kalt, FTS-Trigramm 21–25 ms; häufiges Wort beide ~150–280 ms. FTS-Trigramm belegt 484 MB.
- **Beschluss Nutzer 11.10.: Teilwortsuche bleibt Pflicht, umgesetzt mit `LIKE '%…%'`, ohne vorher zerlegten Suchindex (kein FTS/Trigramm).** Folgen: Datenbank rund ein Drittel kleiner, Suche wächst linear mit der Zahl der Einträge (hochgerechnet 9 Mio. ≈ 0,8 s warm, kalt mehrere Sekunden). Gegenmittel, in 0.3 zu prüfen und mit 196 zu messen: (1) **schmale Namenstabelle** (nur `id`, `name` bzw. kleingeschriebener Name), damit `LIKE` nur wenige MB statt der ganzen Zeilen liest; (2) `LIMIT 500` beendet die Suche bei häufigen Begriffen früh, nur die Trefferzahl braucht den ganzen Durchlauf (läuft nachgereicht, 215); (3) Popover-Suche mit kurzer Wartezeit nach dem Tippen (z. B. 250 ms) und Abbruch der vorigen Suche; (4) Ziel aus der Messung ableiten (Vorschlag: Ergebnisliste < 300 ms bei 9 Mio. Einträgen, warm).

- Der Scanner schreibt mit UPDATE oder INSERT, nie mit INSERT OR REPLACE. Die `item.id` bleibt stabil, Seitentabellen überstehen jeden Neu-Scan.
- `item_fts` ist eine externe FTS5-Tabelle auf `item.name`. `name` und `id` müssen in `item` bleiben.
- `IndexDatabase` führt bei jedem Öffnen `PRAGMA quick_check` über die ganze Datei aus. Große Daten (Thumbnails) gehören deshalb in eine eigene Datei.
- Die Spaltenansicht (`childrenPage`) liest heute alle Spalten von `item` und sortiert nur nach `isFolder`, `name`, `id`.

## Vergleich der Architekturen (Einschätzung, noch nicht gemessen)

| | Eine gemeinsame Datei | Eine Datei je Medium plus Register |
|---|---|---|
| Medium vergessen | Löschen in Blöcken, Vacuum | Datei löschen |
| Beschädigung | trifft alles | nur das Medium |
| Start | prüft die ganze Datei | liest nur das Register |
| Paralleles Indizieren | ein Schreiber | parallel möglich |
| Globale Suche | eine Abfrage | über alle Dateien (SQLite hängt standardmäßig nur 10 an) |
| Favoriten, Duplikate über Medien | eine Tabelle | Register oder zentraler Index nötig |

## Stichtag

**Ab 0.4 nur noch erweitern (Nutzer 10.10.):** Die Struktur aus 0.3 ist so gebaut, dass spätere Funktionen (Metadaten, EXIF, Vorschaubilder, Prüfsummen) **nur neue Tabellen oder neue Spalten hinzufügen**, nie bestehende umbauen. Die Baumtabelle enthält nur den Baum und die Grunddaten aus dem Dateisystem (Name, Endung, Größe, Änderungsdatum); alles Weitere kommt erst nach 0.4 als eigene Tabelle dazu. Auf **anderen Rechnern** (ab 0.4) wird nie etwas gelöscht: ein Update erweitert die Datenbank einmalig beim Start, die App funktioniert danach mit den vorhandenen Daten weiter. Auf dem **Mac des Nutzers** darf bis 1.0 alles gelöscht werden.

Daraus folgt für 0.3: Alles, was sich später nur durch **Umbau** ändern ließe (Architektur, Zuschnitt der Baumtabelle, Konvention der Nebentabellen, Schlüssel), muss jetzt stimmen. Metadaten, EXIF, Vorschaubilder und Prüfsummen existieren in 0.3 noch **nicht**; die Struktur muss sie nur später ohne Umbau aufnehmen können.

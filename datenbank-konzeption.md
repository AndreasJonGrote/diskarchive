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

## Hinweise aus der Prüfung des Codes

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

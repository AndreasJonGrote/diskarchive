# ROADMAP.md — Disk Archive

Stand 10.10.2026. Der Weg von **0.1 Beta** (jetzt) bis **1.0**. Die Versionsnummern und ihre Reihenfolge stammen vom Nutzer. Mit **[Vorschlag]** markierte Zeilen sind Ergänzungen von Claude und noch nicht bestätigt.

**Maßgeblich ist der Abschnitt „Roadmap“ in [README.md](README.md).** Diese Datei ist die ausführliche Fassung mit Abnahmekriterien. Bei Widerspruch gilt die README.

Gilt zusammen mit [README.md](README.md) (Konzept), [TODO.md](TODO.md) (offene Aufgaben für Cursor), [DONE.md](DONE.md) und [datenbank-konzeption.md](datenbank-konzeption.md).

## Überblick

| Version | Inhalt | Bemerkung |
|---|---|---|
| **0.1 Beta** | **jetzt** | Kern läuft auf echten Daten, Fehler sind noch bekannt |
| **0.2** | alle bekannten Fehler beheben | danach gibt es keine offenen Probleme |
| **0.3** | neue Datenbankstruktur | letzte Version mit freiem Verwerfen der Datenbank |
| **0.3.1** | API-Warteschlange | ein Weg ins Netz; Versions-Check und Sperre kommen mit dem Update-Modal in 0.4 |
| **0.4** | letzte Fixes, **Beta für Beta-Tester** | erste Weitergabe nach außen |
| **0.5** | Metadaten und EXIF (Code und Design) | erste Funktion auf der neuen Struktur |
| **0.6** | Vorschaubilder | Thumbnails |
| **0.7** | Export von CSV-Listen | |
| **0.8** | Duplikate erkennen | |
| **0.9** | Lizenz | Schlüssel, Testversion |
| **1.0** | erste fertige Version | |

**Wichtig (Nutzer 10.10.):** Die Funktionen **0.5 bis 0.9 müssen noch einzeln besprochen werden**. Die Angaben dazu sind Entwürfe und Ausgangspunkte.

**Grundsatz (Nutzer):** Mit 0.4 sind **alle Probleme erledigt**. Live-Überwachung, Indizieren, nicht angezeigte Dinge, Glitches: Das muss **in 0.2** gelöst sein. 0.3 und 0.4 sind keine Fehlerversionen, sondern Umbau und Politur.

**Regel (Nutzer 10.10.):** Was nach dem Einfrieren von 0.2 neu auffällt und kein Fehler ist, kommt ins Backlog der nächsten Version, nicht in 0.2. Sonst wird 0.2 nie fertig.

---

## 0.1 Beta (jetzt)

Stand: Erkennung, Indizierung, Live-Überwachung, Suche, Favoriten, Einstellungen, Fehlerbericht und Menüleiste laufen auf echten Daten (siehe DONE.md). Offen sind bekannte Fehler und Nacharbeiten (siehe TODO.md).

Abgenommen bis 195 (10.10.). Die Liste der bekannten Fehler für 0.2 steht in TODO.md, Abschnitt A. 196 (Messwerkzeug) liegt im Backlog unter 0.3.

**Versionsnummer (Nutzer 10.10.):** Im Xcode-Projekt steht heute `MARKETING_VERSION 1.0`. Auf **0.1** zurückstellen, Build-Nummer automatisch erhöhen (TODO.md, Backlog V1). Wo die Version angezeigt wird, meldet Cursor als Frage.

---

## 0.2 — Alle bekannten Fehler beheben

**Ziel:** Es gibt keine offenen Fehler mehr, die der Nutzer kennt.

Bereiche (Nutzer): Live-Überwachung, Indizieren, nicht angezeigte Dinge, Glitches.

**Fertig, wenn [Vorschlag]:**
1. Die Liste der bekannten Fehler ist eingefroren und leer (nichts mehr offen in TODO.md, Abschnitt A, was ein Fehler ist).
2. Die Regression-Tests sind grün (seriell und parallel).
3. Der Nutzer hat die App **mehrere Tage im Alltag** mit seinen echten Platten benutzt, ohne einen Fehler zu bemerken (Vorschlag: 7 Tage).
4. Der Test am Stick (große Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick) ist bestanden.

**Nicht in 0.2:** Neue Funktionen, Layout-Wünsche ohne Fehlerbezug, Umbauten der Datenbank.

---

## 0.3 — Neue Datenbankstruktur

**Ziel:** Das Fundament für die kommenden Funktionen (Metadaten, Thumbnails, Prüfsummen), skalierbar gedacht. **Prüfmaßstab (Nutzer 10.10.):** Jede spätere Funktion lässt sich **nur durch Hinzufügen** (neue Tabelle `item_<funktion>` oder neue Spalte) einbauen, ohne bestehende Tabellen umzubauen; die Baumtabelle enthält nur Baum und Grunddaten und bleibt bei sehr großen Datenmengen schnell. Siehe [datenbank-konzeption.md](datenbank-konzeption.md).

**Warum hier:** Danach gibt es Beta-Tester (0.4). Ab dann braucht jede Schemaänderung eine echte Migration. **0.3 ist die letzte Version, in der die Datenbank frei verworfen und neu gebaut werden darf.**

Schritte (aus der Konzeption, in dieser Reihenfolge):
1. Messwerkzeug (Aufgabe 196) und Messung "vorher".
2. Architektur festlegen: eine Datei oder eine Datei je Medium plus Register.
3. Konvention für Seitentabellen festschreiben (`item_<funktion>`, `itemID`, `ON DELETE CASCADE`, `srcSize`, `srcModifiedAt`, `extractorVersion`). Thumbnails in eigener Datei.
4. Zuschnitt von `item` und `medium` bestimmen.
5. Schema neu schreiben, Abfragen umstellen, in kleinen Aufgaben mit Zwischenabnahme.
6. Messung "nachher", gegen die Schwelle prüfen.
7. Altlasten entfernen.

**Fertig, wenn [Vorschlag]:**
- Messung vorher und nachher liegt vor, die Schwelle ist erreicht (Vorschlag: Spaltenansicht nicht langsamer, Datenbank mindestens 20 % kleiner oder Abfrage mindestens 25 % schneller).
- Alle Funktionen aus 0.2 funktionieren unverändert auf dem neuen Schema.
- Test mit 300 Medien und 9 Mio. Objekten bestanden.
- Der Stichtag ist in der README notiert.

---

## 0.3.1 — API-Warteschlange (Nutzer 11.10.)

Tabelle `api_queue`; Aufträge: Fehlerberichte (ersetzt den heutigen `outbox`-Ordner), später Update-, Versions- und Lizenz-Check. Online → sofort leeren (auch auf macOS-Meldung „Netz wieder da“); offline → Ping alle 60 s. Versions-Check, Beta-Sperre und Update-Modal kommen in **0.4**. Details: `datenbank-konzeption.md`.

---

## 0.4 — Letzte Fixes, Beta für Beta-Tester

**Ziel:** Die erste Version, die andere Menschen bekommen. **Alle Probleme sind erledigt.**

**Voraussetzungen für die Weitergabe [Vorschlag]** (ohne diese kann kein Tester die App starten oder erreicht später keine neue Version):
- **Signatur und Notarisierung:** Developer ID Application, `notarytool`, Stapeln. Heute signiert Release mit "Apple Development".
- **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (`/download`).
- **Versions-Check mit Update-Modal und Beta-Sperre** (Nutzer 11.10.; Regeln in `datenbank-konzeption.md`: Vergleich `n.n`, Beta bei API ≥ 1.0 → 7 Tage, frisch installiert sofort, keine Entsperrung, 1 Monat ohne API → gesperrt, gesperrt = 100 % nur ansehen). Bisheriger Plan dazu: (sonst erreicht man die Tester später nicht): `version.json` auf der Domain mit Kanal beta/stable, Hintergrundabfrage, Dialog "Neue Version verfügbar" einmal je Version, Link nur auf die eigene Domain, Schalter in den Einstellungen. Datenschutztext. README 8 und 9 ("Kein Netzwerkcode außer dem Bericht") anpassen.
- **Beta-Verfallsdatum** (60 bis 90 Tage nach dem Build) mit freundlicher Meldung.
- **Zentrale Stelle "Darf der Nutzer das?"** (`FeatureAccess`), in der Beta immer "ja". Vorbereitung für 0.9.
- **Mindest-macOS 14:** Laufzeittest auf macOS 14 (z. B. VM).
- **Fehlerbericht** mit echten Protokollzeilen getestet (Datenschutz).
- **Update-Prozess durch Ersetzen der App:** Bundle-ID und Datenordner gleich lassen, Einzelinstanz-Übergabe bei neuerer Version, Launch Agent beim Start neu registrieren.
- **Ab jetzt nur noch erweitern (Nutzer 10.10.):** Auf anderen Rechnern wird nie etwas gelöscht. Spätere Versionen fügen nur Tabellen oder Spalten hinzu (einmalig beim Start), mit Sicherungskopie davor und Schutz vor Rückschritt (GRDB `hasBeenSuperseded`). Auf dem Mac des Nutzers darf bis 1.0 alles gelöscht werden.

**Fertig, wenn [Vorschlag]:**
- Keine bekannten Fehler offen.
- Eine Testperson außer dem Nutzer hat die App aus dem Download installiert und eine Woche benutzt, ohne Eingriff.

---

## 0.5 — Metadaten und EXIF (Code und Design)

Erste Funktion auf der neuen Struktur (`item_meta`). Felder laut [datenbank-konzeption.md](datenbank-konzeption.md):

| Typ | Felder |
|---|---|
| Video | Auflösung, Dauer, FPS, Codec, Farbraum mit SDR/HDR |
| Foto/RAW | Auflösung, Megapixel, Farbraum |
| Audio | Dauer, Samplerate, Qualität, Kanäle |
| PDF | Seiten, Seitenformat, Text (durchsuchbar oder Scan), Schutz |

Alles andere, was ausgelesen wird, bleibt komplett im gespeicherten Blob. Fehlende Werte als "–".

**Design:** Das Layout für Detailspalte und Liste kommt vom Nutzer, bevor Cursor baut.
**Last:** Tiefenanalyse als eigener Schritt nach dem normalen Index, getrennt pausierbar, niedrige Priorität, je Medium abschaltbar. Eine Datei wird nur einmal gelesen.
**Offen:** Aufnahmedatum bei Fotos als Filter? HLG als eigener Wert? Office-Dokumente?

---

## 0.6 — Vorschaubilder

**[offen, zu besprechen]** Thumbnails mit **250 px langer Seite** (Nutzer 10.10.; 400 px gelten als problematisch). Überschlag: etwa 8 bis 12 KB je Bild, 5.000 Fotos ca. 40 bis 60 MB, 100.000 Fotos ca. 1 GB (nicht gemessen). Zu klären: Schärfe auf Retina-Anzeige in der Detailspalte, Obergrenze, Abschalter. In eigener Datei `thumbs.sqlite`. Beim Auslesen aus derselben Dateilesung wie die Metadaten (0.5). RAW über das eingebettete JPEG. QuickLook nur live, solange das Laufwerk angeschlossen ist.

---

## 0.7 — Export von CSV-Listen

Noch nicht ausgearbeitet. **Offene Fragen [Vorschlag]:** Was wird exportiert (ein Medium, die Treffer einer Suche, die Favoriten)? Welche Spalten? Trennzeichen und Kodierung für deutsches Excel (Semikolon, UTF-8 mit BOM)? Auch Metadaten aus 0.5?

---

## 0.8 — Duplikate erkennen

Sichere Erkennung über mehrere Medien hinweg per vollständiger Prüfsumme (BLAKE3 oder SHA-256). Zuerst nach Größe gruppieren, nur Kandidaten hashen. Opt-in je Medium. Die Prüfsumme gibt es nur, solange das Laufwerk angeschlossen war. Gemeinsame Dateilesung mit 0.5 und 0.6.

---

## 0.9 — Lizenz

**Lizenzmodell (Nutzer, README):** Stufen nach Medienzahl — **max. 1 / max. 50 / max. 250 Medien**. Technisch trägt die Datenbank 250 Medien (Messung in 0.3 mit 300 als Reserve). In der Beta (0.1 bis 0.8) gibt es keine Grenze.

- Signierter Schlüssel (Ed25519), lokal prüfbar, kein Server nötig zum Prüfen. Online-Rückfrage nur optional mit Schonfrist; die App sperrt nie ohne Netz.
- Der Index bleibt ohne Lizenz immer nutzbar und durchsuchbar. Die Grenze betrifft, wie viele Medien **aktualisiert** werden.
- Schlüsselaufbau: 16 Byte Nutzdaten (Version, Schlüssel-ID, Edition/Stufe, Hauptversion, Ausstellungs- und Ablaufdatum, Lizenz-ID) plus 64 Byte Signatur, Base32 in Gruppen, zusätzlich Lizenzdatei zum Herunterladen.
- `FeatureAccess` (ab 0.4 vorbereitet) liefert „Medienlimit“ statt „Funktion gesperrt“.
- Testzeitraum. Beta-Tester bekommen eine Anerkennung (Schlüssel oder Rabatt) **[Vorschlag]**.

**Offene Fragen (vor 0.9 zu klären):** Was zählt als Medium (alle erkannten, nur „Indizieren: Ja“, auch offline)? Gibt „Vergessen“ einen Platz frei? Was passiert beim Erreichen der Grenze (Erkennungs-Dialog sagt es, Medium bleibt sichtbar, wird aber nicht indiziert)? Was passiert bei Herabstufung mit mehr Medien als erlaubt? Prüfung online über diskarchive.app oder offline per Schlüssel?

---

## 1.0 — Erste fertige Version

Alle Funktionen von 0.5 bis 0.9 sind drin, der Nutzer hat 1.0 selbst mehrere Wochen benutzt.

---

## Offene Entscheidungen

- Wie lange darf 0.2 dauern? [Vorschlag] Ein festes Stopp-Datum setzen, ab dem nur noch Fehler behoben werden.
- Lizenzgrenze nach Medienzahl (1 / 50 / 250): offene Fragen siehe 0.9.
- Architektur der Datenbank (0.3).
- Reihenfolge: Die Lizenz kommt als 0.9 nach den Funktionen. `FeatureAccess` ist ab 0.4 vorbereitet.

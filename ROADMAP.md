# ROADMAP.md — Disk Archive

Stand 16.10.2026. Der Weg von **0.1 Beta** bis **1.0**; **gebaut ist der Stand 0.3.2 (Code) mit Teilen von 0.4; bis zur Beta kommen die Sprünge 0.3.8 und 0.3.9**. Die Versionsnummern und ihre Reihenfolge stammen vom Nutzer. Mit **[Vorschlag]** markierte Zeilen sind Ergänzungen von Claude und noch nicht bestätigt.

**Maßgeblich ist der Abschnitt „Roadmap“ in [README.md](README.md).** Diese Datei ist die ausführliche Fassung mit Abnahmekriterien. Bei Widerspruch gilt die README.

Gilt zusammen mit [README.md](README.md) (Konzept, Abschnitt „Datenbank“), [TODO.md](TODO.md) (offene Aufgaben und Fehler, Kennungen `todo.<Version>.<Nr>` und `bug.<Version>.<Nr>`) und [DONE.md](DONE.md).

## Überblick

| Version | Inhalt | Bemerkung |
|---|---|---|
| **0.1 Beta** | ✓ | Kern läuft auf echten Daten |
| **0.2** | ✓ eingefroren 11.10. | alle damals bekannten Fehler behoben (die Fehler des Audits 13.10. laufen als `bug.0.4.*`; Projekt-Version steht seit 16.10. auf 0.3.2, `todo.0.3.2.002`) |
| **0.3** | ✓ neue Datenbankstruktur | abgenommen 12.10., Messung bestanden, Schema eingefroren |
| **0.3.1** | ✓ API-Warteschlange | ein Weg ins Netz (abgenommen 12.10.) |
| **0.3.2** | Erkennung und Dashboard | Code ✓ (12.10.); offen: Layout 02 + 04 nachziehen (`todo.0.3.2.001`), Version anheben (`todo.0.3.2.002`) |
| **0.3.8** | Stabilität, Teil 1 | Paket 4 (Medien-I/O, Nacharbeit, Testisolation) und Paket 5 (Entscheidung, Status, Regeln, Identität): `bug.0.3.8.001`–`002`, `bug.0.4.045`, `021`–`033` |
| **0.3.9** | Stabilität, Teil 2 | Paket 6 (Oberfläche `034`–`040`), Paket 7 (`041`–`042`), Paket 8 (`050`–`062`), Stabilitätsprüfung |
| **0.4** | **Beta für Beta-Tester** | erste Weitergabe nach außen; nur noch Voraussetzungen der Weitergabe (Signatur, Notarisierung, Download-Seite, Beta-Verfallsdatum, macOS 14, Update durch Ersetzen); Versions-Check, Update-Modal, Beta-Sperre und Nur-Lesen-Sperre bereits gebaut ✓ (`todo.0.4.001`, `bug.0.4.001`) |
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

## 0.1 Beta

Erledigt. Erkennung, Indizierung, Live-Überwachung, Suche, Favoriten, Einstellungen, Fehlerbericht und Menüleiste laufen auf echten Daten (siehe DONE.md).

---

## 0.2 — Alle bekannten Fehler beheben

**Ziel:** Es gibt keine offenen Fehler mehr, die der Nutzer kennt.

Bereiche (Nutzer): Live-Überwachung, Indizieren, nicht angezeigte Dinge, Glitches.

**Stand:** eingefroren am 11.10. (Nutzer). Fehler, die danach auffielen, stehen als `bug.*` in TODO.md.

**Nicht in 0.2:** Neue Funktionen, Layout-Wünsche ohne Fehlerbezug, Umbauten der Datenbank.

---

## 0.3 — Neue Datenbankstruktur

**Ziel:** Das Fundament für die kommenden Funktionen (Metadaten, Thumbnails, Prüfsummen), skalierbar gedacht. **Prüfmaßstab (Nutzer 10.10.):** Jede spätere Funktion lässt sich **nur durch Hinzufügen** (neue Tabelle `item_<funktion>` oder neue Spalte) einbauen, ohne bestehende Tabellen umzubauen; die Baumtabelle enthält nur Baum und Grunddaten und bleibt bei sehr großen Datenmengen schnell. Siehe README, Abschnitt „Datenbank“.

**Warum hier:** Danach gibt es Beta-Tester (0.4). Ab dann braucht jede Schemaänderung eine echte Migration. **0.3 ist die letzte Version, in der die Datenbank frei verworfen und neu gebaut werden darf.**

**Stand: ✓ abgenommen.** Schema `0.3.0-schema` (eine Datei, 11 Tabellen), Status-Flag mit Warteschlange, Umbenennen/Verschieben erkennen, Wartung und WAL, Einstellungen in der Datenbank, Messung nachher (Größe −54…−63 %, häufige Suche −91…−98 %, Spalten innerhalb ±10 %). Der Stichtag steht in der README. Berichte: `archiv/messung/`.

---

## 0.3.1 — API-Warteschlange (Nutzer 11.10.)

Tabelle `api_queue`; Aufträge: Fehlerberichte (ersetzt den heutigen `outbox`-Ordner), später Update-, Versions- und Lizenz-Check. Online → sofort leeren (auch auf macOS-Meldung „Netz wieder da“); offline → Ping alle 60 s. **Stand: ✓ abgenommen 12.10.** Versions-Check, Beta-Sperre und Update-Modal wurden danach vorgezogen und sind ebenfalls gebaut (siehe 0.4). Details: README, Abschnitt „Datenbank“.

---

## 0.3.2 — Erkennung und Dashboard (Alltag)

**Ziel:** Mehrere neu angeschlossene Medien dürfen sich nicht gegenseitig den Erkennungs-Dialog wegnehmen; ohne explizite Ja/Nein-Entscheidung startet **keine** Indizierung. Dashboard-Kacheln zeigen Belegung und Scan-Zeit konsistent unten in der Kachel.

**Layout zuerst (README, Layout-Reminder):** Vor Aufgaben im TODO die Mockups in `layout/Disk Index App.dc.html` anpassen — **Screen 02** (Warteschlange: n Dialoge nacheinander bzw. gestapelt, je Dialog genau ein Medium; Schließen ohne Entscheidung entfernt das Medium nicht aus der Warteschlange) und **Screen 04** (`card-meta`: Belegung links, „Zuletzt indiziert“ rechts in **einer** unteren Zeile; kein Verschwinden der Uhr beim Umschalten Prozent ↔ absolute Größe). Optional **03**, wenn Popover bei „Entscheidung ausstehend“ einen Weg zum Dialog braucht (kein „Neu indizieren“ ohne Entscheidung).

**Inhalt (Produkt):**

1. **Erkennungs-Dialog:** FIFO-Warteschlange aller Medien mit `decision == undecided` (verbunden). Jeder Dialog gilt nur für die Medium-ID, mit der er geöffnet wurde. Nach Ja/Nein: nächstes Medium. Menüleisten-Badge „Neu erkannt“, solange die Warteschlange nicht leer ist (nicht nur solange ein Panel offen ist).
2. **Kein Index ohne Entscheidung:** Indizierung und „Neu indizieren“ nur, wenn `decision == index` (explizit). Popover und Einstellungen dürfen `undecided` nicht umgehen.
3. **Dashboard (04):** In `MediumDashboardCard` die Meta-Zeile wie Layout: Belegter Speicher (klickbar) und Zeitpunkt des **letzten Scans** (`lastIndexedAt` / gleiche Formulierung wie Popover), offline weiter „Zuletzt gesehen“ wie im Mockup.

**Stand:** Code ✓ (`todo.0.3.2.003`, abgenommen 12.10.); Layout 02 und 04 fehlen (`todo.0.3.2.001`, Nutzer).

**Fertig, wenn [Vorschlag]:**

- Zwei Medien nacheinander anschließen, erste ohne Entscheidung: beide erscheinen nacheinander im Dialog; erste erhält nach Beantwortung der zweiten weiterhin einen Dialog.
- Kein Lauf und kein Reindex-Klick für `undecided`.
- Dashboard-Kacheln: Meta-Zeile unten, Layout 04 entspricht dem aktualisierten Mockup; Toggle Belegung ändert die Zeilenstruktur nicht.
- Layout 02 und 04 aktualisiert; Regression/Rauchtest für Erkennung und Dashboard grün.

---

## 0.3.8 — Stabilität, Teil 1 (Nutzer 16.10.)

**Ziel:** Kein Einfrieren („Spinning Ball“) mehr durch Medien-I/O oder Datenbank auf dem Haupt-Thread; Entscheidung, Status, Regeln und Identität eines Mediums sind verlässlich.

**Inhalt (Reihenfolge verbindlich):** (1) Nacharbeit Paket 4 Teil A (`bug.0.3.8.001`: Warnungen im Testziel, Datei-I/O vom Store-Actor und von main), (2) Testisolation (`bug.0.3.8.002`: keine prozessweiten Test-Variablen, Parallellauf stabil), (3) Rest Paket 4 (`bug.0.4.024`, `025`; `045`, `021`–`023` zur Abnahme), (4) Paket 5 (`bug.0.4.026`–`033`).

## 0.3.9 — Stabilität, Teil 2 (Nutzer 16.10.)

**Inhalt:** Paket 6 Oberfläche (`bug.0.4.034`–`040`), Paket 7 Absturzschreiber und Start (`041`–`042`), Paket 8 Fehler niedriger Schwere (`050`–`062`), danach Stabilitätsprüfung.

**Fertig je Sprung (0.3.8 und 0.3.9), alle Kriterien:** (1) alle Kennungen von Claude abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün; (4) Parallellauf dreimal hintereinander grün; (5) keine neuen `Disk Archive*.ips`; (6) Claude baut die App des Nutzers (Regel 23) als letzten Schritt; (7) **entfällt je Sprung (Nutzer 17.10.):** der Test am echten Stick kommt gesammelt als letzter Schritt von 0.4 (`todo.0.4.040`: Großplatten-Lauf, Stick, Layout; danach an die Nutzer); (8) keine offene „Frage:“ in TODO.md. **Eingefroren:** neue Funde kommen nur in einen Sprung, wenn sie ein Kriterium verletzen, sonst ins Backlog 0.4 oder später.

---

## 0.4 — Beta für Beta-Tester

**Ziel:** Die erste Version, die andere Menschen bekommen. **Alle Probleme sind erledigt** (Sprünge 0.3.8 und 0.3.9). 0.4 enthält nur noch die Voraussetzungen der Weitergabe.

**Voraussetzungen für die Weitergabe [Vorschlag]** (ohne diese kann kein Tester die App starten oder erreicht später keine neue Version):
- ○ **Signatur und Notarisierung:** Developer ID Application, `notarytool`, Stapeln. Heute signiert Release mit "Apple Development".
- ○ **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (`/download`).
- ✓ **Versions-Check mit Update-Modal und Beta-Sperre** (gebaut und abgenommen 13.10., `todo.0.4.001`, Härtung `bug.0.4.001`; Regeln in der README, Abschnitt „Datenbank“, Netz: Vergleich `n.n`, Beta bei API ≥ 1.0 → 7 Tage, frisch installiert sofort, keine Entsperrung, 1 Monat ohne API → gesperrt, gesperrt = 100 % nur ansehen). Bisheriger Plan dazu: (sonst erreicht man die Tester später nicht): `version.json` auf der Domain mit Kanal beta/stable, Hintergrundabfrage, Dialog "Neue Version verfügbar" einmal je Version, Link nur auf die eigene Domain, Schalter in den Einstellungen. Datenschutztext. README 8 und 9 ("Kein Netzwerkcode außer dem Bericht") anpassen.
- ✓ **Beta-Verfallsdatum** (60 bis 90 Tage nach dem Build) mit freundlicher Meldung.
- ✓ **Zentrale Stelle "Darf der Nutzer das?"** (`FeatureAccess`), in der Beta immer "ja". Vorbereitung für 0.9.
- ○ **Mindest-macOS 14:** Laufzeittest auf macOS 14 (z. B. VM).
- ○ **Fehlerbericht** mit echten Protokollzeilen getestet (Datenschutz); Pflicht davor: `bug.0.4.011` und `bug.0.4.012`.
- ○ **Update-Prozess durch Ersetzen der App:** Bundle-ID und Datenordner gleich lassen, Einzelinstanz-Übergabe bei neuerer Version, Launch Agent beim Start neu registrieren.
- **Ab jetzt nur noch erweitern (Nutzer 10.10.):** Auf anderen Rechnern wird nie etwas gelöscht. Spätere Versionen fügen nur Tabellen oder Spalten hinzu (einmalig beim Start), mit Sicherungskopie davor und Schutz vor Rückschritt (GRDB `hasBeenSuperseded`, ○ `bug.0.4.013`, muss vor der ersten Schema-Erweiterung stehen). Auf dem Mac des Nutzers darf bis 1.0 alles gelöscht werden.

**Fertig, wenn [Vorschlag]:**
- Keine bekannten Fehler offen (0.3.8 und 0.3.9 abgenommen; Audit 13.10.: `bug.0.4.010`–`062`).
- Eine Testperson außer dem Nutzer hat die App aus dem Download installiert und eine Woche benutzt, ohne Eingriff.

---

## 0.5 — Metadaten und EXIF (Code und Design)

Erste Funktion auf der neuen Struktur (`item_meta`). Felder laut README, Abschnitt „Datenbank“ und unten:

| Typ | Felder |
|---|---|
| Video | Auflösung, Dauer, FPS, Codec, Farbraum mit SDR/HDR |
| Foto/RAW | Auflösung, Megapixel, Farbraum |
| Audio | Dauer, Samplerate, Qualität, Kanäle |
| PDF | Seiten, Seitenformat, Text (durchsuchbar oder Scan), Schutz |

Alles andere, was ausgelesen wird, bleibt komplett im gespeicherten Blob. Fehlende Werte als "–".

**Design:** Das Layout für Detailspalte und Liste kommt vom Nutzer, bevor der Umsetzer baut.
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

# Datenbank-Konzeption (Entwurf)

Stand 09.10.2026. Sammlung der Überlegungen des Nutzers zum Umbau der Datenbank. Noch keine Entscheidung, noch nicht in README oder TODO übernommen.

## Grundsatz ab 0.3 (Nutzer 11.10., verbindlich)

**Nach 0.3 wird keine bestehende Tabelle mehr verändert, nur noch erweitert.** Neue Funktionen kommen über **neue Schlüssel** in den Schlüssel/Wert-Tabellen (`settings`, `storage_meta`, `item_meta`) oder, wenn nötig, über **neue Tabellen**. Beispiel: Scan-Tiefe je Medium = Schlüssel `scanDepth` in `storage_meta`, keine neue Spalte in `storages`. Deshalb wird in 0.3 so viel wie möglich festgelegt.

**Folgerungen (Claude 11.10., beschlossen Nutzer 11.10.):**
- **Einstellungen je Medium** (Scan-Tiefe, eigene Ausschlüsse, Analyse an/aus für Metadaten/Vorschau/Prüfsumme, Überwachung an/aus …) immer über `storage_meta`; die App liest „Medium-Wert, sonst globaler Wert aus `settings`“. Eine Stelle im Code, die das auflöst.
- **`item_meta` braucht eine Herkunft** (`source`: erkannt / Nutzer / System). Grund: Regel 4 löscht bei geänderter Datei die *erkannten* Metadaten. Würde der Nutzer später Notizen, Bewertungen oder Farben an Dateien hängen, dürften die dabei **nicht** verloren gehen. Ohne diese Spalte wäre das später nur mit Umbau lösbar.
- **`items.status` als Zahl mit Reserve:** 0 = sichtbar, 1 = zu-löschen; weitere Werte bleiben frei für später (z. B. „nur offline bekannt“), ohne Umbau.
- **`kind` als Zahl:** die Zuordnung Endung → Kategorie steht im Code; ändert sie sich, werden nur Werte neu geschrieben, die Tabelle bleibt.
- **Neue Tabellen sind erlaubt** (z. B. später Tags, Verlauf): sie verweisen auf `items.id` bzw. `storages.id` und werden mitgelöscht.

## Probe der neuen Struktur (Claude 11.10., echte Daten des Nutzers, 1,6 Mio. Einträge)

Nachbau der Skizze per `sqlite3` aus der echten Datenbank (nur gelesen), ohne Suchindex, ohne Pfad, Daten als Zahl, `slug`, `kind`, `extID`, `item_details` getrennt. Natürliche Sortierung noch nicht nachgebaut (Sortierung nach `slug`).

| | alt | neu |
|---|---|---|
| **Dateigröße** | 1.488 MB | **597 MB** (−60 %) |
| davon Tabelle Baum | 359 MB | 212 MB (+ 23 MB `item_details`) |
| Suchhilfen | ~534 MB + 484 MB Suchindex | 335 MB (Spalten 103, Eindeutigkeit 101, Suche 93, Datum 21, Lauf 17) |

| Abfrage (warm, ms) | alt | neu |
|---|---|---|
| seltenes Wort, Liste | 25–28 (Suchindex) | 117–122 (LIKE über die schmale Suchhilfe) |
| häufiges Wort („nachrichten“), Liste 500 | 198–244 | **21–25** |
| häufiges Wort, Zahl (276.721) | – | 139–146 |
| seltenes Wort + PDF, Zahl | 22–23 | 152–236 |
| Filter Dateityp html, Zahl (1,6 Mio.) | **6.389–6.720** | **126–133** |
| größter Ordner (17.856 Kinder), erste Seite 2.000 | 25–27 | 22–24 |
| größter Ordner, Zahl | 25–68 | 23–36 |

Abfragepläne: Suche läuft als Durchlauf der **schmalen Suchhilfe** (`items_search`, nicht der ganzen Tabelle), Spalten über `items_children` ohne Tabellenzugriff.

**Hochrechnung 9 Mio. Einträge (linear):** Suche nach seltenem Wort ~0,6–0,7 s warm (Ziel war < 0,3 s); häufige Wörter und Filter bleiben schnell; Spaltenansicht unabhängig von der Gesamtzahl. **Gegenmittel für das seltene Wort:** Durchlauf **parallel** in mehreren Lese-Verbindungen über Kennungs-Bereiche (WAL erlaubt gleichzeitiges Lesen; 4–6 Kerne → ~0,15 s), dazu Popover mit Wartezeit nach dem Tippen. Messung 196 (S2) und die zweite Messung nach dem Umbau bestätigen das.

## Messung 196 „vorher“ (11.10., Agent; `Werkzeuge/messung/2026-10-11-vorher.md`)

| | S1 (1 Mio.) | S2 (8,6 Mio., 300 Medien) |
|---|---|---|
| Datenbankdatei | 0,75 GB | 5,65 GB |
| Spalte `path` | 0,09 GB | 0,90 GB |
| `quick_check` | 0,5 s | 13 s |
| Suche „bil“ (Suchindex) | 69 ms | 591 ms |
| `LIKE` auf ganzer Tabelle | 125 ms | 1.116 ms |
| `LIKE` auf schmaler Namenstabelle | 79 ms | **681 ms** |
| Spalte mit 50.000 Kindern, alle Seiten | 173 ms | 175 ms |

**Folgerungen für 0.3:**
- Hochrechnung aus der Probe bestätigt: `LIKE` über die schmale Suchhilfe bei ~9 Mio. ≈ 0,7 s → **parallele Suche in Bereichen ist Pflicht** (Ziel < 0,3 s), plus Wartezeit nach dem Tippen im Popover.
- **Zwei Medien gleichzeitig schreiben** bringt kaum mehr Durchsatz (jedes halb so schnell) → ein Schreiber für alle ist richtig; spricht nicht gegen „eine Datei“.
- **WAL begrenzen:** nach jedem Lauf `wal_checkpoint(TRUNCATE)`, `journal_size_limit` setzen (S2: erstes Öffnen 116 s wegen großem WAL).
- **Bereinigen nach Scan-Tiefe** heute unbrauchbar langsam (F25) → mit Status-Flag und `depth` per SQL in Blöcken.
- `quick_check` bei 5,65 GB 13 s → im Hintergrund richtig (219); neue Struktur ~60 % kleiner.

## Schema-Skizze (Entwurf Claude 11.10., zur Freigabe; vor der Auswertung von 196)

**Alle Tabellen werden in 0.3 sofort angelegt** (Nutzer 11.10.), auch die, die erst später gefüllt werden (`item_meta`, `item_checksum`, `api_queue`). Alle Zeitangaben als ganze Sekunden seit 1970 (`INTEGER`), Ja/Nein als 0/1, Aufzählungen als kleine Zahl. Kennungen mit `AUTOINCREMENT` (nie wiederverwendet). Verweise mit `ON DELETE CASCADE`.

**`storages`** – ein Medium
| Feld | Typ | Inhalt |
|---|---|---|
| id | INTEGER PK | Kennung (nie wiederverwendet) |
| uuid | BLOB 16 | feste Kennung der App für das Medium |
| volumeUUID | BLOB 16 | Kennung des Datenträgers (falls vorhanden) |
| fingerprint | INTEGER | Ersatz-Erkennung ohne volumeUUID (Dateisystem, Erstelldatum, Größe) |
| name / slug | TEXT | Anzeigename / Suchname |
| type | INT | USB, HDD, SSD, Netz … |
| fsType | INT | APFS, HFS+, exFAT, FAT … |
| totalBytes / usedBytes | INTEGER | Kapazität |
| decision | INT | indizieren ja / nein / offen |
| rememberDecision | INT | Dialog nicht mehr zeigen |
| indexStatus | INT | ausstehend, läuft, fertig, Fehler … |
| paused | INT | automatisches Indizieren für dieses Medium pausiert |
| isFavorite | INT | Medium als Favorit |
| fileCount / folderCount | INTEGER | Zähler |
| firstSeenAt / lastSeenAt / firstIndexedAt / lastIndexedAt | INTEGER | Zeitpunkte |

**`storage_meta`** – alles Weitere zum Medium: `storageID`, `keyID` (→ `meta_keys`), `value` TEXT, `date` INTEGER. Beispiele: Stand der Überwachung, abgeschlossene Tiefe, Gesamtzahl fürs Zählen, Inhaltsstempel der Wurzel, Scan-Lauf-Zähler, Anzeige absolut/Prozent, später Scan-Tiefe je Medium.

**`items`** – Baum, Suche, Filter, Indizieren
| Feld | Typ | Inhalt |
|---|---|---|
| id | INTEGER PK | Kennung (nie wiederverwendet; Name der Vorschau-Datei) |
| storageID | INT | Medium |
| parentID | INT | Elternordner (leer = Wurzel) |
| name | TEXT | echter Name |
| slug | TEXT | Suchname: klein, Umlaute → Stammlaut |
| extID | INT | Endung (→ `extensions`) |
| kind | INT | Typ-Kategorie (Bild, Video, Audio, PDF …) |
| isFolder | INT | Ordner ja/nein |
| depth | INT | Ebene (Scan-Tiefe, Bereinigen) |
| status | INT | 0 sichtbar, 1 zu-löschen, Rest frei |
| modifiedAt | INTEGER | Änderungsdatum (Alter-Filter, Datum in der Suche) |
| lastSeenRun | INTEGER | Nummer des Scan-Laufs, in dem der Eintrag zuletzt gesehen wurde |
| fileID | INTEGER | Datei-Kennung des Systems (nur APFS/HFS+ verlässlich) |
| contentStamp | INTEGER | nur Ordner: Fingerabdruck des Inhalts |
| listedAt | INTEGER | nur Ordner: zuletzt vollständig gelesen |
| unreadable | INT | nur Ordner: zuletzt nicht lesbar |

**`item_details`** – nur Detailansicht, eine Zeile je Eintrag: `itemID` PK, `sizeBytes` INTEGER, `createdAt` INTEGER, `isPackage` INT. (Suchhilfe auf `sizeBytes` kommt mit 0.8.)

**`item_meta`** (angelegt in 0.3, gefüllt ab 0.5): `itemID`, `keyID` (→ `meta_keys`), `value` TEXT, `source` INT (gelesen / Nutzer / System), `info` TEXT.

**`item_checksum`** (angelegt in 0.3, gefüllt für Favoriten ab 0.3, sonst ab 0.8): `itemID` PK, `partial` BLOB, `full` BLOB, `info` TEXT (Stand: Größe + Datum). Suchhilfe auf `full`.

**`favorites`**: `itemID` PK, `createdAt` INTEGER.

**`extensions`**: `id`, `ext` TEXT (eindeutig). **`meta_keys`**: `id`, `key` TEXT (eindeutig).

**`settings`**: `key` TEXT PK, `value` TEXT, `date` INTEGER (Einstellungen und Systemzustand).

**`api_queue`** (angelegt in 0.3, genutzt ab 0.3.1): `id`, `kind` INT, `payload` TEXT, `createdAt`, `attempts`, `lastTryAt`, `info` TEXT.

**Keine Tabelle:** Vorschaubilder (Dateien `Thumbnails/<storageID>/<itemID>`), Protokoll (Datei). **Entfällt:** Suchindex `item_fts`, Pfad-Spalte, `item_folders`, `logs`.

**Suchhilfen (Vorschlag, Messung entscheidet):**
- Eindeutigkeit: `items(storageID, parentID, name)`.
- Spaltenansicht: `items(storageID, parentID, status, slug COLLATE natürlich)` – Ordner und Dateien **gemischt nach Namen** (Nutzer 11.10.), Zahlen natürlich.
- Suche: `items(slug, status)` als schmale Hilfe für `LIKE '%…%'`; Medien über `storages.slug`.
- Alter-Filter: `items(modifiedAt)`.
- Umbenennen erkennen: `items(storageID, fileID)` nur wo `fileID` vorhanden.
- Abgleich: `items(storageID, lastSeenRun)`.

## Zahlen statt Text (Claude 11.10., **beschlossen** Nutzer 11.10.)

Heute belegt eine Zeile in `item` ~224 Byte (1,6 Mio. Zeilen, 359 MB). Größte Posten sind Text, der als Zahl viel kleiner wäre:

| Feld | heute | Vorschlag | Ersparnis bei 9 Mio. (grob) |
|---|---|---|---|
| Datum (`modifiedAt`, `lastSeenAt`, `listedAt`, `createdAt`) | Text „2026-10-11 13:04:05.123“ (23 Byte) | ganze Sekunden seit 1970 (4–6 Byte) | ~150–300 MB plus kleinere Suchhilfe auf `modifiedAt` |
| `lastSeenAt` | Datum | **Nummer des Scan-Laufs** (1–3 Byte) | weiter kleiner, Vergleich „in diesem Lauf gesehen“ einfacher |
| `fileID` | Text | Zahl (8 Byte) | ~50–100 MB |
| `contentStamp` (Ordner) | Hex-Text 32 Zeichen | Zahl (8 Byte) | klein (nur Ordner) |
| `ext` | Text („jpg“) | Nummer aus Tabelle `extensions` (1–2 Byte) | ~20–30 MB plus kleinere Suchhilfe |
| `kind`, `status`, `isFolder`, `unreadable` | – / Text | Zahl (1 Byte) | beschlossen |
| `item_meta.key` | Text je Zeile | Nummer aus Tabelle `meta_keys` | bei 800.000 Zeilen ~10 MB |
| `item_checksum.partial/full` | – | Binär (16/32 Byte) statt Hex-Text (32/64) | halbiert |
| `storages`: Typ, Entscheidung, Status, UUID | Text | Zahl / 16 Byte binär | unerheblich (≤ 1.000 Zeilen), nur der Einheitlichkeit halber |

Bleiben Text: `name`, `slug`, Werte in `*_meta`, `settings`. Die Zuordnungen (Zahl ↔ Bedeutung) stehen im Code bzw. in kleinen Nachschlagetabellen; neue Werte = neue Zeile, kein Umbau.

## Besprechung Nutzer/Claude 11.10. (Start 0.3)

**Beschlossen:**
1. **Eine gemeinsame Datei** für alle Medien.
2. **Tabellen:** `storages`, `storage_meta`, `items`, `item_details`, `item_meta`, `item_checksum`, `favorites`, `settings`, `api_queue` (0.3.1). Vorschaubilder als Dateien, nicht in der Datenbank. **Keine `logs`-Tabelle** (Nutzer 11.10.); das Protokoll bleibt eine Datei. **`item_meta` und `item_checksum` werden in 0.3 schon angelegt** (leer), damit 0.5/0.8 nur noch füllen.
3. **`items`** enthält, was Suche, Filter, Spalten und Indizieren brauchen: `id`, `storageID`, `parentID`, `name`, **`slug`**, `ext`, `kind` (Typ-Kategorie als **kleine Zahl**, Nutzer 11.10.; MIME bei Bedarf in `item_details`), `isFolder`, `status` (sichtbar / zu-löschen), **`modifiedAt`** (Alter-Filter), `lastSeenAt` (Indizieren). Nur-Ordner-Felder (Inhaltsstempel, gelesen am, nicht lesbar) **auch in `items`** (Nutzer 11.10.: keine `item_folders`; kostet ~27 MB bei 9 Mio. Einträgen).
4. **`item_details`** mit **festen Spalten**, eine Zeile je Eintrag (Größe, Erstelldatum, Datei-Kennung, Paket ja/nein, ggf. MIME). **Kein** Schlüssel/Wert-Schema hier (Nutzer 11.10.: zu aufwendig, auch beim Löschen; 9 Mio. Dateien × 4 Werte wären ~36 Mio. Zeilen).
5. **`item_meta`**: `itemID, key, value, info` (Text), dazu `source` (siehe Grundsatz). **Kein Filtern** nach Metadaten (höchstens später Suche). Kein Datum je Zeile; `info` ist Reserve („headroom“). Betrifft nur Bild, Video, Audio, PDF.
6. **Kein gespeicherter Pfad.** Pfad = Medium + Kette der Elternordner + Name.
7. **Suche** per `LIKE '%…%'` (Teilwort) auf `slug` von **Dateien, Ordnern und Medien**. **`slug`** = Name klein und ohne Umlaute/Akzente, beim Indizieren erzeugt; der Suchbegriff wird genauso umgewandelt → Suche unabhängig von Groß/Klein und Umlauten. **Umlaute und Akzente → Stammlaut** (Nutzer 11.10.: ä→a, ö→o, ü→u, é→e …; Vorschlag Claude: ß→ss).
8. **Alter-Filter = Änderungsdatum der Datei** (Nutzer 11.10., wie heute). Daher `modifiedAt` in `items`, nicht in `item_details`.
9. **Keine Systemgrenze bei der Zahl der Medien.** 250 ist nur die geplante Lizenzgrenze (Pro); die App muss mehr können. Messung mit 300 Medien, zusätzlich Stichprobe mit 1.000 kleinen Medien (Listen, Seitenleiste, Einstellungen).
10. **`settings`** (`key, value, date`) **ist bereits eine Schlüssel/Wert-Tabelle** – kein eigenes `settings_meta` nötig: App-Einstellungen und Systemzustand (z. B. `betaExpiryNoticedAt`, `apiLastSeen`, `systemEnabled`, `lastIntegrityCheck`). Ausnahmen außerhalb der Datenbank: Sprache, Fensterposition. Dazu **`systemEnabled`** (siehe 0.3.1).
11. **Wartung:** nach Zeit (Prüfung auf Schäden alle 7 Tage oder nach Absturz) **und** nach Zähler (Aufräumen/Verkleinern nach N geänderten oder gelöschten Einträgen, wenn die App untätig ist). **N wird gemessen** (196, Vorschlag 10.000 als Startwert).

## Überprüfung gegen die kommenden Funktionen (Claude/Nutzer 11.10.)

Kommend: Metadaten (0.5), Vorschaubilder (0.6), Export (0.7, nur lesen, Ladebalken), Duplikate (0.8, nur auf Knopfdruck, eigener Screen mit Ladeanimation).

1. **Kennung bleibt bei Umbenennen/Verschieben (beschlossen, wichtig).** Heute erkennt der Scanner einen Eintrag nur an Ordner + Name → Umbenennen/Verschieben = neuer Eintrag, Favorit (später Metadaten, Vorschau, Prüfsumme) weg.
   **Versuch Claude 11.10.** (Abbilder 64 MB, Datei-Kennung `stat %i`, mit Aus- und Wiedereinhängen):
   | Dateisystem | Umbenennen | Verschieben | nach Wiedereinhängen |
   |---|---|---|---|
   | APFS | gleich | gleich | gleich |
   | FAT32 | gleich | **neu** | gleich (solange nicht verschoben) |
   | exFAT | gleich | **neu** | **erste Sitzung Fantasiewert** (18446744073709551610), danach andere Zahl |
   → Die Kennung ist nur auf **APFS/HFS+** verlässlich. Auf FAT/exFAT nicht.
   **Lösung (übliches Vorgehen bei Sync- und Katalog-Werkzeugen wie rsync `--fuzzy`, Unison, Syncthing: „sicher verbinden, im Zweifel neu“):**
   - **APFS/HFS+:** über `fileID` verbinden (Suchhilfe `storageID, fileID`).
   - **Live, solange das Medium steckt (alle Dateisysteme):** macOS meldet Umbenennen/Verschieben als Ereignispaar „alt → neu“ → direkt übernehmen (FSEvents mit Datei-Ereignissen; heute liest die Überwachung nur den Elternordner neu).
   - **FAT/exFAT, Änderung außerhalb:** im Abgleich verschwundene und neue Einträge desselben Mediums vergleichen. **Datei:** gleiche Größe + gleiches Änderungsdatum (FAT: 2 s Genauigkeit) + gleiches Erstelldatum + gleiche Endung; liegt schon eine Prüfsumme vor (`item_checksum.partial`), zusätzlich diese. **Ordner:** gleicher Inhaltsstempel. Treffer nach diesen Merkmalen sind **Kandidaten**; entschieden wird wie folgt (Nutzer 11.10.: „lieber verloren“ reicht nicht).
   **Fingerabdruck statt Raten (Vorschlag Claude 11.10., zur Freigabe):**
   - **Teil-Prüfsumme** = Größe + Prüfsumme aus den ersten und letzten 64 KB (~128 KB lesen, auch bei großen Videos schnell; Spalte `item_checksum.partial`).
   - **Für alles, woran Nutzerdaten hängen** (Favoriten, später Notizen/Bewertungen), wird die Teil-Prüfsumme **sofort** berechnet, wenn der Nutzer sie setzt (Medium angeschlossen), sonst beim nächsten Anschließen; bei geänderter Datei neu. Das sind wenige Dateien.
   - **Beim Verbinden:** Gibt es für den verschwundenen Eintrag eine Teil-Prüfsumme, werden die Kandidaten **in dem Moment** gelesen (sie liegen auf dem gerade angeschlossenen Medium) und verglichen → eindeutig. Ohne gespeicherte Prüfsumme (keine Nutzerdaten): eindeutiger Kandidat → verbinden; mehrere → neu (verliert nichts, was dem Nutzer gehört).
   - **Echte Kopien** (gleicher Inhalt, z. B. zweimal dieselbe Datei): Favorit geht an die Kopie mit gleichem Namen, sonst im gleichen Ordner, sonst die erste in Sortierreihenfolge – inhaltlich ist es dieselbe Datei.
   - **Erstscan:** keine Prüfsummen. **Überwachung (live):** Umbenennen kommt als Ereignispaar; fallen Ereignisse aus (viele Änderungen auf einmal), gilt dasselbe Verfahren für die betroffenen Dateien – bei 100–1.000 Dateien sind das höchstens ~128 MB Lesen.
   - **Alle Prüfsummen** sammeln sich später ohnehin im Leerlauf (0.8, Duplikate); dann wird das Verbinden für jede Datei sicher. Bis dahin genügt es für die Dateien, an denen etwas hängt.
   - Bekannte FAT-Grenze: FAT speichert Ortszeit; nach Zeitzonen-/Sommerzeitwechsel können alle Daten um volle Stunden verschoben sein. **Beschlossen (Nutzer 11.10.):** Abweichung von genau ±1 h beim Vergleich als gleich werten.
2. **Vorschaubilder: keine Datenbank** (Nutzer 11.10.). Ein **Ordner je Medium**, Dateiname = `item.id`; erzeugt und geladen nur zusammen mit dem Eintrag. Eintrag gelöscht → Bild gelöscht; Medium vergessen → Ordner gelöscht. Verwaiste Bilder räumt die Wartung auf. Ordner-Komprimierung: später prüfen.
3. **`item_checksum` in 0.3 leer anlegen** (Nutzer 11.10.): `itemID` (Primärschlüssel, Verweis auf `items`, wird mitgelöscht), `partial` (Prüfsumme aus Anfang und Ende), `full` (leer bis berechnet), `info` (für welchen Stand der Datei: Größe + Änderungsdatum), Suchhilfe auf `full`. Berechnung im Leerlauf, eigener Durchgang nach dem Indizieren, nur bei angeschlossenem Medium. Duplikat-Sieb zuerst nach **Größe** (Suchhilfe auf `item_details.sizeBytes`), nicht nach Namen. Rest in 0.8.
4. **Veraltete Zusatzdaten (beschlossen):** Ändern sich Größe oder Änderungsdatum, löscht der Scanner `item_meta`, `item_checksum` und das Vorschaubild der Datei; der nächste Durchgang erzeugt sie neu. Eine Regel für alle Zusatzdaten.
5. **Was schon analysiert ist (beschlossen, Nutzer 11.10.):** über das **Vorhandensein** der Zusatzzeilen (`item_meta`, `item_checksum`), kein eigenes Feld. Damit Dateien **ohne** Metadaten nicht immer wieder gelesen werden, schreibt der Metadaten-Durchgang auch dann eine Markierungszeile (`key = "_analyzed"`). Vorschaubild: vorhanden = Datei existiert. (JSON in `items.status` verworfen: `status` steht in der Suchhilfe und muss klein bleiben.)
6. **Suche über `slug`:** Suchhilfe auf `slug` (mit `status`) dient als „schmale Tabelle“; Messung 196 h prüft das.
7. **Export:** Ordnerpfade einmal in den Speicher laden, dann jede Zeile ohne Nachschlagen (Umsetzung, kein Schema-Thema).
8. **Duplikat-Screen und Export lesen nur** → dürfen auch im Deaktiviert-Modus (0.3.1) laufen.

**API-Anbindung (Nutzer 11.10.). Aufteilung:** 0.3.1 = API-Warteschlange (inkl. Fehlerberichte, Netz-Meldung, Ping). **Versions-Check, Sperre („deaktiviert“), „API zuletzt erreicht“ und Update-Modal kommen zusammen mit dem Update-Modal in 0.4** (Nutzer 11.10.).
- **Versions-Check (Nutzer 11.10., ersetzt die Liste erlaubter Versionen):** `GET https://diskarchive.app/api/version/` liefert `{"version":"n.n"}` (11.10. live: `"1.0"`). Die App heißt `n.n.n` (ab jetzt 0.2.0, 0.3.0, 0.3.1 …); verglichen werden nur **Haupt- und Nebennummer** (`n.n`).
  - App **älter** als API (z. B. App 1.0, API 1.1) → **Modal „Update verfügbar“** (Layout folgt).
  - App ist **Beta** (0.x) und API **≥ 1.0** → Modal „Update“ **plus Hinweis: die App wird in 7 Tagen gesperrt**. Der Zeitpunkt der Entdeckung wird in `settings` gespeichert (`betaExpiryNoticedAt`, zusammen mit der Version); die Prüfung „7 Tage um?“ läuft mit der Wartung und beim Start. Danach **deaktiviert** (nur lesen, kein Indizieren, Modal).
  - Gleich oder neuer → nichts.
  - **Frisch installierte Beta sperrt sofort** (Nutzer 11.10.): Hat die App noch keine Datenbank (Erstinstallation oder Datenbank zurückgesetzt) und meldet die API ≥ 1.0, gibt es **keine 7 Tage**, sondern sofort „deaktiviert“. Damit bringt Zurücksetzen der Datenbank keine neue Frist. Ohne Verbindung beim ersten Start gilt die Regel „1 Monat ohne API“.
  - **API bleibt bis zur Umsetzung von 0.3.1 auf `"1.0"`** (Nutzer 11.10.), damit im Test von 0.3.1 die Sperre einmal ausgelöst werden kann. Vor dem Verteilen einer Beta muss sie auf die aktuelle Beta-Nummer gestellt werden.
  - **Keine Entsperrung (Nutzer 11.10.):** Eine gesperrte Beta bleibt gesperrt, auch wenn die API später wieder etwas anderes meldet. Gespeichert wird **welche Version** gesperrt ist (`settings.lockedVersion`); diese Version startet danach immer gesperrt. Raus kommt man nur mit einer **neueren App-Version** (z. B. 1.0), die den Check besteht; sie ignoriert die Sperre der alten Version. „Deaktiviert“ verändert nichts an der Datenbank (kein Indizieren, Bereinigen, Löschen), daher übernimmt die neue Version Index, Favoriten und Einstellungen vollständig; Änderungen auf den Medien holt der Abgleich nach. Nur in der Entwicklung (neuer Build, Datenbank anpassen) lässt sich eine Sperre lösen.
  - **Test (Nutzer 11.10., mit 0.4):** API bleibt auf `"1.0"`, App 0.x → prüfen, dass die Datenbank sich die Entdeckung merkt (`betaExpiryNoticedAt`, `lockedVersion`); dann den Zeitstempel um 7 Tage zurücksetzen → App sperrt; Neustart → bleibt gesperrt.
  - **Aktive Installationen zählen (Nutzer 11.10.):** wird mit der **Lizenz (0.9)** geklärt; bis dahin keine Installations-Kennung.
  - Vor 1.0 gibt es keine Sperre alter Betas, nur den Update-Hinweis (Nutzer 11.10.: „perfekt so“).
  - Für die 7 Tage genügt die Uhr des Macs (Nutzer 11.10.: „kommt nicht auf die Stunde an“); keine Serverzeit.
- **„API zuletzt erreicht“** (`settings.apiLastSeen`): Wird die API **einen Monat** lang nicht erreicht, gilt das System ebenfalls als deaktiviert, bis wieder eine Verbindung gelingt (Begründung Nutzer: nach einem Monat sollte wieder Internet da sein; die Lizenz wird ab 0.9 auch beim Start geprüft). Ersetzt die alte README-Regel „sperrt nie ohne Netz“.
- **API-Warteschlange** (eigene Tabelle `api_queue`: `id`, `kind`, `payload`, `createdAt`, `attempts`, `lastTryAt`, `info`). Aufträge: **Lizenz-Check** (ab 0.9), **Versions-Check**, **Update-Check** (0.4), **Fehlerbericht senden**. Ist die App online, wird die Warteschlange geleert (der Reihe nach, erfolgreiche Aufträge gelöscht). Geht das nicht (kein Internet), prüft ein **Ping alle 60 s**, ob wieder eine Verbindung besteht, und leert dann. **Beschlossen (Nutzer 11.10.):** zusätzlich sofort leeren, wenn macOS „Netz wieder da“ meldet (`NWPathMonitor`); der 60-s-Ping bleibt als Sicherung (auch gegen Umgehung). Der heutige Fehlerbericht-Ausgang (Dateien im Ordner `outbox` mit eigener Wiederholung) geht in dieser Warteschlange auf.
- Häufigkeit Versions-/Update-Check und Zusammenspiel mit dem Deaktiviert-Modus: **wird in 0.3.1 besprochen** (Vorschlag Claude: beim Start und alle 24 h).

**Für den Schema-Entwurf noch festzulegen (Claude 11.10.):**
- **Kennungen nie wiederverwenden** (`AUTOINCREMENT`, beschlossen Nutzer 11.10.): Vorschaubilder heißen wie `item.id`; würde eine gelöschte Kennung neu vergeben, könnte ein altes Bild an einer fremden Datei hängen. Gilt auch für `storages.id`.
- **Sortierung in den Spalten (beschlossen Nutzer 11.10.): wie der Finder, natürlich, Umlaute wie Stammlaut, Ordner und Dateien gemischt nach Namen** (nicht mehr Ordner oben). Bisher: `name COLLATE NOCASE`, Ordner zuerst. Der Finder sortiert „natürlich“ („Datei 2“ vor „Datei 10“) und Umlaute wie ihren Stammlaut. Festlegen, ob nach `slug` sortiert wird und ob Zahlen natürlich sortiert werden (die Suchhilfe für die Spaltenansicht hängt daran).
- **`storages` bekommt ebenfalls `slug`** (Suche über Mediennamen).
- **Zähler der Scan-Läufe** je Medium (für `lastSeenAt` als Laufnummer) als Schlüssel in `storage_meta`.
- Danach: Messwerte aus 196 einarbeiten, Schema-Entwurf (jede Spalte mit Typ, Suchhilfen, Abfragen) zur Freigabe.

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

## Vorschläge Claude 11.10. (zur Besprechung)

- **Wartung im Hintergrund statt Startbildschirm:** Prüfung auf Schäden (7 Tage / nach Absturz, gibt es seit 219), ausstehende Bereinigung, verwaiste Einträge, Verkleinern nach großem Löschen, Protokolle kürzen – über dieselbe Warteschlange wie die Regeländerungen, wenn die App gerade nichts zu tun hat.
- **Fenster „Datenbank wird aktualisiert“** nur ab 0.4 bei einer Schema-Erweiterung durch ein Update (einmalig, mit Fortschritt). Kein Startbildschirm bei normalen Starts (Menüleisten-App mit Autostart, bereit nach 0,1–0,25 s).

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

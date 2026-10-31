# Paket 44 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 29.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest E1–E4 des Nutzers 29.10. 12:55–13:50 mit der App von 12:48 (Paket 43). Platte „Daten I“ (SanDisk Extreme, 500 GB, **exFAT**): 266 568 Dateien, 16 596 Ordner, keine Teil-Prüfsummen.

## Abnahme Host 29.10. (Gesamtlauf 16:01–16:33)

- Diff gelesen (`IndexStoreV3`: `comparableSizes` je Medium gemerkt, verworfen in `storePartialChecksum` – einzige Schreibstelle von `item_checksum`; Abfrage per `CROSS JOIN` von `item_checksum` aus; `mayReconnect`/`goneRowsExist` mit Literal und `INDEXED BY items_gone`, Index aus der Migration `0.4.0-items_gone`). Nichts Wesentliches. Stufe 3: Gelöschte Teil-Prüfsummen lassen die gemerkte Menge zu groß (höchstens eine Datei mehr gelesen).
- Gesamtlauf bei Last 3,7 (Nutzer: „scheiß auf Last“): Debug und Release 0 Warnungen, seriell 1227/1227, parallel 3× grün (je 1221, 6 übersprungen), Sabotage 3/3 rot (228-a 2/2, -b 3/3, -c 1/1), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 16:33:06, Signatur gültig. Die beim Worker unter Last roten Zeittests aus `bug.0.4.227` waren grün.
- Offen: echte Platte „Daten I“, Abgleich nach dem Einstecken (Nachtest des Nutzers).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (jetzt `archiv/sabotage/paket-44/`) (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `bug.0.4.228`. **HALT.**

## Aufgaben

- **bug.0.4.228 — Abgleich großer Medien dauert eine halbe Stunde und mehr, weil vor jedem Ordner das ganze Medium abgefragt wird (Nutzer 29.10.):**
  - **Nutzer sieht:**
    - Nach jedem Einstecken und jedem Aufwachen steht „Daten I“ **über 30 Minuten bei 99 %**, und die App braucht dabei einen ganzen Kern (CPU 99–106 %).
    - Der Abgleich 13:30–13:50 kam in 19,5 Minuten nur bis Ebene 9 von 17. Das Erstindizieren davor hatte Ebene 9 nach 7 Minuten erreicht.
    - Schon beim Erstindizieren dauerten einzelne Schreibvorgänge in den tiefen Ebenen 20–66 s. Die H4-Karte wartete nach „Ja“ 6 s darauf.
  - **Wann:** Abgleich (Einstecken, Aufwachen) und Erstindizieren jedes großen Mediums ohne verlässliche `fileID` (exFAT/FAT). Je größer das Medium, desto langsamer jeder Ordner. **Stufe 1:** in der echten App nachgewiesen.
  - **Beleg (Host, Protokoll, `sample`, Datenbank nur lesend):**
    - Ebenenzeiten Erstindex gegen Abgleich: Ebene 3 1,0 s gegen 10,0 s, Ebene 4 4,4 s gegen 51,3 s, Ebene 5 10,8 s gegen 97,0 s. Im Abgleich 46 `perf applyDirectories` über 1 s, der längste 105 s, zusammen 562 s.
    - `sample` im Abgleich (13:33, 4 s): 2 658 von rund 2 740 Proben in `IndexStoreV3.precomputedPartials` (Z. ~1889), in der Abfrage `SELECT DISTINCT d.sizeBytes FROM item_checksum c JOIN items i … WHERE i.storageID = ? AND i.isFolder = 0`.
    - Abfrageplan: `SEARCH i USING INDEX items_identity (storageID=?)`, danach `c` je Zeile. SQLite geht also über **alle Einträge des Mediums**, obwohl `item_checksum` leer ist. Gemessen (sqlite3, nur lesend): **0,10 s je Aufruf** bei 283 164 Einträgen.
    - Aufgerufen wird sie in `applyDirectories` (Z. ~669) **für jeden Ordner des Stapels** und in `applyDirectory` (Z. ~630). Bei 16 596 Ordnern sind das gut 28 Minuten nur für diese Abfrage, mit jedem Lauf neu.
    - Zweite Stelle, nur beim Erstindex: `sample` 13:03 zeigt 606 von 2 900 Proben in `IndexStoreV3.mayReconnect` (Z. ~1259), und zwar **in der Schreibtransaktion** bei jedem Stapel. Solange `firstIndexedAt` leer ist, prüft sie `EXISTS(… items WHERE storageID = ? AND status = ?)`. Mit gebundenem `status` kann SQLite den Teilindex `items_gone … WHERE status = 2` nicht nehmen und liest alle Zeilen des Mediums. Dieselbe Form hat `DirectoryWriterV3.goneRowsExist` aus Paket 43 (dort nur einmal am Laufende).
  - **Ursache:** Beide Abfragen kosten so viel, wie das Medium Einträge hat, und laufen einmal je Ordner bzw. Stapel. Damit wächst der Lauf mit Einträgen × Ordnern. Paket 43 hat die Kosten **im** Schreiber behoben, diese beiden liegen davor bzw. daneben.
  - **Soll (Invariante 9, ergänzt 29.10.):**
    - Was ein Ordner beim Indizieren oder Abgleichen kostet, hängt nicht von der Größe des Mediums ab. Das gilt für die Abfragen vor dem Schreiben genauso wie für den Schreiber.
    - Ein Medium ohne gespeicherte Teil-Prüfsumme fragt nicht bei jedem Ordner danach.
    - Der Abgleich von „Daten I“ ohne Änderungen dauert ungefähr so lange wie das Lesen der Platte (Erstindex: 25 Minuten inklusive Schreiben; ein Abgleich sollte deutlich darunter liegen).
    - Favoriten auf verschobenen Dateien verbinden weiter wieder (`bug.0.4.141`, `156`, `169`, `225`, `227`). Wird eine Teil-Prüfsumme **während** eines Laufs gespeichert (Favorit gesetzt), reicht es, wenn sie ab dem nächsten Lauf mitzählt (schon heute so, Stufe 3 aus `bug.0.4.225`).
  - **Weg (Vorschlag, du entscheidest):**
    - Die Menge der vergleichbaren Größen **einmal je Lauf** (bei `beginIndexing` bzw. dem ersten Stapel) holen und im Store je Medium merken. Beim Speichern oder Löschen einer Teil-Prüfsumme den Merker verwerfen.
    - Die Abfrage selbst von `item_checksum` aus führen (z. B. erst `EXISTS` über `item_checksum` mit `JOIN items`, `CROSS JOIN` in der richtigen Reihenfolge), damit sie bei leerer Tabelle sofort fertig ist.
    - Die `segments` des Elternordners nur holen, wenn es überhaupt vergleichbare Größen gibt (heute schon so, bitte so lassen).
    - `mayReconnect`: `status = 2` als Literal in die Abfrage, damit `items_gone` greift, und das Ergebnis je Lauf merken (verschwundene Zeilen entstehen im Lauf erst am Ordnerende bzw. am Laufende). Gleiches Literal in `goneRowsExist`.
  - **Gegenprobe (Tests, Regel 10):**
    1. **Realistischer Test:** exFAT-ähnliches Medium mit großem Bestand (z. B. 200 000 Einträge direkt in die Datenbank geschrieben) und 2 000 Ordnern; Abgleich ohne Änderungen. Die Zeit je Ordner ist höchstens wenig größer als bei einem Medium mit 2 000 Einträgen (z. B. Faktor < 3; gemessene Zeiten vorher/nachher in den Status).
    2. Zähler im Test: Die Größenabfrage läuft je Lauf höchstens einmal (bzw. einmal nach jedem Speichern einer Teil-Prüfsumme), nicht je Ordner.
    3. Erstindex desselben großen Mediums: `mayReconnect` kostet je Stapel nicht mehr als bei einem kleinen Medium (Abfrageplan mit `items_gone`, im Test über `EXPLAIN QUERY PLAN` oder eine Zeitgrenze).
    4. Ein Favorit (gespeicherte Teil-Prüfsumme) auf FAT/exFAT wird verschoben, das Medium neu abgeglichen: Der Favorit hängt an der verschobenen Datei. Ebenso, wenn der Favorit erst **nach** einem Lauf gesetzt wurde und der nächste Lauf ihn braucht (Merker verworfen).
    5. Die bestehenden Tests zu `bug.0.4.141`, `156`, `169`, `225`, `227` (`FatReconnectIndexerTests`, `PartialChecksumStoreTests`, `LargeFolderChunkTests` u. a.) bleiben grün.
  - **Patches (rot erwartet):**
    1. `bug.0.4.228-a.patch`: Größenabfrage wieder je Ordner. Test 1 oder 2 wird rot.
    2. `bug.0.4.228-b.patch`: Merker beim Speichern einer Teil-Prüfsumme nicht verwerfen. Test 4 wird rot.
    3. `bug.0.4.228-c.patch`: `mayReconnect` wieder mit gebundenem `status`. Test 3 wird rot.
  - **Messen:** Test 1 vor und nach dem Fix, Zeiten in den Status. Die echte Platte prüft der Nutzer (Nachtest E1, Abgleich nach dem Einstecken).
  - **So lassen:** Teil-Prüfsumme nur bei Bedarf (`bug.0.4.225`), Store-Actor ohne Plattenzugriff (`bug.0.4.226`, Invariante 8), Abgleich mit verschwundenen Einträgen nur bei `finalize` (`bug.0.4.227`), Abgleich nach dem Aufwachen (Nutzer 28.10.), Ablauf und Lebenszyklus der Läufe (`konzept/lauf-lebenszyklus.md`). Kein neues Schema (Indizes nur, wenn es ohne Migration der Nutzerdaten nicht geht; dann vorher fragen).
  - **Status:** Bereit zur Prüfung. Ursache bestätigt. Dazu: `mayReconnect` las auch mit Literal das ganze Medium, weil die App (mit registrierter Sortierung „natural“) `items_children` wählt. `sqlite3` wählt `items_gone`, nur weil es „natural“ nicht kennt.
    - Fix: vergleichbare Größen je Medium gemerkt (`comparableSizes`), verworfen nach `storePartialChecksum` (Generationszähler), Abfrage per `CROSS JOIN` von `item_checksum` aus; `mayReconnect`/`goneRowsExist` mit `INDEXED BY items_gone` und Literal; `mediumHasStoredPartials` per `CROSS JOIN`. Kein neues Schema.
    - Test 1 (200 000 Einträge, 1 000 Ordner) je Ordner groß/klein: 69,5/4,5 ms → 1,60/1,55 ms; Test 3 je Stapel: 29,8/5,9 → 4,6/4,5 ms; Test 2: 50 → 1 Abfrage. Rot 14:16–14:19, grün 14:29–14:30; 4a/4b schon vorher grün (sichern Patch b).
    - 26 betroffene Suites 14:33–14:40: 210/213 grün; rot nur `LargeFolderChunkTests` 227/1+2 (15,7 s statt < 15 s), ebenso ohne Fix (16,5 s), Last (GeForce NOW, Spotlight). Sabotage a/b/c rot 3/3 (14:47–14:53), 20× parallel 0 Fehler (14:53–15:03), Debug clean 0 Warnungen (15:04).
    - Selbstprüfung: nichts Wesentliches. Stufe 3: Patch c wird nur über die Zeitgrenze rot, nicht über `EXPLAIN QUERY PLAN`.

# Paket 43 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 29.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest E1/E2 des Nutzers 29.10. 10:45–10:53, Platte „Daten I“ (SanDisk Extreme, 500 GB, **exFAT**), nach „Alle Speichermedien vergessen“ neu indiziert, App von 28.10. 20:22.

## Abnahme Host 29.10. (Gesamtlauf 12:16–12:48)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug mit Testziel und Release: 0 Warnungen.
- Seriell 1221/1221, parallel 3× grün (je 1215, 6 übersprungen).
- Sabotage **2/2 rot ✓** (227-a 2/2, -b 1/1).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- App des Nutzers 12:48:35, Signatur gültig, Version 0.4.0.

Diff vom Host gelesen: nichts Wesentliches.
- Abgleich „verschwunden im selben Ordner“ nur bei `finalize`; Kandidaten einmal je `apply` nach Größe (gleichwertig, `resolveIdentityMatch` verlangt dieselbe Größe).
- Teil-Prüfsummen in einer Abfrage; `mediumHasStoredPartials` wird je Schreiber gemerkt, der Schreiber lebt nur eine Transaktion lang.
- Laufende ohne Zeilen mit `status = 2` kehrt sofort zurück.
- Umbenennen zwischen zwei Läufen verbindet jetzt das Laufende (`reconnectInsertedWithGone`), auch in kleinen Ordnern, weil der Indexer jeden Ordner zuerst stückweise schreibt; Test 3 und die alten Tests zu 141/156/169/225 sind grün.
- Nicht nachstellbar: die echte Platte „Daten I“. Das prüft der Nutzer (Nachtest E1–E5).

Patches: `archiv/sabotage/paket-43/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `bug.0.4.227`. **HALT.**

## Aufgaben

- **bug.0.4.227 — Großer Ordner mit gleich großen Dateien legt die ganze App lahm (Nutzer 29.10.):**
  - **Nutzer sieht:**
    - „Daten I“ steht beim Erstindizieren wieder bei **15 %** (wie am 28.10. bei 14 %).
    - Ein zweites Medium (ZOOM_H4E) eingesteckt: Der Erkennungsdialog kommt erst nach langer Zeit.
    - Nach „Ja“ steht das Medium in den Einstellungen minutenlang auf **„Ausstehend“**.
    - „Vergessen“ wirkt erst nach knapp einer Minute.
  - **Wann:** Erstindizieren oder Abgleich eines Mediums ohne verlässliche `fileID` (exFAT/FAT) mit einem Ordner, der mehr Einträge hat als ein Lesestück und viele Dateien gleicher Größe, Endung und Zeit (hier `…/data` mit 13 747 Einträgen, davon 6 295 mit genau 514 Byte). **Stufe 1:** in der echten App nachgewiesen.
  - **Beleg (Host, Protokoll, `sample`, Datenbank nur lesend):**
    - Protokoll: Bis 10:47:15 hat „Daten I“ die Ebenen 1–5 geschrieben (2 398 `applyDirectories` in der Minute 10:47). Danach kommt **ein** `applyDirectories` alle 50–90 s (10:48:11, 10:49:02, 10:50:10, 10:51:39, 10:53:14).
    - Alles andere wartet dahinter und läuft in derselben Millisekunde los, in der ein `applyDirectories` fertig ist:
      - `forget` 10:50:41 → `deleteMedium` erst 10:51:39.
      - `event appeared` von ZOOM_H4E 10:51:39 und 10:53:14.
      - Die Entscheidung „Ja“ (`index anfordern`) erst 10:53:14.
    - `sample` (5 s, CPU 104 %): 2 928/2 928 Proben im Store-Thread, Pfad: `IndexStoreV3.applyDirectories` → `DirectoryWriterV3.apply` (Z. ~189) → `matchVacatedLocalCandidate` → `resolveIdentityMatch` → `disambiguateWithPartial` → `fetchPartial`. Die meiste Zeit geht in `sqlite3Prepare` (Statement pro Kandidat neu).
    - `item_checksum` für „Daten I“: **0 Zeilen**. Jede Abfrage liefert also `nil`.
  - **Ursache (Host, im Code bestätigen):**
    - `DirectoryIndexer` (Z. ~326) schreibt große Ordner stückweise mit `finalize: false`, damit Fortschritt und Index mitwachsen.
    - `DirectoryWriterV3.apply` lädt `existingByName` für den ganzen Ordner. Beim zweiten und jedem weiteren Stück stehen darin die Einträge der **früheren Stücke desselben Laufs**. Weil sie nicht in `incoming` (nur dieses Stück) stehen, hält `matchVacatedLocalCandidate` sie für verschwunden.
    - Für jeden neuen Eintrag wird diese Liste neu gebaut (Schleife über ganz `existingByName`). `resolveIdentityMatch` findet bei gleich großen Dateien Tausende Treffer, und `disambiguateWithPartial` fragt **für jeden Treffer einzeln** `item_checksum` ab. Das ergibt grob Einträge × frühere Einträge Abfragen pro Stück.
    - Das alles läuft in einer Schreibtransaktion auf dem Store-Actor. Deshalb wartet jeder andere Store-Aufruf (Erkennung, Entscheidung, Vergessen, andere Medien).
    - Ein Nebenrisiko derselben Ursache: Gibt es genau **einen** Treffer, gibt `verifyPartialMatch` ohne gespeicherte Teil-Prüfsumme den Kandidaten zurück. Dann wird ein Eintrag aus einem früheren Stück auf den neuen Namen **umgehängt**. Prüfe, ob das passiert; wenn ja, gehört es zum Fix.
  - **Soll:**
    - Einträge, die derselbe Lauf für diesen Ordner schon geschrieben hat, sind **keine** Kandidaten für „verschoben/umbenannt“. Beim Erstindizieren gibt es in einem Stück also gar keine Kandidaten.
    - Der Aufwand je Stück hängt von der Größe des Stücks ab, nicht von der Zahl der schon geschriebenen Einträge des Ordners. Keine Abfrage pro Kandidat in einer Schleife, wenn sich das als eine Abfrage oder als „Medium hat keine Teil-Prüfsummen“ erledigen lässt.
    - Ein zweites Medium wird während eines solchen Laufs sofort erkannt, „Ja“ und „Vergessen“ wirken sofort (Invarianten 8 und neu 9 in `konzept/architektur.md`).
    - Umbenennen und Verschieben zwischen zwei Läufen wird weiter erkannt, Favoriten hängen an der verschobenen Datei (`bug.0.4.141`, `156`, `169`, `225`), auch in Ordnern, die stückweise gelesen werden. Wenn das in großen Ordnern nur am Ordnerende (`finalize: true`) sauber geht, ist das in Ordnung.
  - **Weg (Vorschlag, du entscheidest):**
    - Der Indexer gibt dem Schreiber die Namen mit, die er für diesen Ordner in diesem Lauf schon gelesen hat (`folderEntries` bis hier). Der Schreiber nimmt sie aus den Kandidaten.
    - Oder: Identitätsabgleich mit verschwundenen Einträgen nur beim Schreiben mit `finalize: true`, wenn der ganze Ordner bekannt ist.
    - Zusätzlich: die Kandidatenliste einmal pro `apply` bauen statt pro Eintrag; Teil-Prüfsummen aller Kandidaten in einer Abfrage holen oder vorher prüfen, ob das Medium überhaupt eine Zeile in `item_checksum` hat.
  - **Gegenprobe (Tests, Regel 10):**
    1. **Realistischer Test:** exFAT-ähnliches Medium (keine verlässliche `fileID`), ein Ordner mit z. B. 20 000 Dateien gleicher Größe, Endung und Zeit, gelesen in Stücken wie im echten Lauf (gleiche Stückgröße wie `DirectoryIndexer`). Erstindizieren dauert höchstens wenige Sekunden (Grenze im Test großzügig, z. B. 15 s, gemessene Zeit vorher/nachher in den Status). Danach stehen alle 20 000 Einträge unter ihrem eigenen Namen im Index.
    2. Während Test 1 läuft, beantwortet der Store einen anderen Aufruf (z. B. `children` eines zweiten Mediums) jeweils in unter 1 s.
    3. Ein Favorit in einem Ordner, der stückweise gelesen wird (mehr Einträge als ein Stück), wird auf FAT/exFAT umbenannt bzw. verschoben, dann wird abgeglichen: Der Favorit hängt an der neuen Datei.
    4. Die bestehenden Tests zu `bug.0.4.141`, `156`, `169`, `225` (`FatReconnectIndexerTests`, `PartialChecksumStoreTests` u. a.) bleiben grün.
  - **Patches (rot erwartet):**
    1. `bug.0.4.227-a.patch`: frühere Stücke desselben Laufs wieder als Kandidaten zulassen. Test 1 (oder 2) wird rot.
    2. `bug.0.4.227-b.patch`: Abgleich mit verschwundenen Einträgen ganz abschalten. Test 3 wird rot.
  - **Messen:** Test 1 vor und nach dem Fix, Zeit in den Status. Die echte Platte prüft der Nutzer (Nachtest E1/E2).
  - **So lassen:** Stückweises Schreiben großer Ordner (Fortschritt), Zeitgrenzen aus `bug.0.4.169` b, Teil-Prüfsumme nur bei Bedarf (`bug.0.4.225`), Store-Actor ohne Plattenzugriff (`bug.0.4.226`), Ablauf und Lebenszyklus der Läufe (`konzept/lauf-lebenszyklus.md`).
  - **Status:** Bereit zur Prüfung. Ursache bestätigt: Bei Stücken mit `finalize: false` hielt `matchVacatedLocalCandidate` frühere Stücke für verschwunden. Bei genau einem Treffer ohne Teil-Prüfsumme hing es eine Zeile auf den neuen Namen um (`earlierChunkEntryKeepsItsRow`).
    - Fix in `DirectoryWriterV3`: Den Abgleich „verschwunden im selben Ordner“ gibt es nur bei `finalize`, das Umbenennen zwischen zwei Läufen verbindet das Laufende. Kandidaten werden einmal je `apply` nach Größe gesammelt. Teil-Prüfsummen holt eine Abfrage, die entfällt, wenn das Medium keine hat. Das Laufende kehrt sofort zurück, wenn es keine Zeile mit `status = 2` gibt.
    - Test 1 (20 000 × 514 Byte, Stück 2 000): vorher nach 59 s abgebrochen mit 4 000 Einträgen, nachher 3,4 s. Test 2: zweites Medium vorher 57,8 s, nachher 0,29 s. Rot 11:46–11:49 (Tests 1, 2, 4), grün 11:57 in 20 betroffenen Suites (172 Tests) + `ChangeWatcherTests` + Rauchtest-Zeilen 225–227.
    - Neue Suite `LargeFolderChunkTests` (4 Tests, Rauchtest-Zeile). Patches `bug.0.4.227-a/b` rot (pruefung.sh 11:59–12:00). 20× parallel 80/80 (12:01–12:05). Debug-Build `clean` mit Testziel: 0 Warnungen (12:07).
    - Selbstprüfung: nichts Wesentliches. Stufe 3: Ein großer, umbenannter Ordner zeigt nach einem abgebrochenen Lauf bis zum Folgelauf kurz beide Namen.

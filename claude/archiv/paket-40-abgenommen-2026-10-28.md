# Paket 40 — Zielversion 0.4.0 (freigegeben 28.10.2026, abgenommen 28.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest des Nutzers 28.10. 11:20–11:45, Platte „Daten I“ (SanDisk Extreme 55AE, 500 GB SSD, **exFAT** über FSKit, 139 GB belegt, rund 283 000 Einträge).

## Abnahme Host 28.10. (Gesamtlauf 12:47–13:25)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug mit Testziel und Release: 0 Warnungen.
- Seriell 1216/1216.
- Parallel 1 und 2 grün (je 1210, 6 übersprungen).
- Parallel 3 mit einem roten Test: `SlowVolumeMountTests/mountWithNonStandardPathIsAbandonedByStandardUnmount()` („Aushängen mit anderem Pfad hat die hängende Abfrage nicht verlassen“).
  - Der Test liegt außerhalb des Diffs (`MediumMonitor`, Zeitgrenzen 0,3 s/8 s).
  - Parallel 3 dauerte 12 min statt 5,5 min, der Rechner war belastet. Er steht im Backlog als Stufe 2.
- Sabotage **5/5 rot ✓** (225-a 2/2, -b 1/1, -c 1/1, 226-a 1/1, -b 2/2).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- App des Nutzers 13:25:10, Signatur gültig, Version 0.4.0.

Diff vom Host gelesen, Prüf-Agent (Sonnet): nichts Wesentliches.
- 225: `precomputedPartials` liest nur Dateien, deren Größe zu einem Eintrag mit gespeicherter Teil-Prüfsumme passt; `resolveIdentityMatch` verlangt dieselbe Größe, also geht kein nötiger Vergleich verloren. `disambiguateWithPartial` liest nicht ohne gespeicherten Wert.
- 226: `fileURL` ohne Plattenzugriff (`appending(component:directoryHint:)`), Lesen beim Live-Umbenennen in `LiveRenameTarget` (losgelöster Task), Quelltext-Wächter.
- Nicht nachstellbar auf einem Disk-Image: die Langsamkeit auf „Daten I“ und die 11 s beim Auswerfen. Das prüft der Nutzer in der echten App.
- Neu ab diesem Paket: Der Worker macht keine Gesamtläufe mehr (Regel 13/14, Nutzer 28.10.).

Patches: `archiv/sabotage/paket-40/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.225`, dann `bug.0.4.226`. **HALT.**

## Aufgaben

- **bug.0.4.225 — Indizieren liest Anfang und Ende jeder Datei, ohne es zu brauchen (Nutzer 28.10.):**
  - **Nutzer sieht:** „Daten I“ kommt beim Erstindizieren kaum voran. Die Ebenen 1–5 gingen in 3 Minuten, danach steht der Fortschritt scheinbar bei 14 %. Gemessen 11:49–11:50: **eine Datei pro Minute**.
  - **Wann:** Erstindizieren und Abgleich großer Medien, am stärksten auf exFAT/FAT mit großen Dateien. **Stufe 1:** in der echten App nachgewiesen.
  - **Beleg (Host, Protokoll, `sample`, Datenbank nur lesend):**
    - `sample` des Prozesses: Fast alle Zeit steckt in `IndexStoreV3.applyDirectories` → `precomputedPartials` (Z. ~1872) → `PartialChecksum.computeOffActor`/`compute` (`open`, `seek` ans Ende, `read`).
    - Die Platte liest dabei 5 800 Mal pro Sekunde je 4 KB. exFAT muss für den Sprung ans Dateiende die Clusterkette ablaufen; bei großen Dateien sind das zehntausende Lesevorgänge.
    - Ab 11:27 schreibt `applyDirectories` nur noch einzelne Ordner; um 11:46–11:50 einen pro Minute.
    - `item_checksum` hat **0 Zeilen**. Die berechneten Werte werden also nie gespeichert und nur verworfen.
  - **Ursache (Host, im Code bestätigen):**
    - `precomputedPartials` berechnet die Teil-Prüfsumme für **jede** Datei jedes Stapels, sobald `partialMatchingEnabled` gilt (Voreinstellung `true`).
    - Gebraucht wird sie nur in `DirectoryWriterV3.verifyPartialMatch` und `disambiguateWithPartial`, also nur, wenn es einen **verschwundenen Eintrag mit gespeicherter Teil-Prüfsumme** gibt, gegen den verglichen wird.
    - Eingeführt mit `bug.0.4.023` (16.10., Teil-Prüfsumme vor dem Store), seit `bug.0.4.169` (Paket 17) gilt ein fehlender Vorab-Wert als „unlesbar“.
  - **Soll (Konzept `datenbank.md` „Umbenennen und Verschieben erkennen“, ergänzt 28.10.):**
    - Das Indizieren liest **keine Dateiinhalte**, solange kein Vergleich nötig ist. Beim Erstindizieren und bei Medien ohne gespeicherte Teil-Prüfsumme wird nichts gelesen.
    - Gelesen wird nur für Einträge, die gegen einen verschwundenen Eintrag mit gespeicherter Teil-Prüfsumme verglichen werden.
    - Das Wiederverbinden von Favoriten verschobener Dateien (`bug.0.4.141`, `156`, `169`) funktioniert unverändert. Ein fehlender Wert für einen Eintrag, der verglichen werden muss, gilt weiter als „unlesbar“ (`bug.0.4.169` a).
  - **Weg (Vorschlag, du entscheidest):**
    - Vor dem Lesen in `precomputedPartials` in einem `pool.read` bestimmen, welche Namen des Stapels überhaupt verglichen werden können. Am einfachsten zuerst: Hat das Medium keine Zeile in `item_checksum`, wird nichts gelesen.
    - Sonst nur die Einträge lesen, für die `DirectoryWriterV3` einen Kandidaten mit gespeicherter Teil-Prüfsumme finden kann (gleiche Merkmale wie beim Abgleich: Größe usw.).
  - **Gegenprobe (Tests, Regel 10):**
    1. Erstindizieren eines Mediums mit vielen Dateien (z. B. 500) und Abgleich ohne Favoriten: `PartialChecksum.compute` wird **0-mal** aufgerufen (Zähler im Test).
    2. Ein Favorit (gespeicherte Teil-Prüfsumme) wird auf FAT/exFAT verschoben und das Medium neu abgeglichen: Der Favorit hängt an der verschobenen Datei. Gelesen wird nur für die Kandidaten, nicht für alle Dateien.
    3. Die bestehenden Tests zu `bug.0.4.141`, `156`, `169` (`FatReconnectIndexerTests`, `PartialChecksumStoreTests` u. a.) bleiben grün.
  - **Patches (rot erwartet):**
    1. `bug.0.4.225-a.patch`: wieder für alle Dateien lesen. Test 1 wird rot.
    2. `bug.0.4.225-b.patch`: nie lesen. Test 2 wird rot.
  - **Zweite Folge (Nutzer 28.10. 12:01, gleiche Ursache vermutet):** „Daten I“ im Finder ausgeworfen: Bis die App „Offline“ zeigt, dauert es **11 s** (`willDisappear` 12:01:56.652 → `disappeared` 12:02:07.642). Bei allen anderen Auswürfen heute 17–43 ms. Vermutung Host: Die App hält noch Dateien zum Lesen der Teil-Prüfsumme offen (nach der Zeitgrenze laufen die Lese-Threads weiter, Invariante 3), und macOS wartet mit dem Aushängen. Im Status belegen, ob das nach dem Fix weg ist (Test: Medium mit großen Dateien während des Laufs auswerfen, Zeit bis `disappeared`).
  - **Messen:** Lauf über einen Ordner mit vielen großen Dateien (künstlich, in `$TMPDIR`, z. B. auf einem exFAT-Disk-Image mit `hdiutil`, wenn es geht), vorher/nachher. Wert in den Status.
  - **So lassen:** Teil-Prüfsumme beim Setzen eines Favoriten, Zeitgrenzen aus `bug.0.4.169` b, Ablauf und Lebenszyklus der Läufe (`konzept/lauf-lebenszyklus.md`).
  - **Status:** Bereit zur Prüfung. `precomputedPartials` liest nur Dateien gleicher Größe wie ein Eintrag mit Zeile in `item_checksum` (Erstindex/ohne Favoriten: nichts); `disambiguateWithPartial` liest nicht, wenn kein Kandidat eine gespeicherte Teil-Prüfsumme hat (Fund der Selbstprüfung, Laufende). Tests `PartialReadOnDemandTests` (2) + Rauchtest-Zeile; rot vor dem Fix 12:18–12:19 (1000/2000 bzw. 201 Lesevorgänge) und 12:33 (Laufende 1), grün 12:20/12:34.
    - Patches 225-a/b/c rot 12:36–12:38. Betroffene Suites 243/243 (28 Suites, 12:34–12:36), 20× parallel grün 12:38–12:39, Debug mit Testziel 0 Warnungen 12:40.
    - Messung exFAT-Image (300 × 8 MB, fragmentiert): alt 300 gelesen 0,105 s, neu 0 gelesen 0,042 s; das Image liegt im Cache, die Langsamkeit selbst ist so nicht nachstellbar.
    - Auswerfen während des Laufs (Image): alt und neu je ~0,3 s, die 11 s nicht nachstellbar; nach dem Fix öffnet das Indizieren ohne Favoriten keine Datei mehr. Nachtest in der echten App offen.
    - Stufe 3: die Größenmenge ist ein Schnappschuss vor dem Schreiben; ein dazwischen gespeicherter Wert verbindet erst am Laufende wieder.

- **bug.0.4.226 — Eine langsame Platte hält alle anderen Medien auf (Nutzer 28.10.):**
  - **Nutzer sieht:** Nach dem Aufwachen des Macs stehen alle anderen Medien still. Erst als er „Daten I“ abzieht, laufen sie los. Er hält das Abziehen für den Auslöser („wenn ich eine abziehe, werden alle anderen indiziert“).
  - **Wann:** Eine Platte liest langsam oder hängt (großes exFAT-Medium, nach dem Aufwachen), und gleichzeitig will ein anderes Medium schreiben oder einen Lauf beginnen. **Stufe 1:** in der echten App nachgewiesen.
  - **Beleg (Protokoll 28.10.):**
    - 11:42:59 Aufwachen: `auftrag` (Abgleich) für „Transfer“ und „ZOOM_H4E“, gewollt (`bug.0.4.028`: nach dem Aufwachen genau ein Abgleich je verbundenem, indiziertem Medium).
    - Der zugehörige `start` (`DirectoryIndexer` Z. ~80, nach `store.beginIndexing`) kommt erst um **11:43:23.390**, in derselben Millisekunde wie das Ausstecken von „Daten I“ (`ausgehängt` 11:43:23.361, `store error applyDirectories CancellationError` 11:43:23.384).
    - Die beiden Abgleiche dauern dann je 1–2 s.
  - **Ursache (Host, im Code bestätigen):**
    - `precomputedPartials` läuft auf dem Actor `IndexStoreV3`. Darin baut `DirectoryWriterV3.fileURL` (Z. ~852) die URL mit `URL.appendPathComponent`. Das fragt die Platte (`getattrlist`, im `sample` sichtbar), ob der Pfad ein Ordner ist, und zwar **synchron auf dem Actor**.
    - Solange die Platte nicht antwortet, wartet jeder andere Aufruf des Stores, auch `beginIndexing` und das Schreiben der anderen Medien.
    - Schon in der Bestandsaufnahme 16.10. (Nr. 121, „TEILWEISE“) als Rest von `bug.0.4.023` vermerkt: `fileExists`/`resourceValues` in `precomputedPartials`/`applyLiveRename` auf dem Store-Actor.
  - **Soll (Invariante, `konzept/architektur.md` ergänzt 28.10.):** Der Actor `IndexStoreV3` greift **nie** auf ein Speichermedium zu, weder lesend noch mit `stat`/`getattrlist`. Pfade baut er ohne Plattenzugriff. Alles Lesen von Medien geschieht außerhalb, mit Zeitgrenze.
  - **Weg (Vorschlag, du entscheidest):**
    - `fileURL` ohne Plattenzugriff bauen, z. B. `URL(fileURLWithPath:isDirectory: false)` aus dem zusammengesetzten Pfad oder `appending(path:directoryHint: .notDirectory)`.
    - Die übrigen Stellen im Actor-Code von `IndexStoreV3` suchen, die das Medium berühren (`fileExists`, `resourceValues`, `attributesOfItem`, `appendPathComponent` auf Medienpfaden, `applyLiveRename`), und nach außen verlegen. Im Status auflisten, was du gefunden hast.
  - **Gegenprobe (Tests, Regel 10):**
    1. Medium A hängt beim Lesen der Teil-Prüfsumme bzw. beim Pfadbau (Haken `fileExistsDelayForTesting` o. ä., einige Sekunden). Währenddessen beginnt ein Lauf für Medium B und schreibt einen Stapel: Das gelingt, **ohne** auf A zu warten (Zeitgrenze im Test deutlich kürzer als die Verzögerung).
    2. Ein Quelltext-Wächter (wie beim Nur-Lesen-Nachweis, `todo.0.4.014`) findet im Actor-Code von `IndexStoreV3` keinen Aufruf von `appendPathComponent`/`appendingPathComponent` auf Medienpfaden und kein `FileManager`.
  - **Patches (rot erwartet):**
    1. `bug.0.4.226-a.patch`: `fileURL` wieder mit `appendPathComponent`. Test 2 wird rot.
    2. `bug.0.4.226-b.patch`: das Lesen wieder auf dem Actor (z. B. `fileExists` vor `computeOffActor` im Actor). Test 1 wird rot.
  - **So lassen:** Der Abgleich nach dem Aufwachen bleibt (`bug.0.4.028`, vom Nutzer am 28.10. bestätigt). Lebenszyklus der Läufe und Fenster aus `konzept/lauf-lebenszyklus.md`.
  - **Status:** Bereit zur Prüfung. Gefunden im Actor-Code: `DirectoryWriterV3.fileURL` (`appendPathComponent`, jetzt `appending(component:directoryHint:)`), Pfadbau in `storePartialChecksum` (jetzt über `fileURL`), `liveRenameTargetFields` (`FileManager`/`resourceValues`/`compute`, verlegt nach `Indexing/LiveRenameTarget.swift`), DEBUG-`fileExists` (jetzt `MountedMediumCheck.testFolderExists`); `storeFileURL`/`inventoryLabels` betreffen nur die eigene Datenbank.
    - Tests `StoreActorMediumAccessTests` (2) + Rauchtest-Zeile. Wächter rot vor dem Fix 12:18; Test 1 vor dem Fix grün (langsamer Pfadbau auf lokaler Platte nicht nachstellbar), Beweis über Patch b. Grün 12:20/12:34.
    - Patches 226-a/b rot 12:38. 20× parallel grün 12:38–12:39.
    - Stufe 2 (Selbstprüfung, außerhalb des Actors): `stat` in `liveRenameTargetMatches` und `standardizedFileURL` in `relativeComponents` laufen beim Live-Umbenennen in der Schreibtransaktion; nur, wenn eine Platte genau dabei hängt.

## Status

Abgenommen 28.10.

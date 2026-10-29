# Paket 39 — Zielversion 0.4.0 (freigegeben 28.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest des Nutzers 28.10. 07:51–07:52.

## Abnahme Host 28.10. (Gesamtlauf 09:10–09:41)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell 1210/1210.
- Parallel 2 und 3 grün.
- Parallel 1 hatte einen roten Test: `IndexFailureReasonTests/serviceRunPassesTheUnconfirmedReasonToTheDialog()`.
  - Er wurde nach 120 s abgebrochen („signal term“), sonst dauert er 2 s.
  - Der Test liegt außerhalb des Diffs, weil er weder Vergessen noch Löschen berührt.
  - Bisher ist er nie aufgefallen. Er steht im Backlog als Stufe 2.
- Sabotage **3/3 rot ✓** (224-a 2 von 2, -b 1 von 1, -c 2 von 2).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- App des Nutzers 09:41:35, Signatur gültig, Version 0.4.0.

Diff vom Host gelesen, Prüf-Agent (Sonnet): nichts Wesentliches.
- **Messung des Workers:** Altes Löschen von „Daten“ (1,6 Mio. Zeilen) 25,1 s in einer Transaktion. Neu: Markierung aller 7 Medien 0,07 s, dann 173 Stücke, das längste 0,18 s.
- `deleteMedia(uuids:)` markiert alle Medien in **einer** kurzen Transaktion: `pendingDeletion`, neue Zufalls-UUID, Favoriten weg.
- `purgePendingDeletions` löscht danach 10 000 Zeilen je Transaktion, zuletzt die `storages`-Zeile mit der Wartungsschuld (`bug.0.4.108`). Der Start setzt das fort, ohne zu warten.
- Laden, Erkennung, Suche (alle und ein Medium), Favoriten und Zähler übergehen markierte Medien.
- Schreiber finden die alte Zeile nicht mehr (`unknownMedium`). Ein wieder eingestecktes Medium bekommt eine neue Zeile und den Erkennungsdialog.
- Das Schema bleibt gleich, nur ein neuer Schlüssel in `meta_keys`.
- Stufe 3, Prüf-Agent: Das erste Stück scannt Zeilen später indizierter Medien mit. Ein Fehler beim Löschen hält bis zum nächsten Start an; das Medium bleibt dabei unsichtbar.

Patches: `archiv/sabotage/paket-39/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** nur `bug.0.4.224`. **HALT.**

## Aufgaben

- **bug.0.4.224 — „Vergessen“ geht verloren, wenn die App bald danach beendet wird (Nutzer 28.10.):**
  - **Nutzer sieht:**
    - Er klickt „Alle Speichermedien vergessen“. Die Liste ist sofort leer, und die Mitteilung kommt.
    - Nach dem Beenden und Neustart sind alle Medien mit Index und Entscheidung wieder da.
    - Das Beenden hängt 8 s und endet unsauber („previous run ended without clean exit“).
  - **Wann:** Ein großes Medium ist registriert, und der Nutzer beendet die App in den nächsten Sekunden. Das gilt auch für „Vergessen“ eines einzelnen großen Mediums. **Stufe 1:** In der echten App zweimal nachgestellt.
  - **Beleg, Protokoll des Nutzers vom 28.10.:**
    - Erster Versuch: `forget all count=7` um 07:51:04, `app terminate timeout after=8.0 seconds` um 07:51:19.
    - Zweiter Versuch: dasselbe von 07:52:00 bis 07:52:13.
    - Danach folgt **kein** `deleteMedium count=1`, und beim Start steht `loaded media=7`.
    - In `storages` stehen danach weiter 7 Zeilen; „Daten“ hat 1 602 092 Einträge.
  - **Ursache (Host, im Code bestätigen):**
    - `forgetAllMedia` (`AppState+Media.swift` Z. ~246) leert sofort nur den Zustand im Speicher.
    - Die Datenbank löscht danach in einem Task, Medium für Medium, je eine Transaktion mit Kaskade (`IndexStoreV3.deleteMedium` Z. ~494). Das erste ist „Daten“ mit 1,6 Mio. Zeilen.
    - Diese Transaktion dauert länger als die Zeit bis zum Beenden. Nach 8 s wird die App hart beendet, und SQLite rollt die Transaktion zurück. So ist **kein** Medium gelöscht, auch nicht die kleinen danach.
  - **Messen, bevor du baust:** Wie lange dauert `deleteMedium` für ein Medium mit 1,6 Mio. Zeilen? Miss das an einer Kopie der Datenbank des Nutzers in `$TMPDIR`, das Original nur lesen (Regel 13). Halte den Wert im Status fest.
  - **Soll (Konzept `medien.md` 7, ergänzt 28.10.):**
    - Nach dem zweiten Klick ist das Vergessen **sofort dauerhaft**. Auch bei einem Beenden in der nächsten Sekunde, einem harten Beenden oder einem Absturz bleibt es beim Neustart vergessen.
    - Registrierung, Entscheidung und Favoriten sind weg. Steckt der Nutzer das Medium wieder ein, gilt es als unbekannt und der Erkennungsdialog erscheint.
    - Das Löschen der Einträge darf danach im Hintergrund weiterlaufen. Wird die App vorher beendet, setzt es beim nächsten Start fort.
    - Das Beenden wartet nicht darauf: kein Hänger, kein `terminate timeout` wegen des Löschens.
    - Suche, Favoriten und Zähler zeigen zu keinem Zeitpunkt Einträge eines vergessenen Mediums, auch nicht während das Löschen noch läuft.
  - **Weg (Vorschlag, du entscheidest):**
    - In **einer kurzen Transaktion** das Medium als „wird gelöscht“ markieren: eine Spalte in `storages` oder eine eigene Tabelle.
    - Dabei die Kennungen freigeben (UUID und Fingerabdruck), z. B. auf einen Zufallswert ändern. So kann dasselbe Medium sofort neu registriert werden, ohne mit der alten Zeile zu kollidieren.
    - Favoriten löschen.
    - Laden, Erkennung, Suche, Favoriten und Zähler übergehen markierte Medien.
    - Die Einträge in Stücken löschen (z. B. 10 000 Zeilen je Transaktion), zuletzt die `storages`-Zeile. Wartungsschuld wie bisher buchen (`bug.0.4.108`).
    - Beim Start laufen offene Löschungen weiter.
    - Wenn das Schema sich ändert: Migration nur erweiternd (AGENTS.md: ab 0.4 auf fremden Rechnern nie löschen).
  - **Gegenprobe (Tests, Regel 10):**
    1. Ein Medium mit vielen Einträgen (z. B. 200 000 künstlich) vergessen. Gleich danach den Speicher schließen, ohne zu warten, und neu öffnen. Das Medium ist nicht mehr da, auch nicht in Suche und Favoriten.
    2. Dasselbe mit „Alle vergessen“ und drei Medien, das große zuerst: Nach dem Neuöffnen ist keines mehr da.
    3. Eine offene Löschung läuft nach dem Neuöffnen zu Ende, und `items` des Mediums ist leer.
    4. Ein vergessenes Medium wird mit derselben UUID wieder eingesteckt, während seine Löschung noch läuft. Es erscheint als neu (`undecided`), und der Erkennungsdialog wird angefordert.
    5. Ein kleines Medium vergessen verhält sich wie bisher; die bestehenden Tests zu `bug.0.4.108` und `135` bleiben grün.
  - **Patches (rot erwartet):**
    1. `bug.0.4.224-a.patch`: die Markierung erst nach dem Löschen der Einträge. Test 1 oder 2 wird rot.
    2. `bug.0.4.224-b.patch`: keine Fortsetzung beim Start. Test 3 wird rot.
    3. `bug.0.4.224-c.patch`: markierte Medien nicht übergehen. Test 1 oder 4 wird rot.
  - **Beleg in der echten App (nur, wenn es ohne Gefahr geht):** Nicht an den Daten des Nutzers. Den Nachtest macht der Nutzer.
  - **So lassen:** Bestätigung mit zwei Klicks, Mitteilung, das Verhalten im Speicher von `forgetAllMedia` und `forgetMedium`, der Lebenszyklus der Läufe (`konzept/lauf-lebenszyklus.md`).
  - **Status:** Bereit zur Prüfung. Messung (Kopie in `$TMPDIR`, Debug -O): alt `deleteMedium` „Daten“ 1 602 092 Zeilen **25,1 s** in einer Transaktion; neu Markierung aller 7 Medien 0,07 s, dann 173 Stücke (längstes 0,18 s), gesamt 23,1 s, Rest 0.
    Fix: `deleteMedia(uuids:)` (`IndexStoreV3`) markiert in einer kurzen Transaktion (`storage_meta` `pendingDeletion`, neue Zufalls-UUID, Favoriten weg), dann `purgePendingDeletions` 10 000 Zeilen je Transaktion von oben, zuletzt `storages` + Wartungsschuld; `fetchAll`, Suche „alle Medien“, Inventar- und Sperrzähler übergehen markierte; `forgetAllMedia` markiert alle auf einmal; Start setzt fort (`MediumRecognitionStartup`). Schema unverändert (neuer Schlüssel).
    Tests 1–4: `ForgetDurableTests` (3) und `MediumCoordinatorTests/forgottenVolumeReturnsAsNewWhileItsEntriesAreStillDeleted`, rot mit altem Löschweg 08:14–08:15 (11 Fehler), grün 08:13; Test 5: `DatabaseMaintenanceTests`, `StoreWriteTests`, `SurfaceStoreTests`, `ColumnBrowserNormalizeTests` u. a. grün (148/148, 08:21–08:22); Rauchtest-Zeile. Patches 224-a/b/c rot (5/5). 20× parallel grün 08:55. Selbstprüfung: nichts Wesentliches.
    Läufe 08:23–08:54: Debug/Release 0 Warnungen, seriell 1210/1210, 3× parallel grün, keine .ips; App 08:54:12, neueste .swift 08:15:13.

## Status

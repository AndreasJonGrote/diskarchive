# Paket 37 — Zielversion 0.4.0 (freigegeben 27.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest des Nutzers nach den Paketen 34–36 (27.10., Checkliste [todo/abnahmerunde-0.4.0.md](abnahmerunde-0.4.0.md) Abschnitt 4). Alle übrigen Punkte des Nachtests sind bestanden.

**Für jede Aufgabe gilt:**
- **Zuerst in der echten App nachstellen** (Regel 14), dann der Test. Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.221`, dann `bug.0.4.222`. **HALT.**

## Funde aus dem Nachtest (Nutzer 27.10., Host hat Protokoll und Code gelesen)

- **bug.0.4.221 — Dialog hält den Fokus fest (Regression von `bug.0.4.209`).**
  - **Nutzer sieht:** Er schreibt in einer anderen App und steckt ein Medium ein. Der Erkennungsdialog erscheint und nimmt den Fokus. Danach bekommt die andere App den Fokus **gar nicht mehr** zurück, auch nicht durch einen Klick in ihr Fenster. Wörtlich: „der Fokus ist jetzt noch aggressiver und lässt Apps nun gar nicht mehr in den Fokus. Das Modal soll im Hintergrund gehen, wenn man es aus dem Fokus nimmt, und ruhig sein!“ **Wann:** bei jedem neuen Medium, während der Nutzer in einer anderen App arbeitet. **Stufe 1.**
  - **Soll (Konzept `konzept/medien.md` Punkt 3, unverändert):**
    - Der Dialog kommt beim Erscheinen einmal nach vorn.
    - Ein Klick in ein Fenster einer anderen App gibt dieser App den Fokus **sofort und vollständig zurück**: Tastatureingaben gehen an sie, ihr Fenster liegt über dem Dialog.
    - Danach bleibt der Dialog ruhig dahinter, bis der Nutzer ihn selbst wieder vorholt (Menüleiste, Zeile „Entscheidung offen“, Klick auf den Dialog).
    - Gilt für alle Panels mit `bringForward`: Erkennungsdialog, „Ersetzt dieses Medium?“, Absturzbericht, „Ignorieren bestätigen“.
  - **Vermutete Ursache (Host, nicht belegt):** `AppWindowPresenter.bringForward` (Z. ~350–358) ruft auf einem Panel mit `.nonactivatingPanel` `orderFrontRegardless()` und `makeKey()` auf, während eine andere App aktiv ist. Das Panel wird Key-Fenster, ohne dass Disk Archive aktive App wird. Ein Klick in die andere App löst darum keinen App-Wechsel aus, und der Fokus bleibt am Panel hängen. Seit `bug.0.4.209` liegt das Panel auf `.normal` statt `.floating`; das hat das Verhalten verändert. Dazu kommt `KeyablePanel.sendEvent` (`MenuBar/KeyablePanel.swift`), das bei jedem Klick `makeKey()` ruft.
  - **Weg:** Die Ursache selbst in der echten App klären. Dafür TextEdit öffnen, tippen, einen Stick einstecken, in TextEdit klicken und weiter tippen. Ob der Fix über eine echte Aktivierung der App läuft, über kein `makeKey` bei fremder aktiver App oder anders, entscheidest du. Bedingung: Das Soll oben gilt in der echten App. Was im Status steht, belegst du dort (Regel 14).
  - **Nicht anfassen:** das Popover der Menüleiste (`MenuBarController`, ebenfalls `KeyablePanel`); es soll weiter wie heute funktionieren.
  - **Tests:** Ein Test, der zeigt: Nachdem eine andere App bzw. ein anderes Fenster aktiv wurde, ist der Dialog nicht mehr Key und fordert Key auch nicht wieder an. Gibt es dafür keinen ehrlichen automatischen Test, schreib „Frage:“ und HALT, statt einen Test zu bauen, der nur den Aufruf zählt.
  - **Patch (rot erwartet):** `bug.0.4.221-a.patch` stellt das heutige Verhalten wieder her. Dein Test wird rot.

- **bug.0.4.222 — Fortschritt nach Abziehen und Wiedereinstecken um 1 % versetzt (Rest von `bug.0.4.210`).**
  - **Nutzer sieht:** Er zieht einen Stick mitten im Lauf ab und steckt ihn wieder ein. Die Prozentzahl liegt danach 1 % neben dem Wert vor dem Abziehen. Wörtlich: „hier 1 % versetzt, das müssten wir lösen können.“ **Wann:** bei jedem Abziehen mitten im Lauf. **Stufe 1** (falsche Anzeige, Konzept `konzept/indizieren.md`: „denselben Prozentwert“ online, offline und nach dem Fortsetzen).
  - **Protokoll des Nutzers (27.10.):** Medium `8E5F9F0E…`, Lauf ab 13:49:40. Abgezogen um 13:57:44 mitten in einem Schreibvorgang: `store error applyDirectories domain=Swift.CancellationError`, `index info abgebrochen`. Wiedereingesteckt um 13:57:59: `index info start … tiefe=3 start=4`. Fertig um 14:48:28.
  - **Vermutete Ursache (Host, nicht belegt):**
    - Online zählt `DirectoryIndexer` (Z. ~333–339) nach jedem Stück die geschriebenen Einträge hoch.
    - Offline und beim Fortsetzen gilt `fileCount + folderCount` des Mediums (`MediumCoordinator` Z. ~762, `IndexingService` Z. ~325, `DirectoryIndexer` Z. ~155).
    - Vermutung: Diese beiden Werte werden nicht gleich fortgeschrieben, zum Beispiel erst am Ende einer Ebene, oder das abgebrochene Stück zählt nur auf einer Seite.
  - **Soll:** Für dasselbe Medium zeigen alle drei Zeitpunkte denselben ganzen Prozentwert, aus einer Rechnung: zuletzt online vor dem Abziehen, offline, Beginn nach dem Wiedereinstecken.
    - Erlaubt ist nur ein Wert, der danach weiter steigt.
    - Ein Sprung nach oben oder unten ist es nicht.
  - **Nicht anfassen:** den Lebenszyklus von `IndexingService` (wie in Paket 34). Geändert werden darf nur, was als gespeichert zählt und was als Fortschritt weitergegeben wird. Muss am Ablauf etwas anders werden: „Frage:“ und HALT.
  - **Tests:**
    - Über die echte Kette, mit einem Medium im Speicher, groß genug für mehrere Stücke in einer Ebene.
    - Abbruch mitten in einer Ebene, auch während eines Schreibvorgangs.
    - Prüfen: letzter angezeigter Wert vor dem Abbruch = Wert offline = erster Wert nach dem Fortsetzen.
    - Kein `sleep`, positives Signal zuerst.
  - **Patch (rot erwartet):** `bug.0.4.222-a.patch` stellt die heutige Zählung wieder her. Der Test wird rot.

## Status

- **bug.0.4.221:** **Frage:** nichts geändert, HALT für diese Aufgabe. (1) Nachstellen in der echten App geht für mich nicht: kein Stick, Disk-Images zählen nicht als Medium (`VolumeCandidateRule`), Klicken/Tippen in eine andere App braucht Eingabe-Berechtigung (`CGPreflightPostEventAccess` = false).
  Ersatzbeleg 15:03–15:05 mit zwei Hilfsprogrammen in `$TMPDIR` (Panel wie `makeNewMediumPanel`: `.nonactivatingPanel`, `.normal`, `orderFrontRegardless` + `makeKey`): das Panel wird Key, die andere App bleibt aktiv und vorn; sie erneut zu aktivieren gibt ihr den Fokus **nicht** zurück (Panel bleibt Key). Mit `NSApp.activate(ignoringOtherApps: true)` vor `makeKey`: Aktivieren der anderen App gibt ihr sofort Key, das Panel gibt Key ab. Vermutung des Hosts damit gestützt.
  (2) Ein ehrlicher automatischer Test müsste eine andere App aktivieren (`NSApp.activate` im Test verboten, Regel 10); im Testprozess bliebe nur das Zählen von Aufrufen.
  Vorschlag: `bringForward` aktiviert die App (nur `.centered`); Dialog-Panels ohne `.nonactivatingPanel`, damit auch ein späterer Klick auf den Dialog die App aktiviert (`KeyablePanel.sendEvent` macht sonst wieder Key ohne Aktivierung). Popover unverändert. Möglich (nicht geprüft): ein offenes Hauptfenster kommt mit nach vorn. Beleg dann durch den Nutzer (TextEdit + Stick) statt Test – einverstanden?
- **bug.0.4.222:** Bereit zur Prüfung. Ursache: Zähler des Mediums während des Laufs fast nie gespeichert (Drossel in `commitPendingMetaIfNeeded` gegen das laufkonstante `seenAt`, nur Stapel mit `finalize` alle 5000 Einträge); beim Abziehen trifft das Nachschreiben den Abbruch (`CancellationError`, wie im Protokoll 13:57:44) → gespeichert bis zu einem Stapel weniger als online gezählt. Dazu zwei 250-ms-Drosseln (Indexer, `IndexingService.publish`), die die letzte Meldung verschlucken konnten. Fix: `applyDirectories` schreibt den Zähler im selben Schreibvorgang wie die Einträge; beide Drosseln lassen eine Meldung mit neuem ganzem Prozentwert immer durch. Lebenszyklus unverändert.
  Nachstellen in der echten App nicht möglich (kein Stick zum Abziehen), Beleg über das Protokoll des Nutzers und den Kettentest. Test `IndexProgressRuleTests/unplugMidLayerKeepsThePercent()` (Kette, Medium im Speicher, je zwei Stücke in `a` und `b`, Abziehen hält `b` an, das nächste Schreiben trifft den Abbruch): rot vor dem Fix 15:10 (online 0 %, Drossel) und 15:11 (online 42, offline 0, nach Wiedereinstecken 0), grün 15:11/15:32. Angepasst: `StoreWriteTests/metaCommitBatchesRapidChunksUntilFlush` → `metaCommitCountsEveryChunkAtOnce` (prüfte genau das alte Aufschieben).
  Sabotage a (Zähler getrennt), b (Drossel Indexer), c (Drossel `publish`) je 3× rot 15:32–15:34. Erst 6/20 rot unter Last (zweite Drossel), danach 20× parallel grün 15:35–15:37 (1720 Zeilen, 0 rot). Ganzes Testziel parallel 15:38–15:43: 1262 grün, 1 rot `LayoutCopyTests/windowLinesFromTheLayoutAreInLayoutCopy()` (Datei `layout/Disk Index App.dc.html` fehlt seit der Umsortierung in `layout/bis 0.4.1`/`ab 0.4.2`, außerhalb des Diffs). Debug clean und Release 0 Warnungen, keine `.ips`, App des Nutzers 15:45:21 (0.4.0, Signatur ok, `find -newer` leer).
  Selbstprüfung (Sonnet, zweimal): nichts Wesentliches; Stufe 3: Vergleich in `publish` gegen `ratio` statt Maximum lässt selten eine Meldung mehr durch. Gesamtlauf weggelassen (Last 5–12).

## Abnahme Host 27.10. (Gesamtlauf 15:59–16:30)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell 1196/1197, parallel 1–3 je 1 rot (1190 bestanden, 6 übersprungen). Der rote Test ist jedes Mal `LayoutCopyTests/windowLinesFromTheLayoutAreInLayoutCopy()`: Die Datei `layout/Disk Index App.dc.html` fehlt, weil der Nutzer `layout/` in `bis 0.4.1/` und `ab 0.4.2/` umsortiert hat (Commit 59ae5bc). Das liegt außerhalb des Diffs; der Pfad wird in Paket 38 angepasst (`todo.0.4.049`).
- Sabotage **3/3 rot ✓** (222-a 2 von 2, -b und -c je 1 von 1).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- App des Nutzers 16:30:25, Signatur gültig, Version 0.4.0.

Den Diff hat der Host gelesen:
- **222:** `applyDirectories` schreibt den Zähler des Mediums (`commitMediumMeta`) im selben Schreibvorgang wie die Einträge. Bei einem Abbruch fallen beide zusammen weg, sonst bleiben beide. Vorher wurde der Zähler gedrosselt nachgeschrieben, und beim Abziehen traf dieses Nachschreiben den Abbruch (Protokoll des Nutzers 13:57:44, `CancellationError`).
- Beide 250-ms-Drosseln (Indexer, `publish`) lassen eine Meldung mit neuem ganzem Prozentwert immer durch.
- Der Lebenszyklus von `IndexingService` ist unverändert.

Prüf-Agent (Sonnet, Vorlage 2b): nichts Wesentliches, kein Befund der Stufe 1 oder 2. Es wird nichts doppelt gezählt: `pendingMetaDelta` bekommt nur noch Nullen über `flushMediumMeta`. Der Test prüft ehrlich „online = offline = nach dem Wiedereinstecken“.

- **Abgenommen:** `bug.0.4.222`.
- **Nicht erledigt:** `bug.0.4.221`. Der Worker hat eine Frage gestellt: Nachstellen in der echten App ging nicht, ein ehrlicher Test auch nicht. Sein Ersatzbeleg mit Hilfsprogrammen stützt die Ursache. Der Host nimmt den Vorschlag an (echte Aktivierung, kein `.nonactivatingPanel` bei Dialogen) und gibt Bedingungen vor → Paket 38, zusammen mit `bug.0.4.223`.
- **Stufe 3 (keine Aufgabe):** `publish` vergleicht gegen `ratio` statt gegen das Maximum. Dadurch geht selten eine Meldung mehr durch.

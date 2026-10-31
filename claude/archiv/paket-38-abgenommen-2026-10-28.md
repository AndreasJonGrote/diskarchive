# Paket 38 — Zielversion 0.4.0 (freigegeben 27.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest des Nutzers 27.10. ([todo/abnahmerunde-0.4.0.md](abnahmerunde-0.4.0.md) Abschnitt 4) und die Frage zu `bug.0.4.221` aus Paket 37 ([archiv/paket-37-abgenommen-2026-10-27.md](paket-37-abgenommen-2026-10-27.md)).

## Abnahme Host 28.10. (Gesamtlauf 01:05–01:35)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell 1205/1205, parallel 1–3 grün (je 1199 bestanden, 6 übersprungen).
- Sabotage **5/5 rot ✓** (221-a bis -e).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- App des Nutzers 01:35:53, Signatur gültig, Version 0.4.0.

Den Diff hat der Host gelesen. Einen Prüf-Agenten gab es nicht, weil der Diff nach zwei Korrekturen klein ist.
- **049:** In `LayoutCopyTests` ist nur der Pfad geändert (`layout/bis 0.4.1/`).
- **221:**
  - Die vier Dialoge sind `DialogPanel` (Key und Main), ohne `.nonactivatingPanel`.
  - `bringForward` holt bei `.centered` mit `NSApp.activate(ignoringOtherApps: true)` nach vorn. Das gibt keine Warnung, weil die Methode nur „to be deprecated“ ist.
  - Die Menüleiste gleicht nur noch ab (`newMediumStateChanged`), und das Popover bleibt `KeyablePanel`.
  - Der Merker „weggeklickt“ fällt bei jedem Anschließen, auch für eine wartende ID.
- **Hilfsprogramm des Workers, 28.10. 00:00:**
  - (a) Der Dialog nimmt einmal den Fokus.
  - (b) Ein Klick in die andere App legt ihn ruhig dahinter.
  - (c) Der neueste liegt vorn.
  - (d) Das Hauptfenster bleibt hinten.
- **223:** Im Versuch nicht nachstellbar, darum kein Fix. Der Nutzer prüft es im Nachtest. Zeigt sich die Vertauschung dort wieder, ist es eine Regression von 223.
- **Test:** `progressCountsFoldersWhenTheyAreDiscovered` erwartet `<= 0.99`.
- **Stufe 3, Backlog:** Die drei Reihenfolge-Tests waren beim Worker einmal parallel rot (28.10. 00:14). Das ließ sich nicht nachstellen; der Host-Lauf war grün.

Patches: `archiv/sabotage/paket-38/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `todo.0.4.049` (klein, zuerst, damit der Gesamtlauf grün sein kann), dann `bug.0.4.221` + `bug.0.4.223` (eine Aufgabe, gleiche Stelle). **HALT.**

## Aufgaben

- **todo.0.4.049 — `LayoutCopyTests` nach der Umsortierung von `layout/`.**
  - Der Nutzer hat `layout/` in `layout/bis 0.4.1/` und `layout/ab 0.4.2/` geteilt.
  - `LayoutCopyTests/windowLinesFromTheLayoutAreInLayoutCopy()` liest noch `layout/Disk Index App.dc.html`. Die Datei liegt jetzt unter `layout/bis 0.4.1/Disk Index App.dc.html`, denn für 0.4.0 gilt das alte Layout.
  - Nur den Pfad ändern. Den Inhalt der Layout-Dateien nicht anfassen.
  - Kein Sabotage-Patch nötig. Im Status reicht: Test vorher rot, danach grün.

- **bug.0.4.221 + bug.0.4.223 — Dialoge: Fokus zurückgeben, neuester vorn (eine Aufgabe).**
  - **bug.0.4.221, Antwort des Hosts auf deine Frage aus Paket 37:** Dein Vorschlag ist angenommen.
    - **Nutzer sieht:** Nach dem Einstecken bekommt die andere App den Fokus nicht mehr zurück. **Stufe 1.**
    - Dein Ersatzbeleg mit den Hilfsprogrammen (15:03–15:05) stützt die Ursache.
    - **Fix:** `bringForward` aktiviert die App, nur bei `.centered`. Die Dialog-Panels (Erkennung, „Ersetzt dieses Medium?“, Absturzbericht, „Ignorieren bestätigen“) bekommen kein `.nonactivatingPanel` mehr. Dann aktiviert auch ein späterer Klick auf den Dialog die App, statt nur `makeKey` aufzurufen.
    - **Bedingung 1, nur der Dialog kommt nach vorn:** Das Hauptfenster bleibt, wo es ist. Lag es hinter der anderen App, bleibt es dort.
      - Nimm darum keine Aktivierung, die alle Fenster nach vorn holt.
      - Geeignet ist z. B. `NSRunningApplication.current.activate(options: [])` ohne `.activateAllWindows`, nach `orderFrontRegardless` + `makeKey` des Panels.
      - Belege das mit deinem Hilfsprogramm: Hauptfenster offen und hinter einem fremden Fenster, Dialog erscheint, das Hauptfenster bleibt dahinter.
    - **Bedingung 2:** 0 Warnungen (keine veraltete API ohne Ersatz).
    - **Bedingung 3:** Das Popover der Menüleiste (`MenuBarController`) bleibt unverändert, ebenso `KeyablePanel` für das Popover.
    - **Beleg:**
      - Dein Hilfsprogramm zeigt: Nach dem Aktivieren einer anderen App hat diese sofort Key, das Panel nicht mehr.
      - Der Nutzer prüft danach in der echten App (TextEdit + Stick).
      - Ein automatischer Test, der eine andere App aktiviert, ist nicht verlangt (Regel 10).
      - Als Test genügt ein Strukturtest: Die vier Dialog-Panels haben kein `.nonactivatingPanel`, und `bringForward` ruft bei `.centered` die Aktivierung über einen Testhaken, bei `.offscreen` nie.
  - **bug.0.4.223 — Reihenfolge beim Anschließen mehrerer Medien (Nutzer 27.10.):**
    - **Nutzer sieht:** Er schließt mehrere Platten gleichzeitig an. Der erste Dialog liegt vorn, die späteren dahinter. Der neueste ist also verdeckt. **Wann:** wenn mehrere Medien kurz nacheinander oder gleichzeitig kommen. **Stufe 1, Regression von `bug.0.4.216`.**
    - **Soll** (Layout 02, `todo.0.4.048`):
      - Der älteste Dialog liegt hinten links oben.
      - Die Kaskade läuft nach rechts unten.
      - Der neueste liegt immer vorn.
    - **Was schon stimmt:** Die Lage (`newMediumPanelFrame`) ist richtig, falsch ist nur die Reihenfolge von vorn nach hinten.
    - **Ursache selbst finden.** Ansatzpunkte:
      - Reihenfolge von `pendingNewMediumDecisionIDs` (ältester zuerst?).
      - `syncNewMediumPanels` (Z. ~185–200): `orderFrontRegardless` nur für neu erschienene Panels, mehrere in einem oder mehreren Abgleichen.
      - Ein Key-Panel, das vor einem später nur nach vorn geholten Panel bleibt.
      - Mit dem Fix von 221 ändert sich die Aktivierung; die Reihenfolge muss danach stimmen.
    - **Tests** (Lage `.offscreen` erlaubt, Reihenfolge über `orderedIndex` oder `NSApp.orderedWindows`):
      1. Zwei Medien im selben Abgleich.
      2. Zwei Medien in zwei Abgleichen kurz nacheinander.
      3. Drei Medien, danach wird der mittlere entschieden: Die übrigen behalten „neuester vorn“.
    - Jeweils: Der neueste liegt vorn, der älteste hinten.
  - **Patches (rot erwartet):**
    1. `bug.0.4.221-a.patch`: `.nonactivatingPanel` beim Erkennungs-Panel zurück. Der Strukturtest wird rot.
    2. `bug.0.4.221-b.patch`: keine Aktivierung in `bringForward`. Der Haken-Test wird rot.
    3. `bug.0.4.223-a.patch`: das heutige Verhalten der Reihenfolge. Test 1 oder 2 wird rot.

## Korrektur Host 27.10. (nach Prüfung; noch nicht abgenommen)

Angenommen ist der Weg: Aktivierung, kein `.nonactivatingPanel`, die Menüleiste gleicht nur noch ab. Auch der Fund in `appStateDidChange` ist richtig. Die Ursache stimmt mit „noch aggressiver“ überein. Offen sind drei Punkte, **in dieser Reihenfolge**:

1. **Regression aus diesem Fix, Stufe 1.**
   - **Nutzer sieht:** Er schließt den Erkennungsdialog ohne Antwort (X oder Esc), wirft das Medium aus und steckt es in derselben Sitzung wieder ein. Es erscheint **kein** Dialog; nur die Menüleiste zeigt „Entscheidung offen“. Konzept `medien.md` Punkt 3: Jedes Anschließen zählt, ohne Haken erscheint der Dialog wieder.
   - **Wann:** Dialog wegklicken, später dasselbe Medium wieder einstecken. Normaler Gebrauch.
   - **Ursache:**
     - `enqueueNewMediumDecision` (`AppState+Media.swift` Z. ~161–165) kehrt zurück, wenn die ID schon in der Warteschlange steht. `dismissedNewMediumPanelIDs.remove` wird dann nicht erreicht.
     - Beim Aushängen wird der Merker nicht geleert.
     - Bisher hat das `revealDismissed: true` aus `appStateDidChange` den Fall zufällig verdeckt.
   - **Fix:** Bei jedem Anschließen, das den Dialog anfordert, ist der Merker für dieses Medium weg. Wo genau, entscheidest du: beim Aushängen oder in `enqueueNewMediumDecision` auch für eine schon wartende ID.
   - **Test:** Dialog schließen ohne Antwort → aushängen → wieder einhängen → das Panel ist da. Dazu ein Patch, der den Test rot macht.
2. **Bedingung 1 belegen: nur der Dialog kommt nach vorn.**
   - Laut Apple holt `activate(options: [])` das **Main- und das Key-Fenster** nach vorn.
   - `KeyablePanel` hat `canBecomeMain == false`. Das Main-Fenster bleibt also das Hauptfenster und kommt wahrscheinlich mit.
   - **Versuch mit deinem Hilfsprogramm**, sobald der Bildschirm offen ist (der Nutzer lässt ihn offen): Hauptfenster offen und hinter einem fremden Fenster, Dialog erscheint.
   - Kommt das Hauptfenster mit nach vorn: Die Dialog-Panels dürfen Main werden (eigene Unterklasse oder Eigenschaft, **nicht** für das Popover). Danach den Versuch wiederholen.
   - Im Status steht das Ergebnis des Versuchs vorher und nachher.
3. **`bug.0.4.223` im selben Versuch.**
   - Zwei oder drei Panels kurz nacheinander auf dem Bildschirm, während eine andere App aktiv ist.
   - Festhalten: Welches liegt vorn? Was ändert die Aktivierung?
   - Tritt die Vertauschung mit dem jetzigen Code nicht mehr auf, schreib das so in den Status. Kein Fix nötig, der Nutzer prüft es im Nachtest.
   - Tritt sie auf: Ursache, Fix, Patch `bug.0.4.223-a.patch`.

4. **Wackliger Test nach Paket 37 (Gesamtlauf Host 18:22–18:51, Parallel 3 rot).**
   - `DirectoryIndexerTests/progressCountsFoldersWhenTheyAreDiscovered()` erwartet: alle Werte außer dem letzten `< 0.99`.
   - Seit `bug.0.4.222` geht jeder neue ganze Prozentwert durch. Bei einem langsamen Lauf kommen darum zwei Meldungen mit 0,99 vor dem Ende, und `dropLast` entfernt nur eine.
   - 99 % bis zum Ende ist laut Konzept richtig (`konzept/indizieren.md`: höchstens 99 % bis zum Ende).
   - **Fix:** die Erwartung auf `<= 0.99` ändern. Nur den Test anfassen, keinen Code.
   - Kein Patch nötig.

`todo.0.4.049` ist geprüft und in Ordnung (Abnahme mit dem Paket). Gesamtlauf Host 18:22–18:51: 0 Warnungen, seriell 1203/1203, Parallel 1–2 grün, Parallel 3 nur Punkt 4 rot, Sabotage 221-a/b/c 3/3 rot ✓.

## Korrektur 2 Host 27.10. (nach deinem Versuch; noch nicht abgenommen)

Punkte 1 und 4 der ersten Korrektur sind gelesen und in Ordnung, auch Patch 221-d. Der Gesamtlauf des Hosts von 21:57 bis 22:28 war grün:
- 0 Warnungen
- seriell 1204/1204, alle drei Parallelläufe grün
- Sabotage 221-a bis d: 4 von 4 rot ✓ Der Fehler liegt in meinem Briefing: `activate(options: [])` ist seit macOS 14 kooperativ und gibt dem Dialog keinen Fokus, solange eine andere App aktiv ist. Das widerspricht dem Konzept (`medien.md` 3).

**Der Nutzer hat am 27.10. bestätigt, so soll es sein:**
1. Ein neues Medium kommt an. Der Dialog kommt nach vorn und **nimmt einmal den Fokus**, auch wenn gerade eine andere App aktiv ist. Tippen, Esc und Return gehen dann in den Dialog.
2. Klickt der Nutzer in eine andere App, bekommt sie sofort den Fokus. Der Dialog geht dahinter und bleibt dort ruhig, ohne den Fokus wieder anzufordern.
3. Ein zweites Medium kommt an: ein neuer Dialog, wieder einmal Fokus, nach rechts unten versetzt, **über** dem älteren.
4. Das Hauptfenster bleibt, wo es ist (Bedingung 1).

**Weg:**
- In `bringForward` bei `.centered`: `NSApp.activate(ignoringOtherApps: true)` statt `NSRunningApplication.current.activate(options: [])`.
- Das gibt **keine Warnung**. Die Methode ist nur als „to be deprecated“ markiert, und das Projekt nutzt sie schon warnungsfrei in `AppWindowPresenter.swift` Z. 77 (Hauptfenster). Bedingung 2 ist also erfüllt. Prüf das im Build.
- Laut deinem Versuch holt die erzwungene Aktivierung das Hauptfenster mit nach vorn, mit `canBecomeMain` am Panel aber nicht. Darum dürfen die vier Dialog-Panels Main werden (eigene Unterklasse oder Eigenschaft). Das Popover und sein `KeyablePanel` bleiben unverändert (Bedingung 3).
- Was sonst angenommen ist, bleibt: kein `.nonactivatingPanel`, die Menüleiste gleicht nur ab, `revealDismissed` nur beim Klick des Nutzers, Punkt 1 der ersten Korrektur.

**Beleg mit dem Hilfsprogramm, Bildschirm offen.** Die Varianten wie in deinem Versuch, diesmal mit dem neuen Weg:
- (a) Die andere App ist aktiv, der Dialog erscheint. Danach hat das Panel Key, und die App ist aktiv.
- (b) Danach wird die andere App aktiviert oder angeklickt. Sie hat sofort Key, das Panel liegt dahinter, und es kommt keine weitere Aktivierung.
- (c) Zwei Dialoge kurz nacheinander. Der neuere liegt vorn und hat Key.
- (d) Das Hauptfenster lag hinter der fremden App und bleibt dort.

Das Ergebnis jeder Variante gehört in den Status.

**Tests und Patches:**
- Den Strukturtest und den Haken-Test an den neuen Weg anpassen: Bei `.centered` wird aktiviert, bei `.offscreen` nie.
- Ein Strukturtest prüft: Die Dialog-Panels können Main werden, das Popover-Panel nicht.
- `bug.0.4.221-b` bei Bedarf neu schneiden.
- Neuer Patch `bug.0.4.221-e.patch`: `canBecomeMain` der Dialog-Panels wieder `false`. Der Strukturtest wird rot.
- `bug.0.4.223`: kein Fix verlangt. Gilt (c) nicht, Ursache und Fix wie in der ersten Korrektur, Punkt 3.

## Status

- **todo.0.4.049:** Bereit zur Prüfung. `LayoutCopyTests` liest `layout/bis 0.4.1/Disk Index App.dc.html` (nur der Pfad). `windowLinesFromTheLayoutAreInLayoutCopy()` rot 17:05, grün 17:08.
- **bug.0.4.221 + bug.0.4.223:** Bereit zur Prüfung (Korrektur 2). `bringForward(.centered)`: `NSApp.activate(ignoringOtherApps: true)`; die vier Dialog-Panels sind `DialogPanel` (neu, `App/DialogPanel.swift`: Key und Main, `sendEvent` wie `KeyablePanel`); Popover/`KeyablePanel` unverändert; Build 0 Warnungen. Test `dialogPanelsCanBecomeMainThePopoverCannot` rot 23:58, grün 23:59; `MediumRecognitionTests` filtert `is DialogPanel`. Patches 221-a/b neu geschnitten, 221-e neu; a–d je rot, e 3× rot (00:03–00:04). Korrektur 1 (Punkte 1, 4) unverändert. Selbstprüfung: nichts Wesentliches.
  **Versuch Hilfsprogramm (00:00–00:01, Bildschirm offen, neuer Weg):** (a) fremde App aktiv → Dialog erscheint: App aktiv, Panel Key und Main ✓. (b) danach fremde App aktiviert: sie ist aktiv, Panel ohne Key, `Fremd > Panel1`; 3 s später keine weitere Aktivierung ✓. (c) zwei Dialoge in einem oder zwei Abgleichen (0,3 s): `Panel2 > Panel1`, Panel2 Key ✓; erster Dialog, dann fremde App, dann zweiter: `Panel2 > Fremd > Panel1`, Panel2 Key ✓; drei, mittlerer entschieden: `Panel3 > Panel1` ✓. (d) Hauptfenster bleibt in allen Fällen hinter der fremden App ✓. 223 tritt nicht auf → kein Fix, kein Patch 223-a.
  Läufe: Debug clean und Release 0 Warnungen; seriell 1205/1205 (00:05–00:14); parallel 2, 3, 4, 5 grün (00:20–00:46); **parallel 1 (00:14–00:20) rot:** die drei Reihenfolge-Tests (`newestInFront…`, `newestStays…`) gleichzeitig, Meldung verloren (Ergebnis überschrieben). Nicht nachstellbar (Suite 20× parallel grün, 2 weitere Gesamtläufe grün); Ursache offen, vermutlich `NSWindow.windowNumbers` kurzzeitig ohne die Panels (Fensterserver). Keine `.ips`; App 00:47:23, jüngste `.swift` 23:58:51, `find -newer` leer.

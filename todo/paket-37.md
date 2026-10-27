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

- **bug.0.4.221:** 
- **bug.0.4.222:** 

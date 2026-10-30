# Paket 49 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 30.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („Alles“) aus dem Backlog (Supervisor 27.10., Stufe 2); `bug.0.4.236` aus der Messung des Nutzers 30.10. (Screenshot Einstiegskachel). Konzept: `konzept/indizieren.md` (nicht lesbarer Ordner: wiederholen, sonst „nicht lesbar“, Index unvollständig), Invariante 1 (alter Inhalt bleibt).

## Abnahme Host 30.10. (Gesamtlauf 09:14–09:46)

- Diff gelesen: `AppState.popoverConnectedMedia` (angeschlossen, `decision == .index`) als eine Quelle für `MenuBarPopoverView` und `MenuBarPopoverLayout.corePanelHeight`, `connectedMedia` unverändert; Leertext `popoverConnectedEmptyText` (neuer Text de/en). `DirectoryIndexer.readFolderWithRetry` wirft „keine Rechte“ (`isPermissionDenied`: POSIX `EACCES`/`EPERM`, `CocoaError.fileReadNoPermission`, auch zugrunde liegend) ohne Wartezeit, gilt im Zähl- und Indizierschritt; `unreadableThisRun` überspringt Nachfahren (Präfix mit „/“, nur dieser Lauf), ihre Zeilen und Favoriten bleiben. Nichts Wesentliches.
- Die vom Worker bei Last 7,5 gemeldeten Zeittests (`StoreSwitchTests/pruningAfterLowerDepth…`, `largeSameSizeFolder…`) sind im Gesamtlauf grün; kein Befund.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1248/1248, parallel 3× grün (je 1242, 6 übersprungen), Sabotage 5/5 rot (235-a, -b, -c, 236-a, -b je 1/1), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 09:46:11, Signatur gültig, Version 0.4.0.
- Konzept: `konzept/indizieren.md` (keine Wiederholung bei „keine Rechte“, Nachfahren im selben Lauf nicht gelesen), `konzept/medien.md` (Liste „Angeschlossen“, schon 30.10.).
- **Nachtest des Nutzers 30.10. (App 09:46): N0–N4 bestanden** (Kachel nur mit „Ja“-Medien, Höhe passt, beide Leertexte, Einstellungen und Dialog unverändert; gesperrter Ordner nur per Test).
- Patches: `archiv/sabotage/paket-49/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `bug.0.4.236`, `bug.0.4.235`. **HALT.**

## Aufgaben

- **bug.0.4.235 — Ein nachträglich gesperrter Ordner macht jeden Lauf langsam (Backlog 27.10.):**
  - **Nutzer sieht:** Wird ein schon indizierter Ordner gesperrt (keine Leserechte), dauert jeder Abgleich des Mediums je **alten Unterordner** rund 14 s länger. Bei 50 Unterordnern über 10 Minuten bei „99 %“.
  - **Wann:** Nur bei Ordnern, die nach dem Indizieren gesperrt wurden (z. B. Rechte geändert, fremdes Benutzerkonto).
  - **Ursache:**
    1. `DirectoryIndexer.readFolderWithRetry` (Z. ~606) wiederholt **jeden** Fehler mit 1 s, 3 s, 10 s (`IndexRunTypes.readRetryDelays`), auch „keine Rechte“, das sich in 14 s nicht ändert.
    2. `parentsFor` (Z. ~831) holt die Ordner der nächsten Ebene **aus der Datenbank**; die alten Unterordner des gesperrten Ordners (Invariante 1: sie bleiben) werden einzeln gelesen, jeder scheitert, jeder wartet wieder 14 s.
  - **Soll:**
    1. **Keine Rechte** (`EACCES`, `EPERM`, `CocoaError.fileReadNoPermission`) wird **nicht wiederholt**; der Ordner gilt sofort als nicht lesbar (wie heute nach dem letzten Versuch: `markFolderUnreadable`, Lücke, Status „Fehler“ mit Grund „Einige Ordner … nicht gelesen“). Andere Fehler (Zeitüberschreitung, E/A) wiederholen wie bisher.
    2. **Nachfahren eines in diesem Lauf nicht lesbaren Ordners** werden in diesem Lauf **nicht gelesen**: Ihre Zeilen bleiben unverändert (nicht entfernt, nicht als verschwunden markiert, Favoriten bleiben), sie zählen nicht zusätzlich als Lesefehler. Gilt im Zähl- und im Indizierschritt.
    3. Rechte wiederhergestellt → nächster Lauf liest alles, Status „Online“, 100 % (wie `bug.0.4.199`).
  - **Gegenprobe (Tests, Regel 10/11, keine festen Zeiten als Beweis):**
    1. **Realistisch:** Temporäres Medium mit `A/{s1..s5}/datei`, indiziert. Danach `A` mit `chmod 000`. Abgleich: Lesezugriffe zählen (Zugriff über `MediumAccess`-Attrappe oder Zähler): `A` **einmal** gelesen, `s1..s5` **nie**; keine Wartezeit aus `readRetryDelays` (Attrappe der Wartezeit zählt 0 Aufrufe). Zeilen von `A`, `s1..s5` und ihren Dateien bleiben, Favorit auf `s3/datei` bleibt, Status Fehler mit Grund. Danach `chmod 755`, Abgleich: Online, 100 %, nichts doppelt.
    2. Zeitüberschreitung/E/A-Fehler wird weiter 3× wiederholt (bestehende Tests zu `bug.0.4.182` u. a. bleiben grün).
    3. Bestehende Tests zu `bug.0.4.199`, `151`, `177`, `182` bleiben grün.
  - **Patches (rot erwartet):** `bug.0.4.235-a.patch`: „keine Rechte“ wieder wiederholen → Test 1 rot. `bug.0.4.235-b.patch`: Nachfahren wieder lesen → Test 1 rot. `bug.0.4.235-c.patch`: Nachfahren als verschwunden markieren → Test 1 rot (Zeilen/Favorit weg).
  - **So lassen:** Wächterzeit 30 s ohne Lebenszeichen, `VanishedMediumGuard` (`bug.0.4.177`), Lebenszyklus der Läufe, Teil-Prüfsummen und Abgleich (Pakete 43–45). Kein neues Schema (vorher fragen).
  - **Status:** Bereit zur Prüfung. Rot 08:12 (`A` 8× gelesen, je Unterordner 4×), grün 08:17.
    Fix: `DirectoryIndexer.readFolderWithRetry` wiederholt „keine Rechte“ nicht (`isPermissionDenied`: POSIX `EACCES`/`EPERM`, `CocoaError.fileReadNoPermission`, auch als zugrunde liegender Fehler; gilt im Zähl- und Indizierschritt); in diesem Lauf nicht lesbare Ordner (`unreadableThisRun`) → Nachfahren werden übersprungen, ihre Zeilen bleiben unangetastet.
    Test: `LockedFolderRunTests` (echte Dateien, `chmod 000`, zählende Hülle um `DirectMediumAccess`): `A` 1× indiziert, `s1…s5` nie, Zeilen und Favorit bleiben, Fehler mit Grund; `chmod 755` → indiziert, 100 %, nichts doppelt.
    Suites: 40 betroffene, 262 Tests, 260 grün (08:23–08:27); rot nur zwei Zeitgrenzen außerhalb des Diffs bei hoher Rechnerlast (GeForce NOW, App des Nutzers, Last 7,5): `largeSameSizeFolderIndexesFastAndKeepsRows` einzeln grün (08:47), `StoreSwitchTests/pruningAfterLowerDepth…` (`pruneToMatch`, 14 s statt < 10 s) auch einzeln rot – Datenbank-Schicht, nicht im Diff. Sabotage 08:48–08:55: a, b, c rot.
    Selbstprüfung: nichts Wesentliches.

- **bug.0.4.236 — Abgelehnte Medien stehen als „Wird indiziert“ in der Einstiegskachel (Nutzer 30.10.):**
  - **Nutzer sieht:** Nach „Nicht indizieren“ stehen „Volume“, „EOS_DIGITAL“, „INTENSO“, „ZOOM_H4E“ unter „Angeschlossen“ mit **„Wird indiziert“**, obwohl nichts indiziert wird (Screenshot 30.10. ~01:00; Datenbank: `decision = 2`, `indexStatus = 0`).
  - **Wann:** Jedes Mal, wenn ein angeschlossenes Medium abgelehnt ist. **Stufe 1** (falscher Text).
  - **Ursache:** `Medium.menuBarSecondaryLine` (`Models/Medium+Dashboard.swift` Z. ~45–50): `.pending` und nicht `undecided` → `LayoutCopy.indexingInProgress`, auch bei `dontIndex`/`ignore`. Die Liste nimmt `AppState.connectedMedia` (`AppState+Media.swift` Z. ~343: alle angeschlossenen, nicht vergessenen).
  - **Soll (Konzept `medien.md`, Absatz „Liste ‚Angeschlossen‘ in der Einstiegskachel“, Nutzer 30.10.):**
    1. Die Liste zeigt **nur** angeschlossene Medien mit `decision == .index`. Unentschiedene und abgelehnte (`dontIndex`, `ignore`) fehlen. **Eine** Quelle für Ansicht **und** Höhenberechnung (`MenuBarPopoverView` Z. ~108 und `MenuBarPopoverLayout` Z. ~130 nutzen heute beide `connectedMedia`; neue Eigenschaft, `connectedMedia` selbst nicht ändern, andere Verwender bleiben).
    2. Leerzustand: Ist keins übrig, aber mindestens ein unentschiedenes oder abgelehntes Medium angeschlossen → neuer Text `copy.hint.popover_none_indexed_connected` de „Kein indiziertes Speichermedium angeschlossen“, en „No indexed storage medium connected“; ohne angeschlossenes Medium wie bisher „Kein Speichermedium angeschlossen“.
    3. Der Zweig „Entscheidung offen“ in der Zeile (`MenuBarConnectedMediumRow.rowPrimaryTap`, `decision == .undecided`) wird dadurch für unentschiedene Medien nicht mehr erreicht; `needsNewMediumDialog` (erneut gefragtes Medium mit Entscheidung Ja) bleibt. Die Zeile „Entscheidung offen“ (Konzept `medien.md` Punkt 3, Abnahmerunde D6) **entfällt** (Nutzer 30.10.).
    4. Badge „Neu erkannt“ am Menüleisten-Symbol, Dialoge und Einstellungen → Speichermedien bleiben unverändert.
  - **Gegenprobe:** Liste mit vier angeschlossenen Medien (Ja indiziert, Ja beim Indizieren, Nein, unentschieden) → nur die zwei mit Ja, Höhe passt zu zwei Zeilen; nur „Nein“ angeschlossen → neuer Leertext; nichts angeschlossen → alter Leertext. Bestehende Tests zur Einstiegskachel (Höhe, Suche, D6-Tests nur dort anpassen, wo sie die Zeile „Entscheidung offen“ verlangen, im Status nennen). `EnglishLocalizationTests` grün (neuer Text in de und en).
  - **Patches (rot erwartet):** `bug.0.4.236-a.patch`: wieder `connectedMedia` in der Ansicht → rot. `bug.0.4.236-b.patch`: Höhe aus `connectedMedia` → rot.
  - **So lassen:** Suchzustand der Einstiegskachel, Pausentimer, Ghost-Knopf „Neu indizieren“, Dashboard und Seitenleiste.
  - **Status:** Bereit zur Prüfung. Rot 08:12 (vier Medien in Liste und Höhe, alter Leertext), grün 08:17/08:42.
    Fix: `AppState.popoverConnectedMedia` (angeschlossen, `decision == .index`) als eine Quelle für `MenuBarPopoverView` und `MenuBarPopoverLayout.corePanelHeight`; `connectedMedia` unverändert. `popoverConnectedEmptyText`: neuer Text `copy.hint.popover_none_indexed_connected` (de/en) bei angeschlossenen, aber keinen mit Ja.
    Test: `PopoverIndexedOnlyTests` (Liste, Höhe zwei Zeilen, gezeichnete Kachel Ja+Nein+offen = Ja allein, beide Leertexte); keine bestehenden D6-Tests angepasst (keiner verlangte die Zeile). Der Zweig „Entscheidung offen“ in `menuBarSecondaryLine`/`rowPrimaryTap` wird nicht mehr erreicht, bleibt im Code.
    Sabotage 08:55–08:59: a, b rot (a erst nach Bildvergleich; die Messung über `fittingSize` sah nichts, weil die Ansicht ihre Höhe aus dem Layout nimmt). Gesamt 5/5 rot, 0 Mängel. EnglishLocalizationTests grün.
    Selbstprüfung: nichts Wesentliches.

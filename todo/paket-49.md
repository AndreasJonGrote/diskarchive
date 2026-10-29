# Paket 49 — Zielversion 0.4.0 (freigegeben 29.10.2026, nach Abnahme von Paket 48)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („Alles“) aus dem Backlog (Supervisor 27.10., Stufe 2). Konzept: `konzept/indizieren.md` (nicht lesbarer Ordner: wiederholen, sonst „nicht lesbar“, Index unvollständig), Invariante 1 (alter Inhalt bleibt).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `bug.0.4.235`. **HALT.**

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
  - **Status:**

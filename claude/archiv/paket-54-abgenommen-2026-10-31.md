# Paket 54 — Zielversion 0.4.2 (freigegeben 31.10., abgenommen 31.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12). Herkunft: Nutzer 31.10. („Download weg, die Seite gibt es nicht“; Update-Knopf öffnet die Startseite). Konzept: `konzept/datenbank.md` (Update-Modal).

**Für jede Aufgabe gilt:**
- Der Test ist vor der Änderung rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Nur die betroffenen Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Gesamtlauf, kein Git.

**Reihenfolge (HALT am Ende):** `todo.0.4.2.004`. **HALT.**

## Aufgaben

- **todo.0.4.2.004 — Update-Fenster: „Zur neuen Version“ öffnet die Startseite (Nutzer 31.10.):**
  - **Heute:** `AppState.openUpdateDownload()` (`AppState+VersionLock.swift` Z. ~44) öffnet `AppLinks.download` = `https://www.diskarchive.app/download/` (Z. ~71). Die Seite gibt es nicht (404) und wird es nicht geben.
  - **Soll:** Der Knopf öffnet die Startseite **`https://diskarchive.app`**. Eine Adresse für die Website: `AboutPanel.website` (`AboutPanel.swift` Z. 12) und der Knopf nutzen denselben Wert (eine Stelle, Regel 7; wohin er wandert, entscheidest du). `AppLinks.download` entfällt. Funktionsname darf bleiben oder sinnvoll umbenannt werden.
  - **Texte bleiben:** Titel „Es ist eine neue Version verfügbar“, Text und Knopf „Zur neuen Version“ unverändert. Haken „Auf Updates hinweisen“ wird wie heute beim Schließen gespeichert.
  - **Gegenprobe:** `UpdateDialogTests` (Z. ~83) erwartet `https://diskarchive.app`; kein Vorkommen von `/download/` mehr im App-Code (`grep -rn "download/" diskindex/diskindex`).
  - **Patch (rot erwartet):** `todo.0.4.2.004-a.patch`: Knopf öffnet wieder `…/download/` → `UpdateDialogTests` rot.
  - **So lassen:** Versions-Check (`VersionCheckClient`), Beta-Sperre, Fehlerbericht-Adresse, Layout des Fensters.
  - **Status:** Adresse an einer Stelle: `AppLinks.website` (+ `websiteURL`) in `AppState+VersionLock.swift`; `AboutPanel` nutzt sie, `AboutPanel.website` und `AppLinks.download` entfallen; Funktion heißt jetzt `openUpdateWebsite()`, Testname `getTheNewVersionOpensTheWebsite`. `grep "download/" diskindex/diskindex`: leer.
    Rot 10:30 (`UpdateDialogTests`, geöffnet `…/download/`), grün 10:37 mit `AboutAndSettingsMenuTests` (7 Tests), 0 Warnungen. Patch `todo.0.4.2.004-a`. Bereit zur Prüfung.

## Abnahme Host 31.10. (Gesamtlauf 12:23–12:58)

- Diff gelesen: nichts Wesentliches.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1277/1277, parallel 3× grün (je 1270, 7 übersprungen), Sabotage 6/6 rot (004-a, 005-a…e), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 12:57:58, Version 0.4.1.
- Patches: `archiv/sabotage/paket-54/`.

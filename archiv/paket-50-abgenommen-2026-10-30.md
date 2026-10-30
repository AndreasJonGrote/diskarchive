# Paket 50 — Zielversion 0.4.1 (freigegeben und abgenommen 30.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Herkunft: Nutzer 30.10. („go“): 0.4.0 ist Release-Kandidat; nächster Schritt laut `todo.0.4.1.002` (Backlog): Version 0.4.1 setzen und das DMG bauen, danach lädt der Nutzer es auf seinem zweiten Mac (macOS 27) herunter.

**Für diese Aufgabe gilt:**
- Reine Versionsänderung, kein Verhalten: **kein Sabotage-Patch** (Regel 9 gilt nur für Verhaltensänderungen).
- Nur die betroffenen Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Gesamtlauf, kein Git.

**Reihenfolge (HALT am Ende):** `todo.0.4.1.004`. **HALT.**

## Abnahme Host 30.10. (Gesamtlauf 11:09–11:38)

- Diff gelesen: `MARKETING_VERSION` 0.4.1 an 4 Stellen, `BundleVersionTests` und `AboutAndSettingsMenuTests` auf 0.4.1; feste Testdaten „0.4.0“ in `UpdateDialogTests`/`AppSettingsPersistenceTests` bleiben (lesen kein Bundle). Nichts Wesentliches.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1248/1248, parallel 3× grün (je 1242, 6 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 11:38:23, Version 0.4.1.
- DMG selbst geprüft (schreibgeschützt eingehängt, ohne Finder): `hdiutil verify` gültig; App 0.4.1, Build 202610301058, Mindest-macOS 15, universal (x86_64, arm64), Launch Agent vorhanden; signiert „Apple Development“ (Team KATFD9R38G) mit Hardened Runtime und `get-task-allow`; `codesign --verify --deep` ok, mit `--strict` Fehler „Finder information … not allowed“ (`com.apple.FinderInfo` am App-Paket, sonst nur `com.apple.provenance`). Ob Gatekeeper das stört, zeigt der Quarantäne-Test (`todo.0.4.1.002`). SHA-256 `11d3b60dee3abaa58b0f185051c297694aae4bd3a5ee2f8737128150dba5e01a`.
- Für den Test hier: Kopie `Disk-Archive-0.4.1-quarantaene.dmg` mit gesetztem `com.apple.quarantine` (wie Safari, Nutzer 30.10.), von Git ignoriert.
- **Quarantäne-Test des Nutzers hier 30.10. 11:44 (macOS 15.7.4): Q0–Q6 bestanden** – Standardmeldung, „Dennoch öffnen“ angeboten, App 0.4.1 (Release) startet aus „Programme“; das FinderInfo-Merkmal stört Gatekeeper nicht. Datenordner: 4 Dateien und `Logs/` mit 4 Dateien (`crash-last.txt` ist der leere 64-KB-Puffer), wie erwartet.

## Aufgaben

- **todo.0.4.1.004 — Version 0.4.1 und Ausgabe-DMG:**
  - **Soll:**
    1. `MARKETING_VERSION` an allen 4 Stellen in `diskindex/diskindex.xcodeproj/project.pbxproj` auf `0.4.1` (wie `todo.0.4.044` für 0.4.0). `CURRENT_PROJECT_VERSION` bleibt 1.
    2. Tests, die die App-Version selbst prüfen, auf `0.4.1`: `BundleVersionTests` (Z. ~13), `AboutAndSettingsMenuTests` (Z. ~27). **So lassen:** feste Beispielwerte in `UpdateDialogTests` und `AppSettingsPersistenceTests` (`currentDisplay: "0.4.0"` als Testdaten), sofern sie nicht die Bundle-Version lesen; im Status nennen, was du geprüft hast.
    3. Suiten `BundleVersionTests`, `AboutAndSettingsMenuTests`, `UpdateDialogTests`, `VersionCheck*` (alle, deren Name so beginnt) und `EnglishLocalizationTests` grün.
    4. Danach `Werkzeuge/dmg-erstellen.sh` ausführen (ohne Änderung am Skript, Werte aus `Werkzeuge/dmg/dmg-einstellungen.json`). Erwartet: `Disk-Archive-0.4.1.dmg` im Hauptverzeichnis, Schlusszeile des Skripts grün.
  - **Status:** Bereit zur Prüfung (Worker 30.10.).
    - `MARKETING_VERSION` 0.4.1 in project.pbxproj Z. 405, 444, 467, 488; `CURRENT_PROJECT_VERSION` überall 1.
    - Tests: `BundleVersionTests` (erwartet 0.4.1, Test umbenannt in `marketingVersionIsZeroFourOne`), `AboutAndSettingsMenuTests` Z. 27. `UpdateDialogTests` Z. 20/24 und `AppSettingsPersistenceTests` Z. 34 sind feste Testdaten (`currentDisplay: "0.4.0"`), lesen kein Bundle (grep `Bundle` leer, auch in `VersionCheck*`) → so gelassen.
    - Rot 10:55 (2 Fehler: Bundle 0.4.0 ≠ 0.4.1); grün 10:57: 7 Suites (Bundle, About, UpdateDialog, VersionCheck, -MainThread, -Calendar, EnglishLocalization), 34 Tests; Build 0 Warnungen.
    - `Werkzeuge/dmg-erstellen.sh` 10:58, Exit 0: `Disk-Archive-0.4.1.dmg`, 15 446 846 Bytes, Volume „Disk Archive 0.4.1 Beta“, Release-Build ohne Warnungen; App im DMG `CFBundleShortVersionString` 0.4.1 (Build 202610301058, selbst schreibgeschützt eingehängt).
  - **So lassen:** alles andere, auch `Werkzeuge/dmg/` (gehört dem Host), Hintergrund, Fenstergröße, Signatur-Einstellungen (`todo.0.4.1.002` prüft die Signatur erst auf dem fremden Mac).

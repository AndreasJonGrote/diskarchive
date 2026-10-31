# Paket 56 — Zielversion 0.4.2 (freigegeben und abgenommen 31.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Herkunft: Nutzer 31.10. („mit 0.4.2 sind wir durch“): Pakete 52–55 abgenommen, Nachtest bestanden. Vorlage: Paket 50 (`todo.0.4.1.004`, [archiv/paket-50-abgenommen-2026-10-30.md](paket-50-abgenommen-2026-10-30.md)).

**Für diese Aufgabe gilt:**
- Reine Versionsänderung, kein Verhalten: **kein Sabotage-Patch** (Regel 9 gilt nur für Verhaltensänderungen).
- Nur die betroffenen Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Gesamtlauf, kein Git.

**Reihenfolge (HALT am Ende):** `todo.0.4.2.006`. **HALT.**

## Aufgaben

- **todo.0.4.2.006 — Version 0.4.2 und Ausgabe-DMG:**
  - **Soll:**
    1. `MARKETING_VERSION` an allen 4 Stellen in `diskindex/diskindex.xcodeproj/project.pbxproj` (Z. 405, 444, 467, 488) auf `0.4.2`. `CURRENT_PROJECT_VERSION` bleibt 1.
    2. Tests, die die App-Version selbst prüfen, auf `0.4.2`: `BundleVersionTests` (Z. 13, Testname passend), `AboutAndSettingsMenuTests` (Z. 27). **So lassen:** feste Beispielwerte (`currentDisplay: "0.4.0"`) in `UpdateDialogTests` und `AppSettingsPersistenceTests`, sofern sie kein Bundle lesen.
    3. Suiten `BundleVersionTests`, `AboutAndSettingsMenuTests`, `UpdateDialogTests`, `VersionCheck*` und `EnglishLocalizationTests` grün, Build 0 Warnungen.
    4. Danach `Werkzeuge/dmg-erstellen.sh` ausführen (Skript unverändert). Erwartet: `Disk-Archive-0.4.2.dmg` im Hauptverzeichnis, Schlusszeile grün; im Status Größe, Volume-Name und `CFBundleShortVersionString` der App im DMG.
  - **So lassen:** alles andere, auch `Werkzeuge/dmg/` (gehört dem Host), Versions-Check (automatisch vergleicht weiter `n.n`), `Disk-Archive-0.4.1.dmg`.
  - **Status:** Bereit zur Prüfung. `MARKETING_VERSION` 0.4.2 an allen 4 Stellen (Build bleibt 1); `BundleVersionTests` (`marketingVersionIsZeroFourTwo`) und `AboutAndSettingsMenuTests` Z. 27 auf 0.4.2, Beispielwerte unverändert.
    `pruefung.sh schnell` 14:24–14:25: Build 0 Warnungen, 36 Tests in 9 Suites grün (Bundle, About, UpdateDialog, VersionCheck, -Calendar, -MainThread, -QueueTrim, EnglishLocalization).
    `dmg-erstellen.sh` 14:26, Exit 0, Schritt 7/7 grün: `Disk-Archive-0.4.2.dmg`, 16 MB (17 274 622 Bytes), Volume „Disk Archive 0.4.2 Beta“, SHA-256 0b4a8222…50a5.
    App im DMG (schreibgeschützt eingehängt unter `$TMPDIR`): `CFBundleShortVersionString` 0.4.2, Build 202610311426, universal (x86_64, arm64), Apple Development.

## Abnahme Host 31.10. (Gesamtlauf 14:39–15:11)

- Diff gelesen: `MARKETING_VERSION` 0.4.2 an 4 Stellen, `BundleVersionTests` und `AboutAndSettingsMenuTests` auf 0.4.2. Nichts Wesentliches.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1277/1277, parallel 3× grün (je 1270, 7 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 15:11:31, Version 0.4.2.
- DMG selbst geprüft (schreibgeschützt, ohne Finder): `hdiutil verify` gültig, SHA-256 `0b4a82227fdb60b91833f8e4dee1316bb6fe0b281b554d3f3fb2b299ef7050a5`; App 0.4.2, Build 202610311426, Mindest-macOS 15, universal; `codesign --verify --deep` ok, Team KATFD9R38G, Hardened Runtime; Inhalt App, „Programme“ → `/Applications`, Hintergrund.

## Nachtrag Host 31.10. 16:53: Hintergrund mit „Beta 0.4.1“

- Nutzer: Im DMG-Hintergrund stand noch „Beta 0.4.1“ (fest im Bild, ebenso in der Layout-Seite). Host hat die Fußzeile in `Werkzeuge/dmg/hintergrund.png` und `@2x` ersetzt (Archivo 11 px, gerendert mit Chrome; Probe mit „0.4.1“ pixelgleich zum alten Bild, geändert nur die Fußzeile).
- DMG neu mit `Werkzeuge/dmg-erstellen.sh` (Skript unverändert): App 0.4.2, Build 202610311653, Signatur gültig, `hdiutil verify` gültig, Hintergrund zeigt „Beta 0.4.2“. SHA-256 `197e40b2db17ba3567304c28507f3bd2f620b5a22765332e25c07a120c7fd5b7` (ersetzt `0b4a8222…`).

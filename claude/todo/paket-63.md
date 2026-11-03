# Paket 63 — Zielversion 0.4.3 (vorbereitet 03.11.2026; freigegeben, sobald Paket 62 abgenommen und der Nutzertest bestanden ist)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). **Letztes Paket für 0.4.3: Version und DMG.** Vorlage: Paket 56 ([archiv/paket-56-abgenommen-2026-10-31.md](../archiv/paket-56-abgenommen-2026-10-31.md)).

**Vorher (Host):** Hintergrund des DMG (`Werkzeuge/dmg/hintergrund.png`, `@2x`) nach `layout/DMG Hintergrund.dc.html` neu: Fußzeile „www.diskarchive.app“ statt „Beta x.x.x“ (`todo.0.4.3.003` entfällt).

**Für dieses Paket gilt:** reine Versionsänderung, kein Sabotage-Patch; nur betroffene Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.022`. **HALT.**

## Aufgaben

- **todo.0.4.3.022 — Version 0.4.3 und DMG:**
  - `MARKETING_VERSION` an allen Stellen in `DiskArchive/DiskArchive.xcodeproj/project.pbxproj` auf `0.4.3` (`CURRENT_PROJECT_VERSION` bleibt 1); Tests, die die eigene Version prüfen (`BundleVersionTests`, `AboutAndSettingsMenuTests` u. a.), auf 0.4.3; feste Beispielwerte ohne Bundle so lassen.
  - Danach `Werkzeuge/dmg-erstellen.sh` (Skript unverändert): `builds/Disk-Archive-0.4.3.dmg` und `builds/Disk Archive 0.4.3.app`, die 0.4.2-Dateien in `builds/` werden dabei gelöscht. Im Status Größe, Volume-Name, `CFBundleShortVersionString` der App im DMG, Schlusszeile.
  - **Status:**

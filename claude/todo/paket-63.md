# Paket 63 — Zielversion 0.4.3 (vorbereitet 03.11.2026; freigegeben, sobald Paket 62 abgenommen und der Nutzertest bestanden ist)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). **Letztes Paket für 0.4.3: Version und DMG.** Vorlage: Paket 56 ([archiv/paket-56-abgenommen-2026-10-31.md](../archiv/paket-56-abgenommen-2026-10-31.md)).

**Vorher (Host):** Hintergrund des DMG (`Werkzeuge/dmg/hintergrund.png`, `@2x`) nach `layout/DMG Hintergrund.dc.html` neu: Fußzeile „www.diskarchive.app“ statt „Beta x.x.x“ (`todo.0.4.3.003` entfällt).

**Für dieses Paket gilt:** außer `bug.0.4.3.004` (Sabotage-Patch) reine Versionsänderung; nur betroffene Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git.

**Reihenfolge (HALT am Ende):** `bug.0.4.3.004` → `todo.0.4.3.022`. **HALT.**

## Aufgaben

- **bug.0.4.3.004 — Absturz beim Start nach dem Anmelden (Nutzer 12.11., Stufe 1):**
  - **Nutzer sieht:** Nach dem Hochfahren meldet macOS „Disk Archive wurde unerwartet beendet“; die App läuft nicht in der Menüleiste. **Wann:** bei jedem Start über „Beim Anmelden starten“ (Argument `--background`), ab 0.4.1 belegt (`Disk Archive-2026-11-12-092702.ips`: `EXC_BREAKPOINT` in `diskindexApp.init()`, `x8` = `NSApp`, `x0` = 0; im Protokoll seit 0.4.1 kein einziger Start mit `kind=login`).
  - **Ursache:** `DiskArchiveApp.init()` ruft `NSApp.setActivationPolicy(.accessory)`. In `App.init()` gibt es `NSApp` noch nicht (implizit entpacktes `nil` → Abbruch). Dieselbe Umstellung macht `AppDelegate.applicationWillFinishLaunching` schon richtig (`launchKind == .login`).
  - **Soll:** In `init()` kein Zugriff auf `NSApp`/`NSApplication.shared`; die Umstellung bleibt allein im `AppDelegate`. Der Start beim Anmelden zeigt kein Fenster und kein Dock-Symbol, die App sitzt in der Menüleiste.
  - **Test:** Start der gebauten App mit `--background` als eigener Prozess (Release-Build aus dem Prüflauf, eigener `HOME`/Datenordner wie bei den bestehenden Starttests): Prozess läuft nach 5 s noch, kein neuer `.ips`; dazu ein Quelltext-Test, dass `DiskArchiveApp.init` `NSApp` nicht berührt. Sabotage-Patch: Zeile wieder einfügen → Test rot.
  - **Status:**

- **todo.0.4.3.022 — Version 0.4.3 und DMG:**
  - `MARKETING_VERSION` an allen Stellen in `DiskArchive/DiskArchive.xcodeproj/project.pbxproj` auf `0.4.3` (`CURRENT_PROJECT_VERSION` bleibt 1); Tests, die die eigene Version prüfen (`BundleVersionTests`, `AboutAndSettingsMenuTests` u. a.), auf 0.4.3; feste Beispielwerte ohne Bundle so lassen.
  - Danach `Werkzeuge/dmg-erstellen.sh` (Skript unverändert): `builds/Disk-Archive-0.4.3.dmg` und `builds/Disk Archive 0.4.3.app`, die 0.4.2-Dateien in `builds/` werden dabei gelöscht. Im Status Größe, Volume-Name, `CFBundleShortVersionString` der App im DMG, Schlusszeile.
  - **Dazu (Host 06.11., Stufe 3 aus Paket 62):** `MediumEjectTests.refusalOffersTryAgainWhichEjectsAgain` wartet mit `waitUntil(timeout: 5)` und fiel unter Parallellast einmal rot; auf `timeout: 20` anheben (Helfer nicht ändern). Zum Schluss einmal `Werkzeuge/pruefung.sh voll` (ohne `S=`).
  - **Status:**

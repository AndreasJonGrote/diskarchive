# Paket 33 — Zielversion 0.4.0 (freigegeben 26.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Maßstab: [konzept/architektur.md](../konzept/architektur.md), Absatz „Speicherung“ (ein Ordner). Volltexte und Abnahme von Paket 32: [archiv/paket-32-abgenommen-2026-10-26.md](../archiv/paket-32-abgenommen-2026-10-26.md).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen (Regel 12).
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.208` a → e. **HALT.**

**Befunde (ab diesem Paket):** Es gelten die drei Stufen (AGENTS.md „Befunde: drei Stufen“, Regel 12). Beheben musst du nur Stufe 1. Stufe 2 nur, wenn sie realistisch auftritt; Stufe 3 gar nicht.

## Umbau „ein Ordner“ (Nutzer 26.10., über den Supervisor: vor der Abnahmerunde, vor allem anderen)

- **bug.0.4.208 — Alles von Disk Archive in einen Ordner; Tests schreiben nichts nach `~/Library/Preferences`.**
  - **Nutzer sieht:** Andere Apps (WhatsApp, Mail, Finder) verlieren ihre Anzeige-Einstellungen. **Wann:** bei jedem Testlauf. **Stufe 1.**
  - **Anlass:** Jeder Testprozess legt heute eine `UserDefaults`-Suite `app.diskarchive.tests.<pid>[.<Name>-<uuid>]` an (`AppDefaults.current`, `TestDefaults.make`, dazu eigene Suiten in einzelnen Tests). Das läuft über `cfprefsd`. Die Testläufe haben den Einstellungsdienst aller Apps überlastet: WhatsApp, Mail und Finder haben ihre Anzeige-Einstellungen verloren. Außerdem liegt das Protokoll in `~/Library/Logs/Disk Archive/`, und `WriteGuard` erlaubt ganz `~/Library/Preferences` und ganz `~/Library/Caches`.
  - **Ziel** (Konzept „Speicherung“): Alles liegt in `~/Library/Application Support/Disk Archive/`:
    - `archive.sqlite`
    - `app-state.plist`
    - `Logs/` (Protokoll `diskindex.log` und `crash-last.txt`)
    - `outbox/`

    Einzige Ausnahme ist, was macOS in `app.diskarchive.plist` führt: `AppleLanguages` und die Fensterposition.

  - **a) Ein Speicher für den App-Zustand statt `UserDefaults`.**
    - Heute liegen in `AppDefaults.current` diese Schlüssel: `diskindex.globalPause`, `diskindex.failureModalCounts`, `diskindex.noticePermissionAsked`, `lastIntegrityCheck`, `diskindex.pruneAt` und `diskindex.displayLanguage`. Sie kommen in einen eigenen Speicher, z. B. `AppStateStore`. Er hat eine schmale Schnittstelle (`data`, `bool`, `date`, `string`, `set`, `remove`), so viel, wie die heutigen Aufrufer brauchen.
    - Es gibt zwei Ausführungen:
      - **App:** die Datei `app-state.plist` im Datenordner. Sie wird synchron gelesen (sie wird vor der Datenbank gebraucht, z. B. für die Sprache beim Start) und atomar geschrieben, Rechte 600, nur über `WriteGuard`. Lesefehler ergeben einen leeren Zustand und eine Protokollzeile, keinen Absturz.
      - **Tests:** im Speicher, je Instanz.
    - Alle Parameter `defaults: UserDefaults` dieser Aufrufer werden zu diesem Speicher: `AppState+Pause`, `AppState.init`, `StartupSequence`, `StoreLaunchSequence`, `NoticePermission`, `PauseDurationMenu`, `IssueTracker`, `AppLanguagePolicy`, `AppSettingsRuntimeCache`.
    - **`UserDefaults.standard`** steht danach nur noch an **einer** Stelle der App, z. B. `SystemDefaults.swift`: `AppleLanguages` setzen und `NSQuitAlwaysKeepsWindows` registrieren (`register` schreibt keine Datei). Die Fensterposition schreibt macOS selbst. Unter Tests schreibt diese Stelle nichts.
    - **Kein Übernehmen alter Werte** (keine Datenvorsicht bis 1.0, AGENTS.md):
      - Der Legacy-Import aus `UserDefaults` entfällt: `PersistedAppSettings.loadLegacyPersisted`, `IssueConsent.legacyAutoSendKey`, `AppSettings.load(from:)` und `save(to:)`, soweit nur dafür da, samt ihrer Tests.
      - Die App entfernt beim Start **einmal** ihre alten Schlüssel aus `app.diskarchive.plist` (nicht unter Tests). Das sind die sechs oben plus `diskindex.appSettings` und `diskindex.autoSendCrashReports`.
  - **b) Tests ohne `UserDefaults`.**
    - `TestDefaults.make` und alle Tests mit `UserDefaults(suiteName:)` oder `UserDefaults.standard` nehmen den Speicher im Speicher. Betroffen sind u. a.:
      - `AppSettingsPersistenceTests`
      - `AppLanguagePolicyTests`
      - `PauseExpiredAtLaunchTests`
      - `IssueReportRealLogTests`
      - `AppDefaultsTests`
      - `CrashWriterSafetyTests`
      - `IndexPruneTests`
      - `RunLifecycleTests`
      - `StartupSequenceTests`
      - `PauseNoticeTextTests`
      - `IndexFailureReasonTests`
      - `ArchiveDatabaseStartupTests`
    - Tests der Dateiausführung schreiben in einen Ordner unter `$TMPDIR`.
    - `AppDefaults` mit `removeStaleTestDomains`, `testDomainPrefix`, `legacyTestPrefixes` und `AppDefaultsCleanupTests` entfällt. Die Reste löscht der Nutzer einmal (Checkliste „Vorher 1“).
    - Kein Test schreibt in den echten Datenordner.
  - **c) Protokoll in den Datenordner.**
    - `DiskIndexLog.defaultDirectory` wird zu `Disk Archive/Logs/`, dort liegen auch `crash-last.txt` und die Rotation.
    - Alle Stellen, die den Pfad nennen, ziehen mit: Fehlerbericht (`logTail`), Absturzdialog, „Protokoll im Finder zeigen“ (falls vorhanden), Texte.
    - Den alten Ordner `~/Library/Logs/Disk Archive/` fasst die App nicht an (der Nutzer löscht ihn, Checkliste).
  - **d) Schreibschranke enger.**
    - `WriteGuard.allowedRoots` enthält nur noch den Datenordner und `NSTemporaryDirectory()`.
    - `~/Library/Preferences`, `~/Library/Caches` und `~/Library/Logs` fallen weg.
    - Der Ausweichweg der Outbox nach `NSTemporaryDirectory()/diskindex-outbox` bleibt nur, wenn der Datenordner nicht anzulegen ist (Protokollzeile).
  - **e) Wächter-Test über den Quelltext** (wie der Wächter von `todo.0.4.014`), z. B. `OneFolderGuardTests`:
    1. In `diskindexTests/` kommt `UserDefaults` nicht vor (Kommentare ausgenommen).
    2. In `diskindex/` steht `UserDefaults` nur in der einen Ausnahmedatei aus a.
    3. `WriteGuard.permitsWrite` ist falsch für `~/Library/Preferences/x.plist`, `~/Library/Caches/x` und `~/Library/Logs/x`. Für `…/Disk Archive/app-state.plist` und `…/Disk Archive/Logs/diskindex.log` ist es wahr.
    4. Das Standardverzeichnis des Protokolls liegt im Datenordner.

    Dazu ein Rundlauf: Pause setzen, neuen Speicher auf dieselbe Datei öffnen, die Pause ist da. Eine kaputte Datei ergibt einen leeren Zustand. **Gegenprobe zuerst:** Der Rundlauf liest einen gesetzten Wert positiv.
  - **Patches (rot erwartet):**
    1. `bug.0.4.208-a.patch`: Der Testspeicher nimmt wieder `UserDefaults(suiteName:)`. Der Wächter e1 wird rot.
    2. `bug.0.4.208-b.patch`: `WriteGuard` erlaubt wieder `~/Library/Preferences`. e3 wird rot.
    3. `bug.0.4.208-c.patch`: Das Protokoll liegt wieder in `~/Library/Logs/Disk Archive`. e4 wird rot.
    4. `bug.0.4.208-d.patch`: Die Dateiausführung schreibt nicht (`set` ohne Speichern). Der Rundlauf wird rot.
  - **Abnahmekriterium:** Nach dem Gesamtlauf gibt es keine neue Datei `app.diskarchive.tests.*` (und keine `*diskindex*`) in `~/Library/Preferences`. `Werkzeuge/pruefung.sh voll` meldet „Neue Dateien in ~/Library/Preferences seit Start: 0“. Belege das im Status mit deinem eigenen Lauf, gezählt mit `find ~/Library/Preferences -maxdepth 1 -newer <Startmarke> …`.
  - **So lassen:**
    - Gefälschte Medien und Testdatenbanken der Tests bleiben unter `$TMPDIR` (sie sind keine Daten der App).
    - Die Tabelle `settings` bleibt, wie sie ist.
    - `AppleLanguages` bleibt in `app.diskarchive.plist`.
  - **Status:** Bereit zur Prüfung. a) `AppStateStore` (`App/AppStateStore.swift`, mit `AppDataFolder`): `data/bool/date/string/set/remove`; App: `app-state.plist` synchron gelesen, atomar, 600, über `WriteGuard`; Lesefehler → leer, Protokollzeile erst nach dem Start des Protokolls (sonst gälte der Start als unsauber); Tests: im Speicher. Alle genannten Aufrufer umgestellt (Label `defaults:` blieb); `pruneAt` als `Date`; `IssueReporter.defaults` entfiel (nie gelesen). `UserDefaults` nur in `App/SystemDefaults.swift` (`AppleLanguages`, `NSQuitAlwaysKeepsWindows`, alte 8 Schlüssel entfernen; unter Tests nichts). Legacy-Import samt Test weg; fehlt `settings`, werden die Standardwerte gespeichert. b) `TestDefaults.make()` → Speicher im Speicher; `AppDefaults`, `AppDefaultsCleanupTests` gelöscht, `AppDefaultsTests` → `AppStateStoreTests`. c) Protokoll und `crash-last.txt` in `Disk Archive/Logs/`. d) `WriteGuard`: Datenordner + `$TMPDIR`; `storeFileURL` nutzt `AppDataFolder`; Outbox-Ausweichweg mit Protokollzeile. e) `OneFolderGuardTests` (e1–e4, Rundlauf, kaputte Datei; Gegenprobe je Test).
    Rot vor dem Umbau 26.10. 19:49: e1–e4 alle rot. Belege: ganzes Testziel parallel grün 20:21–20:26 (1223 Zeilen, rc 0); 15 Suites mit geändertem Speicher 20× parallel grün 20:26–20:31 (rc 0, 0 rote Zeilen); **Startmarke 20:21:04, `find ~/Library/Preferences -maxdepth 1 -newer <Marke>` nach beiden Läufen: 0 neue `app.diskarchive.tests.*`/`*diskindex*`**; Sabotage a 1/1, b 1/1, c 1/1, d 2/2 rot (20:08–20:09); Debug clean mit Testziel und Release 0 Warnungen; keine `.ips`; App des Nutzers 20:33:31 (0.4.0, Signatur ok, `find -newer` leer). Gesamtlauf (`pruefung.sh voll`) weggelassen (Last 3–5).
    App kurz gestartet (20:33–20:34): `app-state.plist` (600; Sprache, „Mitteilungen erfragt“) und `Logs/diskindex.log` + `crash-last.txt` entstehen im Datenordner, in `~/Library/Logs/Disk Archive/` nichts Neues. Unbelegt: dass die alten Schlüssel aus `app.diskarchive.plist` verschwinden – die Datei ist noch vom 19.10. (cfprefsd schreibt verzögert), und von hier liefert `defaults read` für keine Domäne etwas (auch nicht `-g AppleLocale`). Bitte beim Nutzertest prüfen.
    Selbstprüfung (Sonnet): keine hohen/mittleren Funde. Behoben: Gegenprobe für e1, Lesefehler-Zeile vor Protokollstart, zwei Quellen des Datenordners, Zeile „settings migrate“, e4 prüft auch `DiskIndexLog.shared`. Niedrig, offen: zwei Prozesse überschreiben die ganze Datei (Doppelstart im selben Moment); Kommentarfilter des Wächters schneidet bei `//` in Zeichenketten ab; vorbestehend: der neu angelegte Ordner `Logs/` und `diskindex.log` haben beim allerersten Anlegen 755/644, `FilePrivacy.restrict` setzt 700/600 erst beim nächsten Start.

**Paketende:**
- 0 Warnungen in Debug und Release.
- Alle Suites grün, die Suites mit geändertem Speicher 20× parallel grün. Rote Läufe zählen auch, wenn nur das Protokoll sie zeigt.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut. Kurz von Hand starten:
  - `app-state.plist` und `Logs/diskindex.log` entstehen im Datenordner.
  - In `~/Library/Logs/Disk Archive/` kommt nichts Neues dazu.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

## Abnahme Host 26.10. (Gesamtlauf 20:45–21:13, erste Prüfung nach den drei Stufen)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell **1164/1164** grün.
- Parallel 1–3 **grün** (je 1158 bestanden, 6 übersprungen, Exit 0).
- Keine neuen `.ips`.
- **Neue Dateien in `~/Library/Preferences`: 0.**
- Sabotage **4/4 rot ✓**.
- App des Nutzers 21:13:32, Signatur gültig, Version 0.4.0.

Den Produktcode hat der Host gelesen: `AppStateStore`, `SystemDefaults` (einzige Stelle mit `UserDefaults`, unter Tests ohne Wirkung), `WriteGuard` (nur Datenordner und `$TMPDIR`), `DiskIndexLog.defaultDirectory` (`Disk Archive/Logs/`). Prüf-Agent (Sonnet, Vorlage 2b): nichts Wesentliches gefunden, kein Befund der Stufe 1 oder 2. Der Absturzdialog findet `crash-last.txt` im neuen Ordner, und kein Aufrufer von `WriteGuard` schreibt im normalen Gebrauch außerhalb.

- **Abgenommen:** `bug.0.4.208`.
- **Offen für den Nutzertest:** Dass die alten Schlüssel aus `app.diskarchive.plist` verschwinden, ließ sich nicht belegen (cfprefsd schreibt verzögert). Das steht als Punkt in der Checkliste.
- **Stufe 3 (Backlog, keine Aufgabe):**
  - `Logs/` und `diskindex.log` haben beim allerersten Anlegen 755/644. `FilePrivacy` setzt 700/600 erst beim nächsten Start; das war schon vorher so.
  - Die alten Schlüssel werden bei jedem Start entfernt, nicht nur beim ersten.
  - Zwei Prozesse, die im selben Moment starten, können die Datei gegenseitig überschreiben.

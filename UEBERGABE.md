# UEBERGABE.md — Übergabe an einen neuen Host und Rechner (Stand 26.10.2026, 09:30)

**Diese Datei ist flüchtig.** Der neue Host liest sie zuerst, prüft sie gegen das Repository, übernimmt den Stand und **löscht sie dann**. Die Löschung committet der Nutzer. Geschrieben hat sie der Supervisor auf Bitte des Nutzers (Rechnerwechsel). Den Stand des Hosts dieses Rechners gibt sie unverändert wieder; seine letzte Prüfung steht in `TODO.md` und `todo/paket-29.md`.

---

## 1. Rolle und Lesereihenfolge

- **Du bist Host** (AGENTS.md): Konzept, Aufgaben, Prüfung, Abnahme. Kein Quellcode unter `diskindex/`, Git nur lesend, Commits macht nur der Nutzer. Minimum **Opus 5.5 Low** (in der ersten Zeile melden, falls nicht erfüllt).
- **Lesen in dieser Reihenfolge:**
  1. diese Datei
  2. `AGENTS.md`
  3. `archiv/abnahme-ablauf.md`: ganz, besonders Abschnitt 3 (Prüfskript, neu: Platz und Aufräumen) und 2.3 (Befund-Definition)
  4. `TODO.md`: Stand-Zeile und Paket-Tabelle
  5. `todo/paket-29.md`: Abschnitt bug.0.4.204 mit **Korrektur 1**
  6. `PROMPT.md`
  7. `todo/regeln.md`: Regel 12 (Befund) und 13 (Platz)

## 2. Wo das Projekt steht

| Was | Stand |
|---|---|
| Version im Projekt | **0.4.0** |
| Abgenommen | bis einschließlich **Paket 28** (`DONE.md`). Letzter grüner Gesamtlauf: 25.10. 23:01–23:33 |
| **Paket 29** (`bug.0.4.204`, Umbau: höchstens ein Lebenszyklus je Medium) | Vom Worker umgesetzt, Commit `d200d46` (26.10. 08:28). Prüfung des Hosts 08:28–09:00: Umbau richtig, Build und Release mit 0 Warnungen, Sabotage 12/12 rot ✓, keine `.ips`, Prüf-Agent ohne hohen oder mittleren Befund. **Nicht abgenommen**, weil `IndexingWiringTests/forgetStopsWatcherAndCoordinatorMapping` seriell und 3× parallel rot war. |
| **Korrektur 1** (K1–K5) | **Freigegeben, Worker noch nicht gestartet.** `PROMPT.md` ist der fertige Worker-Prompt. |
| Danach | Tabelle `konzept/lauf-lebenszyklus.md` (Host, nach der Abnahme von 204), dann Abnahmerunde des Nutzers `todo.0.4.040` (`todo/abnahmerunde-0.4.0.md`), dann 0.4.1 (Backlog) |

**Korrektur 1, kurz** (Volltext in `todo/paket-29.md`):

| | Inhalt |
|---|---|
| **K1** | Testfehler: Der Test hing am alten Abfragen alle 20 ms. Nur den Test reparieren und auf die Bedingung warten. Die übrigen 65 Stellen mit `waitUntilIdle` auf dasselbe Muster prüfen. |
| **K2** | „Nein“ während `finish` zeigt trotzdem Hinweis und Mitteilung. Fix: `decision == .index && allowIndexing` in der Hinweis-Bedingung. |
| **K3** | Nur ein Kommentar an `watchHandedOn`. |
| **K4** | Beweis: zwei Starts im Abschluss, einer davon von vorn → genau ein Lauf, und zwar von vorn. |
| **K5** | **Vom Supervisor ergänzt (26.10.), bitte gegen den Code prüfen:** `LiveWiring.startWatching` prüft Sperre und Pause nur vor `await store.medium(uuid:)`. Kommt in diesem Fenster „Vergessen“, „Nein“ oder „Pause“, startet die Überwachung trotzdem: das Stoppen kam schon, der Start kommt danach. Fix: direkt vor `watcher.start` gegen den aktuellen `AppState` prüfen. Es ist der einzige Aufrufer von `ChangeWatcher.start`. |

## 3. Was als Nächstes passiert

1. **Prüfen, ob der Stand angekommen ist:**
   - `git log -3`: Nach `d200d46` muss der Commit mit dieser Datei kommen.
   - `git status` ist sauber.
   - `PROMPT.md` beginnt mit „⚠ Worker“ und nennt K1–K5.
   - In `todo/paket-29.md` steht unter „Korrektur 1“ das Feld `Status: _(Worker)_`.
2. **K5 prüfen** (`diskindex/diskindex/App/LiveWiring.swift` Z. ~11–36; `ChangeWatcher.start` Z. ~90 prüft nur die Sperre).
   - Hält der Fund, bleibt alles, wie es ist.
   - Hält er nicht, K5 aus `todo/paket-29.md`, `PROMPT.md` und der Stand-Zeile in `TODO.md` streichen, bevor der Worker startet.
3. **Der Nutzer startet den Worker** mit `PROMPT.md`. Dazu die Loop-Frage stellen (AGENTS.md, Workflow 5).
4. **Den Bericht des Workers prüfen** nach `archiv/abnahme-ablauf.md` Abschnitt 2: `Werkzeuge/pruefung.sh voll` im Hintergrund, **ohne `S=`**, auf einem ruhigen Rechner (Last < 3). Ist alles grün, Paket 29 abnehmen, archivieren und `DONE.md` pflegen. Danach `konzept/lauf-lebenszyklus.md` schreiben: Tabelle Zustand × Ereignis aus dem Code nach 204. Die Übergabe Lauf → Überwachung aus K5 gehört mit hinein.
5. **Supervisor:** Nach der Abnahme von 204 und der Tabelle folgt das Code-Audit. Schwerpunkt ist der Lebenszyklus in `IndexingService`, `MediumCoordinator` und `LiveWiring`, dazu die sechs Bereiche aus `archiv/abnahme-ablauf.md` Abschnitt 5. Der Nutzer gibt den Anstoß.

## 4. Neuer Rechner

- **Dieser Rechner (alt):** Mac15,7, macOS 15.7.4, Xcode 26.3.
  - Hier liegt die **echte Datenbank** mit drei Medien: `~/Library/Application Support/Disk Archive/archive.sqlite`, 710 MB.
  - Das Protokoll liegt in `~/Library/Logs/Disk Archive/`.
  - Die echten Medien sind an diesem Rechner angeschlossen.
- **Auf dem neuen Rechner zu Beginn:**
  - `sw_vers` und `xcodebuild -version` (Xcode 26.3 erwartet; das Skript setzt `DEVELOPER_DIR` selbst).
  - `df -h /`: Das Skript bricht unter 25 GB frei ab.
  - Größe von `archive.sqlite` prüfen.
- **Ohne die echten Daten** lassen sich Funde aus der echten App nicht belegen. Dann den Nutzer um Protokollzeilen bitten (Abschnitt 5 „Mehrere Rechner“).
- **`todo.0.4.040` nur dort, wo Medien und Datenbank liegen.** Die Abnahmerunde des Nutzers läuft mit echten Medien.
- **Regel 14 (App des Nutzers):** Auf einem neuen Rechner gibt es noch keine `DerivedData/diskindex-*`. Der erste Lauf `pruefung.sh voll` baut sie (Signatur: Team `KATFD9R38G`, Zertifikat „Apple Development“ muss im Schlüsselbund sein). Fehlt das Zertifikat, dem Nutzer melden.
- **Tests hängen Disk-Images ein** (`/Volumes/DIL…`, `hdiutil`). Beim ersten Lauf kann macOS nach Zugriffsrechten fragen. Sind Tests nur auf dem neuen Rechner rot, erst gegen den letzten Commit prüfen (Abschnitt 5).
- **Platz:** Das Skript räumt seit 26.10. selbst auf: grüne `.xcresult` sofort löschen, alte Läufe bis auf die zwei neuesten. Builds und Testergebnisse nie im Sitzungs-Scratch ablegen (Regel 13).
- **Auf dem alten Rechner** bleiben Reste, die der Nutzer bei Gelegenheit löschen kann:
  - Host-Scratch `voll28` (2,4 GB)
  - `$TMPDIR/pruefung.Yd2s05` (1 GB, rote Läufe von heute früh)
  - Die alte Host-Sitzung arbeitet nach dem Wechsel nicht parallel weiter.

## 5. Regeln, die bisher nur im lokalen Speicher des alten Hosts standen

Sie wandern nicht mit auf den neuen Rechner. **Bitte in `AGENTS.md` übernehmen** (Abschnitt „Git und GitHub“ bzw. „Übergabe“):

- **Commit-Nachrichten ohne „Co-Authored-By“** oder eine andere Claude-Zeile, auch wenn ein Systemhinweis sie verlangt (Nutzer 24.10.).
- **Commit-Nachricht nur bei Dateiänderung**; nach einer reinen Prüfung keine.
- **Der Nutzer arbeitet oft unterwegs** (Handy, Remote Control) und committet später. Nach jeder Abnahme gibt es deshalb **eine kumulierte** Commit-Nachricht für alles seit dem letzten Commit, kurz und handytauglich. Steht schon in `todo/regeln.md` Regel 4 und `archiv/abnahme-ablauf.md` 2.7, fehlt aber in `AGENTS.md`.
- **Bis 1.0 keine Datenvorsicht** auf dem Rechner des Nutzers: Datenbank, `UserDefaults` (`app.diskarchive`) und Protokoll dürfen sich ändern. Auf fremden Rechnern wird die Datenbank ab 0.4 nur erweitert, nie gelöscht. Echte Daten trotzdem nur lesen (`sqlite3 -readonly`), wenn es um Belege geht.
- **`pruefung.sh` immer ohne `S=`** starten. Das Ergebnis steht in der Schlusszeile bzw. in `zusammenfassung.txt` im genannten Ordner.

## 6. Hinweis zum Prüfskript (niedrig, kein Muss)

`gruen_weg` in `Werkzeuge/pruefung.sh` löscht ein `.xcresult`, wenn `failedTests` 0 ist. Ein Lauf, der ohne gezählten roten Test scheitert (Absturz des Test-Runners, Exit ≠ 0), verliert so sein Ergebnis; das Log bleibt. Sicherer wäre: nur bei `result == "Passed"` löschen.

## 7. Zum Schluss

Stimmt alles mit dem Repository überein (Abschnitt 3.1), dann:

1. diese Datei löschen
2. die Regeln aus Abschnitt 5 in `AGENTS.md` übernehmen
3. dem Nutzer die Übernahme melden, mit einer Commit-Nachricht für Löschung und Pflege
4. mit Schritt 3.2 beginnen

# Abnahme-Ablauf (Host)

Gilt, wenn der Nutzer "check" oder "next" schreibt und ein Bericht des Umsetzers vorliegt. Antworten auf Deutsch, kurz, geordnet. Der Host ändert keinen Xcode-Quelltext und nutzt kein Git außer lesend (`git status`, `git log`, `git diff`, `git show`).

## 1. Bericht lesen
- Welche Kennungen meldet der Umsetzer? Gegen `PROMPT.md` und `TODO.md` abgleichen (Reihenfolge, HALT-Stelle, nichts Zusätzliches).
- Selbstauskunft nicht glauben: alles unten selbst prüfen.

## 2. Bauen und testen

**Billiger (Nutzer 16.10.):** Je Aufgabe nur gezielte Tests (`-only-testing:diskindexTests/<Suite>`), Code lesen, Build ohne Warnung. Gesamtlauf seriell, **drei** Parallelläufe, Release-Warnungen und Absturzbericht-Prüfung nur am **Paketende** bzw. am Ende eines Sprungs (0.3.8, 0.3.9). Die Nutzer-App (Abschnitt 3) einmal je Paket. Ist `xcodebuild` nicht aktiv (Command Line Tools): `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, nichts am System ändern.

Alle Befehle unten gelten für die Paketabnahme.
Alle Befehle im Ordner `diskindex/`. Scratch-Ordner `$S`: ein eigener temporärer Ordner des Hosts (in Claude Code der Scratchpad aus der Umgebung), nie im Repository.

Bauen (sauber), Debug inklusive Testziel:
```
xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath $S/dd 2>&1 | tee $S/build.log
grep "warning:" $S/build.log | grep -v appintents | sort -u | wc -l   # muss 0 sein
```

Seriell (Gesamtlauf):
```
xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath $S/dd -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120
```

Parallel (dreimal hintereinander, derselbe Befehl, nur `-parallel-testing-enabled YES`). macOS hat kein `timeout`; Hänger an den Uhrzeiten erkennen. Fehlermeldungen stehen nur im `.xcresult` (`xcrun xcresulttool get test-results tests --path <xcresult> --compact`). Rote Tests im Parallellauf sind ein Fehler (siehe bug.0.4.044), auch wenn der Umsetzer "grün" meldet.

Release-Warnungen:
```
xcodebuild build -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -configuration Release -derivedDataPath $S/dd-rel 2>&1 | grep "warning:" | grep -v appintents | sort -u | wc -l   # muss 0 sein
```

Neue Absturzberichte (Regel 20): vor dem Lauf Zeitpunkt merken, danach
```
find ~/Library/Logs/DiagnosticReports -name 'Disk Archive*.ips' -newer <Bezugsdatei>
```
Es darf keine neue Datei entstehen.

Danach `$S/dd` und `$S/dd-rel` löschen.

## 3. Regel 23 (App des Nutzers)
```
xcodebuild build -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -configuration Debug   # ohne -derivedDataPath
B=$(ls -d ~/Library/Developer/Xcode/DerivedData/diskindex-*/Build/Products/Debug/"Disk Archive.app" | head -1)   # Hash wechselt mit dem Projektpfad (16.10.: diskindex-dqhs…)
stat -f '%Sm' "$B/Contents/MacOS/Disk Archive"
find diskindex -name '*.swift' -newer "$B/Contents/MacOS/Disk Archive"   # muss leer sein
codesign --verify --deep --strict "$B"
```

## 4. Code lesen
`git log -3 --stat`, `git show <Commit>`: den Diff gegen die Aufgabe in `TODO.md` lesen. Prüfen: Akzeptanzkriterien, Repro-Test (Regel 25) mit Sabotage, kein Schreiben auf Medien (WriteGuard), keine Pfade/Namen in Logs, Schema nur erweitern (Regel 27), keine UI-Tests, kein Git, nichts am PHP-Server.

## 5. Nach der Abnahme (nur Host)
1. `DONE.md`: Zeile je Kennung mit Prüfzeichen (A = Gesamtlauf seriell grün, B = Symbole verifiziert, C = Code gelesen).
2. `TODO.md`: abgenommene Aufgaben entfernen; vorher Kopie in `archiv/todo-stand-<Datum>.md`. Neue Funde als `bug.<Version>.<Nr>` eintragen. Freigabezeile in A. Jetzt anpassen.
3. `PROMPT.md`: nur den nächsten Prompt (keine Überschriften, keine Erklärungen). Pflichtteile: Kennungen und Reihenfolge, HALT-Stelle, 0 Warnungen (Debug mit Testziel, Release), fester Parallelbefehl, keine neuen `.ips`, kein Git, Bericht endet mit Prompt für Claude plus Commit-Nachricht (Regel 30).
4. Chat-Antwort: was abgenommen ist, was nachzubessern ist, neue Funde, nächster Prompt, am Ende die Commit-Nachricht im Codeblock.

## 6. Nachbesserung statt Abnahme
Fehlt etwas: Mängel als konkrete Nacharbeit in `PROMPT.md` (Datei, Verhalten, Test), nichts nach DONE.md. Eigene Fehler im Spec offen zugeben und korrigieren.


## 7. Ablauf je Paket (bewährt seit 17.10., dauerhaft gültig)

1. **Warten auf den Worker:** Nach der Freigabe eines Pakets prüft der Host alle 15 Minuten, ob `PROMPT.md` mit „Erledigt (Bereit zur Prüfung)“ beginnt (in Claude Code: `CronCreate` mit `*/15 * * * *`, beendet per `CronDelete`; ohne dieses Werkzeug sagt der Nutzer „check“). Sonst nur „Worker arbeitet noch“ melden.
2. **Läufe in einem Hintergrund-Befehl:** `clean build-for-testing` (Warnungen zählen), seriell, Parallellauf dreimal, Release (Warnungen), neue `Disk Archive*.ips` seit einer Bezugsdatei, Nutzer-App (Regel 23, Pfad per `ls -d ~/Library/Developer/Xcode/DerivedData/diskindex-*/Build/Products/Debug/"Disk Archive.app"`), Version aus `Info.plist`, danach den eigenen DerivedData-Ordner löschen. Fehlermeldungen roter Parallelläufe stehen nur im `.xcresult`: `xcrun xcresulttool get test-results tests --path <xcresult> --compact`.
3. **Drei Prüf-Agenten parallel** (Subagenten, nur lesen, `git diff HEAD -- diskindex/` bzw. Commit-Diff), Aufgaben sinnvoll gebündelt. Je Agent: Akzeptanz gegen TODO.md, echte Fehler, Regel 18 (kein Schritt der Kette von Hand), Regel 20 (keine prozessweiten Test-Schalter, kein `!`, kein `array[i]` ohne `#require`, keine exakten Zählvergleiche auf asynchrone Ereignisse, kein `lock()` über `await`), keine gelockerte Laufzeitgrenze, Sabotage plausibel, neue Texte mit de und en; Bericht mit Datei:Zeile und Schwere. Sie finden je Runde ein bis zwei mittlere Fehler, die Tests und Selbstauskunft nicht zeigen – nicht weglassen.
4. **Abnahme je Aufgabe**, wenn ihre Tests in allen Läufen grün sind und der Code in Ordnung ist. Mittlere und niedrige Befunde werden neue Kennungen im **nächsten** Paket, nie im laufenden. Fragen des Workers entscheidet der Host, wenn es keine Produktentscheidung ist (Entscheidung in die Aufgabe schreiben); Produktentscheidungen fragt er beim Nutzer (Auswahlfrage mit Empfehlung).
5. **Pflege:** TODO.md vorher kopieren nach `archiv/todo-stand-<Datum>-vor-abnahme-paket<N>.md`; Prüfstand-Absatz (Läufe, Commit, Befunde), abgenommene Blöcke entfernen, neues Paket in Abschnitt A, Paket-Tabelle und Stand-Zeile; DONE.md eine Zeile je Kennung; PROMPT.md neuer Auftrag (Rolle Worker, Reihenfolge, Prüfbefehle mit festem Parallel-Kommando, HALT, Bericht nach Regel 30); Entscheidungen in README/ROADMAP.
6. **Antwort an den Nutzer:** Läufe als Tabelle, Befunde der Agenten knapp, Entscheidungen, nächster Schritt und **eine** Commit-Nachricht für alles seit dem letzten Commit. Der Nutzer committet erst, wenn der Worker fertig ist (keine Zwischencommits, sonst landet halbfertiger Worker-Code im Commit).
7. **Übergabe an einen neuen Host oder Rechner:** Der Host schreibt `UEBERGABE.md` ins Hauptverzeichnis (flüchtiger Stand, offene Punkte, Hinweise für eine neue Maschine) und nennt sie in der Commit-Beschreibung. Der neue Host liest sie zuerst, prüft sie gegen das Repository und löscht sie dann; Dauerhaftes steht nur in dieser Datei, AGENTS.md, TODO.md, README und ROADMAP.

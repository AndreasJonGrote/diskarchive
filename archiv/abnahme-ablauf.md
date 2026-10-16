# Abnahme-Ablauf (Host)

Gilt, wenn der Nutzer "check" oder "next" schreibt und ein Bericht des Umsetzers vorliegt. Antworten auf Deutsch, kurz, geordnet. Der Host ändert keinen Xcode-Quelltext und nutzt kein Git außer lesend (`git status`, `git log`, `git diff`, `git show`).

## 1. Bericht lesen
- Welche Kennungen meldet der Umsetzer? Gegen `PROMPT.md` und `TODO.md` abgleichen (Reihenfolge, HALT-Stelle, nichts Zusätzliches).
- Selbstauskunft nicht glauben: alles unten selbst prüfen.

## 2. Bauen und testen

**Billiger (Nutzer 16.10.):** Je Aufgabe nur gezielte Tests (`-only-testing:diskindexTests/<Suite>`), Code lesen, Build ohne Warnung. Gesamtlauf seriell, **drei** Parallelläufe, Release-Warnungen und Absturzbericht-Prüfung nur am **Paketende** bzw. am Ende eines Sprungs (0.3.8, 0.3.9). Die Nutzer-App (Abschnitt 3) einmal je Paket. Ist `xcodebuild` nicht aktiv (Command Line Tools): `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, nichts am System ändern.

Alle Befehle unten gelten für die Paketabnahme.
Alle Befehle im Ordner `diskindex/`. Scratch-Ordner: `/private/tmp/claude-501/-Users-jon-Projekte-Disk-Index/a7f638a5-cee3-42a2-9efa-f4ff942dfbfa/scratchpad` (heißt `$S`; in einem neuen Chat den Scratchpad-Pfad aus der Umgebung nehmen).

Bauen (sauber), Debug inklusive Testziel:
```
xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath $S/dd 2>&1 | tee $S/build.log
grep "warning:" $S/build.log | grep -v appintents | sort -u | wc -l   # muss 0 sein
```

Seriell (Gesamtlauf):
```
xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath $S/dd -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120
```

Parallel (dreimal hintereinander, derselbe Befehl, nur `-parallel-testing-enabled YES`). Rote Tests im Parallellauf sind ein Fehler (siehe bug.0.4.044), auch wenn der Umsetzer "grün" meldet.

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
B=~/Library/Developer/Xcode/DerivedData/diskindex-arbizwwvkjqgvickwkengqhdtrav/Build/Products/Debug/"Disk Archive.app"
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

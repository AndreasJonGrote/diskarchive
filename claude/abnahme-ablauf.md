# Abnahme-Ablauf (Host)

Gilt, wenn ein Bericht des Workers vorliegt („check“, „next“ oder Loop meldet „Erledigt (Bereit zur Prüfung)“). Antworten auf Deutsch, kurz, geordnet. Der Host ändert keinen Xcode-Quelltext und nutzt Git nur lesend (`git status`, `git log`, `git diff`, `git show`).

## 0. Modelle und Kosten (Nutzer 23.10.)

- **Minimum Host: Opus 5.5 Low. Minimum Worker: Sonnet 5.5 Medium.** Jeder Agent nennt sein Minimum in der **ersten Zeile** seiner ersten Antwort einer Sitzung („⚠ Host-Minimum: Opus 5.5 Low – läuft die Sitzung darunter, bitte wechseln“). Den eigenen Aufwand (Low/Medium) kann ein Agent nicht sicher erkennen; er meldet, was er sieht (Modellname), und das Minimum.
- **Subagenten des Hosts:** Sonnet 5.5 für alles mit Urteil (Prüf-Agenten, Audit). Haiku 5.5 nur für Mechanik, die ich sofort gegenprüfen kann (Suchen, Zählen, Formalprüfung von TODO/DONE). **Tests, Builds, Warnungszählung und Messungen macht nie ein Agent, sondern `Werkzeuge/pruefung.sh`;** Agenten bekommen höchstens die Zusammenfassung.
- **Subagenten des Workers:** dürfen für mechanische Teile (Suchen, Umbenennen, Formatieren) auf Low gehen; die Selbstprüfung (`todo/regeln.md` Regel 12) bleibt Sonnet.
- **Kontext sparen:** große Dateien (`TODO.md`, `README.md`, `archiv/`) nur gezielt lesen (Suche, Zeilenbereich); Build- und Testausgaben nie roh in den Chat; kurze Sitzungen je Paket, Rest in `UEBERGABE.md`.

## 1. Bericht lesen
- Welche Kennungen meldet der Worker? Gegen `PROMPT.md` und das Paket-File `todo/paket-NN.md` abgleichen (Reihenfolge, HALT-Stelle, nichts Zusätzliches).
- Selbstauskunft nicht glauben: alles Folgende selbst prüfen. Fragen des Workers zuerst lesen: technische entscheidet der Host und schreibt die Entscheidung in die Aufgabe, Produktfragen gehen als Auswahlfrage mit Empfehlung an den Nutzer.

## 2. Ablauf je Paket (bewährt seit 17.10., dauerhaft gültig)

1. **Warten auf den Worker:** siehe Abschnitt 9 (Loop nur nach Rückfrage).
2. **Prüfskript im Hintergrund:** `Werkzeuge/pruefung.sh voll` (Abschnitt 3), Dauer etwa 25 Minuten; prüft am Ende auch die Sabotage-Patches aus `todo/sabotage/` (Regel 9). Jeder Patch muss „rot ✓“ melden.
3. **Prüf-Agenten parallel** (Sonnet, nur lesen; drei bei großen Paketen, zwei bei bis zu 8 Kennungen), Aufgaben nach Themen gebündelt. Je Agent: Akzeptanz je Unterpunkt, echte Fehler mit Datei:Zeile und Schwere, die **fünf Fragen** aus Regel 12 (Zeitfenster, Löschen, fremde Ereignisse, alte Reste, Beweis), die Invarianten aus `konzept/architektur.md`, Regel 10/11 (Kette ohne Nachhilfe, keine prozessweiten Schalter, keine festen Zeiten als Beweis), neue Texte mit de und en. „Lieber 5 belastbare als 20 Vermutungen.“ **Seit 26.10. gelten die drei Stufen (Abschnitt 2b).** Den Auftrag jedes Prüf-Agenten baut der Host nach der Vorlage in 2b. Befunde der Stufen 1 und 2 bestätigt der Host selbst im Code und legt die Stufe selbst fest; Agenten stufen oft zu hoch. **Lauf-Lebenszyklus:** Ab `bug.0.4.204` höchstens ein Lebenszyklus je Medium; ein Fund „zwei Läufe gleichzeitig“ heißt Marker oder Wächter falsch, dort beheben, keine neue Einzelprüfung. Nach 204 prüfen Agenten diese Stelle nur gegen `konzept/lauf-lebenszyklus.md` (Tabelle Zustand × Ereignis); erst wenn danach dort noch Befunde kommen, Umbau zum vollen Zustandsautomaten.
4. **Code selbst lesen:** `git log -3 --stat`, `git show <Commit>`. Prüfen: Akzeptanzkriterien, Rot vor dem Fix (Regel 8), Sabotage-Patches vollständig (Regel 9), kein Schreiben auf Medien (WriteGuard), Invarianten, Schema nur erweitern (Regel 7), keine UI-Tests, kein Git, nichts am PHP-Server.
5. **Abnahme je Aufgabe**, wenn ihre Tests in allen Läufen grün sind, ihre Sabotage-Patches rot melden und der Code in Ordnung ist. Was mit einem Befund geschieht, richtet sich nach der Stufe (2b):
   - Ein Befund der **Stufe 1** im Diff der Aufgabe oder eine Regression heißt: nicht abgenommen, Nacharbeit vorn im nächsten Paket. Andere Stufe-1-Befunde werden neue Kennungen im **nächsten** Paket.
   - **Stufe 2** kommt nur dann ins nächste Paket, wenn sie in der echten App oder in einem realistischen Test auftritt. Sonst wird sie eine Zeile im Sammeleintrag `todo/backlog.md`.
   - **Stufe 3** bekommt keine Aufgabe, höchstens eine Zeile im Backlog.

   Rote Tests im Parallellauf blockieren die Abnahme unabhängig von der Stufe (bug.0.4.044, Abnahmekriterium 4), auch wenn der Worker „grün“ meldet. Die Ursache wird in derselben Kennung behoben und bekommt keine neue Kennung.
6. **Pflege (nur Host):**
   1. Das Paket-File nach `archiv/paket-<N>-abgenommen-<Datum>.md` verschieben (Volltext mit Status), die Patches der abgenommenen Kennungen nach `archiv/sabotage/paket-<N>/` (Patches nicht abgenommener Kennungen bleiben liegen). In `TODO.md` (Index, kurz halten): Stand-Zeile, Prüfstand-Absatz (Läufe, Commit, Befunde; nur das letzte Paket, ältere stehen in DONE.md), Paket-Tabelle. Neue Funde als `bug.<Version>.<Nr>` direkt ins nächste `todo/paket-<N+1>.md`.
   2. `DONE.md`: eine Zeile je Kennung mit Prüfzeichen (A = Gesamtlauf seriell grün, B = Symbole verifiziert, C = Code gelesen).
   3. `PROMPT.md`: nur der nächste Auftrag, Aufbau siehe Abschnitt 8.
   4. Entscheidungen direkt in der Themendatei unter `konzept/` (Index README.md) und in ROADMAP.
7. **Antwort an den Nutzer:** Läufe als Tabelle, Befunde der Agenten knapp, Entscheidungen, nächster Schritt, **eine** Commit-Nachricht für alles seit dem letzten Commit (im Codeblock) und danach die **Loop-Frage** (Abschnitt 9). Der Nutzer committet erst, wenn der Worker fertig ist (keine Zwischencommits, sonst landet halbfertiger Worker-Code im Commit). Bei reiner Prüfung ohne Dateiänderung keine Commit-Nachricht.
8. **Nachbesserung statt Abnahme:** Fehlt etwas, kommen die Mängel als konkrete Nacharbeit in `PROMPT.md` (Datei, Verhalten, Test); nichts geht nach DONE.md. Eigene Fehler im Spec offen zugeben und korrigieren.

## 2a. Aufgaben schreiben (Host 23.10., aus den Paketen 13–16)

- **Kleine Pakete:** höchstens 8 Kennungen, Sammelposten höchstens 5 Unterpunkte. Höchstens **eine schwere Aufgabe** (Datenverlust, Nebenläufigkeit, Zeitablauf in der Oberfläche) je Paket, und zwar als erste.
- **Jede Vorgabe gegen die Invarianten** (`konzept/architektur.md`) prüfen, bevor sie rausgeht. Beispiel `bug.0.4.169`: Die Vorgabe „erst lesen, dann schreiben“ sagte nicht, was mit Zeilen ohne Vorab-Wert geschieht; daraus wurde ein Datenverlust (Invariante 1 und 2).
- **Gegenprobe nennen:** Jede schwere Aufgabe nennt den Fall, der sie kaputt machen würde (z. B. „während ein anderes Medium indiziert“, „zweiter Lauf desselben Mediums“, „Medium hängt“), und verlangt dafür einen Test.
- **Zweimal „Rest von“ in derselben Stelle** heißt: kein weiterer Flicken, sondern die Stelle als Ganzes neu beschreiben (Ablauf, Zustände, Invarianten), dann eine Aufgabe. Danach kommen dort nur noch Befunde der Stufe 1 in die laufende Version (AGENTS.md).
- **Jede `bug`-Aufgabe** beginnt mit „Nutzer sieht: … · Wann: … · Stufe N“. Vor dem Schreiben laufen die drei Prüfungen aus 2b. Fällt eine davon durch, gibt es keine Aufgabe.

## 2b. Prüfregeln: drei Stufen, drei Prüfungen (Nutzer 26.10., Host 26.10.)

Regelwerk: AGENTS.md „Befunde: drei Stufen“. Es ersetzt „Keine Schwelle“ vom 20.10. und gilt ab Paket 33.

**Umfang:** Der Host prüft den Diff des Pakets gegen seine Aufgaben, das Konzept und die Invarianten. Er sucht nicht in fremdem Code nach neuen Befunden und gibt das auch keinem Agenten auf.

**Ablauf je Befund** (Host, Agent oder Worker):
1. **Nutzer sieht / Wann:** Beides konkret benennen. Fehlt eins, gilt Stufe 3, und der Befund ist hier zu Ende.
2. **Schon behoben?** Gegen den aktuellen Code prüfen. Mit `grep` in `DONE.md` und `archiv/paket-*-abgenommen-*.md` nach Stelle und Ursache suchen. Ist der Befund abgedeckt, zählt er nicht. Hält ein früherer Fix nicht, ist es eine Regression dieser Kennung.
3. **Bewusst so?** In `konzept/` nach „bewusst offen“ suchen, in der Aufgabe nach „So lassen“, in TODO.md nach „Entscheidungen“. Steht der Fall dort, ist es kein Befund, höchstens eine Frage an den Nutzer.
4. **Sinnvoll?** Brächte die Korrektur dem Nutzer etwas, das er bemerkt? Wenn nicht: Stufe 3.
5. **Stufe festlegen:**
   - **1:** Der Nutzer merkt es im normalen Gebrauch.
   - **2:** Der Nutzer merkt es nur bei seltener Folge. Ins Paket kommt es nur, wenn ein realistischer Test (ohne Haken, der eine Stelle anhält) oder die echte App es zeigt.
   - **3:** Sonst.

**Vorlage für den Auftrag eines Prüf-Agenten** (immer mitgeben, dazu Dateien, Aufgabe und Maßstab):
> Prüfe nur den Diff gegen die Aufgabe. Suche nicht in anderem Code nach neuen Fehlern. Nenne je Befund zuerst „Nutzer sieht: …“ und „Wann im normalen Gebrauch: …“, dann die Ereignisfolge (Datei:Zeile) und die Stufe 1/2/3 nach AGENTS.md. Melde nichts, was in `DONE.md` oder im Archiv schon behoben ist, was im Konzept als „bewusst offen“ oder in der Aufgabe unter „So lassen“ steht, und nichts über Schutzprüfungen oder Testlücken ohne Folge für den Nutzer. Bekannt und nicht zu melden: <Liste aus der letzten Abnahme>. „Nichts Wesentliches gefunden“ ist ein gutes Ergebnis.

**In der Antwort an den Nutzer** stehen nur Befunde der Stufen 1 und 2, jeder mit „Nutzer sieht / Wann / Stufe“. Stufe 3 steht höchstens als ein Satz da.

## 3. Prüfskript `Werkzeuge/pruefung.sh`

Aufruf aus beliebigem Ordner, im Hintergrund starten, **ohne `S=`** (Voreinstellung). Rohlogs liegen im Ordner `$S` = `$TMPDIR/pruefung.XXXXXX`. Ein `S` außerhalb von `$TMPDIR` (Repository, Scratch einer Sitzung) bricht das Skript ab.

**Platz und Aufräumen (Host 26.10., nach 167 GB Testresten bei 12 GB frei):**
- **Beim Start:** unter **25 GB** frei → Abbruch „zu wenig Platz“ (Exit 3) statt falscher Roter (Build, SQLite „disk full“). Danach werden ältere `pruefung.*`-Ordner unter `$TMPDIR` bis auf die **zwei neuesten** gelöscht; ein Ordner mit lebendem Lauf (PID in `.laeuft`) bleibt immer.
- **Während des Laufs:** das `.xcresult` jedes **grünen** Laufs (seriell, Parallel 1–3, schnell; grün heißt `result == Passed` und 0 rote Tests, ein Absturz ohne gezählten roten Test bleibt also erhalten) wird sofort gelöscht, ebenso das eines **erwartungsgemäß roten** Sabotage-Patches (rot ✓). Es bleiben nur die zur Fehlersuche nötigen: rote Läufe, nicht lesbare Ergebnisse, Patches mit „GRÜN ✗“. Logs und `zusammenfassung.txt` bleiben immer. Die Schlusszeile nennt die behaltenen `.xcresult`, die Ordnergröße und den freien Platz.
- `KEEP=1` behält DerivedData und alle `.xcresult` (nur zur Fehlersuche, danach von Hand löschen).
- Sitzungs-Scratch (`/private/tmp/claude-501/…/scratchpad`) räumt das Skript nicht; Host und Worker legen dort keine Builds und Testergebnisse ab (Regel 13).

```
Werkzeuge/pruefung.sh voll                    # Paketende
Werkzeuge/pruefung.sh schnell [Suite ...]     # je Aufgabe: Build + Warnungen + gezielte Suites
Werkzeuge/pruefung.sh sabotage                # nur die Patches aus todo/sabotage/: je Patch Kopie, Patch, genannte Tests → rot ✓ / GRÜN ✗
```

`voll` macht der Reihe nach: `clean build-for-testing` (Debug mit Testziel, Warnungen, Ziel 0), Gesamtlauf seriell, Parallellauf dreimal mit `-resultBundlePath` (rote Tests samt Fehlertext aus dem `.xcresult`), Release-Warnungen (Ziel 0), neue `Disk Archive*.ips` seit Start (Ziel 0), die Sabotage-Patches, Regel 14 (Nutzer-App ohne `-derivedDataPath` gebaut, Binary-Zeit, neuere `.swift`-Dateien, `codesign`, Version aus `Info.plist`) und löscht danach den eigenen DerivedData-Ordner (Aufräumen siehe oben). Das Ergebnis ist `$S/zusammenfassung.txt`; der Host liest nur sie und bei roten Tests die genannten Logs.

- **Pflege nur durch den Host** (AGENTS.md); der Worker ändert die Datei nicht und braucht sie nicht zu nutzen. Änderungen am Skript nennt der Host in der Commit-Nachricht.
- Setzt `DEVELOPER_DIR` selbst, wenn `/Applications/Xcode.app` vorhanden ist (Command Line Tools sind die Voreinstellung). Nichts am System ändern.
- Das Skript ersetzt nicht die Prüfung durch Lesen: grüne Zahlen beweisen nicht, dass Tests etwas beweisen.
- Hänger: macOS hat kein `timeout`; Hänger erkennt man an den Uhrzeiten in der Zusammenfassung.
- **Von Hand** (nur zur Fehlersuche): `xcodebuild … -only-testing:diskindexTests/<Suite>`; Fehlermeldungen roter Läufe: `xcrun xcresulttool get test-results tests --path <xcresult> --compact`.

## 4. Regel 14 (App des Nutzers)

Steckt im Skript. Der Nutzer startet die App aus `~/Library/Developer/Xcode/DerivedData/diskindex-*/Build (ab Paket 57 `DiskArchive-*`)/Products/Debug/Disk Archive.app` (der Hash wechselt mit dem Projektpfad); das Binary muss jünger sein als die letzte `.swift`-Datei und gültig signiert (Zertifikat „Apple Development“, Team `KATFD9R38G`). Ohne das baut der Host die App vor dem Nutzertest selbst.

## 5. Werkzeuge und Erfahrungen (Host 18.–21.10., dauerhaft)

- **Leistungsabnahmen selbst nachmessen,** wenn eine Abnahme an einer Zahl hängt (Beispiel `bug.0.4.077`): eigener Build mit `SWIFT_OPTIMIZATION_LEVEL=-O SWIFT_COMPILATION_MODE=wholemodule`, Varianten aus **demselben** Build im Wechsel (je 3 Läufe), Median; Umgebungsvariablen an den Test über `TEST_RUNNER_<NAME>=…`. Nie gleichzeitig mit anderen Testläufen messen. Danach den Build-Ordner löschen.
- **Auf einem neuen Rechner können Tests rot werden, die vorher grün waren** (andere macOS-Version, Rollbalken-Stil „automatisch“ mit Maus = dauerhaft). Erst prüfen, ob der Test auch auf dem letzten Commit rot ist; dann ist er kein Fehler des Pakets, sondern ein eigener `bug.*` – und meist ein echter Fehler der Oberfläche (Beispiel `bug.0.4.081`: Klickfläche nur die Beschriftung).
- **Funde des Nutzers aus der echten App** gehen vor Prüfbefunde. Belegen mit dem Protokoll (`~/Library/Application Support/Disk Archive/Logs/diskindex.log`, vor `bug.0.4.208` `~/Library/Logs/Disk Archive/diskindex.log`, nur lesen) und **nur lesend** mit der Datenbank (`sqlite3 -readonly ~/Library/Application\ Support/Disk\ Archive/archive.sqlite`; Abfragen über den Index `items_search_natural` brauchen die Kollation „natural“ und gehen in `sqlite3` nicht). Ursache, Code-Stelle und Test in die Aufgabe schreiben; Produktfragen beim Nutzer klären.
- **Mehrere Rechner:** Der Host kann auf einem anderen Mac arbeiten als der Nutzer (20.10.: MacBook Air, macOS 15.7.3; echte Datenbank mit drei Medien, 710 MB, und echtes Protokoll liegen auf dem Rechner des Nutzers, macOS 15.7.4). Funde aus der echten App lassen sich dann nicht belegen; den Nutzer um die Zeilen bitten. Zu Beginn prüfen: `sw_vers`, Größe von `archive.sqlite`.
- **Audit mit sechs Agenten (20.10., bewährt):** Bereiche gebündelt (1+4, 2+8, 3, 5, 6+9, 7), je Agent ein eigener Prompt mit „bekannte Befunde nicht melden“ und „lieber 5 belastbare als 20 Vermutungen“; Sonnet; Dauer 8–13 Minuten je Agent. Danach Stichproben des Hosts an den mittleren Befunden, dann Kennungen und Pakete.

## 6. Übergabe an einen neuen Host oder Rechner

Der Host schreibt `UEBERGABE.md` ins Hauptverzeichnis (flüchtiger Stand, offene Punkte, Hinweise für eine neue Maschine) und nennt sie in der Commit-Beschreibung. Der neue Host liest sie zuerst, prüft sie gegen das Repository und löscht sie dann. Dauerhaftes steht nur in AGENTS.md, dieser Datei, TODO.md, README und ROADMAP.

## 7. Dateien, die der Worker nie anfasst

Layout, README, `konzept/`, ROADMAP, DONE.md, AGENTS.md, TODO.md, `todo/regeln.md`, `todo/backlog.md`, `archiv/`, diese Datei und `Werkzeuge/pruefung.sh`. Er ändert im Paket-File `todo/paket-NN.md` nur das Feld „Status“ seiner Aufgabe und zum Schluss `PROMPT.md` (Regel 4 und 15).

## 8. Aufbau von `PROMPT.md` (Host schreibt, Worker ersetzt zum Schluss durch die Kurzmeldung)

Keine Überschriften, keine Erklärungen. Pflichtteile in dieser Reihenfolge:

1. **Erste Zeile, auffällig:** `⚠ Worker: Rolle Worker. Minimum Sonnet 5.5 Medium – läuft die Sitzung darunter, sofort melden und anhalten.`
2. Kennungen und Reihenfolge, HALT-Stelle.
3. 0 Warnungen (Debug mit Testziel, Release), fester Parallelbefehl, keine neuen `.ips`, kein Git.
4. Bericht endet mit Prompt für den Host plus Commit-Nachricht (Regel 15).

## 9. Warten auf den Worker (Loop, nur nach Rückfrage)

- **Immer fragen, einmal, am Ende der Freigabe-Antwort** (nach der Commit-Nachricht): „Commit-Nachricht oben, Aufgabe für den Worker bereit. Loop zur Kontrolle (alle 15 Minuten) starten?“ Ohne Ja des Nutzers wird nichts gestartet.
- **Umsetzung:** bevorzugt `Monitor` mit einer Schleife, die alle 15 Minuten nur `PROMPT.md` per `grep` auf den Anfang „Erledigt (Bereit zur Prüfung)“ prüft; beim Warten kostet das kein Modell, der Host wird erst beim Treffer geweckt und startet dann Abschnitt 2. Ohne `Monitor`: `CronCreate` mit `*/15 * * * *` (Prompt sinngemäß: „PROMPT.md lesen; beginnt sie nicht mit ‚Erledigt (Bereit zur Prüfung)‘, nur ‚Worker arbeitet noch‘ melden; sonst Loop per `CronDelete` beenden und die Paketprüfung starten“). Ohne beides schreibt der Nutzer „check“.
- Der Loop lebt nur in der laufenden Sitzung (Cron endet spätestens nach 7 Tagen). **„Stopp“ heißt sofort beenden,** ohne Rückfrage. Fragt der Nutzer nur nach einem Wert (z. B. Kontingent), einmal antworten, keinen Loop anlegen.

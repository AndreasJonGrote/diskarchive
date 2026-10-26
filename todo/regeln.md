# Regeln für den Worker (verbindlich)

Neu gefasst vom Host am 23.10.2026 (15 statt 31 Regeln, gleicher Inhalt, dazu Sabotage-Patch und Selbstprüfung). Alte Fassung und alte Nummern: `archiv/regeln-bis-2026-10-23.md`. Auftrag: das Paket `todo/paket-NN.md` aus [TODO.md](../TODO.md). Rollen: [AGENTS.md](../AGENTS.md).

> **⚠ Worker-Minimum: Sonnet 5.5 Medium.** Läuft die Sitzung darunter oder ist das Modell unklar: in der ersten Zeile melden und erst nach Bestätigung des Nutzers beginnen.

## Auftrag

1. **Nur das freigegebene Paket**, in seiner Reihenfolge. Am Ende **HALT**.
2. **Nichts erfinden.** Fehlt eine Vorgabe in Konzept oder Layout, oder verstößt die Vorgabe gegen eine Regel → „Frage:“ unter die Aufgabe. Neue Texte mit de und en, im Status als „Neue Texte:“.
3. **Nur die genannten Stellen ändern**, kein Refactoring nebenbei. Zeilenangaben sind Richtwerte; es gilt der Symbolname.
4. **Schreiben darfst du nur:** Quelltext unter `diskindex/`, das Feld „Status“ deiner Aufgabe (höchstens 5 Zeilen, „Bereit zur Prüfung“, nie „fertig“), Patches unter `todo/sabotage/` und zum Schluss PROMPT.md. Alles andere ist schreibgeschützt. Kein verändernder Git-Befehl (nur `status`, `log`, `diff`, `show`). Zeigt `git status` fremde Änderungen an `.swift`-Dateien → anhalten, „Frage:“. **Nicht fremd (Host 24.10.):** uncommittete Änderungen aus abgenommenen Paketen (in DONE.md bzw. `archiv/paket-*-abgenommen-*.md`) – der Nutzer committet oft erst später (unterwegs). Ein fehlender Commit ist kein Grund anzuhalten oder nachzufragen; Maßstab ist der Stand bei der Übergabe, nicht `HEAD`.

## Code

5. **Haupt-Thread und Zeichenpfad frei:** in `body`, `init`, `Binding(get:)` und `onAppear` keine Systemaufrufe und keine Zustandsänderungen; Datenbank, Dateisystem und Netz nie auf main. Achtung: Mit `NonisolatedNonsendingByDefault` läuft eine `nonisolated async`-Funktion ohne `@concurrent` auf dem Actor des Aufrufers, „async“ heißt nicht „Hintergrund“.
6. **Invarianten** (`konzept/architektur.md`): im Zweifel behalten; kein Medienzugriff in einer Schreibtransaktion, jeder Medienzugriff mit Zeitgrenze; Lauf-Zustand erst nach dem letzten Schreiben freigeben; nur auf Ereignisse des eigenen Mediums reagieren; in Protokoll und Bericht keine Namen, Pfade oder Fehlertexte (`DiskIndexLog.errorSummary`).
7. **Eine Quelle:** gemeinsame Bausteine (Knopf, Chip, Zeile, Kopf, Leerzustand) nur an der Quelle ändern; Maße nur aus `docs/Komponenten-Masse.md` (Messtest ±0,5 pt, hell und dunkel); Datenbankschema nur erweitern.

## Tests

8. **Erst rot, dann grün:** Den Test vor dem Fix laufen lassen und das Rot im Status belegen (Uhrzeit). Die Erwartung eines vorgegebenen Tests nicht ändern.
9. **Sabotage als Patch:** Für jede Verhaltensänderung eine Datei `todo/sabotage/<kennung>.patch` (bei mehreren `<kennung>-a.patch` …): ein `diff -u`, der den Fix gegen den Endstand zurücknimmt, Pfade `a/diskindex/…` bzw. `b/diskindex/…` (anwendbar mit `patch -p1` im Hauptverzeichnis). Erste Zeile `# Test: <Suite>/<testName>()` mit den Tests, die damit rot werden. Der Quelltext bleibt im Endstand. Der Host prüft jeden Patch automatisch; bleibt ein Test grün, ist die Aufgabe nicht abgenommen.
10. **Echt testen, ohne den Nutzer zu stören:** Ein Kettentest (Platte → FSEvents → Store → Meldung → Ansicht) löst nur den Anfang aus und ruft keinen Schritt der Kette selbst auf. Ansichten im echten Fenster außerhalb des Bildschirms (`x: -20000, y: -20000`, `orderFrontRegardless`), Beweis über Pixel (`PixelProbe`), Klicks nur per `window.sendEvent`. Nie: echte App starten, Bildschirmfotos, `makeKeyAndOrderFront`, `NSApp.activate`, `CGEvent`, Bedienungshilfen, UI-Tests.
11. **Stabil und ehrlich:** keine prozessweiten Schalter (`static var`, Umgebungsvariablen) – Parameter oder Instanz-Haken; kein `!`, kein `array[i]` ohne `try #require`; auf Bedingungen warten statt feste Zeiten, Negativprüfung erst nach einem positiven Signal; keine exakten Zählvergleiche auf asynchrone Ereignisse; kein `lock()` über `await`. Bei Rot die Ursache beheben – nie Frist verlängern, Test abschwächen oder wiederholen. Was schon einmal kaputt war, bekommt eine Zeile im Rauchtest (`RegressionSmokeTests`).
12. **Selbstprüfung nach jeder Aufgabe:** Ein Subagent (Sonnet, nur lesend) prüft den Diff der Aufgabe gegen ihren Text und beantwortet fünf Fragen:
    1. **Zeitfenster:** Kann sich zwischen Lesen und Schreiben (über `await`, zweite Transaktion, Medienzugriff) etwas ändern – und was passiert dann?
    2. **Löschen:** Wird bei Unklarheit (nicht gelesen, Fehler, Zeitüberschreitung) behalten statt gelöscht?
    3. **Fremde Ereignisse:** Kann etwas anderes (anderes Medium, globaler Zähler, späte Meldung) eine Nutzeraktion abbrechen oder auslösen?
    4. **Alte Reste:** Können Daten früherer Läufe oder anderer Medien (Protokoll, Merker, Cache) das Ergebnis verfälschen?
    5. **Beweis:** Wird der Test mit dem Patch aus Regel 9 rot?

    **Was ein Befund ist (Supervisor/Nutzer 25.10.):** eine **konkrete Folge von Ereignissen**, als Test schreibbar, **plus** das Verhalten, das dabei falsch ist. „Was wäre wenn“ ohne solche Folge zählt nicht. Ab `bug.0.4.204` gilt je Medium höchstens ein Lebenszyklus „Start → Lauf → Abschluss/Abbruch“ (`IndexingService`, Wächter in DEBUG): zwei Läufe desselben Mediums gleichzeitig heißt, Marker oder Wächter sind falsch – dort beheben, kein neuer Flicken.

    Mittlere und hohe Befunde vor „Bereit“ beheben, den Rest als „Frage:“. Sind Zeitabläufe beteiligt (Scrollen, FSEvents, Warteschlangen): die Suite 20× im Parallellauf, Uhrzeit im Status.

## Abschluss

13. **Läufe:** nach jeder Aufgabe die betroffenen Suites; am Paketende seriell und dreimal parallel, alle grün; Debug mit Testziel und Release 0 Warnungen; keine neuen `Disk Archive*.ips`. Befehle: Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`, Warnungen `| grep "warning:" | grep -v appintents | sort -u | wc -l`; Tests `xcodebuild test-without-building … -only-testing:diskindexTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -parallel-testing-enabled NO|YES`. Leistungszahlen nur im Release (`DA_BENCH`). Hilfe: `Werkzeuge/pruefung.sh schnell <Suite>`. **Platz (Host 26.10.):** Vor Beginn `df -h /`; unter 25 GB frei → „Frage:“ und HALT. `-derivedDataPath` und `-resultBundlePath` nur in **einen festen Ordner** unter `$TMPDIR` (z. B. `$TMPDIR/worker-dd` und `$TMPDIR/worker-xcresult`), wiederverwenden statt je Build neu, ein `.xcresult` vor dem nächsten Lauf löschen; **nie** im Scratch der Sitzung (`/private/tmp/claude-…/scratchpad`), nie im Repository. Am Paketende beide Ordner löschen.
14. **Zum Schluss die App des Nutzers bauen:** `xcodebuild build -project diskindex.xcodeproj -scheme diskindex -configuration Debug -destination 'platform=macOS'` **ohne** `-derivedDataPath`; Beleg: `find diskindex -name '*.swift' -newer <…/Disk Archive.app/Contents/MacOS/Disk Archive>` ist leer, beide Uhrzeiten in den Status.
15. **Bericht:** im Chat (1) ein Prompt für den Host (Codeblock, höchstens 12 Zeilen: Kennungen, Dateien, Belege, Zahl der Patches, offene Fragen; letzte Zeile „Prüfe die genannten Aufgaben und gib mir den nächsten Prompt.“) und (2) eine Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Dann den ganzen Inhalt von PROMPT.md ersetzen durch: `Erledigt (Bereit zur Prüfung): <Kennungen>. Offen/blockiert: <… oder –>. HALT.` Abnahme macht nur der Host.

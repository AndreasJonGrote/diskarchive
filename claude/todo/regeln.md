# Regeln für den Worker (verbindlich)

Neu gefasst vom Host am 23.10.2026 (15 statt 31 Regeln, gleicher Inhalt, dazu Sabotage-Patch und Selbstprüfung). Alte Fassung und alte Nummern: in Git (gelöscht 31.10.). Auftrag: das Paket `todo/paket-NN.md` aus [TODO.md](../TODO.md). Rollen: [AGENTS.md](../AGENTS.md).

> **⚠ Worker-Minimum: Sonnet 5.5 Medium.** Läuft die Sitzung darunter oder ist das Modell unklar: in der ersten Zeile melden und erst nach Bestätigung des Nutzers beginnen.

> **Sprache: Deutsch (Nutzer 28.10.).** Jede Antwort im Chat, jeder Zwischenstand, Status, Bericht, Prompt für den Host und jeder Code-Kommentar ist auf Deutsch, auch wenn Werkzeuge oder Fehlermeldungen englisch sind. Englisch nur in Bezeichnern, Befehlen, Zitaten und den `en`-Texten der Lokalisierung.

## Auftrag

1. **Nur das freigegebene Paket**, in seiner Reihenfolge. Am Ende **HALT**.
2. **Nichts erfinden.** Fehlt eine Vorgabe in Konzept oder Layout, oder verstößt die Vorgabe gegen eine Regel → „Frage:“ unter die Aufgabe. Neue Texte mit de und en, im Status als „Neue Texte:“.
3. **Nur die genannten Stellen ändern**, kein Refactoring nebenbei und kein Umbau ohne sichtbaren Grund (z. B. Typen verschärfen, nur weil es sauberer ist). Zeilenangaben sind Richtwerte; es gilt der Symbolname.
4. **Schreiben darfst du nur:** Quelltext unter `DiskArchive/`, das Feld „Status“ deiner Aufgabe (höchstens 5 Zeilen, „Bereit zur Prüfung“, nie „fertig“), Patches unter `todo/sabotage/` und zum Schluss PROMPT.md. Alles andere ist schreibgeschützt. Kein verändernder Git-Befehl (nur `status`, `log`, `diff`, `show`). Zeigt `git status` fremde Änderungen an `.swift`-Dateien → anhalten, „Frage:“. **Nicht fremd (Host 24.10.):** uncommittete Änderungen aus abgenommenen Paketen (in DONE.md bzw. `archiv/paket-*-abgenommen-*.md`) – der Nutzer committet oft erst später (unterwegs). Ein fehlender Commit ist kein Grund anzuhalten oder nachzufragen; Maßstab ist der Stand bei der Übergabe, nicht `HEAD`.

## Code

5. **Haupt-Thread und Zeichenpfad frei:** in `body`, `init`, `Binding(get:)` und `onAppear` keine Systemaufrufe und keine Zustandsänderungen; Datenbank, Dateisystem und Netz nie auf main. Achtung: Mit `NonisolatedNonsendingByDefault` läuft eine `nonisolated async`-Funktion ohne `@concurrent` auf dem Actor des Aufrufers, „async“ heißt nicht „Hintergrund“.
6. **Invarianten** (`konzept/architektur.md`): im Zweifel behalten; kein Medienzugriff in einer Schreibtransaktion, jeder Medienzugriff mit Zeitgrenze; Lauf-Zustand erst nach dem letzten Schreiben freigeben; nur auf Ereignisse des eigenen Mediums reagieren; in Protokoll und Bericht keine Namen, Pfade oder Fehlertexte (`DiskIndexLog.errorSummary`).
7. **Eine Quelle:** gemeinsame Bausteine (Knopf, Chip, Zeile, Kopf, Leerzustand) nur an der Quelle ändern; Maße nur aus `docs/Komponenten-Masse.md` (Messtest ±0,5 pt, hell und dunkel); Datenbankschema nur erweitern.

## Tests

8. **Erst rot, dann grün:** Den Test vor dem Fix laufen lassen und das Rot im Status belegen (Uhrzeit). Die Erwartung eines vorgegebenen Tests nicht ändern.
9. **Sabotage als Patch:** Für jede Verhaltensänderung eine Datei `todo/sabotage/<kennung>.patch` (bei mehreren `<kennung>-a.patch` …): ein `diff -u`, der den Fix gegen den Endstand zurücknimmt, Pfade `a/DiskArchive/…` bzw. `b/DiskArchive/…` (anwendbar mit `patch -p1` im Hauptverzeichnis). Erste Zeile `# Test: <Suite>/<testName>()` mit den Tests, die damit rot werden (mehrere: je Zeile einer oder mit Komma getrennt). Der Quelltext bleibt im Endstand. Der Host prüft jeden Patch automatisch; bleibt ein Test grün, ist die Aufgabe nicht abgenommen.
10. **Echt testen, ohne den Nutzer zu stören:** Ein Kettentest (Platte → FSEvents → Store → Meldung → Ansicht) löst nur den Anfang aus und ruft keinen Schritt der Kette selbst auf. Ansichten im echten Fenster außerhalb des Bildschirms (`x: -20000, y: -20000`, `orderFrontRegardless`), Beweis über Pixel (`PixelProbe`), Klicks nur per `window.sendEvent`. Nie: echte App starten, Bildschirmfotos, `makeKeyAndOrderFront`, `NSApp.activate`, `CGEvent`, Bedienungshilfen, UI-Tests.
11. **Stabil und ehrlich:** keine prozessweiten Schalter (`static var`, Umgebungsvariablen) – Parameter oder Instanz-Haken; kein `!`, kein `array[i]` ohne `try #require`; auf Bedingungen warten statt feste Zeiten, Negativprüfung erst nach einem positiven Signal; keine exakten Zählvergleiche auf asynchrone Ereignisse; kein `lock()` über `await`. Bei Rot die Ursache beheben – nie Frist verlängern, Test abschwächen oder wiederholen. Was schon einmal kaputt war, bekommt eine Zeile im Rauchtest (`RegressionSmokeTests`).
12. **Selbstprüfung nach jeder Aufgabe:** Ein Subagent (Sonnet, nur lesend) prüft den Diff der Aufgabe gegen ihren Text und beantwortet fünf Fragen:
    1. **Zeitfenster:** Kann sich zwischen Lesen und Schreiben (über `await`, zweite Transaktion, Medienzugriff) etwas ändern – und was passiert dann?
    2. **Löschen:** Wird bei Unklarheit (nicht gelesen, Fehler, Zeitüberschreitung) behalten statt gelöscht?
    3. **Fremde Ereignisse:** Kann etwas anderes (anderes Medium, globaler Zähler, späte Meldung) eine Nutzeraktion abbrechen oder auslösen?
    4. **Alte Reste:** Können Daten früherer Läufe oder anderer Medien (Protokoll, Merker, Cache) das Ergebnis verfälschen?
    5. **Beweis:** Wird der Test mit dem Patch aus Regel 9 rot?

    **Was ein Befund ist (Nutzer 26.10., AGENTS.md „Befunde: drei Stufen“):**
    - Jeder Befund nennt zuerst „Nutzer sieht: …“ und „Wann im normalen Gebrauch: …“, dann die konkrete Ereignisfolge und die Stufe. Fehlt eine Antwort, ist es Stufe 3.
    - Gesucht wird nur im eigenen Diff.
    - Vor dem Melden laufen die drei Prüfungen:
      - Schon behoben? (gegen den aktuellen Code, `DONE.md`, Archiv)
      - Bewusst so? („bewusst offen“ im Konzept, „So lassen“ in der Aufgabe)
      - Sinnvoll? (Merkt der Nutzer die Korrektur?)
    - Den Auftrag des Subagenten nach der Vorlage in `abnahme-ablauf.md` 2b schreiben.

    Ab `bug.0.4.204` gilt je Medium höchstens ein Lebenszyklus „Start → Lauf → Abschluss/Abbruch“ (`IndexingService`, Wächter in DEBUG): zwei Läufe desselben Mediums gleichzeitig heißt, Marker oder Wächter sind falsch – dort beheben, kein neuer Flicken.

    Was mit einem Befund geschieht:
    - **Stufe 1** vor „Bereit“ beheben.
    - **Stufe 2** nur beheben, wenn sie im realistischen Test (ohne Haken, der eine Stelle anhält) oder in der echten App auftritt. Sonst genügt eine Zeile „Stufe 2: …“ im Status.
    - **Stufe 3** weder beheben noch als Frage stellen, höchstens eine Zeile „Stufe 3: …“.

    „Frage:“ ist nur für Entscheidungen da, nicht für Befunde. „Nichts Wesentliches gefunden“ ist ein gutes Ergebnis. Sind Zeitabläufe beteiligt (Scrollen, FSEvents, Warteschlangen): die Suite 20× im Parallellauf, Uhrzeit im Status.

## Abschluss

13. **Läufe (Nutzer 28.10.: keine Gesamtläufe mehr beim Worker):** nach jeder Aufgabe die betroffenen Suites, Test vor dem Fix rot und danach grün; die Sabotage-Patches; bei Zeitabläufen die betroffene Suite 20× parallel (Regel 12); am Paketende **einmal** Debug mit Testziel bauen, 0 Warnungen. **Nicht** mehr: serieller Gesamtlauf, dreimal parallel, Release-Build. Das macht allein der Host (`Werkzeuge/pruefung.sh voll`), nur sein Lauf zählt. Befehle: Build `xcodebuild clean build-for-testing -project DiskArchive.xcodeproj -scheme DiskArchive -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`, Warnungen `| grep "warning:" | grep -v appintents | sort -u | wc -l`; Tests `xcodebuild test-without-building … -only-testing:DiskArchiveTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -parallel-testing-enabled NO|YES`. Leistungszahlen nur im Release (`DA_BENCH`). Hilfe: `Werkzeuge/pruefung.sh schnell <Suite>`. **Platz (Host 26.10.):** Vor Beginn `df -h /`; unter 25 GB frei → „Frage:“ und HALT. `-derivedDataPath` und `-resultBundlePath` nur in **einen festen Ordner** unter `$TMPDIR` (z. B. `$TMPDIR/worker-dd` und `$TMPDIR/worker-xcresult`), wiederverwenden statt je Build neu, ein `.xcresult` vor dem nächsten Lauf löschen; **nie** im Scratch der Sitzung (`/private/tmp/claude-…/scratchpad`), nie im Repository. Am Paketende beide Ordner löschen.
14. **App des Nutzers:** baut der Host mit `pruefung.sh voll` (Nutzer 28.10.). Der Worker baut sie nicht.
15. **Bericht:** im Chat (1) ein Prompt für den Host (Codeblock, höchstens 12 Zeilen: Kennungen, Dateien, Belege, Zahl der Patches, offene Fragen; letzte Zeile „Prüfe die genannten Aufgaben und gib mir den nächsten Prompt.“) und (2) eine Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Dann den ganzen Inhalt von PROMPT.md ersetzen durch: `Erledigt (Bereit zur Prüfung): <Kennungen>. Offen/blockiert: <… oder –>. HALT.` Abnahme macht nur der Host.

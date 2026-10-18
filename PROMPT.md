Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–31, Abschnitt A, Paket 12). Paket 11 ist vom Host abgenommen (Prüfung 18.10. 16:36–17:04 auf dem neuen Rechner, macOS 15.7.4: 0 Warnungen, seriell 872/873, parallel je 1 rot – nur `thePathHeaderToggles…`, jetzt `bug.0.4.081`; Nachmessung 077 +5,2 %; drei Prüf-Agenten ohne hohen Befund). Paket 12 enthält **zuerst sieben Funde des Nutzers vom 18.10. abends** (erster Start der App mit seiner Datenbank, siehe Hintergrund in TODO.md), danach die Befunde dieser Prüfung; es ist das letzte Code-Paket von 0.4.0.

Reihenfolge (verbindlich):
1. `bug.0.4.086`: ein Pool je Prozess für `archive.sqlite` (Warteschlange und Fehlerbericht nutzen ihn mit), Migration genau einmal und vor jedem anderen Zugriff, lange Migration ist kein Fehler und blockiert die Oberfläche nicht; Test über die echte Startkette mit großer Datenbank ohne die letzte Migration. Sabotage rot ✓.
2. `bug.0.4.087`: automatisches Scrollen zur Details-Spalte bzw. neuen Spalte (README „Automatisch nach rechts“) wiederherstellen; Fenstertest, Zeile im Rauchtest. Sabotage rot ✓.
3. `bug.0.4.088`: Ignorieren und Wieder-Freigeben blenden Einträge an Ort und Stelle aus bzw. ein (kurz weggleiten), kein Ladezustand, kein Neuladen der Spalten; Fenstertest mit Abtastung während der Warteschlange. Sabotage rot ✓.
4. `bug.0.4.090`: Spaltenansicht eines Mediums bleibt nach Ignorieren/Freigeben gestört, Details-Spalte fehlt – hängenden Spaltenzustand finden und zurücksetzen; Details hängen nur an der Spalte der Auswahl; Fenstertest über die echte Kette. Sabotage rot ✓.
5. `bug.0.4.089`: Trennlinie zwischen allen Spalten in jedem Zustand; Pixeltest hell/dunkel. Sabotage rot ✓.
6. `bug.0.4.091`: Platz für den Rollbalken immer reservieren (zentraler Baustein, Breite nach Systemstil), alle Einstellungs-Tabs gleich breit, kein Springen beim Tab-Wechsel; Fenstertest mit dauerhaftem und Overlay-Stil. Sabotage rot ✓.
7. `bug.0.4.092`: reine Filtersuche ohne Suchbegriff zeigt keine Medien-Kacheln, Medien nur als Namenstreffer eines Suchbegriffs (auch Popover-Suche); Test. Sabotage rot ✓.
8. `bug.0.4.081`: Sortierkopf „Status“ auf macOS 15 – Ursache im echten Testfenster belegen (Klick/hitTest an linkem Rand, Mitte, rechtem Rand jedes sortierbaren Kopfes), Fix zentral in `TableSortHeader` (ganze Spaltenbreite klickbar); neuer Fenstertest hell/dunkel; `thePathHeaderToggles…` auf diesem Mac in allen Läufen grün, Erwartung unverändert. Sabotage rot ✓.
9. `bug.0.4.082`: Zeilenumbrüche in Protokollnachrichten ersetzen; `$s`-Ausnahme nur für das Symbol nach der Adresse; Test mit „12 x 0x1 $Sgeheim.pdf“ über Zeilenumbruch. Sabotage rot ✓.
10. `bug.0.4.083`: Kürzungsreihenfolge (Brotkrumen, Rahmen bis Rahmen 0, `logTail` bis 20, `actions`); zwei Tests laut Aufgabe. Sabotage rot ✓.
11. `bug.0.4.084`: Live-Überwachung startet auch nach einem Lauf mit Fehler (angeschlossen, „Indizieren: Ja“, nicht pausiert, nicht gesperrt); Test über die echte Kette (Regel 18). Sabotage rot ✓.
12. `bug.0.4.085` a)–e): Kleinkram laut Aufgabe.

Regel 31: nach jeder Aufgabe Selbstprüfung mit Subagent, am Ende einmal selbst korrigieren. Laufzeitgrenzen, die bewusst Laufzeit messen, nicht lockern; Regel 18 und 20 für jeden geänderten Test; ein Test, der immer grün ist, zählt nicht.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Ist `xcodebuild` nicht aktiv: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status (rote Tests im Parallellauf aus dem `.xcresult`: `xcrun xcresulttool get test-results summary --path <xcresult> --compact`); ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Ziel: **alle Läufe grün**. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen je Aufgabe). Nicht anfassen: `todo.0.4.020`–`022`, `024`, `040`, `todo.0.4.1.*`, alles in B.

HALT nach Punkt 12. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
